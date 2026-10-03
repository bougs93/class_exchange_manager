import 'dart:io';
import 'dart:developer' as developer;
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'excel_parsing_utils.dart';
import 'excel_shared_strings_normalizer.dart';
import 'excel_constants.dart';

/// 엑셀 파일 선택/읽기/기본 검증 등 파일 입출력 관련 로직을 담당하는 클래스
///
/// `excel_service.dart`에서 분리되었습니다 (2026-10-03).
/// 원래 `ExcelService`의 정적 메서드였던 내용을 그대로 옮긴 것으로,
/// 호출부는 `ExcelService`를 통해 그대로 사용하며 이 클래스가 실제 구현을 담당합니다.
class ExcelFileAccess {
  /// 사용자가 엑셀 파일을 선택할 수 있게 하는 메서드
  ///
  /// 반환값:
  /// - File?: 선택된 파일 (취소 시 null)
  ///
  /// 사용 예시:
  /// ```dart
  /// File? selectedFile = await ExcelService.pickExcelFile();
  /// if (selectedFile != null) {
  ///   // 파일이 선택됨
  /// }
  /// ```
  /// 네이티브 전용 파일 선택 (File 반환).
  ///
  /// 웹에서는 파일 경로가 존재하지 않으므로 이 메서드를 쓰지 않는다.
  /// 웹 업로드 경로는 `ExchangeOperationManager._selectExcelFileWeb` →
  /// `processExcelBytes` → `readExcelFromBytes`로 통합되어 있다.
  static Future<File?> pickExcelFile() async {
    try {
      // 파일 선택 다이얼로그 표시
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'xlsx',
          'xls',
          'xlsm',
        ], // 엑셀 파일 형식만 허용 (xlsm: 매크로 포함)
        allowMultiple: false, // 단일 파일만 선택 가능
      );

      // 사용자가 파일을 선택했는지 확인
      if (result != null && result.files.isNotEmpty) {
        // 선택된 파일의 경로를 File 객체로 변환
        String filePath = result.files.first.path!;
        return File(filePath);
      }

