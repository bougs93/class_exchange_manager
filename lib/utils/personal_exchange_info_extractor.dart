import '../models/exchange_history_item.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../providers/personal_schedule_provider.dart';
import '../providers/substitution_plan_provider.dart';
import '../utils/logger.dart';
import '../utils/exchange_date_helper.dart';

/// 교체 정보를 셀 테마에 적용하기 위한 데이터 구조
class ExchangeCellInfo {
  final String teacherName;
  final String date; // YYYY.MM.DD
  final String day; // 월, 화, 수, 목, 금
  final int period;
  final bool isAbsence; // true: 결강, false: 수업
  final String? subject; // 과목명
  final String? className; // 학급명

  ExchangeCellInfo({
    required this.teacherName,
    required this.date,
    required this.day,
    required this.period,
    required this.isAbsence,
    this.subject,
    this.className,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeCellInfo &&
        other.teacherName == teacherName &&
        other.date == date &&
        other.day == day &&
        other.period == period &&
        other.isAbsence == isAbsence;
  }

  @override
  int get hashCode {
    return Object.hash(teacherName, date, day, period, isAbsence);
  }

  @override
  String toString() {
    return 'ExchangeCellInfo(teacher: $teacherName, date: $date, day: $day, period: $period, isAbsence: $isAbsence, subject: $subject, className: $className)';
  }
}

/// 개인 시간표용 교체 정보 추출기
/// 
/// 교체리스트에서 교사별 결강/수업 정보를 추출하여 셀 테마 적용에 사용합니다.
class PersonalExchangeInfoExtractor {
  /// 교체리스트에서 특정 교사의 교체 정보 추출
  /// 
  /// 매개변수:
  /// - `List<ExchangeHistoryItem>` exchangeList: 전체 교체 리스트
  /// - `String` teacherName: 추출할 교사명
  /// - `List<DateTime>` weekDates: 현재 주의 날짜 리스트 [월, 화, 수, 목, 금]
  /// - `SubstitutionPlanState` substitutionPlanState: 결보강 계획서 상태
  /// - `PersonalScheduleState` scheduleState: 개인 시간표 상태
  /// 
  /// 반환값: 교체 정보 리스트 (결강/수업 정보)
  static List<ExchangeCellInfo> extractExchangeInfo({
    required List<ExchangeHistoryItem> exchangeList,
    required String teacherName,
    required List<DateTime> weekDates,
    required SubstitutionPlanState substitutionPlanState,
    required PersonalScheduleState scheduleState,
  }) {
    final List<ExchangeCellInfo> exchangeInfoList = [];

    AppLogger.info('\n=== [교체정보추출] 시작 ===');
    AppLogger.info('대상 교사: $teacherName');
    AppLogger.info('전체 교체 개수: ${exchangeList.length}');

    for (int i = 0; i < exchangeList.length; i++) {
      final exchange = exchangeList[i];
      final path = exchange.originalPath;

      AppLogger.info('\n[교체 ${i + 1}/${exchangeList.length}] 타입: ${exchange.typeDisplayName}');

      if (path is OneToOneExchangePath) {
        final extracted = _extractOneToOneInfo(
          path,
          teacherName,
          weekDates,
          substitutionPlanState,
          scheduleState,
        );
        AppLogger.info('  → 1:1 교체: ${path.sourceNode.teacherName} ↔ ${path.targetNode.teacherName}');
        AppLogger.info('  → 추출된 정보: ${extracted.length}개');
        exchangeInfoList.addAll(extracted);
      } else if (path is CircularExchangePath) {
        final extracted = _extractCircularInfo(
          path,
          teacherName,
          weekDates,
          substitutionPlanState,
          scheduleState,
        );
        final nodeNames = path.nodes.map((n) => n.teacherName).join(' → ');
        AppLogger.info('  → 순환교체: $nodeNames');
        AppLogger.info('  → 추출된 정보: ${extracted.length}개');
        exchangeInfoList.addAll(extracted);
      } else if (path is ChainExchangePath) {
        final extracted = _extractChainInfo(
          path,
          teacherName,
          weekDates,
          substitutionPlanState,
          scheduleState,
        );
        AppLogger.info('  → 연쇄교체: ${path.nodeA.teacherName} → ${path.nodeB.teacherName}');
        AppLogger.info('  → 추출된 정보: ${extracted.length}개');
        exchangeInfoList.addAll(extracted);
      } else if (path is SupplementExchangePath) {
        final extracted = _extractSupplementInfo(
          path,
          teacherName,
          weekDates,
          substitutionPlanState,
          scheduleState,
        );
        AppLogger.info('  → 보강교체: ${path.sourceNode.teacherName} → ${path.targetNode.teacherName}');
        AppLogger.info('  → 추출된 정보: ${extracted.length}개');
        exchangeInfoList.addAll(extracted);
      }
    }

    // 날짜가 저장되지 않은 교체 정보 필터링 (날짜가 빈 문자열인 항목 제거)
    final filteredByDate = exchangeInfoList.where((info) => info.date.isNotEmpty).toList();
    AppLogger.info('\n[필터링] 날짜 없는 항목 제거: ${exchangeInfoList.length} → ${filteredByDate.length}');

    // 현재 주에 해당하는 교체 정보만 필터링
    // 주의: 저장된 날짜가 현재 주가 아닌 경우에도 포함 (다음 주 교체도 표시)
    final weekDateStrings = weekDates.map((date) => 
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
    ).toSet();

    // 현재 주에 포함되는 교체 정보만 필터링
    // (저장된 날짜가 현재 주가 아니면 제외)
    final result = filteredByDate.where((info) => weekDateStrings.contains(info.date)).toList();
    AppLogger.info('[필터링] 현재 주 필터링: ${filteredByDate.length} → ${result.length}');
    
    // 필터링된 항목이 없는 경우, 저장된 날짜 정보 출력
    if (result.isEmpty && filteredByDate.isNotEmpty) {
      AppLogger.info('[필터링] 현재 주에 해당하지 않는 교체 정보:');
      for (final info in filteredByDate) {
        AppLogger.info('  - ${info.date} ${info.day} ${info.period}교시 (현재 주: ${weekDateStrings.join(", ")})');
      }
    }
    
    AppLogger.info('=== [교체정보추출] 완료 ===\n');

    return result;
  }

