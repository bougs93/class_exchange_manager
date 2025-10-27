import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import '../utils/logger.dart';

/// 엑셀 템플릿 서비스 사용 가이드
/// 
/// 이 서비스는 기존 엑셀 파일을 읽어서 템플릿 정보를 추출하고,
/// 나중에 이 템플릿을 사용해서 데이터를 채운 엑셀 파일을 생성할 수 있습니다.
/// 
/// ### 사용 흐름:
/// 
/// 1. **템플릿 파일 읽기**
///    ```dart
///    // 방법 1: 파일 선택 다이얼로그로 선택
///    ExcelTemplateInfo? info = await ExcelTemplateService().pickAndExtractTemplate();
///    
///    // 방법 2: 특정 파일 직접 지정
///    File templateFile = File('path/to/template.xlsx');
///    ExcelTemplateInfo? info = await ExcelTemplateService().extractTemplateInfo(templateFile);
///    ```
///
/// 2. **템플릿 정보 확인**
///    ```dart
///    if (info != null) {
///      print('워크시트: ${info.sheetName}');
///      print('테그 위치: ${info.tagLocations}'); // {date: CellLocation, day: CellLocation, ...}
///      print('셀 개수: ${info.cells.length}');
///    }
///    ```
///
/// 3. **템플릿 정보 저장**
///    ```dart
///    if (info != null) {
///      await ExcelTemplateService().saveTemplateInfo(info, 'path/to/template_info.json');
///    }
///    ```
///
/// ### 템플릿 파일 요구사항:
/// 
/// - 엑셀 파일 (.xlsx)
/// - 테이블 헤더에 다음 테그 중 하나 이상 포함:
///   - 단순 형식: date, day, period, grade, class, subject, teacher, remarks
///   - 복합 형식: date(day), date3(day3) 등
/// - 예시: 
///   ```
///   결강일    결강요일  교시  학년  반   과목   교사   보강과목  보강교사
///   date      day      period grade class subject teacher subject2 teacher2
///   ```
///
/// ### 출력 시 사용:
/// 
/// 추출된 템플릿 정보(ExcelTemplateInfo)는 다음 용도로 사용됩니다:
/// - 템플릿의 구조 파악
/// - 테그 위치 확인
/// - 나중에 같은 형식으로 데이터 채우기

/// 셀 스타일 정보를 담는 클래스
/// 
/// 셀의 폰트, 색상, 정렬 등의 스타일 정보를 저장합니다.
class CellStyleInfo {
  /// 폰트 이름
  final String? fontName;
  
  /// 폰트 크기
  final double? fontSize;
  
  /// 폰트 굵기 (true: 굵게)
  final bool? isBold;
  
  /// 폰트 기울임 (true: 기울임)
  final bool? isItalic;
  
  /// 글자색 (16진수 컬러 코드)
  final String? fontColor;
  
  /// 배경색 (16진수 컬러 코드)
  final String? fillColor;
  
  /// 가로 정렬
  final String? horizontalAlign;
  
  /// 세로 정렬
  final String? verticalAlign;
  
  /// 테두리 (두께, 색상 등)
  final Map<String, dynamic>? border;
  
  /// 셀 내용 줄바꿈 허용 여부
  final bool? wrapText;
  
  const CellStyleInfo({
    this.fontName,
    this.fontSize,
    this.isBold,
    this.isItalic,
    this.fontColor,
    this.fillColor,
    this.horizontalAlign,
    this.verticalAlign,
    this.border,
    this.wrapText,
  });
  
  /// Map으로 변환 (저장/불러오기용)
  Map<String, dynamic> toMap() {
    return {
      'fontName': fontName,
      'fontSize': fontSize,
      'isBold': isBold,
      'isItalic': isItalic,
      'fontColor': fontColor,
      'fillColor': fillColor,
      'horizontalAlign': horizontalAlign,
      'verticalAlign': verticalAlign,
      'border': border,
      'wrapText': wrapText,
    };
  }
  