      // 파일을 선택하지 않았거나 취소한 경우
      return null;
    } catch (e) {
      // 파일 선택 중 오류 발생
      developer.log('파일 선택 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }

  /// 엑셀 파일을 읽어서 Excel 객체로 변환하는 메서드
  ///
  /// 매개변수:
  /// - File file: 읽을 엑셀 파일
  ///
  /// 반환값:
  /// - Excel?: 읽은 엑셀 객체 (실패 시 null)
  ///
  /// 사용 예시:
  /// ```dart
  /// File file = File('path/to/file.xlsx');
  /// Excel? excel = await ExcelService.readExcelFile(file);
  /// if (excel != null) {
  ///   // 엑셀 파일 읽기 성공
  /// }
  /// ```

  /// Web에서 bytes로 엑셀 파일을 읽어서 Excel 객체로 변환
  ///
  /// 매개변수:
  /// - `List<int>` bytes: 엑셀 파일의 바이트 데이터
  ///
  /// 반환값:
  /// - Excel?: 파싱된 엑셀 데이터 (실패 시 null)
  static Future<Excel?> readExcelFromBytes(List<int> bytes) async {
    try {
      // excel 패키지 sharedStrings 중복 버그 우회 후 디코딩
      final normalized = ExcelSharedStringsNormalizer.normalize(bytes);
      final excel = Excel.decodeBytes(normalized);
      return excel;
    } catch (e) {
      developer.log('엑셀 파일 파싱 실패: $e', name: 'ExcelService');
      return null;
    }
  }

  static Future<Excel?> readExcelFile(File file) async {
    try {
      // 파일이 존재하는지 확인
      if (!await file.exists()) {
        developer.log('파일이 존재하지 않습니다: ${file.path}', name: 'ExcelService');
        return null;
      }

      // 파일 크기 확인 (너무 큰 파일은 처리하지 않음)
      int fileSize = await file.length();
      if (fileSize > ExcelServiceConstants.maxFileSizeBytes) {
        developer.log(
          '파일 크기가 너무 큽니다: ${fileSize / 1024 / 1024}MB',
          name: 'ExcelService',
        );
        return null;
      }

      // 엑셀 파일 읽기 (sharedStrings 정규화 포함)
      final bytes = await file.readAsBytes();
      final excel = await readExcelFromBytes(bytes);
      if (excel == null) {
        developer.log('엑셀 파일 읽기 실패: ${file.path}', name: 'ExcelService');
        return null;
      }

      developer.log('엑셀 파일 읽기 성공: ${file.path}', name: 'ExcelService');
      return excel;
    } catch (e) {
      // 엑셀 파일 읽기 중 오류 발생
      developer.log('엑셀 파일 읽기 중 오류 발생: $e', name: 'ExcelService');
      return null;
    }
  }

  /// 엑셀 파일의 기본 정보를 출력하는 디버깅 메서드
  ///
  /// 매개변수:
  /// - Excel excel: 분석할 엑셀 객체
  ///
  /// 사용 예시:
  /// ```dart
  /// Excel excel = await ExcelService.readExcelFile(file);
  /// ExcelService.printExcelInfo(excel);
  /// ```
  static void printExcelInfo(Excel excel) {
    try {
      developer.log('=== 엑셀 파일 정보 ===', name: 'ExcelService');

      // 워크시트 개수 및 이름 출력
      developer.log('워크시트 개수: ${excel.tables.length}', name: 'ExcelService');
      developer.log(
        '워크시트 이름들: ${excel.tables.keys.toList()}',
        name: 'ExcelService',
      );

      // 각 워크시트별 정보 출력
      excel.tables.forEach((sheetName, sheet) {
        developer.log('\n--- 워크시트: $sheetName ---', name: 'ExcelService');
        developer.log('최대 행 수: ${sheet.maxRows}', name: 'ExcelService');
        developer.log('최대 열 수: 동적으로 확인됨', name: 'ExcelService');

        // 첫 번째 행의 데이터 출력 (헤더 확인용)
        if (sheet.maxRows > 0) {
          developer.log('첫 번째 행 데이터:', name: 'ExcelService');
          // 열 수를 동적으로 확인
          int colCount = 0;
          while (colCount < ExcelServiceConstants.maxRowsToLog) {
            // 최대 행/열 로그 제한
            try {
              var cell = sheet.cell(
                CellIndex.indexByColumnRow(columnIndex: colCount, rowIndex: 0),
              );
              String cellValue = cell.value?.toString() ?? '';
              if (cellValue.isNotEmpty) {
                developer.log(
                  '  열 $colCount: $cellValue',
                  name: 'ExcelService',
                );
              }
              colCount++;
            } catch (e) {
              break; // 더 이상 열이 없으면 중단
            }
          }
        }

        // 첫 번째 열의 데이터 출력 (교사명 확인용)
        developer.log('첫 번째 열 데이터:', name: 'ExcelService');
        for (
          int row = 0;
          row < sheet.maxRows && row < ExcelServiceConstants.maxRowsToLog;
          row++
        ) {
          try {
            var cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
            );
            String cellValue = cell.value?.toString() ?? '';
            if (cellValue.isNotEmpty) {
              developer.log('  행 $row: $cellValue', name: 'ExcelService');
            }
          } catch (e) {
            break; // 더 이상 행이 없으면 중단
          }
        }
      });

      developer.log('=== 엑셀 파일 정보 끝 ===', name: 'ExcelService');
    } catch (e) {
      developer.log('엑셀 정보 출력 중 오류 발생: $e', name: 'ExcelService');
    }
  }

  /// 엑셀 파일의 특정 셀 값을 읽는 헬퍼 메서드
  ///
  /// 매개변수:
  /// - Excel excel: 엑셀 객체
  /// - String sheetName: 워크시트 이름
  /// - int row: 행 번호 (0부터 시작)
  /// - int col: 열 번호 (0부터 시작)
  ///
  /// 반환값:
  /// - String: 셀 값 (빈 셀이거나 오류 시 빈 문자열)
  ///
  /// 사용 예시:
  /// ```dart
  /// String cellValue = ExcelService.getCellValue(excel, 'Sheet1', 0, 1);
  /// ```
  static String getCellValue(Excel excel, String sheetName, int row, int col) {
    try {
      var sheet = excel.tables[sheetName];
      if (sheet == null) {
        developer.log('워크시트를 찾을 수 없습니다: $sheetName', name: 'ExcelService');
        return '';
      }

      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      return ExcelParsingUtils.formatCellValue(cell.value);
    } catch (e) {
      developer.log('셀 값 읽기 중 오류 발생: $e', name: 'ExcelService');
      return '';
    }
  }

  /// 엑셀 파일의 유효성을 검사하는 메서드
  ///
  /// 매개변수:
  /// - Excel excel: 검사할 엑셀 객체
  ///
  /// 반환값:
  /// - bool: 유효한 엑셀 파일인지 여부
  ///
  /// 사용 예시:
  /// ```dart
  /// bool isValid = ExcelService.isValidExcelFile(excel);
  /// if (isValid) {
  ///   // 유효한 엑셀 파일
  /// }
  /// ```
  static bool isValidExcelFile(Excel excel) {
    try {
      // 워크시트가 있는지 확인
      if (excel.tables.isEmpty) {
        developer.log('워크시트가 없습니다.', name: 'ExcelService');
        return false;
      }

      // 첫 번째 워크시트 가져오기
      var firstSheet = excel.tables.values.first;

      // 최소한의 데이터가 있는지 확인
      if (firstSheet.maxRows < 2) {
        developer.log('데이터가 부족합니다. 최소 2행이 필요합니다.', name: 'ExcelService');
        return false;
      }

      return true;
    } catch (e) {
      developer.log('엑셀 파일 유효성 검사 중 오류 발생: $e', name: 'ExcelService');
      return false;
    }
  }
}
