import '../models/notice_message.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/logger.dart';

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
      
      for (int i = 0; i < classDataList.length; i++) {
        final data = classDataList[i];
        final isFirstMessage = i == 0; // 첫 번째 메시지인지 확인
        final message = _generateClassMessage(data, messageOption, isFirstMessage);
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
      
      final List<NoticeMessage> messages = [];
      
      for (int i = 0; i < teacherDataList.length; i++) {
        final data = teacherDataList[i];
        final isFirstMessage = i == 0; // 첫 번째 메시지인지 확인
        final message = _generateTeacherMessage(data, teacherName, messageOption, isFirstMessage);
        if (message != null) {
          messages.add(message);
        }
      }
      
      if (messages.isNotEmpty) {
        teacherMessageGroups.add(NoticeMessageGroup(
          groupIdentifier: teacherName,
          messages: messages,
          groupType: GroupType.teacherGroup,
        ));
      }
    }
    
    AppLogger.exchangeDebug('교사 메시지 그룹 생성 완료 - 그룹 개수: ${teacherMessageGroups.length}');
    return teacherMessageGroups;
  }
  
  /// 개별 학급 메시지 생성
  static NoticeMessage? _generateClassMessage(
    SubstitutionPlanData data,
    MessageOption messageOption,
    bool isFirstMessage,
  ) {
    // 교체 유형 판단
    final exchangeType = data.substitutionDate.isNotEmpty 
        ? ExchangeType.substitution 
        : ExchangeType.supplement;
    
    String content;
    
    if (exchangeType == ExchangeType.substitution) {
      // 수업교체 메시지
      content = _generateClassSubstitutionMessage(data, messageOption, isFirstMessage);
    } else {
      // 보강 메시지
      content = _generateClassSupplementMessage(data, isFirstMessage);
    }
    
    if (content.isEmpty) {
      AppLogger.warning('학급 메시지 생성 실패 - 데이터: ${data.exchangeId}');
      return null;
    }
    
    return NoticeMessage(
      identifier: '${data.grade}-${data.className}',
      content: content,
      exchangeType: exchangeType,
      messageOption: messageOption,
      exchangeId: data.exchangeId,
    );
  }
  
  /// 개별 교사 메시지 생성
  static NoticeMessage? _generateTeacherMessage(
    SubstitutionPlanData data,
    String teacherName,
    MessageOption messageOption,
    bool isFirstMessage,
  ) {
    // 교체 유형 판단
    final exchangeType = data.substitutionDate.isNotEmpty 
        ? ExchangeType.substitution 
        : ExchangeType.supplement;
    
    String content;
    
    if (exchangeType == ExchangeType.substitution) {
      // 수업교체 메시지
      content = _generateTeacherSubstitutionMessage(data, teacherName, messageOption, isFirstMessage);
    } else {
      // 보강 메시지
      content = _generateTeacherSupplementMessage(data, teacherName, isFirstMessage);
    }
    
    if (content.isEmpty) {
      AppLogger.warning('교사 메시지 생성 실패 - 교사: $teacherName, 데이터: ${data.exchangeId}');
      return null;
    }
    
    return NoticeMessage(
      identifier: teacherName,
      content: content,
      exchangeType: exchangeType,
      messageOption: messageOption,
      exchangeId: data.exchangeId,
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
      // 옵션1: 교체 형태
      if (isFirstMessage) {
        return '''$className 수업 교체되었습니다.
${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' <-> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' ''';
      } else {
        return '''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject} ${data.teacher}' <-> '${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject} ${data.substitutionTeacher}' ''';
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
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 수업 입니다.''';
    } else {
      return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 수업 입니다.''';
    }
  }
  
  /// 교사 수업교체 메시지 생성
  static String _generateTeacherSubstitutionMessage(
    SubstitutionPlanData data,
    String teacherName,
    MessageOption messageOption,
    bool isFirstMessage,
  ) {
    final className = '${data.grade}-${data.className}';
    
    if (messageOption == MessageOption.option1) {
      // 옵션1: 교체 형태
      if (isFirstMessage) {
        return ''''$teacherName' 선생님
'${data.teacher}','${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' <-> '${data.substitutionTeacher}','${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject}' 수업 교체되었습니다.''';
      } else {
        return '''${data.teacher}','${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' <-> '${data.substitutionTeacher}','${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject}' 수업 교체되었습니다.''';
      }
    } else {
      // 옵션2: 분리된 형태
      if (teacherName == data.teacher) {
        // 원래 교사
        if (isFirstMessage) {
          return ''''$teacherName' 선생님 
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' 결강입니다.
'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.subject}' 수업입니다.''';
        } else {
          return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.subject}' 결강입니다.
'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.subject}' 수업입니다.''';
        }
      } else {
        // 교체 교사
        if (isFirstMessage) {
          return ''''$teacherName' 선생님 
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject}' 수업입니다.
'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject}' 결강입니다.''';
        } else {
          return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.substitutionSubject}' 수업입니다.
'${data.substitutionDate} ${data.substitutionDay} ${data.substitutionPeriod}교시 $className ${data.substitutionSubject}' 결강입니다.''';
        }
      }
    }
  }
  
  /// 교사 보강 메시지 생성
  static String _generateTeacherSupplementMessage(
    SubstitutionPlanData data,
    String teacherName,
    bool isFirstMessage,
  ) {
    final className = '${data.grade}-${data.className}';
    
    if (teacherName == data.teacher) {
      // 원래 교사 (결강)
      if (isFirstMessage) {
        return ''''$teacherName' 선생님
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject}' 결강(보강)되었습니다.''';
      } else {
        return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject}' 결강(보강)되었습니다.''';
      }
    } else {
      // 보강 교사
      if (isFirstMessage) {
        return ''''$teacherName' 선생님
'${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업이 있습니다.''';
      } else {
        return ''''${data.absenceDate} ${data.absenceDay} ${data.period}교시 $className ${data.supplementSubject} ${data.supplementTeacher}' 보강 수업이 있습니다.''';
      }
    }
  }
}