  /// Map에서 변환 (저장/불러오기용)
  factory CellStyleInfo.fromMap(Map<String, dynamic> map) {
    return CellStyleInfo(
      fontName: map['fontName'],
      fontSize: map['fontSize']?.toDouble(),
      isBold: map['isBold'],
      isItalic: map['isItalic'],
      fontColor: map['fontColor'],
      fillColor: map['fillColor'],
      horizontalAlign: map['horizontalAlign'],
      verticalAlign: map['verticalAlign'],
      border: map['border'],
      wrapText: map['wrapText'],
    );
  }
}

/// 셀 정보를 담는 클래스
/// 
/// 각 셀의 위치, 값, 스타일 정보를 저장합니다.
class CellInfo {
  /// 행 번호 (0부터 시작)
  final int row;
  
  /// 열 번호 (0부터 시작)
  final int col;
  
  /// 셀 값
  final dynamic value;
  
  /// 셀 스타일 정보
  final CellStyleInfo? style;
  
  /// 셀 타입을 담는 문자열
  final String? cellTypeStr;
  
  const CellInfo({
    required this.row,
    required this.col,
    required this.value,
    this.style,
    this.cellTypeStr,
  });
  
  /// Map으로 변환 (저장/불러오기용)
  Map<String, dynamic> toMap() {
    return {
      'row': row,
      'col': col,
      'value': value,
      'style': style?.toMap(),
      'cellTypeStr': cellTypeStr,
    };
  }
  
  /// Map에서 변환 (저장/불러오기용)
  factory CellInfo.fromMap(Map<String, dynamic> map) {
    return CellInfo(
      row: map['row'],
      col: map['col'],
      value: map['value'],
      style: map['style'] != null ? CellStyleInfo.fromMap(map['style']) : null,
      cellTypeStr: map['cellTypeStr'],
    );
  }
}

/// 셀 병합 정보를 담는 클래스
/// 
/// 병합된 셀의 범위를 저장합니다.
class MergedCellInfo {
  /// 시작 행
  final int startRow;
  
  /// 시작 열
  final int startCol;
  
  /// 끝 행 (포함)
  final int endRow;
  
  /// 끝 열 (포함)
  final int endCol;
  
  const MergedCellInfo({
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
  });
  
  /// Map으로 변환 (저장/불러오기용)
  Map<String, dynamic> toMap() {
    return {
      'startRow': startRow,
      'startCol': startCol,
      'endRow': endRow,
      'endCol': endCol,
    };
  }
  
  /// Map에서 변환 (저장/불러오기용)
  factory MergedCellInfo.fromMap(Map<String, dynamic> map) {
    return MergedCellInfo(
      startRow: map['startRow'],
      startCol: map['startCol'],
      endRow: map['endRow'],
      endCol: map['endCol'],
    );
  }
}

/// 엑셀 템플릿 정보를 담는 클래스
/// 
/// 전체 엑셀 파일의 구조, 셀 정보, 병합 정보를 저장합니다.
class ExcelTemplateInfo {
  /// 워크시트 이름
  final String sheetName;
  
  /// 모든 셀 정보 리스트
  final List<CellInfo> cells;
  
  /// 병합된 셀 정보 리스트
  final List<MergedCellInfo> mergedCells;
  
  /// 최대 행 수
  final int maxRows;
  
  /// 최대 열 수
  final int maxCols;
  
  /// 테이블 테그 위치 정보 (ex: "date" 셀이 어디에 있는지)
  final Map<String, CellLocation> tagLocations;
  
  const ExcelTemplateInfo({
    required this.sheetName,
    required this.cells,
    required this.mergedCells,
    required this.maxRows,
    required this.maxCols,
    this.tagLocations = const {},
  });
  
  /// Map으로 변환 (저장/불러오기용)
  Map<String, dynamic> toMap() {
    return {
      'sheetName': sheetName,
      'cells': cells.map((e) => e.toMap()).toList(),
      'mergedCells': mergedCells.map((e) => e.toMap()).toList(),
      'maxRows': maxRows,
      'maxCols': maxCols,
      'tagLocations': tagLocations.map((key, value) => MapEntry(key, {
        'row': value.row,
        'col': value.col,
      })),
    };
  }
  
