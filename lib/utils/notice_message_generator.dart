import '../models/notice_message.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/logger.dart';
import 'notice_message_helpers.dart';

/// 안내 메시지 생성기
///
/// SubstitutionPlanData를 기반으로 학급안내와 교사안내 메시지를 생성합니다.
/// 교체 유형(수업교체/보강)과 메시지 옵션(옵션1/옵션2)에 따라 다른 형태의 메시지를 생성합니다.
class NoticeMessageGenerator {
  /// 학급별 안내 메시지 생성
  ///
  /// [planDataList]: 교체 계획 데이터 리스트
  /// [messageOption]: 메시지 옵션 (옵션1 또는 옵션2)
  /// 반환: 학급별로 그룹화된 안내 메시지 리스트
  static List<NoticeMessageGroup> generateClassMessages(
    List<SubstitutionPlanData> planDataList,
    MessageOption messageOption,
  ) {
    AppLogger.exchangeDebug('학급 메시지 생성 시작 - 데이터 개수: ${planDataList.length}, 옵션: ${messageOption.displayName}');

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
        final category = _getExchangeCategory(data);

        if (category == ExchangeCategory.circularFourPlus) {
          // 순환교체 4단계 이상: 그룹화하여 처리
          circularGroups.putIfAbsent(data.groupId, () => []).add(data);
        } else {
          // 기본 교체 유형과 보강 교체: 일반 교체로 처리
          otherData.add(data);
        }
      }

      // 순환교체 그룹별로 메시지 생성
      for (final groupEntry in circularGroups.entries) {
        final groupDataList = groupEntry.value;
        // 그룹 내에서 날짜순으로 정렬
        final sortedGroupData = DataSorter.sortByDateAndPeriod(groupDataList);

        final message = _generateCircularGroupMessage(sortedGroupData, messageOption);
        if (message != null) {
          messages.add(message);
        }
      }

      // 일반 교체 메시지 생성 (날짜순 정렬)
      final sortedOtherData = DataSorter.sortByDateAndPeriod(otherData);

      // 일반 교체가 있는 경우 하나의 통합 메시지로 생성
      if (sortedOtherData.isNotEmpty) {
        final isFirstMessage = circularGroups.isEmpty; // 순환교체가 없을 때만 첫 번째 메시지
        final message = _generateClassCombinedMessage(sortedOtherData, messageOption, isFirstMessage);
        if (message != null) {
          messages.add(message);
        }
      }

