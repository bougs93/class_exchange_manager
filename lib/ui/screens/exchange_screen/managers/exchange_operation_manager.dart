import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../../services/excel_service.dart';
import '../../../../services/exchange_history_service.dart';
import '../../../../services/timetable_storage_service.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/non_exchangeable_manager.dart';
import '../../../../models/exchange_mode.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../ui/dialogs/exchange_data_reset_dialog.dart';
import '../../../../ui/dialogs/same_content_file_dialog.dart';
import '../exchange_screen_state_proxy.dart';

/// 파일 선택, 로딩, 교체 모드 전환 등 핵심 비즈니스 로직을 관리하는 Manager
///
/// ExchangeFileHandler와 ExchangeModeHandler Mixin을 대체합니다.
class ExchangeOperationManager {
  final BuildContext context;
  final WidgetRef ref;
  final ExchangeScreenStateProxy stateProxy;
  final VoidCallback onCreateSyncfusionGridData;
  final VoidCallback onClearAllExchangeStates;
  final VoidCallback onRefreshHeaderTheme;

  // 서비스들 (Provider에서 가져옴 - 지연 초기화)
  late final ExchangeHistoryService _historyService;
  late final NonExchangeableManager _nonExchangeableManager;
  late final TimetableStorageService _timetableStorageService;

  ExchangeOperationManager({
    required this.context,
    required this.ref,
    required this.stateProxy,
    required this.onCreateSyncfusionGridData,
    required this.onClearAllExchangeStates,
    required this.onRefreshHeaderTheme,
  }) {
    // Provider에서 서비스 가져오기
    _historyService = ref.read(exchangeHistoryServiceProvider);
    _timetableStorageService = ref.read(timetableStorageServiceProvider);
    _nonExchangeableManager = NonExchangeableManager();
  }

  // ===== 파일 관리 =====

  /// Excel 파일 선택
  /// 
  /// Returns: 파일 선택 성공 여부 (true: 성공, false: 취소 또는 실패)
  Future<bool> selectExcelFile() async {
    stateProxy.setLoading(true);
    stateProxy.setErrorMessage(null);

    try {
      bool success = false;
      if (kIsWeb) {
        success = await _selectExcelFileWeb();
      } else {
        success = await _selectExcelFileNative();
      }
      return success;
    } catch (e) {
      stateProxy.setErrorMessage('파일 선택 중 오류가 발생했습니다: $e');
      return false;
    } finally {
      stateProxy.setLoading(false);
    }
  }