  /// Map에서 변환 (저장/불러오기용)
  factory ExcelTemplateInfo.fromMap(Map<String, dynamic> map) {
    return ExcelTemplateInfo(
      sheetName: map['sheetName'],
      cells: (map['cells'] as List).map((e) => CellInfo.fromMap(e)).toList(),
      mergedCells: (map['mergedCells'] as List).map((e) => MergedCellInfo.fromMap(e)).toList(),
      maxRows: map['maxRows'],
      maxCols: map['maxCols'],
      tagLocations: (map['tagLocations'] as Map).map((key, value) => MapEntry(
        key,
        CellLocation(row: value['row'], col: value['col']),
      )),
    );
  }
}

/// 셀 위치 정보
class CellLocation {
  final int row;
  final int col;
  
  const CellLocation({required this.row, required this.col});
}

/// 엑셀 템플릿 서비스
/// 
/// 엑셀 파일을 읽어서 템플릿 정보를 추출하고 저장합니다.
/// 나중에 이 템플릿을 사용해서 데이터를 채운 엑셀 파일을 생성할 수 있습니다.
class ExcelTemplateService {
  // 싱글톤 인스턴스
  static final ExcelTemplateService _instance = ExcelTemplateService._internal();
  
  // 싱글톤 생성자
  factory ExcelTemplateService() => _instance;
  
  // 내부 생성자
  ExcelTemplateService._internal();
  
  /// 엑셀 파일을 읽어서 템플릿 정보를 추출하는 메서드
  /// 
  /// 매개변수:
  /// - File? templateFile: 읽을 엑셀 템플릿 파일
  /// 
  /// 반환값:
  /// - ExcelTemplateInfo?: 추출된 템플릿 정보 (실패 시 null)
  /// 
  /// 사용 예시:
  /// ```dart
  /// File? file = await ExcelService.pickExcelFile();
  /// if (file != null) {
  ///   ExcelTemplateInfo? info = await ExcelTemplateService().extractTemplateInfo(file);
  ///   if (info != null) {
  ///     // 템플릿 정보 추출 성공
  ///   }
  /// }
  /// ```
  Future<ExcelTemplateInfo?> extractTemplateInfo(File templateFile) async {
    try {
      // 파일 존재 확인
      if (!await templateFile.exists()) {
        AppLogger.error('템플릿 파일이 존재하지 않습니다: ${templateFile.path}');
        return null;
      }
      
      // 엑셀 파일 읽기
      var bytes = await templateFile.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      
      // 첫 번째 워크시트 가져오기
      if (excel.tables.isEmpty) {
        AppLogger.error('워크시트가 없습니다.');
        return null;
      }
      
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;
      
      // 최대 행/열 개수 계산
      int maxRows = sheet.maxRows;
      int maxCols = 0;
      
      AppLogger.exchangeInfo('워크시트: $sheetName, 최대 행: $maxRows');
      
      // 모든 셀 정보 추출
      final List<CellInfo> cells = [];
      final Map<String, CellLocation> tagLocations = {};
      final List<MergedCellInfo> mergedCells = [];
      
      for (var row in sheet.rows) {
        for (var cell in row) {
          if (cell == null) continue;
          
          // 최대 열 업데이트
          if (cell.columnIndex > maxCols) {
            maxCols = cell.columnIndex;
          }
          
          // 셀 정보 생성
          final cellInfo = CellInfo(
            row: cell.rowIndex,
            col: cell.columnIndex,
            value: cell.value,
            style: _extractCellStyle(cell),
          );
          
          cells.add(cellInfo);
          
          // 테이블 테그 위치 저장 (컬럼 헤더 찾기)
          if (cell.value != null) {
            final cellValue = cell.value.toString().trim();
            if (_isTagName(cellValue)) {
              tagLocations[cellValue] = CellLocation(row: cell.rowIndex, col: cell.columnIndex);
              AppLogger.exchangeDebug('테그 발견: $cellValue at (${cell.rowIndex}, ${cell.columnIndex})');
            }
          }
        }
      }
      
      // 템플릿 정보 생성
      final templateInfo = ExcelTemplateInfo(
        sheetName: sheetName,
        cells: cells,
        mergedCells: mergedCells,
        maxRows: maxRows,
        maxCols: maxCols,
        tagLocations: tagLocations,
      );
      
      AppLogger.exchangeInfo('템플릿 정보 추출 완료: ${cells.length}개 셀');
      return templateInfo;
      
    } catch (e, stackTrace) {
      AppLogger.error('템플릿 정보 추출 중 오류: $e', e, stackTrace);
      return null;
    }
  }
  
