import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../../services/excel_service.dart';
import '../../../../utils/logger.dart';
import '../exchange_screen_state_proxy.dart';

/// 파일 선택, 로딩, 교체 모드 전환 등 핵심 비즈니스 로직을 관리하는 Manager
///
/// ExchangeFileHandler와 ExchangeModeHandler Mixin을 대체합니다.
class ExchangeOperationManager {
  final BuildContext context;
  final ExchangeScreenStateProxy stateProxy;
  final VoidCallback onCreateSyncfusionGridData;
  final VoidCallback onClearAllExchangeStates;
  final VoidCallback onRestoreUIToDefault;
  final VoidCallback onRefreshHeaderTheme;

  ExchangeOperationManager({
    required this.context,
    required this.stateProxy,
    required this.onCreateSyncfusionGridData,
    required this.onClearAllExchangeStates,
    required this.onRestoreUIToDefault,
    required this.onRefreshHeaderTheme,
  });

  // ===== 파일 관리 =====

  /// Excel 파일 선택
  Future<void> selectExcelFile() async {
    stateProxy.setLoading(true);
    stateProxy.setErrorMessage(null);

    try {
      if (kIsWeb) {
        await _selectExcelFileWeb();
      } else {
        await _selectExcelFileNative();
      }
    } catch (e) {
      stateProxy.setErrorMessage('파일 선택 중 오류가 발생했습니다: $e');
    } finally {
      stateProxy.setLoading(false);
    }
  }

  Future<void> _selectExcelFileWeb() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final bytes = result.files.first.bytes;
      if (bytes != null) {
        await processExcelBytes(bytes);
      }
    }
  }

  Future<void> _selectExcelFileNative() async {
    File? file = await ExcelService.pickExcelFile();

    if (file != null) {
      stateProxy.setSelectedFile(file);
      await loadExcelData();
    }
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
      stateProxy.setTimetableData(timetableData);
      onCreateSyncfusionGridData();
    } else {
      stateProxy.setErrorMessage('시간표 데이터를 파싱할 수 없습니다.');
    }
  }

  // ===== 교체 모드 관리 =====

  /// 1:1 교체 모드 토글
  void toggleExchangeMode() {
    bool wasEnabled = stateProxy.isExchangeModeEnabled;
    bool hasOtherModesActive =
        stateProxy.isCircularExchangeModeEnabled || stateProxy.isChainExchangeModeEnabled;

    if (hasOtherModesActive) {
      stateProxy.setCircularExchangeModeEnabled(false);
      stateProxy.setChainExchangeModeEnabled(false);
    }

    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    stateProxy.setExchangeModeEnabled(!wasEnabled);

    if (!stateProxy.isExchangeModeEnabled) {
      onRestoreUIToDefault();
      stateProxy.setAvailableSteps([]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    } else {
      onClearAllExchangeStates();
      stateProxy.setAvailableSteps([2]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    }

    onRefreshHeaderTheme();

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
  void toggleCircularExchangeMode() {
    AppLogger.exchangeDebug('순환교체 모드 토글 시작 - 현재 상태: ${stateProxy.isCircularExchangeModeEnabled}');

    bool wasEnabled = stateProxy.isCircularExchangeModeEnabled;
    bool hasOtherModesActive =
        stateProxy.isExchangeModeEnabled || stateProxy.isChainExchangeModeEnabled;

    if (hasOtherModesActive) {
      stateProxy.setExchangeModeEnabled(false);
      stateProxy.setChainExchangeModeEnabled(false);
    }

    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    stateProxy.setCircularExchangeModeEnabled(!wasEnabled);

    if (!stateProxy.isCircularExchangeModeEnabled) {
      onRestoreUIToDefault();
      stateProxy.setAvailableSteps([]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    } else {
      onClearAllExchangeStates();
      stateProxy.setAvailableSteps([2, 3, 4, 5]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    }

    onRefreshHeaderTheme();

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
  void toggleChainExchangeMode() {
    AppLogger.exchangeDebug('연쇄교체 모드 토글 시작 - 현재 상태: ${stateProxy.isChainExchangeModeEnabled}');

    bool wasEnabled = stateProxy.isChainExchangeModeEnabled;
    bool hasOtherModesActive =
        stateProxy.isExchangeModeEnabled || stateProxy.isCircularExchangeModeEnabled;

    if (hasOtherModesActive) {
      stateProxy.setExchangeModeEnabled(false);
      stateProxy.setCircularExchangeModeEnabled(false);
    }

    if (stateProxy.isNonExchangeableEditMode) {
      stateProxy.setNonExchangeableEditMode(false);
    }

    stateProxy.setChainExchangeModeEnabled(!wasEnabled);

    if (!stateProxy.isChainExchangeModeEnabled) {
      onRestoreUIToDefault();
      stateProxy.setAvailableSteps([]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    } else {
      onClearAllExchangeStates();
      stateProxy.setAvailableSteps([2, 3, 4, 5]);
      stateProxy.setSelectedStep(null);
      stateProxy.setSelectedDay(null);
    }

    onRefreshHeaderTheme();

    if (stateProxy.isChainExchangeModeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('연쇄교체 모드가 활성화되었습니다. 연쇄적으로 교체 경로를 찾을 수 있습니다.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