      if (messages.isNotEmpty) {
        classMessageGroups.add(NoticeMessageGroup(
          groupIdentifier: className,
          messages: messages,
          groupType: GroupType.classGroup,
        ));
      }
    }

    AppLogger.exchangeDebug('학급 메시지 그룹 생성 완료 - 그룹 개수: ${classMessageGroups.length}');
    return classMessageGroups;
  }

  /// 순환교체 그룹 메시지 생성
  static NoticeMessage? _generateCircularGroupMessage(
    List<SubstitutionPlanData> groupDataList,
    MessageOption messageOption,
  ) {
    if (groupDataList.isEmpty) return null;

    final className = '${groupDataList.first.grade}-${groupDataList.first.className}';
    final List<String> exchangeLines = [];

    for (final data in groupDataList) {
      final category = _getExchangeCategory(data);
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
      exchangeType: _determineExchangeType(groupDataList),
      exchangeTypeCombination: _determineExchangeTypeCombination(groupDataList),
      messageOption: messageOption,
      exchangeId: groupDataList.first.exchangeId,
    );
  }

  /// 교사별 안내 메시지 생성
  ///
  /// [planDataList]: 교체 계획 데이터 리스트
  /// [messageOption]: 메시지 옵션 (옵션1 또는 옵션2)
  /// 반환: 교사별로 그룹화된 안내 메시지 리스트
  static List<NoticeMessageGroup> generateTeacherMessages(
    List<SubstitutionPlanData> planDataList,
    MessageOption messageOption,
  ) {
    AppLogger.exchangeDebug('교사 메시지 생성 시작 - 데이터 개수: ${planDataList.length}, 옵션: ${messageOption.displayName}');

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
      final message = _generateTeacherGroupMessage(teacherDataList, teacherName, messageOption);
      if (message != null) {
        teacherMessageGroups.add(NoticeMessageGroup(
          groupIdentifier: teacherName,
          messages: [message],
          groupType: GroupType.teacherGroup,
        ));
      }
    }

    AppLogger.exchangeDebug('교사 메시지 그룹 생성 완료 - 그룹 개수: ${teacherMessageGroups.length}');
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
      // 옵션1: 화살표 형태
      final exchangeLines = _generateTeacherOption1Lines(sortedDataList, teacherName);

      if (exchangeLines.isEmpty) return null;

      return NoticeMessage(
        identifier: teacherName,
        content: ''''$teacherName' 선생님
${exchangeLines.join('\n')}''',
        exchangeType: _determineExchangeType(sortedDataList),
        exchangeTypeCombination: _determineExchangeTypeCombination(sortedDataList),
        messageOption: messageOption,
        exchangeId: sortedDataList.first.exchangeId,
      );
    } else {
      // 옵션2: 수업 형태
      final classLines = _generateTeacherOption2Lines(sortedDataList, teacherName);

      // 해당 교사가 관련된 수업이 있는 경우만 메시지 생성
      if (classLines.isNotEmpty) {
        return NoticeMessage(
          identifier: teacherName,
          content: ''''$teacherName' 선생님
${classLines.join('\n')}''',
          exchangeType: _determineExchangeType(sortedDataList),
          exchangeTypeCombination: _determineExchangeTypeCombination(sortedDataList),
          messageOption: messageOption,
          exchangeId: sortedDataList.first.exchangeId,
        );
      }
    }

    return null;
  }

  /// 교사 메시지 옵션1 라인 생성
  static List<String> _generateTeacherOption1Lines(
    List<SubstitutionPlanData> sortedDataList,
    String teacherName,
  ) {
    final List<String> exchangeLines = [];

    for (final data in sortedDataList) {
      final className = '${data.grade}-${data.className}';
      final category = _getExchangeCategory(data);

      switch (category) {
        case ExchangeCategory.basic:
          // 기본 교체 유형: <-> 형식
          exchangeLines.add(
            "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' <-> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업 교체되었습니다."
          );
          break;
        case ExchangeCategory.circularFourPlus:
          // 순환교체 4단계 이상: -> 형식, 각 교사가 자신의 수업에 관련된 교체만 표시
          if (teacherName == data.teacher) {
            exchangeLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' -> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 이동 되었습니다."
            );
          }
          break;
        case ExchangeCategory.supplement:
          // 보강 교체
          if (teacherName == data.teacher) {
            exchangeLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' 결강(보강) 되었습니다."
            );
          } else if (teacherName == data.supplementTeacher) {
            exchangeLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject}' 보강 수업입니다."
            );
          }
          break;
      }
    }

    return exchangeLines;
  }

  /// 교사 메시지 옵션2 라인 생성
  static List<String> _generateTeacherOption2Lines(
    List<SubstitutionPlanData> sortedDataList,
    String teacherName,
  ) {
    final List<String> classLines = [];

    for (final data in sortedDataList) {
      final className = '${data.grade}-${data.className}';
      final category = _getExchangeCategory(data);

      switch (category) {
        case ExchangeCategory.basic:
          // 기본 교체 유형: 각 교사가 자신의 결강과 수업을 명확히 구분하여 표시
          if (teacherName == data.teacher) {
            classLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 ${data.subject} $className' 결강입니다."
            );
            classLines.add(
              "'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} $className' 수업입니다."
            );
          } else if (teacherName == data.substitutionTeacher) {
            classLines.add(
              "'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} $className' 결강입니다."
            );
            classLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 ${data.subject} $className' 수업입니다."
            );
          }
          break;
        case ExchangeCategory.circularFourPlus:
          // 순환교체 4단계 이상: 각 교사가 자신이 직접 이동하는 수업만 표시
          if (teacherName == data.teacher) {
            classLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시' -> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} $className' 이동 되었습니다."
            );
          }
          break;
        case ExchangeCategory.supplement:
          // 보강 교체
          if (teacherName == data.teacher) {
            classLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' 결강(보강) 되었습니다."
            );
          } else if (teacherName == data.supplementTeacher) {
            classLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject}' 보강 수업입니다."
            );
          }
          break;
      }
    }

    return classLines;
  }

  /// 교체 유형 구분 헬퍼 메서드 (그룹ID 기반)
  static ExchangeCategory _getExchangeCategory(SubstitutionPlanData data) {
    // 보강 교체 확인
    if (data.supplementTeacher.isNotEmpty) {
      return ExchangeCategory.supplement;
    }

    // 순환교체 4단계 이상 확인
    if (GroupIdParser.isCircular4Plus(data.groupId)) {
      return ExchangeCategory.circularFourPlus;
    }

    // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체)
    return ExchangeCategory.basic;
  }

  /// 교체 유형 결정 헬퍼 메서드 (그룹ID 기반)
  static ExchangeTypeCombination _determineExchangeTypeCombination(List<SubstitutionPlanData> dataList) {
    final List<ExchangeType> types = [];

    for (final data in dataList) {
      final type = _getExchangeTypeForData(data);

      if (!types.contains(type)) {
        types.add(type);
      }
    }

    return ExchangeTypeCombination(types);
  }

  /// 개별 데이터의 교체 유형 결정
  static ExchangeType _getExchangeTypeForData(SubstitutionPlanData data) {
    if (data.supplementTeacher.isNotEmpty) {
      return ExchangeType.supplement;
    }

    final step = GroupIdParser.extractCircularStep(data.groupId);
    if (step != null && step >= 4) {
      return ExchangeType.circular;
    }

    return ExchangeType.substitution;
  }

  static ExchangeType _determineExchangeType(List<SubstitutionPlanData> dataList) {
    // 보강 교체가 하나라도 있으면 보강으로 분류
    for (final data in dataList) {
      if (data.supplementTeacher.isNotEmpty) {
        return ExchangeType.supplement;
      }
    }

    // 그룹ID 기반으로 교체 유형 판단
    for (final data in dataList) {
      if (GroupIdParser.isSupplement(data.groupId)) {
        return ExchangeType.supplement;
      }

      final step = GroupIdParser.extractCircularStep(data.groupId);
      if (step != null) {
        if (step >= 4) {
          return ExchangeType.circular; // 4단계 이상은 순환교체
        }
        return ExchangeType.substitution; // 3단계 이하는 수업교체
      }

      if (GroupIdParser.isOneToOne(data.groupId) || GroupIdParser.isChain(data.groupId)) {
        return ExchangeType.substitution;
      }
    }

    // 그 외에는 수업교체
    return ExchangeType.substitution;
  }

  /// 학급 통합 메시지 생성 (여러 교체 유형을 하나의 메시지로)
  static NoticeMessage? _generateClassCombinedMessage(
    List<SubstitutionPlanData> dataList,
    MessageOption messageOption,
    bool isFirstMessage,
  ) {
    if (dataList.isEmpty) return null;

    final className = '${dataList.first.grade}-${dataList.first.className}';
    final List<String> messageLines = [];

    // 헤더 메시지 추가 (한 번만)
    messageLines.add('$className 수업변경 안내');

    // 교체 유형별로 메시지 생성 (헤더 제외)
    for (final data in dataList) {
      final exchangeType = data.substitutionDate.isNotEmpty
          ? ExchangeType.substitution
          : ExchangeType.supplement;

      String content;

      if (exchangeType == ExchangeType.substitution) {
        // 수업교체 메시지 (헤더 제외)
        content = _generateClassSubstitutionMessage(data, messageOption, false);
      } else {
        // 보강 메시지 (헤더 제외)
        content = _generateClassSupplementMessage(data, false);
      }

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
      identifier: className,
      content: combinedContent,
      exchangeType: _determineExchangeType(dataList),
      exchangeTypeCombination: _determineExchangeTypeCombination(dataList),
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
    final className = '${data.grade}-${data.className}';

    if (messageOption == MessageOption.option1) {
      // 옵션1: 교체 형태 - 교체 유형에 따라 화살표 형식 구분
      final category = _getExchangeCategory(data);
      final arrowFormat = category == ExchangeCategory.circularFourPlus ? '->' : '<->';

      if (isFirstMessage) {
        return '''$className 수업변경 안내
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' $arrowFormat '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' ''';
      } else {
        return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' $arrowFormat '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' ''';
      }
    } else {
      // 옵션2: 분리된 형태
      if (isFirstMessage) {
        return '''$className 수업변경 안내
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업입니다.
'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.subject} ${data.teacher}' 수업입니다.''';
      } else {
        return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업입니다.
'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.subject} ${data.teacher}' 수업입니다.''';
      }
    }
  }

  /// 학급 보강 메시지 생성
  static String _generateClassSupplementMessage(SubstitutionPlanData data, bool isFirstMessage) {
    final className = '${data.grade}-${data.className}';

    if (isFirstMessage) {
      return '''$className 수업변경 안내
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업입니다.''';
    } else {
      return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업입니다.''';
    }
  }
}
