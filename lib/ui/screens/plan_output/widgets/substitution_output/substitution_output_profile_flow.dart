/// 계획서(교사별 인쇄 프로파일) 흐름 중 ref/setState에 의존하지 않는 순수 로직 모음
///
/// [SubstitutionOutputWidgetState]의 계획서 선택 흐름 메서드들은 ref.read·
/// setState·mounted·인스턴스 필드에 깊게 엉켜 있어 그대로 옮기면 동작이
/// 바뀔 위험이 큽니다. 여기에는 입력값만으로 결과가 결정되는, 안전하게
/// 분리 가능한 계산 로직만 추출했습니다. ref 읽기와 setState는 여전히
/// 위젯 쪽에서 수행하고, 그 결과(원시값)만 이 함수들에 전달합니다.
library;

import '../../../../../constants/korean_fonts.dart';
import '../../../../../models/print_profile.dart';

/// 교사 이름 목록을 정리(trim → 빈 값 제외 → 중복 제거 → 가나다순 정렬)
///
/// [SubstitutionOutputWidgetState._availableTeachers]에서 추출한 순수 로직.
/// 준비 화면(activeTimetableTeachersProvider)과 동일하게 trim 후 비교합니다.
List<String> sortedAvailableTeacherNames(Iterable<String> rawNames) {
  final names =
      rawNames.map((n) => n.trim()).where((n) => n.isNotEmpty).toSet().toList()
        ..sort();
  return names;
}

/// 결보강 출력 '교사' 드롭다운의 초기/우선 교사 결정
///
/// 우선순위:
/// 1. 준비 화면(활성 시간표)에서 고른 교사
/// 2. 계획서에서 마지막으로 고른 교사
/// 3. 시간표 교사 목록의 첫 번째
///
/// [SubstitutionOutputWidgetState._resolvePreferredTeacher]에서 추출한 순수 로직.
String? resolvePreferredTeacher({
  required List<String> teachers,
  required String preparedTeacher,
  required String? lastSelectedTeacher,
}) {
  if (teachers.isEmpty) return null;

  // 준비 > 교사 선택이 단일 출처 (activeTeacherNameProvider)
  final prepared = preparedTeacher.trim();
  if (prepared.isNotEmpty && teachers.contains(prepared)) {
    return prepared;
  }

  if (lastSelectedTeacher != null && teachers.contains(lastSelectedTeacher)) {
    return lastSelectedTeacher;
  }

  return teachers.first;
}

/// 폰트 값이 선택 가능한 드롭다운 목록에 있는지 검증
///
/// 없으면(또는 null이면) 플랫폼 기본 폰트로 대체합니다.
/// [SubstitutionOutputWidgetState._loadSavedSettings]와
/// [SubstitutionOutputWidgetState._applyProfileToUi]에 중복돼 있던
/// 폰트 유효성 검사 로직을 하나로 통합했습니다.
String resolveValidFont(String? candidate) {
  final availableFonts =
      KoreanFontConstants.platformFontListWithNames
          .map((font) => font['file']!)
          .toList();
  return (candidate != null && availableFonts.contains(candidate))
      ? candidate
      : KoreanFontConstants.platformDefaultFont;
}

/// 현재 화면 입력값으로 계획서 객체 갱신
///
/// [SubstitutionOutputWidgetState._collectProfileFromUi]에서 추출한 순수 로직.
PrintProfile collectProfileFromFields({
  required PrintProfile base,
  required int templateIndex,
  required double fontSize,
  required double remarksFontSize,
  required String selectedFont,
  required bool includeRemarks,
  required String? selectedTemplateFilePath,
  required String teacherName,
  required String absencePeriod,
  required String workStatus,
  required String reasonForAbsence,
  required String schoolName,
  required String notes,
}) {
  return base.copyWith(
    templateIndex: templateIndex,
    fontSize: fontSize,
    remarksFontSize: remarksFontSize,
    selectedFont: selectedFont,
    includeRemarks: includeRemarks,
    selectedTemplateFilePath: selectedTemplateFilePath,
    additionalFields: {
      'teacherName': teacherName,
      'absencePeriod': absencePeriod,
      'workStatus': workStatus,
      'reasonForAbsence': reasonForAbsence,
      'schoolName': schoolName,
      'notes': notes,
    },
  );
}
