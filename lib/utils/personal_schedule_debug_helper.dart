import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_node.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../providers/personal_schedule_provider.dart';
import '../providers/substitution_plan_provider.dart';
import '../providers/services_provider.dart';
import '../services/excel_service.dart';
import 'logger.dart';

/// 개인 시간표 디버그 헬퍼
///
/// 디버그 정보 출력 및 교사별 안내 메시지 생성 기능을 제공합니다.
class PersonalScheduleDebugHelper {
  /// 디버그 정보 출력
  ///
  /// 교체 리스트를 콘솔에 출력합니다.
  static void showDebugInfo(
    WidgetRef ref,
    PersonalScheduleState scheduleState,
    TimetableData? timetableData,
    String? teacherName,
  ) {
    // 교체 리스트 정보 가져오기 및 콘솔 출력
    if (teacherName != null && timetableData != null) {
      try {
        final historyService = ref.read(exchangeHistoryServiceProvider);

        // _exchangeList 핵심 정보만 간단히 출력
        final exchangeList = historyService.getExchangeList();
        AppLogger.info('=== _exchangeList (${exchangeList.length}개) ===');

        for (int i = 0; i < exchangeList.length; i++) {
          final exchange = exchangeList[i];
          final path = exchange.originalPath;

          // 핵심 정보만 출력
          String exchangeInfo = '';

          if (path is OneToOneExchangePath) {
            exchangeInfo = '${path.sourceNode.teacherName}(${path.sourceNode.day}${path.sourceNode.period}교시, ${path.sourceNode.className}) ↔ ${path.targetNode.teacherName}(${path.targetNode.day}${path.targetNode.period}교시, ${path.targetNode.className})';
          } else if (path is CircularExchangePath) {
            final nodeNames = path.nodes.map((n) => '${n.teacherName}(${n.day}${n.period}교시)').join(' → ');
            exchangeInfo = '$nodeNames → ${path.nodes.first.teacherName} (${path.nodes.length}명)';
          } else if (path is ChainExchangePath) {
            exchangeInfo = '[1단계] ${path.node1.teacherName}(${path.node1.day}${path.node1.period}교시) ↔ ${path.node2.teacherName}(${path.node2.day}${path.node2.period}교시) | [2단계] ${path.nodeA.teacherName}(${path.nodeA.day}${path.nodeA.period}교시) ↔ ${path.nodeB.teacherName}(${path.nodeB.day}${path.nodeB.period}교시)';
          } else if (path is SupplementExchangePath) {
            exchangeInfo = '${path.sourceNode.teacherName}(${path.sourceNode.day}${path.sourceNode.period}교시, ${path.sourceNode.className}) → ${path.targetNode.teacherName}(${path.targetNode.day}${path.targetNode.period}교시) [보강]';
          }

          AppLogger.info('[${i + 1}] ${exchange.typeDisplayName} | $exchangeInfo | ${exchange.formattedTimestamp}${exchange.isReverted ? " [되돌림]" : ""}');
        }
        AppLogger.info('=== 출력 완료 ===\n');

        // 교사별 날짜별 결강/수업 정보 출력
        printTeacherScheduleInfo(ref, scheduleState);
      } catch (e) {
        AppLogger.error('교체 리스트 로드 중 오류: $e', e);
      }
    } else {
      AppLogger.info('교체 리스트: 교사명 또는 시간표 데이터가 없어서 로드할 수 없습니다.');
    }
  }

  /// 교사별 날짜별 결강/수업 정보 출력
  ///
  /// 교체리스트에서 직접 데이터를 가져와 메시지를 생성합니다.
  static void printTeacherScheduleInfo(WidgetRef ref, PersonalScheduleState scheduleState) {
    try {
      final historyService = ref.read(exchangeHistoryServiceProvider);
      final exchangeList = historyService.getExchangeList();
      final substitutionPlanState = ref.read(substitutionPlanProvider);

      if (exchangeList.isEmpty) {
        AppLogger.info('교체 리스트가 없습니다.');
        return;
      }

      AppLogger.info('\n=== 교사별 안내 메시지 (교체리스트 기준) ===\n');

      // 교사별로 그룹화
      final Map<String, List<String>> teacherMessages = {};

      for (final exchange in exchangeList) {
        final path = exchange.originalPath;

        if (path is OneToOneExchangePath) {
          _handleOneToOneDebugMessage(
            path,
            teacherMessages,
            scheduleState,
            substitutionPlanState,
          );
        } else if (path is CircularExchangePath) {
          _handleCircularDebugMessage(
            path,
            teacherMessages,
            scheduleState,
            substitutionPlanState,
          );
        } else if (path is ChainExchangePath) {
          _handleChainDebugMessage(
            path,
            teacherMessages,
            scheduleState,
            substitutionPlanState,
          );
        } else if (path is SupplementExchangePath) {
          _handleSupplementDebugMessage(
            path,
            teacherMessages,
            scheduleState,
            substitutionPlanState,
          );
        }
      }

      // 교사별로 메시지 출력
      final teacherNames = teacherMessages.keys.toList()..sort();
      for (int i = 0; i < teacherNames.length; i++) {
        final teacherName = teacherNames[i];
        final messages = teacherMessages[teacherName]!;

        AppLogger.info('$teacherName: \'$teacherName\' 선생님');
        for (final message in messages) {
          AppLogger.info(message);
        }

        // 교사 사이에 빈 줄 추가
        if (i < teacherNames.length - 1) {
          AppLogger.info('');
        }
      }

      AppLogger.info('\n=== 교사별 안내 메시지 출력 완료 ===\n');
    } catch (e) {
      AppLogger.error('교사별 안내 메시지 출력 중 오류: $e', e);
    }
  }