  /// 1:1 교체 정보 추출
  static List<ExchangeCellInfo> _extractOneToOneInfo(
    OneToOneExchangePath path,
    String teacherName,
    List<DateTime> weekDates,
    SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState scheduleState,
  ) {
    final List<ExchangeCellInfo> infoList = [];
    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;

    // 해당 교사와 관련된 교체만 추출
    if (sourceNode.teacherName != teacherName && targetNode.teacherName != teacherName) {
      return infoList;
    }

    // 원래 교사(sourceNode)의 날짜 정보
    final sourceAbsenceDate = ExchangeDateHelper.getSavedDateByNode(
      teacherName: sourceNode.teacherName,
      day: sourceNode.day,
      period: sourceNode.period,
      subject: sourceNode.subjectName,
      dateType: 'absenceDate',
      substitutionPlanState: substitutionPlanState,
      scheduleState: scheduleState,
      useFallback: false,
    );
    final sourceSubstitutionDate = ExchangeDateHelper.getSavedDateByNode(
      teacherName: sourceNode.teacherName,
      day: sourceNode.day,
      period: sourceNode.period,
      subject: sourceNode.subjectName,
      dateType: 'substitutionDate',
      substitutionPlanState: substitutionPlanState,
      scheduleState: scheduleState,
      useFallback: false,
    );

    // 원래 교사(sourceNode) 정보
    if (sourceNode.teacherName == teacherName) {
      // 결강
      infoList.add(ExchangeCellInfo(
        teacherName: sourceNode.teacherName,
        date: sourceAbsenceDate,
        day: sourceNode.day,
        period: sourceNode.period,
        isAbsence: true,
        subject: sourceNode.subjectName,
        className: sourceNode.className,
      ));
      // 수업 (targetNode 시간으로 이동)
      infoList.add(ExchangeCellInfo(
        teacherName: sourceNode.teacherName,
        date: sourceSubstitutionDate,
        day: targetNode.day,
        period: targetNode.period,
        isAbsence: false,
        subject: sourceNode.subjectName,
        className: targetNode.className,
      ));
    }

    // 교체 교사(targetNode) 정보
    if (targetNode.teacherName == teacherName) {
      // 결강
      infoList.add(ExchangeCellInfo(
        teacherName: targetNode.teacherName,
        date: sourceSubstitutionDate,
        day: targetNode.day,
        period: targetNode.period,
        isAbsence: true,
        subject: targetNode.subjectName,
        className: targetNode.className,
      ));
      // 수업 (sourceNode 시간으로 이동)
      infoList.add(ExchangeCellInfo(
        teacherName: targetNode.teacherName,
        date: sourceAbsenceDate,
        day: sourceNode.day,
        period: sourceNode.period,
        isAbsence: false,
        subject: targetNode.subjectName,
        className: sourceNode.className,
      ));
    }

    return infoList;
  }

