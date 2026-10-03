import '../../providers/substitution_plan_viewmodel.dart';
import '../date_format_utils.dart';
import 'teacher_notice_line.dart';

/// 2중교체(옵션: 수업 안내 형태) 교사 메시지 라인 생성 로직
///
/// 2중교체는 2단계로 이루어지며, 각 교사별로 최종 결과를 계산하여 메시지를 생성합니다.
/// - 중간 단계 (remarks: '2중교체(중간)'): node1 ↔ node2
/// - 최종 단계 (remarks: '2중교체(최종)'): nodeA ↔ nodeB
///
/// 최종 결과:
/// - 중간 단계의 교사들은 교체 후 최종 위치에 있는 수업을 표시
/// - 최종 단계의 교사들은 결강과 교체 후 수업을 표시
class TeacherNoticeDualLines {
  /// 2중교체 옵션2 라인 생성 (최종 결과 반영)
  static List<TeacherNoticeLine> generateDualExchangeOption2Lines(
    List<SubstitutionPlanData> groupDataList,
    String teacherName,
  ) {
    final List<TeacherNoticeLine> classLines = [];

    // 중간 단계와 최종 단계 구분
    SubstitutionPlanData? intermediateData; // 2중교체(중간)
    SubstitutionPlanData? finalData; // 2중교체(최종)

    for (final data in groupDataList) {
      if (data.remarks == '2중교체(중간)') {
        intermediateData = data;
      } else if (data.remarks == '2중교체(최종)') {
        finalData = data;
      }
    }

    // 데이터가 하나도 없으면 빈 리스트 반환
    if (intermediateData == null && finalData == null) {
      return classLines;
    }

    // 각 교사별 메시지 추가
    _addIntermediateSourceTeacherLines(
      classLines,
      intermediateData,
      teacherName,
    );
    _addFinalSourceTeacherLines(classLines, finalData, teacherName);
    _addIntermediateSubstitutionTeacherLines(
      classLines,
      intermediateData,
      teacherName,
    );
    _addFinalSubstitutionTeacherLines(classLines, finalData, teacherName);

    return classLines;
  }

  /// 2중교체 중간 단계 원래 교사 메시지 추가
  static void _addIntermediateSourceTeacherLines(
    List<TeacherNoticeLine> classLines,
    SubstitutionPlanData? intermediateData,
    String teacherName,
  ) {
    if (intermediateData == null || teacherName != intermediateData.teacher) {
      return;
    }

    classLines.add(
      TeacherNoticeLine(
        date: DateFormatUtils.parseYearMonthDay(
          intermediateData.substitutionDate,
        ),
        period: int.tryParse(intermediateData.substitutionPeriod) ?? 0,
        text:
            "${intermediateData.formattedSubstitutionDate} ${intermediateData.substitutionDay} ${intermediateData.substitutionPeriod}교시 ${intermediateData.subject} ${intermediateData.fullClassName} 수업입니다.",
      ),
    );
  }

  /// 2중교체 최종 단계 원래 교사 메시지 추가
  static void _addFinalSourceTeacherLines(
    List<TeacherNoticeLine> classLines,
    SubstitutionPlanData? finalData,
    String teacherName,
  ) {
    if (finalData == null || teacherName != finalData.teacher) {
      return;
    }

    classLines.add(
      TeacherNoticeLine(
        date: DateFormatUtils.parseYearMonthDay(finalData.absenceDate),
        period: int.tryParse(finalData.period) ?? 0,
        text:
            "${finalData.formattedAbsenceDate} ${finalData.absenceDay} ${finalData.period}교시 ${finalData.subject} ${finalData.fullClassName} 결강입니다.",
      ),
    );
    classLines.add(
      TeacherNoticeLine(
        date: DateFormatUtils.parseYearMonthDay(finalData.substitutionDate),
        period: int.tryParse(finalData.substitutionPeriod) ?? 0,
        text:
            "${finalData.formattedSubstitutionDate} ${finalData.substitutionDay} ${finalData.substitutionPeriod}교시 ${finalData.subject} ${finalData.fullClassName} 수업입니다.",
      ),
    );
  }

  /// 2중교체 중간 단계 교체 교사 메시지 추가
  static void _addIntermediateSubstitutionTeacherLines(
    List<TeacherNoticeLine> classLines,
    SubstitutionPlanData? intermediateData,
    String teacherName,
  ) {
    if (intermediateData == null ||
        teacherName != intermediateData.substitutionTeacher) {
      return;
    }

    classLines.add(
      TeacherNoticeLine(
        date: DateFormatUtils.parseYearMonthDay(
          intermediateData.substitutionDate,
        ),
        period: int.tryParse(intermediateData.substitutionPeriod) ?? 0,
        text:
            "${intermediateData.formattedSubstitutionDate} ${intermediateData.substitutionDay} ${intermediateData.substitutionPeriod}교시 ${intermediateData.substitutionSubject} ${intermediateData.fullClassName} 결강입니다.",
      ),
    );
    classLines.add(
      TeacherNoticeLine(
        date: DateFormatUtils.parseYearMonthDay(intermediateData.absenceDate),
        period: int.tryParse(intermediateData.period) ?? 0,
        text:
            "${intermediateData.formattedAbsenceDate} ${intermediateData.absenceDay} ${intermediateData.period}교시 ${intermediateData.substitutionSubject} ${intermediateData.fullClassName} 수업입니다.",
      ),
    );
  }

  /// 2중교체 최종 단계 교체 교사 메시지 추가
  static void _addFinalSubstitutionTeacherLines(
    List<TeacherNoticeLine> classLines,
    SubstitutionPlanData? finalData,
    String teacherName,
  ) {
    if (finalData == null || teacherName != finalData.substitutionTeacher) {
      return;
    }

    classLines.add(
      TeacherNoticeLine(
        date: DateFormatUtils.parseYearMonthDay(finalData.substitutionDate),
        period: int.tryParse(finalData.substitutionPeriod) ?? 0,
        text:
            "${finalData.formattedSubstitutionDate} ${finalData.substitutionDay} ${finalData.substitutionPeriod}교시 ${finalData.substitutionSubject} ${finalData.fullClassName} 결강입니다.",
      ),
    );
    classLines.add(
      TeacherNoticeLine(
        date: DateFormatUtils.parseYearMonthDay(finalData.absenceDate),
        period: int.tryParse(finalData.period) ?? 0,
        text:
            "${finalData.formattedAbsenceDate} ${finalData.absenceDay} ${finalData.period}교시 ${finalData.substitutionSubject} ${finalData.fullClassName} 수업입니다.",
      ),
    );
  }
}
