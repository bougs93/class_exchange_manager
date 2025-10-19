import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../../services/excel_service.dart';
import '../../../../services/exchange_history_service.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/non_exchangeable_manager.dart';
import '../../../../models/exchange_mode.dart';
import '../exchange_screen_state_proxy.dart';

/// 파일 선택, 로딩, 교체 모드 전환 등 핵심 비즈니스 로직을 관리하는 Manager
///
/// ExchangeFileHandler와 ExchangeModeHandler Mixin을 대체합니다.
class ExchangeOperationManager {
  final BuildContext context;
  final ExchangeScreenStateProxy stateProxy;
  final VoidCallback onCreateSyncfusionGridData;
  final VoidCallback onClearAllExchangeStates;
  final VoidCallback onRefreshHeaderTheme;

  // 히스토리 서비스 인스턴스
  final ExchangeHistoryService _historyService = ExchangeHistoryService();
  
  // 교체불가 관리자 인스턴스
  final NonExchangeableManager _nonExchangeableManager = NonExchangeableManager();

  ExchangeOperationManager({
    required this.context,
    required this.stateProxy,
    required this.onCreateSyncfusionGridData,
    required this.onClearAllExchangeStates,
    required this.onRefreshHeaderTheme,
  });

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
      // 새로운 시간표 데이터 파싱 시 히스토리와 교체리스트 초기화
      _clearHistoryAndExchangeList();
      
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
      // 4. 활성화: Level 2 초기화 + 단계 설정
      onClearAllExchangeStates();
      stateProxy.setAvailableSteps([2, 3, 4, 5]); // 연쇄: 2~5단계
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
}