  /// 1:1 교체 디버그 메시지 처리
  static void _handleOneToOneDebugMessage(
    OneToOneExchangePath path,
    Map<String, List<String>> teacherMessages,
    PersonalScheduleState scheduleState,
    SubstitutionPlanState substitutionPlanState,
  ) {
    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;

    // 원래 교사(sourceNode)의 날짜 정보
    final sourceAbsenceDate = _getSavedDateByNode(
      sourceNode.teacherName, sourceNode.day, sourceNode.period,
      sourceNode.subjectName, 'absenceDate', scheduleState, substitutionPlanState
    );
    final sourceSubstitutionDate = _getSavedDateByNode(
      sourceNode.teacherName, sourceNode.day, sourceNode.period,
      sourceNode.subjectName, 'substitutionDate', scheduleState, substitutionPlanState
    );

    // 원래 교사(sourceNode) 메시지
    teacherMessages.putIfAbsent(sourceNode.teacherName, () => []);
    teacherMessages[sourceNode.teacherName]!.add(
      "'${sourceAbsenceDate.isNotEmpty ? '$sourceAbsenceDate ' : ''}${sourceNode.day} ${sourceNode.period}교시 ${sourceNode.subjectName} ${sourceNode.className}' 결강입니다."
    );
    teacherMessages[sourceNode.teacherName]!.add(
      "'${sourceSubstitutionDate.isNotEmpty ? '$sourceSubstitutionDate ' : ''}${targetNode.day} ${targetNode.period}교시 ${sourceNode.subjectName} ${targetNode.className}' 수업입니다."
    );

    // 교체 교사(targetNode) 메시지
    teacherMessages.putIfAbsent(targetNode.teacherName, () => []);
    teacherMessages[targetNode.teacherName]!.add(
      "'${sourceSubstitutionDate.isNotEmpty ? '$sourceSubstitutionDate ' : ''}${targetNode.day} ${targetNode.period}교시 ${targetNode.subjectName} ${targetNode.className}' 결강입니다."
    );
    teacherMessages[targetNode.teacherName]!.add(
      "'${sourceAbsenceDate.isNotEmpty ? '$sourceAbsenceDate ' : ''}${sourceNode.day} ${sourceNode.period}교시 ${targetNode.subjectName} ${sourceNode.className}' 수업입니다."
    );
  }

  /// 순환교체 디버그 메시지 처리
  static void _handleCircularDebugMessage(
    CircularExchangePath path,
    Map<String, List<String>> teacherMessages,
    PersonalScheduleState scheduleState,
    SubstitutionPlanState substitutionPlanState,
  ) {
    final nodes = path.nodes;
    final stepCount = nodes.length;

    if (stepCount >= 4) {
      // 4단계 이상: 각 교사가 자신의 과목을 들고 이동
      for (int i = 0; i < nodes.length - 1; i++) {
        final sourceNode = nodes[i];
        final targetNode = nodes[i + 1];

        final sourceDate = _getNodeDate(sourceNode, 'absenceDate', substitutionPlanState, scheduleState);
        final targetDate = _getNodeDate(sourceNode, 'substitutionDate', substitutionPlanState, scheduleState);

        teacherMessages.putIfAbsent(sourceNode.teacherName, () => []);
        teacherMessages[sourceNode.teacherName]!.add(
          "'${sourceDate.isNotEmpty ? '$sourceDate ' : ''}${sourceNode.day} ${sourceNode.period}교시 ${sourceNode.subjectName} ${sourceNode.className}' 결강입니다."
        );
        teacherMessages[sourceNode.teacherName]!.add(
          "'${targetDate.isNotEmpty ? '$targetDate ' : ''}${targetNode.day} ${targetNode.period}교시 ${sourceNode.subjectName} ${sourceNode.className}' 수업입니다."
        );
      }
    } else {
      // 3단계 이하: 기본 교체 방식
      for (int i = 0; i < nodes.length - 1; i++) {
        final sourceNode = nodes[i];
        final targetNode = nodes[i + 1];

        final sourceDate = _getNodeDate(sourceNode, 'absenceDate', substitutionPlanState, scheduleState);
        final targetDate = _getNodeDate(sourceNode, 'substitutionDate', substitutionPlanState, scheduleState);

        teacherMessages.putIfAbsent(sourceNode.teacherName, () => []);
        teacherMessages[sourceNode.teacherName]!.add(
          "'${sourceDate.isNotEmpty ? '$sourceDate ' : ''}${sourceNode.day} ${sourceNode.period}교시 ${sourceNode.subjectName} ${sourceNode.className}' 결강입니다."
        );
        teacherMessages[sourceNode.teacherName]!.add(
          "'${targetDate.isNotEmpty ? '$targetDate ' : ''}${targetNode.day} ${targetNode.period}교시 ${targetNode.subjectName} ${targetNode.className}' 수업입니다."
        );
      }
    }
  }

