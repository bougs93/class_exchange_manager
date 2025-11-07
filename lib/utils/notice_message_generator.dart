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

    final className = groupDataList.first.fullClassName;
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
      final className = data.fullClassName;
      final category = _getExchangeCategory(data);

      switch (category) {
        case ExchangeCategory.basic:
          // 기본 교체 유형: <-> 형식 (날짜는 월.일 형식으로 변환)
          exchangeLines.add(
            "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' <-> '${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업 교체되었습니다."
          );
          break;
        case ExchangeCategory.circularFourPlus:
          // 순환교체 4단계 이상: -> 형식, 각 교사가 자신의 과목을 들고 이동 (날짜는 월.일 형식으로 변환)
          if (teacherName == data.teacher) {
            exchangeLines.add(
              "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시' -> '${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.subject} $className' 이동 되었습니다."
            );
          }
          break;
        case ExchangeCategory.supplement:
          // 보강 교체 (날짜는 월.일 형식으로 변환)
          if (teacherName == data.teacher) {
            exchangeLines.add(
              "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' 결강(보강) 되었습니다."
            );
          } else if (teacherName == data.supplementTeacher) {
            exchangeLines.add(
              "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject}' 보강 수업입니다."
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

    // 연쇄교체와 일반 교체 그룹화
    final chainGroups = _groupChainExchanges(sortedDataList);
    final nonChainData = chainGroups['nonChain']!;

    // 연쇄교체 그룹별로 최종 결과 계산하여 메시지 생성
    for (final groupEntry in chainGroups.entries) {
      if (groupEntry.key == 'nonChain') continue;

      final groupDataList = groupEntry.value;
      final chainLines = _generateChainExchangeOption2Lines(groupDataList, teacherName);
      classLines.addAll(chainLines);
    }

    // 일반 교체 메시지 생성
    classLines.addAll(_generateNonChainTeacherLines(nonChainData, teacherName));

    return classLines;
  }

  /// 연쇄교체 그룹화 헬퍼
  static Map<String?, List<SubstitutionPlanData>> _groupChainExchanges(
    List<SubstitutionPlanData> dataList,
  ) {
    final Map<String?, List<SubstitutionPlanData>> chainGroups = {};
    final List<SubstitutionPlanData> nonChainData = [];

    for (final data in dataList) {
      // 연쇄교체인지 확인 (groupId 또는 remarks로 확인)
      final isChainExchange = (data.groupId != null && GroupIdParser.isChain(data.groupId!)) ||
                              data.remarks.contains('연쇄교체');

      if (isChainExchange) {
        chainGroups.putIfAbsent(data.groupId, () => []).add(data);
      } else {
        nonChainData.add(data);
      }
    }

    chainGroups['nonChain'] = nonChainData;
    return chainGroups;
  }

  /// 일반 교체 교사 메시지 라인 생성
  static List<String> _generateNonChainTeacherLines(
    List<SubstitutionPlanData> dataList,
    String teacherName,
  ) {
    final List<String> classLines = [];

    for (final data in dataList) {
      final className = data.fullClassName;
      final category = _getExchangeCategory(data);

      switch (category) {
        case ExchangeCategory.basic:
          classLines.addAll(_generateBasicExchangeTeacherLines(data, className, teacherName));
          break;
        case ExchangeCategory.circularFourPlus:
          classLines.addAll(_generateCircularFourPlusTeacherLines(data, className, teacherName));
          break;
        case ExchangeCategory.supplement:
          classLines.addAll(_generateSupplementTeacherLines(data, className, teacherName));
          break;
      }
    }

    return classLines;
  }

  /// 기본 교체 교사 메시지 라인 생성
  static List<String> _generateBasicExchangeTeacherLines(
    SubstitutionPlanData data,
    String className,
    String teacherName,
  ) {
    final List<String> lines = [];

    if (teacherName == data.teacher) {
      lines.add(
        "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.subject} ${data.fullClassName}' 결강입니다."
      );
      lines.add(
        "'${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} ${data.fullClassName}' 수업입니다."
      );
    } else if (teacherName == data.substitutionTeacher) {
      lines.add(
        "'${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} ${data.fullClassName}' 결강입니다."
      );
      lines.add(
        "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.subject} ${data.fullClassName}' 수업입니다."
      );
    }

    return lines;
  }

  /// 순환교체 4단계 이상 교사 메시지 라인 생성
  static List<String> _generateCircularFourPlusTeacherLines(
    SubstitutionPlanData data,
    String className,
    String teacherName,
  ) {
    final List<String> lines = [];

    if (teacherName == data.teacher) {
      lines.add(
        "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시' -> '${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.subject} ${data.fullClassName}' 이동 되었습니다."
      );
    }

    return lines;
  }

  /// 보강 교체 교사 메시지 라인 생성
  static List<String> _generateSupplementTeacherLines(
    SubstitutionPlanData data,
    String className,
    String teacherName,
  ) {
    final List<String> lines = [];

    if (teacherName == data.teacher) {
      lines.add(
        "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.subject}' 결강(보강) 되었습니다."
      );
    } else if (teacherName == data.supplementTeacher) {
      lines.add(
        "'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 ${data.fullClassName} ${data.supplementSubject}' 보강 수업입니다."
      );
    }

    return lines;
  }

  /// 연쇄교체 옵션2 라인 생성 (최종 결과 반영)
  ///
  /// 연쇄교체는 2단계로 이루어지며, 각 교사별로 최종 결과를 계산하여 메시지를 생성합니다.
  /// - 중간 단계 (remarks: '연쇄교체(중간)'): node1 ↔ node2
  /// - 최종 단계 (remarks: '연쇄교체(최종)'): nodeA ↔ nodeB
  ///
  /// 최종 결과:
  /// - 중간 단계의 교사들은 교체 후 최종 위치에 있는 수업을 표시
  /// - 최종 단계의 교사들은 결강과 교체 후 수업을 표시
  static List<String> _generateChainExchangeOption2Lines(
    List<SubstitutionPlanData> groupDataList,
    String teacherName,
  ) {
    final List<String> classLines = [];

    // 중간 단계와 최종 단계 구분
    SubstitutionPlanData? intermediateData; // 연쇄교체(중간)
    SubstitutionPlanData? finalData; // 연쇄교체(최종)

    for (final data in groupDataList) {
      if (data.remarks == '연쇄교체(중간)') {
        intermediateData = data;
      } else if (data.remarks == '연쇄교체(최종)') {
        finalData = data;
      }
    }

    // 데이터가 하나도 없으면 빈 리스트 반환
    if (intermediateData == null && finalData == null) {
      return classLines;
    }

    // 각 교사별 메시지 추가
    _addIntermediateSourceTeacherLines(classLines, intermediateData, teacherName);
    _addFinalSourceTeacherLines(classLines, finalData, teacherName);
    _addIntermediateSubstitutionTeacherLines(classLines, intermediateData, teacherName);
    _addFinalSubstitutionTeacherLines(classLines, finalData, teacherName);

    return classLines;
  }

  /// 연쇄교체 중간 단계 원래 교사 메시지 추가
  static void _addIntermediateSourceTeacherLines(
    List<String> classLines,
    SubstitutionPlanData? intermediateData,
    String teacherName,
  ) {
    if (intermediateData == null || teacherName != intermediateData.teacher) return;

    classLines.add(
      "'${intermediateData.formattedSubstitutionDate} ${intermediateData.substitutionDay} ${intermediateData.substitutionPeriod}교시 ${intermediateData.subject} ${intermediateData.fullClassName}' 수업입니다."
    );
  }

  /// 연쇄교체 최종 단계 원래 교사 메시지 추가
  static void _addFinalSourceTeacherLines(
    List<String> classLines,
    SubstitutionPlanData? finalData,
    String teacherName,
  ) {
    if (finalData == null || teacherName != finalData.teacher) return;

    classLines.add(
      "'${finalData.formattedAbsenceDate} ${finalData.absenceDay} ${finalData.period}교시 ${finalData.subject} ${finalData.fullClassName}' 결강입니다."
    );
    classLines.add(
      "'${finalData.formattedSubstitutionDate} ${finalData.substitutionDay} ${finalData.substitutionPeriod}교시 ${finalData.subject} ${finalData.fullClassName}' 수업입니다."
    );
  }

  /// 연쇄교체 중간 단계 교체 교사 메시지 추가
  static void _addIntermediateSubstitutionTeacherLines(
    List<String> classLines,
    SubstitutionPlanData? intermediateData,
    String teacherName,
  ) {
    if (intermediateData == null || teacherName != intermediateData.substitutionTeacher) return;

    classLines.add(
      "'${intermediateData.formattedSubstitutionDate} ${intermediateData.substitutionDay} ${intermediateData.substitutionPeriod}교시 ${intermediateData.substitutionSubject} ${intermediateData.fullClassName}' 결강입니다."
    );
    classLines.add(
      "'${intermediateData.formattedAbsenceDate} ${intermediateData.absenceDay} ${intermediateData.period}교시 ${intermediateData.substitutionSubject} ${intermediateData.fullClassName}' 수업입니다."
    );
  }

  /// 연쇄교체 최종 단계 교체 교사 메시지 추가
  static void _addFinalSubstitutionTeacherLines(
    List<String> classLines,
    SubstitutionPlanData? finalData,
    String teacherName,
  ) {
    if (finalData == null || teacherName != finalData.substitutionTeacher) return;

    classLines.add(
      "'${finalData.formattedSubstitutionDate} ${finalData.substitutionDay} ${finalData.substitutionPeriod}교시 ${finalData.substitutionSubject} ${finalData.fullClassName}' 결강입니다."
    );
    classLines.add(
      "'${finalData.formattedAbsenceDate} ${finalData.absenceDay} ${finalData.period}교시 ${finalData.substitutionSubject} ${finalData.fullClassName}' 수업입니다."
    );
  }

  /// 교체 유형 구분 헬퍼 메서드 (그룹ID 기반)
  static ExchangeCategory _getExchangeCategory(SubstitutionPlanData data) {
    // 보강 교체 확인
    if (_isSupplement(data)) {
      return ExchangeCategory.supplement;
    }

    // 순환교체 4단계 이상 확인
    if (GroupIdParser.isCircular4Plus(data.groupId)) {
      return ExchangeCategory.circularFourPlus;
    }

    // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체)
    return ExchangeCategory.basic;
  }

  /// 보강 교체 여부 확인 (공통 로직)
  static bool _isSupplement(SubstitutionPlanData data) {
    return data.supplementTeacher.isNotEmpty || GroupIdParser.isSupplement(data.groupId);
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
    if (_isSupplement(data)) {
      return ExchangeType.supplement;
    }

    final step = GroupIdParser.extractCircularStep(data.groupId);
    if (step != null && step >= 4) {
      return ExchangeType.circular;
    }

    return ExchangeType.substitution;
  }

  /// 리스트의 교체 유형 결정 (우선순위: 보강 > 순환 > 수업교체)
  static ExchangeType _determineExchangeType(List<SubstitutionPlanData> dataList) {
    // 보강 교체가 하나라도 있으면 보강으로 분류
    if (dataList.any(_isSupplement)) {
      return ExchangeType.supplement;
    }

    // 순환교체 4단계 이상이 있으면 순환교체로 분류
    for (final data in dataList) {
      final step = GroupIdParser.extractCircularStep(data.groupId);
      if (step != null && step >= 4) {
        return ExchangeType.circular;
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

    final className = dataList.first.fullClassName;
    final List<String> messageLines = [];

    // 헤더 메시지 추가 (한 번만)
    messageLines.add('$className 수업변경 안내');

    // 교체 유형별로 메시지 생성 (헤더 제외)
    for (final data in dataList) {
      final content = data.substitutionDate.isNotEmpty
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
    final className = data.fullClassName;

    if (messageOption == MessageOption.option1) {
      // 옵션1: 교체 형태 - 교체 유형에 따라 화살표 형식 구분 (따옴표 제거)
      final category = _getExchangeCategory(data);
      final arrowFormat = category == ExchangeCategory.circularFourPlus ? '->' : '<->';

      if (isFirstMessage) {
        return '''$className 수업변경 안내
${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher} $arrowFormat ${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}''';
      } else {
        return '''${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher} $arrowFormat ${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}''';
      }
    } else {
      // 옵션2: 분리된 형태 (따옴표 및 " 수업입니다." 문구 제거)
      if (isFirstMessage) {
        return '''$className 수업변경 안내
${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}
${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.subject} ${data.teacher}''';
      } else {
        return '''${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}
${data.formattedSubstitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.subject} ${data.teacher}''';
      }
    }
  }

  /// 학급 보강 메시지 생성
  static String _generateClassSupplementMessage(SubstitutionPlanData data, bool isFirstMessage) {
    final className = data.fullClassName;

    if (isFirstMessage) {
      return '''$className 수업변경 안내
'${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업입니다.''';
    } else {
      return ''''${data.formattedAbsenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업입니다.''';
    }
  }
}
