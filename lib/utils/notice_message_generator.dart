import '../models/notice_message.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/logger.dart';

/// 교체 유형 카테고리 (메시지 처리 방식 구분)
enum ExchangeCategory {
  basic,           // 1:1교체, 순환교체 3단계, 연쇄교체 (동일한 방식)
  supplement,      // 보강교체 (별도 방식)
  circularFourPlus, // 순환교체 4단계 이상 (별도 방식)
}

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
        
        switch (category) {
          case ExchangeCategory.circularFourPlus:
            // 순환교체 4단계 이상: 그룹화하여 처리
            circularGroups.putIfAbsent(data.groupId, () => []).add(data);
            break;
          case ExchangeCategory.basic:
          case ExchangeCategory.supplement:
            // 기본 교체 유형과 보강 교체: 일반 교체로 처리
            otherData.add(data);
            break;
        }
      }
      
      // 순환교체 그룹별로 메시지 생성
      for (final groupEntry in circularGroups.entries) {
        final groupDataList = groupEntry.value;
        // 그룹 내에서 날짜순으로 정렬 (결강일 기준)
        groupDataList.sort((a, b) {
          // 결강일 기준으로 정렬
          final aDate = a.absenceDate;
          final bDate = b.absenceDate;
          
          if (aDate != bDate) {
            return aDate.compareTo(bDate);
          }
          
          // 같은 날이면 교시 순으로
          final aPeriod = int.tryParse(a.period) ?? 0;
          final bPeriod = int.tryParse(b.period) ?? 0;
          return aPeriod.compareTo(bPeriod);
        });
        
        final message = _generateCircularGroupMessage(groupDataList, messageOption);
        if (message != null) {
          messages.add(message);
        }
      }
      
      // 일반 교체 메시지 생성 (날짜순 정렬)
      otherData.sort((a, b) {
        // 결강일 기준으로 정렬
        final aDate = a.absenceDate;
        final bDate = b.absenceDate;
        
        if (aDate != bDate) {
          return aDate.compareTo(bDate);
        }
        
        // 같은 날이면 교시 순으로
        final aPeriod = int.tryParse(a.period) ?? 0;
        final bPeriod = int.tryParse(b.period) ?? 0;
        return aPeriod.compareTo(bPeriod);
      });
      
      // 일반 교체가 있는 경우 하나의 통합 메시지로 생성
      if (otherData.isNotEmpty) {
        final isFirstMessage = circularGroups.isEmpty; // 순환교체가 없을 때만 첫 번째 메시지
        final message = _generateClassCombinedMessage(otherData, messageOption, isFirstMessage);
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
    
    // 날짜순으로 정렬 (결강일 기준)
    final sortedDataList = List<SubstitutionPlanData>.from(groupDataList);
    sortedDataList.sort((a, b) {
      // 결강일 기준으로 정렬
      final aDate = a.absenceDate;
      final bDate = b.absenceDate;
      
      if (aDate != bDate) {
        return aDate.compareTo(bDate);
      }
      
      // 같은 날이면 교시 순으로
      final aPeriod = int.tryParse(a.period) ?? 0;
      final bPeriod = int.tryParse(b.period) ?? 0;
      return aPeriod.compareTo(bPeriod);
    });
    
    if (messageOption == MessageOption.option1) {
      // 옵션1: 화살표 형태 - 교체 유형에 따라 형식 구분
      final List<String> exchangeLines = [];
      
      for (final data in sortedDataList) {
        // 교체 유형에 따라 화살표 형식 구분
        final category = _getExchangeCategory(data);
        
        switch (category) {
          case ExchangeCategory.basic:
            // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체): <-> 형식
            exchangeLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' <-> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}'"
            );
            break;
          case ExchangeCategory.circularFourPlus:
            // 순환교체 4단계 이상: -> 형식
            exchangeLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' -> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}'"
            );
            break;
          case ExchangeCategory.supplement:
            // 보강 교체는 순환교체 그룹에 포함되지 않음
            break;
        }
      }
      
      return NoticeMessage(
        identifier: className,
        content: '''$className 수업 교체되었습니다.
${exchangeLines.join('\n')}''',
        exchangeType: _determineExchangeType(groupDataList),
        exchangeTypeCombination: _determineExchangeTypeCombination(groupDataList),
        messageOption: messageOption,
        exchangeId: groupDataList.first.exchangeId,
      );
    } else {
      // 옵션2: 수업 형태 - 각 시간대별 수업 안내
      final List<String> classLines = [];
      
      for (final data in sortedDataList) {
        // 교체 유형에 따라 다른 로직 적용
        final category = _getExchangeCategory(data);
        
        switch (category) {
          case ExchangeCategory.basic:
            // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체): 교체 수업 표시
            classLines.add(
              "'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업입니다."
            );
            break;
          case ExchangeCategory.circularFourPlus:
            // 순환교체 4단계 이상: 각 시간대별 실제 수업하는 교사와 과목 표시
            // 결강일에는 교체 교사가 수업
            classLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업입니다."
            );
            break;
          case ExchangeCategory.supplement:
            // 보강 교체는 순환교체 그룹에 포함되지 않음
            break;
        }
      }
      
      return NoticeMessage(
        identifier: className,
        content: '''$className 수업 교체되었습니다.
${classLines.join('\n')}''',
        exchangeType: _determineExchangeType(groupDataList),
        exchangeTypeCombination: _determineExchangeTypeCombination(groupDataList),
        messageOption: messageOption,
        exchangeId: groupDataList.first.exchangeId,
      );
    }
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
    
    // 날짜순으로 정렬 (결강일 기준)
    final sortedDataList = List<SubstitutionPlanData>.from(teacherDataList);
    sortedDataList.sort((a, b) {
      // 결강일 기준으로 정렬
      final aDate = a.absenceDate;
      final bDate = b.absenceDate;
      
      if (aDate != bDate) {
        return aDate.compareTo(bDate);
      }
      
      // 같은 날이면 교시 순으로
      final aPeriod = int.tryParse(a.period) ?? 0;
      final bPeriod = int.tryParse(b.period) ?? 0;
      return aPeriod.compareTo(bPeriod);
    });
    
    if (messageOption == MessageOption.option1) {
      // 옵션1: 화살표 형태
      final List<String> exchangeLines = [];
      
      for (final data in sortedDataList) {
        final className = '${data.grade}-${data.className}';
        
        // 교체 유형 카테고리 구분
        final category = _getExchangeCategory(data);
        
        switch (category) {
          case ExchangeCategory.basic:
            // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체): <-> 형식
            exchangeLines.add(
              "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' <-> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 수업 교체되었습니다."
            );
            break;
          case ExchangeCategory.circularFourPlus:
            // 순환교체 4단계 이상: -> 형식, 각 교사가 자신의 수업에 관련된 교체만 표시
            if (teacherName == data.teacher) {
              // 원래 교사: 자신의 수업이 교체되는 경우
              exchangeLines.add(
                "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' -> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' 이동 되었습니다."
              );
            }
            break;
          case ExchangeCategory.supplement:
            // 보강 교체
            if (teacherName == data.teacher) {
              // 원래 교사: 자신의 수업이 결강(보강)되었다는 메시지
              exchangeLines.add(
                "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' 결강(보강) 되었습니다."
              );
            } else if (teacherName == data.supplementTeacher) {
              // 보강 교사: 보강 수업을 맡는다는 메시지
              exchangeLines.add(
                "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject}' 보강 수업입니다."
              );
            }
            break;
        }
      }
      
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
      final List<String> classLines = [];
      
      for (final data in sortedDataList) {
        final className = '${data.grade}-${data.className}';
        
        // 교체 유형 카테고리 구분
        final category = _getExchangeCategory(data);
        
        switch (category) {
          case ExchangeCategory.basic:
            // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체): 각 교사가 자신의 결강과 수업을 명확히 구분하여 표시
            if (teacherName == data.teacher) {
              // 원래 교사: 자신의 결강과 교체 수업 표시
              classLines.add(
                "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 ${data.subject} $className' 결강입니다."
              );
              classLines.add(
                "'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} $className' 수업입니다."
              );
            } else if (teacherName == data.substitutionTeacher) {
              // 교체 교사: 자신의 결강과 교체 수업 표시
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
              // 원래 교사: 자신이 이동하는 수업만 표시
              classLines.add(
                "'${data.absenceDate} ${data.absenceDay} ${data.period}교시' -> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 ${data.substitutionSubject} $className' 이동 되었습니다."
              );
            }
            break;
          case ExchangeCategory.supplement:
            // 보강 교체
            if (teacherName == data.teacher) {
              // 원래 교사: 자신의 수업이결강(보강)되었다는 메시지
              classLines.add(
                "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' 결강(보강) 되었습니다."
              );
            } else if (teacherName == data.supplementTeacher) {
              // 보강 교사: 보강 수업을 맡는다는 메시지
              classLines.add(
                "'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject}' 보강 수업입니다."
              );
            }
            break;
        }
      }
      
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
    
    return null; // 해당 교사가 이동하는 수업이 없는 경우
  }
  

  /// 교체 유형 구분 헬퍼 메서드 (그룹ID 기반)
  static ExchangeCategory _getExchangeCategory(SubstitutionPlanData data) {
    // 보강 교체 확인
    if (data.supplementTeacher.isNotEmpty) {
      return ExchangeCategory.supplement;
    }
    
    // 순환교체 4단계 이상 확인
    if (data.groupId != null && data.groupId!.startsWith('circular_exchange_')) {
      final stepMatch = RegExp(r'circular_exchange_(\d+)_').firstMatch(data.groupId!);
      if (stepMatch != null) {
        final stepCount = int.tryParse(stepMatch.group(1)!) ?? 0;
        if (stepCount >= 4) {
          return ExchangeCategory.circularFourPlus;
        }
      }
    }
    
    // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체)
    return ExchangeCategory.basic;
  }

  /// 교체 유형 결정 헬퍼 메서드 (그룹ID 기반)
  static ExchangeTypeCombination _determineExchangeTypeCombination(List<SubstitutionPlanData> dataList) {
    List<ExchangeType> types = [];
    
    for (final data in dataList) {
      ExchangeType type;
      
      if (data.supplementTeacher.isNotEmpty) {
        type = ExchangeType.supplement;
      } else if (data.groupId != null && data.groupId!.startsWith('circular_exchange_')) {
        final stepMatch = RegExp(r'circular_exchange_(\d+)_').firstMatch(data.groupId!);
        if (stepMatch != null) {
          final stepCount = int.tryParse(stepMatch.group(1)!) ?? 0;
          if (stepCount >= 4) {
            type = ExchangeType.circular;
          } else {
            type = ExchangeType.substitution;
          }
        } else {
          type = ExchangeType.substitution;
        }
      } else {
        type = ExchangeType.substitution;
      }
      
      if (!types.contains(type)) {
        types.add(type);
      }
    }
    
    return ExchangeTypeCombination(types);
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
      if (data.groupId != null) {
        if (data.groupId!.startsWith('supplement_exchange_')) {
          return ExchangeType.supplement;
        } else if (data.groupId!.startsWith('circular_exchange_')) {
          // 순환교체 단계 수 확인
          final stepMatch = RegExp(r'circular_exchange_(\d+)_').firstMatch(data.groupId!);
          if (stepMatch != null) {
            final stepCount = int.tryParse(stepMatch.group(1)!) ?? 0;
            if (stepCount >= 4) {
              return ExchangeType.circular; // 4단계 이상은 순환교체
            }
          }
          return ExchangeType.substitution; // 3단계 이하는 수업교체
        } else if (data.groupId!.startsWith('one_to_one_exchange_')) {
          return ExchangeType.substitution;
        } else if (data.groupId!.startsWith('chain_exchange_')) {
          return ExchangeType.substitution;
        }
      }
    }
    
    // 그 외에는 수업교체
    return ExchangeType.substitution;
  }
  
  /// 개별 학급 메시지 생성
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
    messageLines.add('$className 수업 교체되었습니다.');
    
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
      String arrowFormat;
      // 교체 유형 카테고리 구분
      final category = _getExchangeCategory(data);
      
      switch (category) {
        case ExchangeCategory.basic:
          // 기본 교체 유형 (1:1교체, 순환교체 3단계, 연쇄교체): <-> 형식
          arrowFormat = '<->';
          break;
        case ExchangeCategory.circularFourPlus:
          // 순환교체 4단계 이상: -> 형식
          arrowFormat = '->';
          break;
        case ExchangeCategory.supplement:
          // 보강 교체는 개별 학급 메시지에서 처리되지 않음
          arrowFormat = '<->';
          break;
      }
      
      if (isFirstMessage) {
        return '''$className 수업 교체되었습니다.
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' $arrowFormat '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' ''';
      } else {
        return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' $arrowFormat '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' ''';
      }
    } else {
      // 옵션2: 분리된 형태
      if (isFirstMessage) {
        return '''$className 수업 교체되었습니다.
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
      return '''$className 수업 교체되었습니다.
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업입니다.''';
    } else {
      return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업입니다.''';
    }
  }
}
