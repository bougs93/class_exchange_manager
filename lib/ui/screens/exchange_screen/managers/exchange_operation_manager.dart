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
import '../../../../utils/snackbar_helper.dart';
import '../../../../models/exchange_mode.dart';
import '../../../../providers/exchange_screen_provider.dart';
import '../../../../providers/services_provider.dart';
import '../../../../ui/dialogs/exchange_data_reset_dialog.dart';
import '../exchange_screen_state_proxy.dart';

/// 교체 모드별 단계 설정
class ExchangeModeSteps {
  static const List<int> oneToOne = [2]; // 1:1 교체는 2단계만
  static const List<int> circular = [2, 3, 4, 5]; // 순환교체는 2~5단계
  static const List<int> chain = []; // 연쇄교체는 단계 필터 불필요
  static const List<int> supplement = [2]; // 보강교체는 2단계
}

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
      allowedExtensions: ['xlsx', 'xls', 'xlsm'], // xlsm: 매크로 포함 Excel 파일 지원
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
      // 엑셀 파일 읽기 및 파싱 (해시 검사는 파싱 후에 수행)
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
    final timetableData = ExcelService.parseTimetableData(excel);

    if (timetableData == null) {
      stateProxy.setErrorMessage('시간표 데이터를 파싱할 수 없습니다.');
      return;
    }

    // 파일 변경 감지 및 사용자 확인
    final shouldContinue = await _handleFileModification();
    if (!shouldContinue) return;

    // 데이터 저장 및 적용
    await _saveAndApplyTimetableData(timetableData);
  }

  /// 파일 변경 감지 및 사용자 확인 처리
  ///
  /// 반환값: 계속 진행 여부 (true: 계속, false: 중단)
  Future<bool> _handleFileModification() async {
    final selectedFile = stateProxy.selectedFile;
    if (selectedFile == null) return true; // Web 플랫폼

    final filePath = selectedFile.path;
    final isModified = await _timetableStorageService.isFileModified(filePath);

    if (!isModified) return true; // 변경되지 않음

    // 파일이 변경되었으면 초기화 확인 다이얼로그 표시
    if (!context.mounted) {
      stateProxy.setErrorMessage('파일 로드 중 위젯이 닫혔습니다.');
      return false;
    }

    bool? shouldReset;
    try {
      shouldReset = await ExchangeDataResetDialog.show(
        context,
        message: '엑셀 파일이 변경되었습니다. 저장된 시간표 데이터와 교체 리스트를 초기화하시겠습니까?',
      );
    } catch (e) {
      stateProxy.setErrorMessage('파일 로드 중 오류가 발생했습니다: $e');
      return false;
    }

    if (shouldReset == true) {
      _clearHistoryAndExchangeList();
      return true;
    }

    return false; // 사용자가 취소
  }

  /// 시간표 데이터 저장 및 적용
  Future<void> _saveAndApplyTimetableData(TimetableData timetableData) async {
    // 데이터 저장 (Native 플랫폼만)
    final selectedFile = stateProxy.selectedFile;
    if (selectedFile != null) {
      final filePath = selectedFile.path;
      final fileName = filePath.split(Platform.pathSeparator).last;

      await _timetableStorageService.saveTimetableData(
        timetableData,
        filePath,
        fileName,
      );
    }

    // 교체불가 관리자에 데이터 설정
    _nonExchangeableManager.setTimeSlots(timetableData.timeSlots);

    // UI 업데이트
    stateProxy.setTimetableData(timetableData);
    onCreateSyncfusionGridData();
    stateProxy.setCurrentMode(ExchangeMode.view);

    AppLogger.exchangeInfo('파일이 선택되고 보기 모드로 전환되었습니다.');
  }

  /// 히스토리와 교체목록록 초기화 (파일 선택 해제 또는 새로 읽기 시 호출)
  void _clearHistoryAndExchangeList() {
    try {
      // 교체 리스트 전체 삭제
      _historyService.clearExchangeList();

      // 되돌리기 스택도 초기화
      _historyService.clearUndoStack();
      
      // 모든 교체불가 설정 초기화 (timeslot.isExchangeable = true로 복원)
      _nonExchangeableManager.resetAllNonExchangeableSettings();
      
      AppLogger.exchangeInfo('히스토리, 교체목록, 교체불가 설정이 모두 초기화되었습니다.');
    } catch (e) {
      AppLogger.error('상태 초기화 중 오류 발생: $e');
    }
  }

  /// 엑셀 파일 선택 해제 (모든 상태 초기화)
  void clearSelectedFile() {
    // 히스토리와 교체목록 초기화
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

  /// 다른 모드 비활성화 (템플릿 메서드 패턴 - 공통 로직)
  void _disableOtherModes({
    bool keepExchange = false,
    bool keepCircular = false,
    bool keepChain = false,
    bool keepSupplement = false,
  }) {
    if (!keepExchange) stateProxy.setExchangeModeEnabled(false);
    if (!keepCircular) stateProxy.setCircularExchangeModeEnabled(false);
    if (!keepChain) stateProxy.setChainExchangeModeEnabled(false);
    if (!keepSupplement) stateProxy.setSupplementExchangeModeEnabled(false);
  }

  /// 모드 활성화 공통 로직 (템플릿 메서드 패턴)
  void _activateMode(List<int> steps) {
    onClearAllExchangeStates();
    stateProxy.setAvailableSteps(steps);
    stateProxy.setSelectedStep(null);
    stateProxy.setSelectedDay(null);
  }

  /// 모드 비활성화 공통 로직 (템플릿 메서드 패턴)
  void _deactivateMode() {
    stateProxy.setAvailableSteps([]);
    stateProxy.setSelectedStep(null);
    stateProxy.setSelectedDay(null);
  }

  /// 스낵바 피드백 표시 (템플릿 메서드 패턴)
  void _showFeedback(String message, {Color? backgroundColor}) {
    if (backgroundColor == Colors.blue) {
      SnackBarHelper.showInfo(context, message, backgroundColor: backgroundColor);
    } else if (backgroundColor == Colors.orange) {
      SnackBarHelper.showWarning(context, message);
    } else {
      SnackBarHelper.showSuccess(context, message);
    }
  }

  /// 1:1 교체 모드 토글
  void toggleExchangeMode() {
    final wasEnabled = stateProxy.isExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    _disableOtherModes(keepExchange: true);

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 1:1 교체 모드 토글
    stateProxy.setExchangeModeEnabled(!wasEnabled);

    // 4. 활성화/비활성화 처리
    if (stateProxy.isExchangeModeEnabled) {
      _activateMode(ExchangeModeSteps.oneToOne);
    } else {
      _deactivateMode();
    }

    // 5. 헤더 테마 업데이트
    onRefreshHeaderTheme();

    // 6. 사용자 피드백
    if (stateProxy.isExchangeModeEnabled) {
      _showFeedback('1:1교체 모드가 활성화되었습니다. 두 교사의 시간을 서로 교체할 수 있습니다.');
    }
  }

  /// 순환교체 모드 토글
  void toggleCircularExchangeMode() {
    AppLogger.exchangeDebug(
      '순환교체 모드 토글 시작 - 현재 상태: ${stateProxy.isCircularExchangeModeEnabled}',
    );

    final wasEnabled = stateProxy.isCircularExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    _disableOtherModes(keepCircular: true);

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 순환교체 모드 토글
    stateProxy.setCircularExchangeModeEnabled(!wasEnabled);

    // 4. 활성화/비활성화 처리
    if (stateProxy.isCircularExchangeModeEnabled) {
      _activateMode(ExchangeModeSteps.circular);
    } else {
      _deactivateMode();
    }

    // 5. 헤더 테마 업데이트
    onRefreshHeaderTheme();

    // 6. 사용자 피드백
    if (stateProxy.isCircularExchangeModeEnabled) {
      _showFeedback('순환교체 모드가 활성화되었습니다. 여러 교사의 시간을 순환 교체할 수 있습니다.', backgroundColor: Colors.blue);
    }
  }

  /// 연쇄교체 모드 토글
  void toggleChainExchangeMode() {
    AppLogger.exchangeDebug(
      '연쇄교체 모드 토글 시작 - 현재 상태: ${stateProxy.isChainExchangeModeEnabled}',
    );

    final wasEnabled = stateProxy.isChainExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    _disableOtherModes(keepChain: true);

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 연쇄교체 모드 토글
    stateProxy.setChainExchangeModeEnabled(!wasEnabled);

    // 4. 활성화/비활성화 처리
    if (stateProxy.isChainExchangeModeEnabled) {
      _activateMode(ExchangeModeSteps.chain);
    } else {
      _deactivateMode();
    }

    // 5. 헤더 테마 업데이트
    onRefreshHeaderTheme();
  }

  /// 보강교체 모드 강제 활성화 (TabBar에서 호출)
  void activateSupplementExchangeMode() {
    AppLogger.exchangeDebug('보강교체 모드 강제 활성화 시작');

    // 1. 다른 모드 비활성화
    _disableOtherModes();

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 보강교체 모드 강제 활성화
    stateProxy.setSupplementExchangeModeEnabled(true);

    // 4. 활성화 처리
    _activateMode(ExchangeModeSteps.supplement);

    // 5. 교사 이름 선택 기능 활성화
    ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
    AppLogger.exchangeDebug('[보강 모드] 교사 이름 선택 기능 활성화');

    // 6. 로딩 상태 설정
    ref.read(exchangeScreenProvider.notifier).setPathsLoading(false);
    ref.read(exchangeScreenProvider.notifier).setLoadingProgress(1.0);

    // 7. 헤더 테마 업데이트
    onRefreshHeaderTheme();
  }

  /// 보강교체 모드 토글
  void toggleSupplementExchangeMode() {
    AppLogger.exchangeDebug('보강교체 모드 토글 시작 - 현재 상태: ${stateProxy.isSupplementExchangeModeEnabled}');

    final wasEnabled = stateProxy.isSupplementExchangeModeEnabled;

    // 1. 다른 모드 비활성화
    _disableOtherModes(keepSupplement: true);

    // 2. 교체불가 편집 모드 비활성화
    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    // 3. 보강교체 모드 토글
    stateProxy.setSupplementExchangeModeEnabled(!wasEnabled);

    // 4. 활성화/비활성화 처리
    if (stateProxy.isSupplementExchangeModeEnabled) {
      _activateMode(ExchangeModeSteps.supplement);

      // 교사 이름 선택 기능 활성화
      ref.read(exchangeScreenProvider.notifier).enableTeacherNameSelection();
      AppLogger.exchangeDebug('[보강 모드] 교사 이름 선택 기능 활성화');

      // 로딩 상태 설정
      ref.read(exchangeScreenProvider.notifier).setPathsLoading(false);
      ref.read(exchangeScreenProvider.notifier).setLoadingProgress(1.0);
    } else {
      _deactivateMode();

      // 교사 이름 선택 기능 비활성화
      ref.read(exchangeScreenProvider.notifier).disableTeacherNameSelection();
      AppLogger.exchangeDebug('[보강 모드] 교사 이름 선택 기능 비활성화');

      // 로딩 상태 해제
      ref.read(exchangeScreenProvider.notifier).setPathsLoading(false);
      ref.read(exchangeScreenProvider.notifier).setLoadingProgress(0.0);
    }

    // 5. 헤더 테마 업데이트
    onRefreshHeaderTheme();

    // 6. 사용자 피드백
    if (stateProxy.isSupplementExchangeModeEnabled) {
      _showFeedback('보강교체 모드가 활성화되었습니다. 교사가 부재 시 다른 교사가 대신 수업할 수 있습니다.', backgroundColor: Colors.orange);
    }
  }
}