  /// 순환교체 정보 추출
  static List<ExchangeCellInfo> _extractCircularInfo(
    CircularExchangePath path,
    String teacherName,
    List<DateTime> weekDates,
    SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState scheduleState,
  ) {
    final List<ExchangeCellInfo> infoList = [];
    final nodes = path.nodes;
    final stepCount = nodes.length;

    // 해당 교사와 관련된 교체인지 확인
    if (!nodes.any((node) => node.teacherName == teacherName)) {
      return infoList;
    }

    if (stepCount >= 4) {
      // 4단계 이상: 각 교사가 자신의 과목을 들고 이동
      for (int i = 0; i < nodes.length - 1; i++) {
        final sourceNode = nodes[i];
        final targetNode = nodes[i + 1];

        if (sourceNode.teacherName != teacherName) continue;

        final sourceDate = ExchangeDateHelper.getNodeDate(
          node: sourceNode,
          dateType: 'absenceDate',
          substitutionPlanState: substitutionPlanState,
          scheduleState: scheduleState,
          useFallback: false,
        );
        final targetDate = ExchangeDateHelper.getNodeDate(
          node: sourceNode,
          dateType: 'substitutionDate',
          substitutionPlanState: substitutionPlanState,
          scheduleState: scheduleState,
          useFallback: false,
        );

        // 결강
        infoList.add(ExchangeCellInfo(
          teacherName: sourceNode.teacherName,
          date: sourceDate,
          day: sourceNode.day,
          period: sourceNode.period,
          isAbsence: true,
          subject: sourceNode.subjectName,
          className: sourceNode.className,
        ));
        // 수업 (자신의 과목을 들고 targetNode 시간으로 이동)
        infoList.add(ExchangeCellInfo(
          teacherName: sourceNode.teacherName,
          date: targetDate,
          day: targetNode.day,
          period: targetNode.period,
          isAbsence: false,
          subject: sourceNode.subjectName,
          className: sourceNode.className,
        ));
      }
    } else {
      // 3단계 이하: 기본 교체 방식
      for (int i = 0; i < nodes.length - 1; i++) {
        final sourceNode = nodes[i];
        final targetNode = nodes[i + 1];

        if (sourceNode.teacherName != teacherName) continue;

        final sourceDate = ExchangeDateHelper.getNodeDate(
          node: sourceNode,
          dateType: 'absenceDate',
          substitutionPlanState: substitutionPlanState,
          scheduleState: scheduleState,
          useFallback: false,
        );
        final targetDate = ExchangeDateHelper.getNodeDate(
          node: sourceNode,
          dateType: 'substitutionDate',
          substitutionPlanState: substitutionPlanState,
          scheduleState: scheduleState,
          useFallback: false,
        );

        // 결강
        infoList.add(ExchangeCellInfo(
          teacherName: sourceNode.teacherName,
          date: sourceDate,
          day: sourceNode.day,
          period: sourceNode.period,
          isAbsence: true,
          subject: sourceNode.subjectName,
          className: sourceNode.className,
        ));
        // 수업
        infoList.add(ExchangeCellInfo(
          teacherName: sourceNode.teacherName,
          date: targetDate,
          day: targetNode.day,
          period: targetNode.period,
          isAbsence: false,
          subject: targetNode.subjectName,
          className: targetNode.className,
        ));
      }
    }

    return infoList;
  }