  /// 연쇄교체 디버그 메시지 처리
  static void _handleChainDebugMessage(
    ChainExchangePath path,
    Map<String, List<String>> teacherMessages,
    PersonalScheduleState scheduleState,
    SubstitutionPlanState substitutionPlanState,
  ) {
    final node1 = path.node1;
    final node2 = path.node2;
    final nodeA = path.nodeA;
    final nodeB = path.nodeB;

    // 중간 단계 날짜
    final date2Sub = _getChainDate(nodeA.teacherName, nodeA.day, nodeA.period, 'substitutionDate', '연쇄중간', substitutionPlanState, scheduleState);

    // 최종 단계 날짜
    final dateAAbs = _getChainDate(nodeA.teacherName, nodeA.day, nodeA.period, 'absenceDate', '연쇄최종', substitutionPlanState, scheduleState);
    final dateBSub = _getChainDate(nodeA.teacherName, nodeA.day, nodeA.period, 'substitutionDate', '연쇄최종', substitutionPlanState, scheduleState);

    // 중간 단계 교사 (node2.teacherName)
    teacherMessages.putIfAbsent(node2.teacherName, () => []);
    teacherMessages[node2.teacherName]!.add(
      "'${date2Sub.isNotEmpty ? '$date2Sub ' : ''}${node2.day} ${node2.period}교시 ${node2.subjectName} ${node2.className}' 수업입니다."
    );

    // 최종 단계 원래 교사 (nodeA.teacherName)
    teacherMessages.putIfAbsent(nodeA.teacherName, () => []);
    teacherMessages[nodeA.teacherName]!.add(
      "'${dateAAbs.isNotEmpty ? '$dateAAbs ' : ''}${nodeA.day} ${nodeA.period}교시 ${nodeA.subjectName} ${nodeA.className}' 결강입니다."
    );
    teacherMessages[nodeA.teacherName]!.add(
      "'${dateBSub.isNotEmpty ? '$dateBSub ' : ''}${nodeB.day} ${nodeB.period}교시 ${nodeA.subjectName} ${nodeA.className}' 수업입니다."
    );

    // 중간 단계 교체 교사 (node1.teacherName)
    teacherMessages.putIfAbsent(node1.teacherName, () => []);
    teacherMessages[node1.teacherName]!.add(
      "'${dateAAbs.isNotEmpty ? '$dateAAbs ' : ''}${node2.day} ${node2.period}교시 ${node2.subjectName} ${node2.className}' 결강입니다."
    );
    teacherMessages[node1.teacherName]!.add(
      "'${date2Sub.isNotEmpty ? '$date2Sub ' : ''}${node1.day} ${node1.period}교시 ${node2.subjectName} ${node2.className}' 수업입니다."
    );

    // 최종 단계 교체 교사 (nodeB.teacherName)
    teacherMessages.putIfAbsent(nodeB.teacherName, () => []);
    teacherMessages[nodeB.teacherName]!.add(
      "'${dateBSub.isNotEmpty ? '$dateBSub ' : ''}${nodeB.day} ${nodeB.period}교시 ${nodeB.subjectName} ${nodeB.className}' 결강입니다."
    );
    teacherMessages[nodeB.teacherName]!.add(
      "'${dateAAbs.isNotEmpty ? '$dateAAbs ' : ''}${nodeA.day} ${nodeA.period}교시 ${nodeB.subjectName} ${nodeB.className}' 수업입니다."
    );
  }

