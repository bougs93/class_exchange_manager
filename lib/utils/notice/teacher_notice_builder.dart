import '../../models/notice_message.dart';
import '../../providers/substitution_plan_viewmodel.dart';
import '../logger.dart';
import '../notice_message_helpers.dart';
import '../teacher_display.dart';
import 'notice_exchange_category.dart';
import 'teacher_notice_option1_lines.dart';
import 'teacher_notice_option2_lines.dart';
import 'teacher_notice_question_lines.dart';

/// 교사별 안내 메시지 생성 로직
class TeacherNoticeBuilder {
  /// 교사별 안내 메시지 생성
  ///
  /// [planDataList]: 교체 계획 데이터 리스트
  /// [messageOption]: 메시지 옵션 (옵션1 또는 옵션2)
  /// 반환: 교사별로 그룹화된 안내 메시지 리스트
  static List<NoticeMessageGroup> generateTeacherMessages(
    List<SubstitutionPlanData> planDataList,
    MessageOption messageOption,
  ) {
    AppLogger.exchangeDebug(
      '교사 메시지 생성 시작 - 데이터 개수: ${planDataList.length}, 옵션: ${messageOption.displayName}',
    );

    // 교사별로 그룹화 (원래 교사와 교체 교사 모두 포함)
    final Map<String, List<SubstitutionPlanData>> teacherGroups = {};

    for (final data in planDataList) {
      // 원래 교사 추가
      if (data.teacher.isNotEmpty) {
        teacherGroups.putIfAbsent(data.teacher, () => []).add(data);
      }

      // 교체 교사 추가 (수업교체인 경우)
      if (data.substitutionTeacher.isNotEmpty) {
        teacherGroups.putIfAbsent(data.substitutionTeacher, () => []).add(data);
      }

      // 보강 교사 추가 (보강인 경우)
      if (data.supplementTeacher.isNotEmpty) {
        teacherGroups.putIfAbsent(data.supplementTeacher, () => []).add(data);
      }
    }

    AppLogger.exchangeDebug('교사 그룹 개수: ${teacherGroups.length}');

    // 각 교사별로 메시지 생성
    final List<NoticeMessageGroup> teacherMessageGroups = [];

    for (final entry in teacherGroups.entries) {
      final teacherName = entry.key;
      final teacherDataList = entry.value;

      // 교사별로 하나의 통합 메시지 생성
      final message = _generateTeacherGroupMessage(
        teacherDataList,
        teacherName,
        messageOption,
      );
      if (message != null) {
        teacherMessageGroups.add(
          NoticeMessageGroup(
            groupIdentifier: teacherName,
            messages: [message],
            groupType: GroupType.teacherGroup,
          ),
        );
      }
    }

    AppLogger.exchangeDebug(
      '교사 메시지 그룹 생성 완료 - 그룹 개수: ${teacherMessageGroups.length}',
    );
    return teacherMessageGroups;
  }

  /// 교사 그룹 메시지 생성 (한 교사의 모든 교체를 하나의 메시지로 통합)
  static NoticeMessage? _generateTeacherGroupMessage(
    List<SubstitutionPlanData> teacherDataList,
    String teacherName,
    MessageOption messageOption,
  ) {
    if (teacherDataList.isEmpty) return null;

    // 날짜순으로 정렬
    final sortedDataList = DataSorter.sortByDateAndPeriod(teacherDataList);

    if (messageOption == MessageOption.option1) {
      // 질문 형태
      final exchangeLines =
          TeacherNoticeQuestionLines.generateTeacherQuestionLines(
            sortedDataList,
            teacherName,
          );

      if (exchangeLines.isEmpty) return null;

      return NoticeMessage(
        identifier: teacherName,
        content: '''${plainTeacherName(teacherName)} 선생님
${exchangeLines.join('\n')}''',
        exchangeType: NoticeExchangeCategorizer.determineExchangeType(
          sortedDataList,
        ),
        exchangeTypeCombination:
            NoticeExchangeCategorizer.determineExchangeTypeCombination(
              sortedDataList,
            ),
        messageOption: messageOption,
        exchangeId: sortedDataList.first.exchangeId,
      );
    } else if (messageOption == MessageOption.option2) {
      // 교체 안내 형태
      final exchangeLines =
          TeacherNoticeOption1Lines.generateTeacherOption1Lines(
            sortedDataList,
            teacherName,
          );

      if (exchangeLines.isEmpty) return null;

      return NoticeMessage(
        identifier: teacherName,
        content: '''${plainTeacherName(teacherName)} 선생님
${exchangeLines.join('\n')}''',
        exchangeType: NoticeExchangeCategorizer.determineExchangeType(
          sortedDataList,
        ),
        exchangeTypeCombination:
            NoticeExchangeCategorizer.determineExchangeTypeCombination(
              sortedDataList,
            ),
        messageOption: messageOption,
        exchangeId: sortedDataList.first.exchangeId,
      );
    } else {
      // 수업 안내 형태
      final classLines = TeacherNoticeOption2Lines.generateTeacherOption2Lines(
        sortedDataList,
        teacherName,
      );

      // 해당 교사가 관련된 수업이 있는 경우만 메시지 생성
      if (classLines.isNotEmpty) {
        return NoticeMessage(
          identifier: teacherName,
          content: '''${plainTeacherName(teacherName)} 선생님
${classLines.join('\n')}''',
          exchangeType: NoticeExchangeCategorizer.determineExchangeType(
            sortedDataList,
          ),
          exchangeTypeCombination:
              NoticeExchangeCategorizer.determineExchangeTypeCombination(
                sortedDataList,
              ),
          messageOption: messageOption,
          exchangeId: sortedDataList.first.exchangeId,
        );
      }
    }

    return null;
  }
}