  Future<bool> _selectExcelFileWeb() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final bytes = result.files.first.bytes;
      if (bytes != null) {
        await processExcelBytes(bytes);
        return true; // 파일 선택 성공
      }
    }
    return false; // 파일 선택 취소 또는 실패
  }

  Future<bool> _selectExcelFileNative() async {
    File? file = await ExcelService.pickExcelFile();

    if (file != null) {
      stateProxy.setSelectedFile(file);
      await loadExcelData();
      return true; // 파일 선택 성공
    }
    return false; // 파일 선택 취소
  }

  Future<void> loadExcelData() async {
    if (stateProxy.selectedFile == null) return;

    try {
      Excel? excel = await ExcelService.readExcelFile(stateProxy.selectedFile!);

      if (excel != null) {
        bool isValid = ExcelService.isValidExcelFile(excel);

        if (isValid) {
          await parseTimetableData(excel);
        } else {
          stateProxy.setErrorMessage('유효하지 않은 엑셀 파일입니다.');
        }
      } else {
        stateProxy.setErrorMessage('엑셀 파일을 읽을 수 없습니다.');
      }
    } catch (e) {
      stateProxy.setErrorMessage('파일 로딩 중 오류: $e');
    }
  }

  Future<void> processExcelBytes(Uint8List bytes) async {
    try {
      // Web에서는 bytes를 Excel로 직접 변환
      Excel excel = Excel.decodeBytes(bytes);

      bool isValid = ExcelService.isValidExcelFile(excel);

      if (isValid) {
        await parseTimetableData(excel);
      } else {
        stateProxy.setErrorMessage('유효하지 않은 엑셀 파일입니다.');
      }
    } catch (e) {
      stateProxy.setErrorMessage('파일 처리 중 오류: $e');
    }
  }

  Future<void> parseTimetableData(Excel excel) async {
    TimetableData? timetableData = ExcelService.parseTimetableData(excel);

    if (timetableData != null) {
      // 파일 변경 감지 및 초기화 확인
      final selectedFile = stateProxy.selectedFile;
      if (selectedFile != null) {
        final filePath = selectedFile.path;
        final fileName = filePath.split(Platform.pathSeparator).last;
        
        // 1. 동일한 내용의 파일인지 확인 (내용 해시 비교)
        final isSameContent = await _timetableStorageService.isSameContent(filePath);
        
        if (isSameContent == true) {
          // 동일한 내용의 파일이면 확인 다이얼로그 표시
          // async gap 이후 BuildContext 사용 시 안전성을 위해 mounted 체크와 try-catch로 보호
          
          // 위젯이 여전히 마운트되어 있는지 확인
          if (!context.mounted) {
            // 위젯이 dispose된 경우 처리 중단
            stateProxy.setErrorMessage('파일 로드 중 위젯이 닫혔습니다.');
            return;
          }
          
          try {
            // async gap 이후 context 사용 - mounted 체크로 안전성 확보
            // 다이얼로그 반환값: true = YES (초기화), false = NO (보존), null = 기본값 NO
            final shouldReset = await SameContentFileDialog.show(context) ?? false; // 기본값 NO (보존)
            
            if (shouldReset == true) {
              // 사용자가 YES를 선택한 경우 (기존 작업 정보 초기화)
              _clearHistoryAndExchangeList();
            }
            // NO를 선택한 경우(shouldReset == false)는 기존 작업 정보 보존
          } catch (e) {
            // 위젯이 dispose되었거나 context가 유효하지 않은 경우 처리 중단
            stateProxy.setErrorMessage('파일 로드 중 오류가 발생했습니다: $e');
            return;
          }
        } else {
          // 2. 파일 내용이 다른 경우 변경 확인
          final isModified = await _timetableStorageService.isFileModified(filePath);
          
          if (isModified) {
            // 파일이 변경되었으면 초기화 확인 다이얼로그 표시
            // async gap 이후 BuildContext 사용 시 안전성을 위해 mounted 체크와 try-catch로 보호
            bool? shouldReset;
            
            // 위젯이 여전히 마운트되어 있는지 확인
            if (!context.mounted) {
              // 위젯이 dispose된 경우 처리 중단
              stateProxy.setErrorMessage('파일 로드 중 위젯이 닫혔습니다.');
              return;
            }
            
            try {
              // async gap 이후 context 사용 - mounted 체크로 안전성 확보
              shouldReset = await ExchangeDataResetDialog.show(
                context,
                message: '엑셀 파일이 변경되었습니다. 저장된 시간표 데이터와 교체 리스트를 초기화하시겠습니까?',
              );
            } catch (e) {
              // 위젯이 dispose되었거나 context가 유효하지 않은 경우 처리 중단
              stateProxy.setErrorMessage('파일 로드 중 오류가 발생했습니다: $e');
              return;
            }
            
            if (shouldReset == true) {
              // 사용자가 초기화를 확인한 경우
              _clearHistoryAndExchangeList();
            } else if (shouldReset == false) {
              // 사용자가 취소한 경우 파싱 중단
              stateProxy.setErrorMessage('파일 로드를 취소했습니다.');
              return;
            }
          }
        }
        
        // 시간표 데이터 저장
        await _timetableStorageService.saveTimetableData(
          timetableData,
          filePath,
          fileName,
        );
      } else {
        // Web 플랫폼의 경우 파일 경로가 없으므로 메타데이터 저장 건너뛰기
        // 필요시 Web에서도 저장할 수 있도록 확장 가능
      }
      
      // 새로운 파일이거나 파일이 변경된 경우에만 초기화
      // (파일이 변경되지 않았고 사용자가 초기화하지 않기로 한 경우는 초기화하지 않음)
      // 첫 로드인 경우(isModified가 false이고 메타데이터가 없는 경우)에는 초기화하지 않음
      // 이 부분은 파일이 변경되지 않은 경우 초기화를 하지 않도록 함
      
      // 교체불가 관리자에 새로운 TimeSlot 데이터 설정
      _nonExchangeableManager.setTimeSlots(timetableData.timeSlots);
      
      stateProxy.setTimetableData(timetableData);
      onCreateSyncfusionGridData();
      
      // 파일 선택 후 보기 모드로 전환
      stateProxy.setCurrentMode(ExchangeMode.view);
      
      AppLogger.exchangeInfo('파일이 선택되고 보기 모드로 전환되었습니다.');
    } else {
      stateProxy.setErrorMessage('시간표 데이터를 파싱할 수 없습니다.');
    }
  }

  /// 히스토리와 교체리스트 초기화 (파일 선택 해제 또는 새로 읽기 시 호출)
  void _clearHistoryAndExchangeList() {
    try {
      // 교체 리스트 전체 삭제
      _historyService.clearExchangeList();

      // 되돌리기 스택도 초기화
      _historyService.clearUndoStack();
      
      // 모든 교체불가 설정 초기화 (timeslot.isExchangeable = true로 복원)
      _nonExchangeableManager.resetAllNonExchangeableSettings();
      
      AppLogger.exchangeInfo('히스토리, 교체리스트, 교체불가 설정이 모두 초기화되었습니다.');
    } catch (e) {
      AppLogger.error('상태 초기화 중 오류 발생: $e');
    }
  }

  /// 엑셀 파일 선택 해제 (모든 상태 초기화)
  void clearSelectedFile() {
    // 히스토리와 교체리스트 초기화
    _clearHistoryAndExchangeList();
    
    // 파일 관련 상태 초기화
    stateProxy.setSelectedFile(null);
    stateProxy.setTimetableData(null);
    stateProxy.setErrorMessage(null);
    
    // 교체 관련 상태 초기화
    onClearAllExchangeStates();
    
    // 파일 선택 해제 후 보기 모드로 전환
    stateProxy.setCurrentMode(ExchangeMode.view);
    
    AppLogger.exchangeInfo('엑셀 파일 선택이 해제되고 보기 모드로 전환되었습니다.');
  }

  /// 교체불가 관리자 접근 (외부에서 사용)
  NonExchangeableManager get nonExchangeableManager => _nonExchangeableManager;

  // ===== 교체 모드 관리 =====

  /// 1:1 교체 모드 토글
  ///
  /// **처리 순서**:
  /// 1. 다른 모드 비활성화 (순환/연쇄)
  /// 2. 교체불가 편집 모드 비활성화
  /// 3. 1:1 교체 모드 활성화/비활성화
  /// 4. 활성화 시: Level 2 초기화 + 단계 설정 (2단계만)
  /// 5. 헤더 테마 업데이트
  /// 6. 사용자 피드백 (SnackBar)
  void toggleExchangeMode() {
    bool wasEnabled = stateProxy.isExchangeModeEnabled;
    bool hasOtherModesActive =
        stateProxy.isCircularExchangeModeEnabled ||
        stateProxy.isChainExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    if (hasOtherModesActive) {
      stateProxy.setCircularExchangeModeEnabled(false);
      stateProxy.setChainExchangeModeEnabled(false);
    }

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 1:1 교체 모드 토글
    stateProxy.setExchangeModeEnabled(!wasEnabled);

    if (stateProxy.isExchangeModeEnabled) {
      // 4. 활성화: Level 2 초기화 + 단계 설정
      onClearAllExchangeStates();
      stateProxy.setAvailableSteps([2]); // 1:1 교체는 2단계만 가능
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    } else {
      // 비활성화: 단계 설정만 초기화
      stateProxy.setAvailableSteps([]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    }

    // 5. 헤더 테마 업데이트
    onRefreshHeaderTheme();

    // 6. 사용자 피드백
    if (stateProxy.isExchangeModeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('1:1교체 모드가 활성화되었습니다. 두 교사의 시간을 서로 교체할 수 있습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 순환교체 모드 토글
  ///
  /// **처리 순서**:
  /// 1. 다른 모드 비활성화 (1:1/연쇄)
  /// 2. 교체불가 편집 모드 비활성화
  /// 3. 순환교체 모드 활성화/비활성화
  /// 4. 활성화 시: Level 2 초기화 + 단계 설정 (2~5단계)
  /// 5. 헤더 테마 업데이트
  /// 6. 사용자 피드백 (SnackBar)
  void toggleCircularExchangeMode() {
    AppLogger.exchangeDebug(
      '순환교체 모드 토글 시작 - 현재 상태: ${stateProxy.isCircularExchangeModeEnabled}',
    );

    bool wasEnabled = stateProxy.isCircularExchangeModeEnabled;
    bool hasOtherModesActive =
        stateProxy.isExchangeModeEnabled || stateProxy.isChainExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    if (hasOtherModesActive) {
      stateProxy.setExchangeModeEnabled(false);
      stateProxy.setChainExchangeModeEnabled(false);
    }

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 순환교체 모드 토글
    stateProxy.setCircularExchangeModeEnabled(!wasEnabled);

    if (stateProxy.isCircularExchangeModeEnabled) {
      // 4. 활성화: Level 2 초기화 + 단계 설정
      onClearAllExchangeStates();
      stateProxy.setAvailableSteps([2, 3, 4, 5]); // 순환: 2~5단계
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    } else {
      // 비활성화: 단계 설정만 초기화
      stateProxy.setAvailableSteps([]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    }

    // 5. 헤더 테마 업데이트
    onRefreshHeaderTheme();

    // 6. 사용자 피드백
    if (stateProxy.isCircularExchangeModeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('순환교체 모드가 활성화되었습니다. 여러 교사의 시간을 순환 교체할 수 있습니다.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 연쇄교체 모드 토글
  ///
  /// **처리 순서**:
  /// 1. 다른 모드 비활성화 (1:1/순환)
  /// 2. 교체불가 편집 모드 비활성화
  /// 3. 연쇄교체 모드 활성화/비활성화
  /// 4. 활성화 시: Level 2 초기화 + 단계 설정 (2~5단계)
  /// 5. 헤더 테마 업데이트
  /// 6. 사용자 피드백 (SnackBar)
  void toggleChainExchangeMode() {
    AppLogger.exchangeDebug(
      '연쇄교체 모드 토글 시작 - 현재 상태: ${stateProxy.isChainExchangeModeEnabled}',
    );

    bool wasEnabled = stateProxy.isChainExchangeModeEnabled;
    bool hasOtherModesActive =
        stateProxy.isExchangeModeEnabled ||
        stateProxy.isCircularExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    if (hasOtherModesActive) {
      stateProxy.setExchangeModeEnabled(false);
      stateProxy.setCircularExchangeModeEnabled(false);
    }

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 연쇄교체 모드 토글
    stateProxy.setChainExchangeModeEnabled(!wasEnabled);

    if (stateProxy.isChainExchangeModeEnabled) {
      // 4. 활성화: Level 2 초기화 + 단계 필터 강제 비활성화
      onClearAllExchangeStates();
      stateProxy.setAvailableSteps([]); // 연쇄교체: 단계 필터 불필요
      stateProxy.setSelectedStep(null); // 단계 필터 강제 초기화
      stateProxy.setSelectedDay(null);
    } else {
      // 비활성화: 단계 설정만 초기화
      stateProxy.setAvailableSteps([]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    }

    // 5. 헤더 테마 업데이트
    onRefreshHeaderTheme();

    // 6. 사용자 피드백 - 연쇄교체 모드 활성화 스낵바 제거
    // if (stateProxy.isChainExchangeModeEnabled) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text('연쇄교체 모드가 활성화되었습니다. 연쇄적으로 교체 경로를 찾을 수 있습니다.'),
    //       backgroundColor: Colors.orange,
    //       duration: Duration(seconds: 3),
    //     ),
    //   );
    // }
  }

  /// 보강교체 모드 강제 활성화 (TabBar에서 호출)
  ///
  /// **처리 순서**:
  /// 1. 다른 모드 비활성화 (1:1/순환/연쇄)
  /// 2. 교체불가 편집 모드 비활성화
  /// 3. 보강교체 모드 강제 활성화
  /// 4. Level 2 초기화 + 단계 설정 (2단계)
  /// 5. 교사 이름 선택 기능 활성화
  /// 6. 헤더 테마 업데이트
  /// 7. 사용자 피드백 (SnackBar)
  void activateSupplementExchangeMode() {
    AppLogger.exchangeDebug('보강교체 모드 강제 활성화 시작');

    bool hasOtherModesActive =
        stateProxy.isExchangeModeEnabled ||
        stateProxy.isCircularExchangeModeEnabled ||
        stateProxy.isChainExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    if (hasOtherModesActive) {
      stateProxy.setExchangeModeEnabled(false);
      stateProxy.setCircularExchangeModeEnabled(false);
      stateProxy.setChainExchangeModeEnabled(false);
    }

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 보강교체 모드 강제 활성화
    stateProxy.setSupplementExchangeModeEnabled(true);

        // 4. Level 2 초기화 + 단계 설정
        onClearAllExchangeStates();
        stateProxy.setAvailableSteps([2]); // 보강교체는 2단계 (보강할 셀 선택 → 보강받을 셀 선택)
        stateProxy.setSelectedStep(null);
        stateProxy.setSelectedDay(null);

        // 5. 교사 이름 선택 기능 활성화
        ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
        AppLogger.exchangeDebug('[보강 모드] 교사 이름 선택 기능 활성화');
        
        // 6. 로딩 상태 설정 (일관된 사용자 경험을 위해)
        ref.read(exchangeScreenProvider.notifier).setPathsLoading(false);
        ref.read(exchangeScreenProvider.notifier).setLoadingProgress(1.0);
        // 사이드바는 셀 선택 시에만 표시되도록 제거
        // ref.read(exchangeScreenProvider.notifier).setSidebarVisible(true);

    // 6. 헤더 테마 업데이트
    onRefreshHeaderTheme();

  }

  /// 보강교체 모드 토글
  ///
  /// **처리 순서**:
  /// 1. 다른 모드 비활성화 (1:1/순환/연쇄)
  /// 2. 교체불가 편집 모드 비활성화
  /// 3. 보강교체 모드 활성화/비활성화
  /// 4. 활성화 시: Level 2 초기화 + 단계 설정 (2단계)
  /// 5. 교사 이름 선택 기능 활성화/비활성화
  /// 6. 헤더 테마 업데이트
  /// 7. 사용자 피드백 (SnackBar)
  void toggleSupplementExchangeMode() {
    AppLogger.exchangeDebug('보강교체 모드 토글 시작 - 현재 상태: ${stateProxy.isSupplementExchangeModeEnabled}');

    bool wasEnabled = stateProxy.isSupplementExchangeModeEnabled;
    bool hasOtherModesActive =
        stateProxy.isExchangeModeEnabled ||
        stateProxy.isCircularExchangeModeEnabled ||
        stateProxy.isChainExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    if (hasOtherModesActive) {
      stateProxy.setExchangeModeEnabled(false);
      stateProxy.setCircularExchangeModeEnabled(false);
      stateProxy.setChainExchangeModeEnabled(false);
    }

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 보강교체 모드 토글
    stateProxy.setSupplementExchangeModeEnabled(!wasEnabled);

        if (stateProxy.isSupplementExchangeModeEnabled) {
          // 4. 활성화: Level 2 초기화 + 단계 설정
          onClearAllExchangeStates();
          stateProxy.setAvailableSteps([2]); // 보강교체는 2단계 (보강할 셀 선택 → 보강받을 셀 선택)
          stateProxy.setSelectedStep(null);
          stateProxy.setSelectedDay(null);

          // 5. 교사 이름 선택 기능 활성화
          ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
          AppLogger.exchangeDebug('[보강 모드] 교사 이름 선택 기능 활성화');
          
          // 6. 로딩 상태 설정 (일관된 사용자 경험을 위해)
          ref.read(exchangeScreenProvider.notifier).setPathsLoading(false);
          ref.read(exchangeScreenProvider.notifier).setLoadingProgress(1.0);
          // 사이드바는 셀 선택 시에만 표시되도록 제거
          // ref.read(exchangeScreenProvider.notifier).setSidebarVisible(true);
        } else {
          // 비활성화: 단계 설정만 초기화
          stateProxy.setAvailableSteps([]);
          stateProxy.setSelectedStep(null);
          stateProxy.setSelectedDay(null);

          // 교사 이름 선택 기능 비활성화
          ref.read(exchangeScreenProvider.notifier).disableTeacherNameSelection();
          AppLogger.exchangeDebug('[보강 모드] 교사 이름 선택 기능 비활성화');
          
          // 로딩 상태 해제
          ref.read(exchangeScreenProvider.notifier).setPathsLoading(false);
          ref.read(exchangeScreenProvider.notifier).setLoadingProgress(0.0);
        }

    // 6. 헤더 테마 업데이트
    onRefreshHeaderTheme();

    // 7. 사용자 피드백
    if (stateProxy.isSupplementExchangeModeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('보강교체 모드가 활성화되었습니다. 교사가 부재 시 다른 교사가 대신 수업할 수 있습니다.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