  /// 보강교체 디버그 메시지 처리
  static void _handleSupplementDebugMessage(
    SupplementExchangePath path,
    Map<String, List<String>> teacherMessages,
    PersonalScheduleState scheduleState,
    SubstitutionPlanState substitutionPlanState,
  ) {
    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;

    final sourceDate = _getSupplementDate(sourceNode, substitutionPlanState, scheduleState);
    final supplementSubject = _getSupplementSubject(sourceNode, targetNode, substitutionPlanState);

    // 원래 교사
    teacherMessages.putIfAbsent(sourceNode.teacherName, () => []);
    teacherMessages[sourceNode.teacherName]!.add(
      "'${sourceDate.isNotEmpty ? '$sourceDate ' : ''}${sourceNode.day} ${sourceNode.period}교시 ${sourceNode.className} ${sourceNode.subjectName}' 결강입니다."
    );

    // 보강 교사
    teacherMessages.putIfAbsent(targetNode.teacherName, () => []);
    teacherMessages[targetNode.teacherName]!.add(
      "'${sourceDate.isNotEmpty ? '$sourceDate ' : ''}${sourceNode.day} ${sourceNode.period}교시 ${sourceNode.className} $supplementSubject' 보강입니다."
    );
  }

  /// 날짜 포맷 함수: YYYY.MM.DD 형식 유지
  static String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return dateStr;
  }

  /// 요일을 날짜로 변환하는 함수 (YYYY.MM.DD 형식)
  static String _dayToDate(String day, PersonalScheduleState scheduleState) {
    final weekDates = scheduleState.weekDates;

    // 요일 인덱스 매핑
    final dayIndex = {
      '월': 0, '화': 1, '수': 2, '목': 3, '금': 4,
    };

    final index = dayIndex[day];
    if (index != null && index < weekDates.length) {
      final date = weekDates[index];
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
    return '';
  }

  /// 저장된 날짜 가져오는 헬퍼 함수 (교사명, 요일, 교시, 과목으로 찾기)
  static String _getSavedDateByNode(
    String teacherName,
    String day,
    int period,
    String subject,
    String dateType,
    PersonalScheduleState scheduleState,
    SubstitutionPlanState substitutionPlanState,
  ) {
    final key = '${teacherName}_$day${period}_${subject}_$dateType';
    final rawDate = substitutionPlanState.savedDates[key];
    final savedDate = _formatDate(rawDate);
    if (savedDate.isNotEmpty) {
      return savedDate;
    }
    return _dayToDate(day, scheduleState);
  }

  /// 노드 날짜 가져오기
  static String _getNodeDate(
    ExchangeNode node,
    String dateType,
    SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState scheduleState,
  ) {
    for (final key in substitutionPlanState.savedDates.keys) {
      if (key.startsWith('${node.teacherName}_${node.day}${node.period}_${node.subjectName}_') &&
          key.endsWith(dateType)) {
        return _formatDate(substitutionPlanState.savedDates[key]);
      }
    }
    final nodeDate = _formatDate(node.date);
    if (nodeDate.isNotEmpty) {
      return nodeDate;
    }
    return _dayToDate(node.day, scheduleState);
  }

  /// 연쇄교체 날짜 가져오기
  static String _getChainDate(
    String teacherName,
    String day,
    int period,
    String dateType,
    String stepInfo,
    SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState scheduleState,
  ) {
    for (final key in substitutionPlanState.savedDates.keys) {
      if (key.contains(teacherName) &&
          key.contains('$day$period') &&
          key.contains(stepInfo) &&
          key.endsWith(dateType)) {
        return _formatDate(substitutionPlanState.savedDates[key]);
      }
    }
    return _dayToDate(day, scheduleState);
  }

  /// 보강 날짜 가져오기
  static String _getSupplementDate(
    ExchangeNode sourceNode,
    SubstitutionPlanState substitutionPlanState,
    PersonalScheduleState scheduleState,
  ) {
    for (final key in substitutionPlanState.savedDates.keys) {
      if (key.startsWith('${sourceNode.teacherName}_${sourceNode.day}${sourceNode.period}_${sourceNode.subjectName}_보강_') &&
          key.endsWith('absenceDate')) {
        return _formatDate(substitutionPlanState.savedDates[key]);
      }
    }
    return _dayToDate(sourceNode.day, scheduleState);
  }

  /// 저장된 보강 과목 가져오기
  static String _getSupplementSubject(
    ExchangeNode sourceNode,
    ExchangeNode targetNode,
    SubstitutionPlanState substitutionPlanState,
  ) {
    final searchKey = '${sourceNode.teacherName}_${sourceNode.day}${sourceNode.period}_${sourceNode.subjectName}_보강';

    final savedSubject = substitutionPlanState.savedSupplementSubjects[searchKey];
    if (savedSubject != null && savedSubject.isNotEmpty) {
      return savedSubject;
    }

    return targetNode.subjectName.isNotEmpty ? targetNode.subjectName : sourceNode.subjectName;
  }
}
