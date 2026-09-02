import '../utils/class_name_parser.dart';
import 'substitution_plan_viewmodel.dart';

/// 교체 노드 파싱 헬퍼 클래스
///
/// 중복된 노드 파싱 로직을 통합합니다.
///
/// §10.10: 결강일·교체일은 `ExchangeHistoryItem.absenceDate`/`substitutionDate`가
/// 유일한 진실원본이다(`savedDates` 제거됨). 이 클래스는 더 이상 날짜를
/// 저장소에서 조회하지 않고, 호출부(`SubstitutionPlanViewModel`)가 전달한
/// 값을 그대로 문자열로 포맷해 채운다.
class ExchangeNodeParser {
  /// 공통 노드 파싱 메서드
  SubstitutionPlanData parseNode({
    required dynamic sourceNode,
    required dynamic targetNode,
    required String exchangeId,
    required String groupId,
    required String absenceDate,
    required String substitutionDate,
    String? remarks,
    bool isCircular = false,
    bool isDual = false,
    bool isSupplement = false,
  }) {
    final parsed = ClassNameParser.parse(sourceNode.className);

    if (isSupplement) {
      // 보강
      return SubstitutionPlanData(
        exchangeId: exchangeId,
        absenceDate: absenceDate,
        absenceDay: sourceNode.day,
        period: sourceNode.period.toString(),
        grade: parsed['grade']!,
        className: parsed['class']!,
        subject: sourceNode.subjectName,
        teacher: sourceNode.teacherName,
        supplementSubject: '',
        supplementTeacher: targetNode.teacherName,
        substitutionDate: '',
        substitutionDay: '',
        substitutionPeriod: '',
        substitutionSubject: '',
        substitutionTeacher: '',
        remarks: remarks ?? '보강',
        groupId: groupId,
      );
    }

    // 수업 교체 (1:1, 순환, 2중)
    return SubstitutionPlanData(
      exchangeId: exchangeId,
      absenceDate: absenceDate,
      absenceDay: sourceNode.day,
      period: sourceNode.period.toString(),
      grade: parsed['grade']!,
      className: parsed['class']!,
      subject: sourceNode.subjectName,
      teacher: sourceNode.teacherName,
      supplementSubject: '',
      supplementTeacher: '',
      substitutionDate: substitutionDate,
      substitutionDay: targetNode.day,
      substitutionPeriod: targetNode.period.toString(),
      substitutionSubject: targetNode.subjectName,
      substitutionTeacher: targetNode.teacherName,
      remarks: remarks ?? '',
      groupId: groupId,
    );
  }
}