  /// 연쇄교체 정보 추출
  static List<ExchangeCellInfo> _extractChainInfo(
    ChainExchangePath path,
    String teacherName,
    List<DateTime> weekDates,
    SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState scheduleState,
  ) {
    final List<ExchangeCellInfo> infoList = [];
    final node1 = path.node1;
    final node2 = path.node2;
    final nodeA = path.nodeA;
    final nodeB = path.nodeB;

    // 해당 교사와 관련된 교체인지 확인
    if (node1.teacherName != teacherName &&
        node2.teacherName != teacherName &&
        nodeA.teacherName != teacherName &&
        nodeB.teacherName != teacherName) {
      return infoList;
    }

    // 중간 단계 날짜
    final date2Sub = ExchangeDateHelper.getChainDate(
      teacherName: nodeA.teacherName,
      day: nodeA.day,
      period: nodeA.period,
      dateType: 'substitutionDate',
      stepInfo: '연쇄중간',
      substitutionPlanState: substitutionPlanState,
      scheduleState: scheduleState,
      useFallback: false,
    );

    // 최종 단계 날짜
    final dateAAbs = ExchangeDateHelper.getChainDate(
      teacherName: nodeA.teacherName,
      day: nodeA.day,
      period: nodeA.period,
      dateType: 'absenceDate',
      stepInfo: '연쇄최종',
      substitutionPlanState: substitutionPlanState,
      scheduleState: scheduleState,
      useFallback: false,
    );
    final dateBSub = ExchangeDateHelper.getChainDate(
      teacherName: nodeA.teacherName,
      day: nodeA.day,
      period: nodeA.period,
      dateType: 'substitutionDate',
      stepInfo: '연쇄최종',
      substitutionPlanState: substitutionPlanState,
      scheduleState: scheduleState,
      useFallback: false,
    );

    // 중간 단계 교사 (node2.teacherName)
    if (node2.teacherName == teacherName) {
      infoList.add(ExchangeCellInfo(
        teacherName: node2.teacherName,
        date: date2Sub,
        day: node2.day,
        period: node2.period,
        isAbsence: false,
        subject: node2.subjectName,
        className: node2.className,
      ));
    }

    // 최종 단계 원래 교사 (nodeA.teacherName)
    if (nodeA.teacherName == teacherName) {
      // 결강 정보
      infoList.add(ExchangeCellInfo(
        teacherName: nodeA.teacherName,
        date: dateAAbs,
        day: nodeA.day,
        period: nodeA.period,
        isAbsence: true,
        subject: nodeA.subjectName,
        className: nodeA.className,
      ));
      // 수업 정보
      infoList.add(ExchangeCellInfo(
        teacherName: nodeA.teacherName,
        date: dateBSub,
        day: nodeB.day,
        period: nodeB.period,
        isAbsence: false,
        subject: nodeA.subjectName,
        className: nodeA.className,
      ));
    }

    // 중간 단계 교체 교사 (node1.teacherName)
    if (node1.teacherName == teacherName) {
      // 결강 정보
      infoList.add(ExchangeCellInfo(
        teacherName: node1.teacherName,
        date: dateAAbs,
        day: node2.day,
        period: node2.period,
        isAbsence: true,
        subject: node2.subjectName,
        className: node2.className,
      ));
      // 수업 정보
      infoList.add(ExchangeCellInfo(
        teacherName: node1.teacherName,
        date: date2Sub,
        day: node1.day,
        period: node1.period,
        isAbsence: false,
        subject: node2.subjectName,
        className: node2.className,
      ));
    }

    // 최종 단계 교체 교사 (nodeB.teacherName)
    if (nodeB.teacherName == teacherName) {
      // 결강 정보
      infoList.add(ExchangeCellInfo(
        teacherName: nodeB.teacherName,
        date: dateBSub,
        day: nodeB.day,
        period: nodeB.period,
        isAbsence: true,
        subject: nodeB.subjectName,
        className: nodeB.className,
      ));
      // 수업 정보
      infoList.add(ExchangeCellInfo(
        teacherName: nodeB.teacherName,
        date: dateAAbs,
        day: nodeA.day,
        period: nodeA.period,
        isAbsence: false,
        subject: nodeB.subjectName,
        className: nodeB.className,
      ));
    }

    return infoList;
  }

  /// 보강교체 정보 추출
  static List<ExchangeCellInfo> _extractSupplementInfo(
    SupplementExchangePath path,
    String teacherName,
    List<DateTime> weekDates,
    SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState scheduleState,
  ) {
    final List<ExchangeCellInfo> infoList = [];
    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;

    // 해당 교사와 관련된 교체만 추출
    if (sourceNode.teacherName != teacherName && targetNode.teacherName != teacherName) {
      return infoList;
    }

    final sourceDate = ExchangeDateHelper.getSupplementDate(
      sourceNode: sourceNode,
      substitutionPlanState: substitutionPlanState,
      scheduleState: scheduleState,
      useFallback: false,
    );
    final supplementSubject = ExchangeDateHelper.getSupplementSubject(
      sourceNode: sourceNode,
      targetNode: targetNode,
      substitutionPlanState: substitutionPlanState,
    );

    // 원래 교사 - 결강
    if (sourceNode.teacherName == teacherName) {
      infoList.add(ExchangeCellInfo(
        teacherName: sourceNode.teacherName,
        date: sourceDate,
        day: sourceNode.day,
        period: sourceNode.period,
        isAbsence: true,
        subject: sourceNode.subjectName,
        className: sourceNode.className,
      ));
    }

    // 보강 교사 - 수업
    if (targetNode.teacherName == teacherName) {
      infoList.add(ExchangeCellInfo(
        teacherName: targetNode.teacherName,
        date: sourceDate,
        day: sourceNode.day,
        period: sourceNode.period,
        isAbsence: false,
        subject: supplementSubject,
        className: sourceNode.className,
      ));
    }

    return infoList;
  }
}

