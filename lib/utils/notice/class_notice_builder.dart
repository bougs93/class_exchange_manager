import '../../models/notice_message.dart';
import '../../providers/substitution_plan_viewmodel.dart';
import '../logger.dart';
import '../notice_message_helpers.dart';
import 'notice_exchange_category.dart';

/// 학급별 안내 메시지 생성 로직
class ClassNoticeBuilder {
  /// 학급별 안내 메시지 생성
  ///
  /// [planDataList]: 교체 계획 데이터 리스트
  /// [messageOption]: 메시지 옵션 (옵션1 또는 옵션2)
  /// 반환: 학급별로 그룹화된 안내 메시지 리스트
  static List<NoticeMessageGroup> generateClassMessages(
    List<SubstitutionPlanData> planDataList,
    MessageOption messageOption,
  ) {
    AppLogger.exchangeDebug(
      '학급 메시지 생성 시작 - 데이터 개수: ${planDataList.length}, 옵션: ${messageOption.displayName}',
    );

    // 학급별로 그룹화
    final Map<String, List<SubstitutionPlanData>> classGroups = {};

    for (final data in planDataList) {
      final classKey = '${data.grade}-${data.className}';
      classGroups.putIfAbsent(classKey, () => []).add(data);
    }

    AppLogger.exchangeDebug('학급 그룹 개수: ${classGroups.length}');

    // 각 학급별로 메시지 생성
    final List<NoticeMessageGroup> classMessageGroups = [];

    for (final entry in classGroups.entries) {
      final className = entry.key;
      final classDataList = entry.value;

      final List<NoticeMessage> messages = [];

      // 순환교체 4단계 이상 그룹별 처리
      final Map<String?, List<SubstitutionPlanData>> circularGroups = {};
      final List<SubstitutionPlanData> otherData = [];

      for (final data in classDataList) {
        // 교체 유형 카테고리 구분
        final category = NoticeExchangeCategorizer.getExchangeCategory(data);

        if (category == ExchangeCategory.circularFourPlus) {
          // 순환교체 4단계 이상: 그룹화하여 처리
          circularGroups.putIfAbsent(data.groupId, () => []).add(data);
        } else {
          // 기본 교체 유형과 보강: 일반 교체로 처리
          otherData.add(data);
        }
      }

      // 순환교체 그룹별로 메시지 생성
      for (final groupEntry in circularGroups.entries) {
        final groupDataList = groupEntry.value;
        // 그룹 내에서 날짜순으로 정렬
        final sortedGroupData = DataSorter.sortByDateAndPeriod(groupDataList);

        final message = _generateCircularGroupMessage(
          sortedGroupData,
          messageOption,
        );
        if (message != null) {
          messages.add(message);
        }
      }

      // 일반 교체 메시지 생성 (날짜순 정렬)
      final sortedOtherData = DataSorter.sortByDateAndPeriod(otherData);

      // 일반 교체가 있는 경우 하나의 통합 메시지로 생성
      if (sortedOtherData.isNotEmpty) {
        final isFirstMessage = circularGroups.isEmpty; // 순환교체가 없을 때만 첫 번째 메시지
        final message = _generateClassCombinedMessage(
          sortedOtherData,
          messageOption,
          isFirstMessage,
        );
        if (message != null) {
          messages.add(message);
        }
      }

      if (messages.isNotEmpty) {
        classMessageGroups.add(
          NoticeMessageGroup(
            groupIdentifier: className,
            messages: messages,
            groupType: GroupType.classGroup,
          ),
        );
      }
    }

    AppLogger.exchangeDebug(
      '학급 메시지 그룹 생성 완료 - 그룹 개수: ${classMessageGroups.length}',
    );
    return classMessageGroups;
  }

  /// 순환교체 그룹 메시지 생성
  static NoticeMessage? _generateCircularGroupMessage(
    List<SubstitutionPlanData> groupDataList,
    MessageOption messageOption,
  ) {
    if (groupDataList.isEmpty) return null;

    final className = groupDataList.first.fullClassName;
    final List<String> exchangeLines = [];

    for (final data in groupDataList) {
      final category = NoticeExchangeCategorizer.getExchangeCategory(data);
      final message = MessageFormatter.format(
        data: data,
        className: className,
        category: category,
        option: messageOption,
      );

      if (message != null) {
        exchangeLines.add(message);
      }
    }

    if (exchangeLines.isEmpty) return null;

    return NoticeMessage(
      identifier: className,
      content: '''$className 수업변경 안내
${exchangeLines.join('\n')}''',
      exchangeType: NoticeExchangeCategorizer.determineExchangeType(
        groupDataList,
      ),
      exchangeTypeCombination:
          NoticeExchangeCategorizer.determineExchangeTypeCombination(
            groupDataList,
          ),
      messageOption: messageOption,
      exchangeId: groupDataList.first.exchangeId,
    );
  }

