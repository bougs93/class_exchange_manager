import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../services/excel_service.dart';

/// 파일 선택 및 로딩 관련 핸들러
mixin ExchangeFileHandler<T extends StatefulWidget> on State<T> {
  // 하위 클래스에서 구현해야 하는 메서드들
  File? get selectedFile;
  void Function(File?) get setSelectedFile;
  void Function(TimetableData?) get setTimetableData;
  void Function(bool) get setLoading;
  void Function(String?) get setErrorMessage;
  void Function() get createSyncfusionGridData;

  /// Excel 파일 선택
  Future<void> selectExcelFile() async {
    setLoading(true);
    setErrorMessage(null);

    try {
      if (kIsWeb) {
        // Web 플랫폼
        await _selectExcelFileWeb();
      } else {
        // Desktop/Mobile 플랫폼
        await _selectExcelFileNative();
      }
    } catch (e) {
      setErrorMessage('파일 선택 중 오류가 발생했습니다: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Web 플랫폼 파일 선택
  Future<void> _selectExcelFileWeb() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'xlsm'], // xlsm: 매크로 포함 Excel 파일 지원
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final bytes = result.files.first.bytes;
      if (bytes != null) {
        await processExcelBytes(bytes);
      }
    }
  }

  /// Native 플랫폼 파일 선택
  Future<void> _selectExcelFileNative() async {
    File? file = await ExcelService.pickExcelFile();

    if (file != null) {
      setSelectedFile(file);
      await loadExcelData();
    }
  }

  /// Excel 데이터 로딩
  Future<void> loadExcelData() async {
    if (selectedFile == null) return;

    try {
      Excel? excel = await ExcelService.readExcelFile(selectedFile!);

      if (excel != null) {
        bool isValid = ExcelService.isValidExcelFile(excel);

        if (isValid) {
          await parseTimetableData(excel);
        } else {
          setErrorMessage('유효하지 않은 엑셀 파일입니다.');
        }
      } else {
        setErrorMessage('엑셀 파일을 읽을 수 없습니다.');
      }
    } catch (e) {
      setErrorMessage('엑셀 파일 읽기 중 오류가 발생했습니다: $e');
    }
  }

  /// 시간표 데이터 파싱
  Future<void> parseTimetableData(Excel excel) async {
    try {
      TimetableData? timetableData = ExcelService.parseTimetableData(excel);

      if (timetableData != null) {
        setTimetableData(timetableData);
        createSyncfusionGridData();
      } else {
        setErrorMessage('시간표 데이터를 파싱할 수 없습니다. 파일 형식을 확인해주세요.');
      }
    } catch (e) {
      setErrorMessage('시간표 파싱 중 오류가 발생했습니다: $e');
    }
  }

  /// Web에서 bytes로 Excel 파일 처리
  Future<void> processExcelBytes(List<int> bytes) async {
    try {
      Excel? excel = await ExcelService.readExcelFromBytes(bytes);

      if (excel != null) {
        bool isValid = ExcelService.isValidExcelFile(excel);

        if (isValid) {
          await parseTimetableData(excel);
        } else {
          setErrorMessage('유효하지 않은 엑셀 파일입니다.');
        }
      } else {
        setErrorMessage('엑셀 파일을 읽을 수 없습니다.');
      }
    } catch (e) {
      setErrorMessage('엑셀 파일 처리 중 오류가 발생했습니다: $e');
    }
  }
}