  /// 엑셀 파일을 선택하여 템플릿 정보를 추출하는 메서드
  /// 
  /// 반환값:
  /// - ExcelTemplateInfo?: 추출된 템플릿 정보 (취소 시 null)
  /// 
  /// 사용 예시:
  /// ```dart
  /// ExcelTemplateInfo? info = await ExcelTemplateService().pickAndExtractTemplate();
  /// if (info != null) {
  ///   // 템플릿 정보 추출 성공
  /// }
  /// ```
  Future<ExcelTemplateInfo?> pickAndExtractTemplate() async {
    try {
      // 파일 선택
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        dialogTitle: '엑셀 템플릿 파일 선택',
      );
      
      if (result == null || result.files.isEmpty) {
        AppLogger.exchangeDebug('파일 선택이 취소되었습니다.');
        return null;
      }
      
      final file = File(result.files.first.path!);
      return await extractTemplateInfo(file);
      
    } catch (e) {
      AppLogger.error('템플릿 파일 선택 중 오류: $e');
      return null;
    }
  }
  
  /// 템플릿 정보를 JSON 파일로 저장하는 메서드
  /// 
  /// 매개변수:
  /// - ExcelTemplateInfo info: 저장할 템플릿 정보
  /// - String filePath: 저장할 파일 경로
  /// 
  /// 사용 예시:
  /// ```dart
  /// ExcelTemplateInfo? info = await ExcelTemplateService().pickAndExtractTemplate();
  /// if (info != null) {
  ///   await ExcelTemplateService().saveTemplateInfo(info, 'path/to/template.json');
  /// }
  /// ```
  Future<bool> saveTemplateInfo(ExcelTemplateInfo info, String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = info.toMap().toString();
      await file.writeAsString(jsonString);
      
      AppLogger.exchangeInfo('템플릿 정보를 저장했습니다: $filePath');
      return true;
    } catch (e) {
      AppLogger.error('템플릿 정보 저장 중 오류: $e');
      return false;
    }
  }
  
  // ==================== 헬퍼 메서드들 ====================
  
  /// 셀에서 스타일 정보를 추출하는 메서드
  CellStyleInfo? _extractCellStyle(dynamic cellData) {
    try {
      // excel 패키지의 실제 구현에 따라 조정 필요
      // 현재 버전에서는 기본 정보만 추출
      return CellStyleInfo(
        wrapText: false, // 기본값
      );
    } catch (e) {
      return null;
    }
  }
  
  /// 셀 값이 테이블 테그인지 확인
  /// 
  /// file_export_widget.dart의 ExcelColumnIdentifiers에 정의된 값들을 확인합니다.
  /// 
  /// 지원하는 태그 형식:
  /// - 단순 태그: date, day, period 등
  /// - 괄호 형식: date(day), date3(day3) 등
  bool _isTagName(String value) {
    final tags = [
      'date', 'day', 'period', 'grade', 'class', 'subject', 'teacher',
      'subject2', 'teacher2',
      'date3', 'day3', 'period3', 'subject3', 'teacher3',
      'remarks',
    ];
    
    final lowerValue = value.toLowerCase();
    
    // 1. 단순 태그 확인
    if (tags.contains(lowerValue)) {
      return true;
    }
    
    // 2. 괄호 형식 태그 확인 (예: date(day), date3(day3))
    for (final tag in tags) {
      // tag(다른값) 형태인지 확인
      final pattern = RegExp('^${RegExp.escape(tag)}\\([^)]+\\)\$');
      if (pattern.hasMatch(lowerValue)) {
        return true;
      }
    }
    
    return false;
  }
}