  /// 학급 통합 메시지 생성 (여러 교체 유형을 하나의 메시지로)
  static NoticeMessage? _generateClassCombinedMessage(
    List<SubstitutionPlanData> dataList,
    MessageOption messageOption,
    bool isFirstMessage,
  ) {
    if (dataList.isEmpty) return null;

    final List<String> messageLines = [];

    // 헤더 메시지 추가 (한 번만)
    messageLines.add('${dataList.first.fullClassName} 수업변경 안내');

    // 교체 유형별로 메시지 생성 (헤더 제외)
    for (final data in dataList) {
      final content =
          data.substitutionDate.isNotEmpty
              ? _generateClassSubstitutionMessage(data, messageOption, false)
              : _generateClassSupplementMessage(data, false);

      if (content.isNotEmpty) {
        messageLines.add(content);
      }
    }

    if (messageLines.length <= 1) {
      AppLogger.warning('학급 통합 메시지 생성 실패 - 데이터 개수: ${dataList.length}');
      return null;
    }

    // 모든 메시지를 하나로 합치기
    final combinedContent = messageLines.join('\n');

    return NoticeMessage(
      identifier: dataList.first.fullClassName,
      content: combinedContent,
      exchangeType: NoticeExchangeCategorizer.determineExchangeType(dataList),
      exchangeTypeCombination:
          NoticeExchangeCategorizer.determineExchangeTypeCombination(dataList),
      messageOption: messageOption,
      exchangeId: dataList.first.exchangeId,
    );
  }

  /// 학급 수업교체 메시지 생성
  static String _generateClassSubstitutionMessage(
    SubstitutionPlanData data,
    MessageOption messageOption,
    bool isFirstMessage,
  ) {
    if (messageOption == MessageOption.option1) {
      // 질문 형태
      final exchangeLine = _buildClassExchangeArrowLine(data, isFirstMessage);
      return '$exchangeLine 교체 가능하신지요?';
    } else if (messageOption == MessageOption.option2) {
      // 교체 안내 형태
      return _buildClassExchangeArrowLine(data, isFirstMessage);
    } else {
      // 수업 안내 형태
      if (isFirstMessage) {
        return '''${data.fullClassName} 수업변경 안내
${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.substitutionSubject} ${data.plainSubstitutionTeacher}
${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.fullClassName} ${data.subject} ${data.plainTeacher}''';
      } else {
        return '''${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.substitutionSubject} ${data.plainSubstitutionTeacher}
${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.fullClassName} ${data.subject} ${data.plainTeacher}''';
      }
    }
  }

  /// 학급 교체 안내 화살표 한 줄 생성
  static String _buildClassExchangeArrowLine(
    SubstitutionPlanData data,
    bool isFirstMessage,
  ) {
    final category = NoticeExchangeCategorizer.getExchangeCategory(data);
    final arrowFormat =
        category == ExchangeCategory.circularFourPlus ? '->' : '<->';

    if (isFirstMessage) {
      return '''${data.fullClassName} 수업변경 안내
${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.subject} ${data.plainTeacher} $arrowFormat ${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.fullClassName} ${data.substitutionSubject} ${data.plainSubstitutionTeacher}''';
    }

    return '''${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.subject} ${data.plainTeacher} $arrowFormat ${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.fullClassName} ${data.substitutionSubject} ${data.plainSubstitutionTeacher}''';
  }

  /// 학급 보강 메시지 생성
  static String _generateClassSupplementMessage(
    SubstitutionPlanData data,
    bool isFirstMessage,
  ) {
    if (isFirstMessage) {
      return '''${data.fullClassName} 수업변경 안내
'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.supplementSubject} ${data.plainSupplementTeacher}' 수업입니다.''';
    } else {
      return ''''${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.supplementSubject} ${data.plainSupplementTeacher}' 수업입니다.''';
    }
  }
}
