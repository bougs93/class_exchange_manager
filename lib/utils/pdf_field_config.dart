// PDF 출력 전용 필드/컬럼 매핑 유틸리티
// - UI와 분리해두면 템플릿 변경 시 이 파일만 수정하면 됩니다.

// 그리드/표의 컬럼 키 목록 (좌→우 순서가 중요합니다)
// 선택된 데이터 컬럼들과 동일한 키를 사용하세요.
// const List<String> kPdfTableColumns = [
//   'absenceDate',
//   'absenceDay',
//   'period',
//   'grade',
//   'className',
//   'subject',
//   'teacher',
//   'supplementSubject',
//   'supplementTeacher',
//   'substitutionDate',
//   'substitutionDay',
//   'substitutionPeriod',
//   'substitutionSubject',
//   'substitutionTeacher',
//   'remarks',
// ];

const List<String> kPdfTableColumns = [
  'date',
  'day',
  'period',
  'grade',
  'class',
  'subject',
  'teacher',
  '2subject',
  '2teacher',
  '3date',
  '3day',
  '3period',
  '3subject',
  '3teacher',
  'remarks',
];

/// PDF 템플릿 정보(간단한 이름과 에셋 경로)
class PdfTemplateInfo {
  final String name;      // UI에 표시할 이름
  final String assetPath; // Flutter 에셋 경로

  const PdfTemplateInfo({
    required this.name,
    required this.assetPath,
  });
}

/// 선택 가능한 PDF 템플릿 목록
/// 실제 파일이 에셋에 존재해야 합니다. (예: lib/assets/templates/substitution_plan_template.pdf)
const List<PdfTemplateInfo> kPdfTemplates = [
  PdfTemplateInfo(
    name: '기본 양식',
    assetPath: 'lib/assets/templates/substitution_plan_template.pdf',
  ),
  // 필요 시 다른 양식을 추가하세요.
  // PdfTemplateInfo(name: '양식 A', assetPath: 'assets/templates/form_a.pdf'),
];

/// 복합 필드 베이스 이름 허용 목록
/// 예: 'date(day)' → 1행은 'date(day).0'
const List<String> kPdfCompositeFieldBases = [
  'date(day)',
  '3date(3day)',
];

/// 컬럼 키 → 1 기반 인덱스 매핑
/// PDF 템플릿이 행·열 규칙으로 필드명을 가지는 경우에 사용합니다.
final Map<String, int> kPdfColumnIndex = {
  for (int i = 0; i < kPdfTableColumns.length; i++) kPdfTableColumns[i]: i + 1
};

/// 표 셀의 PDF 필드명 생성 함수
/// 새 규칙: "{컬럼키}.{0부터 시작하는 행 인덱스}" (예: period.0, grade.1)
/// 또한 복합 키를 직접 전달할 수 있습니다(예: 'date(day)', '3date(3day)') → 'date(day).0'
/// 템플릿 규칙이 다르면 이 함수의 반환 문자열만 바꾸면 됩니다.
String pdfCellFieldName(int row, String columnKey) {
  final int zeroBasedRow = row - 1; // 1행 → 0, 2행 → 1
  // 복합 키가 허용 목록에 있는 경우 그대로 사용
  if (kPdfCompositeFieldBases.contains(columnKey)) {
    return '$columnKey.$zeroBasedRow';
  }
  // 단일 컬럼 키인 경우 검증 후 생성
  if (!kPdfColumnIndex.containsKey(columnKey)) {
    throw ArgumentError('알 수 없는 컬럼 키: $columnKey');
  }
  return '$columnKey.$zeroBasedRow';
}

/// 복합 필드 정규식 패턴 (재사용)
/// 예: 'date(day)', '3date(3day)' 형식을 파싱
const String _compositeFieldPattern = r'^(\w+)\((\w+)\)$';
final RegExp _compositeFieldRegex = RegExp(_compositeFieldPattern);

/// 복합 필드를 파싱하여 개별 필드들로 분해
/// 예: 'date(day)' → ['date', 'day']
/// 예: '3date(3day)' → ['3date', '3day']
List<String> parseCompositeField(String compositeField) {
  final match = _compositeFieldRegex.firstMatch(compositeField);

  if (match != null) {
    return [match.group(1)!, match.group(2)!];
  }

  // 파싱 실패 시 원본 반환
  return [compositeField];
}

/// 복합 필드 값들을 필드 이름 형식에 맞춰 포맷팅
/// 예: date(day) + ['10.27', '월'] → '10.27(월)'
/// 예: 3date(3day) + ['2025-01-15', '수'] → '2025-01-15(수)'
String formatCompositeFieldValue(String compositeField, List<String> values) {
  if (values.isEmpty) return '';
  if (values.length == 1) return values[0];

  // 복합 필드 이름에서 괄호 형식 추출
  // 예: 'date(day)' → primary='date', secondary='day'
  final match = _compositeFieldRegex.firstMatch(compositeField);
  
  if (match != null) {
    // 값의 개수에 맞춰 포맷팅
    if (values.length == 2) {
      return '${values[0]}(${values[1]})';
    } else if (values.length > 2) {
      // 3개 이상이면 첫 번째(나머지) 형식
      return '${values[0]}(${values.sublist(1).join(',')})';
    }
  }
  
  // 기본: 공백으로 구분
  return values.join(' ');
}

/// 복합 필드 매핑: 복합 필드 → 개별 필드 리스트
/// 예: 'date(day)' → ['date', 'day']
final Map<String, List<String>> kPdfCompositeFieldMapping = {
  for (String composite in kPdfCompositeFieldBases)
    composite: parseCompositeField(composite)
};

/// (옵션) 헤더/메타 필드가 필요한 경우 여기에 정의하세요.
/// 필요 없으면 비워두거나 이 섹션을 삭제해도 됩니다.
const Map<String, String> kPdfHeaderFields = {
  // 'date': 'H_DATE',
  // 'writer': 'H_WRITER',
};


