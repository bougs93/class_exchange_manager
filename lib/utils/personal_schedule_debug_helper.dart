import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/personal_schedule_provider.dart';
import '../providers/substitution_plan_provider.dart';
import '../providers/services_provider.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../services/excel_service.dart';
import 'logger.dart';
import 'personal_exchange_info_extractor.dart';

/// 개인 시간표 디버그 헬퍼
///
/// 디버그 정보 출력 및 교사별 안내 메시지 생성 기능을 제공합니다.
/// PersonalExchangeInfoExtractor를 사용하여 교체 정보를 추출하고 메시지를 생성합니다.
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
  /// PersonalExchangeInfoExtractor를 사용하여 교체 정보를 추출하고 메시지를 생성합니다.
  static void printTeacherScheduleInfo(WidgetRef ref, PersonalScheduleState scheduleState) {
    try {
      final historyService = ref.read(exchangeHistoryServiceProvider);
      final exchangeList = historyService.getExchangeList();
      final substitutionPlanState = ref.read(substitutionPlanProvider);

      if (exchangeList.isEmpty) {
        return;
      }

      AppLogger.info('\n=== 교사별 안내 메시지 (교체리스트 기준) ===');

      // PersonalExchangeInfoExtractor를 사용하여 모든 교사의 교체 정보 추출
      final allTeachers = <String>{};
      for (final exchange in exchangeList) {
        final path = exchange.originalPath;
        for (final node in path.nodes) {
          allTeachers.add(node.teacherName);
        }
      }

      // 교사별로 그룹화
      final Map<String, List<String>> teacherMessages = {};

      // 각 교사별로 교체 정보 추출
      for (final teacherName in allTeachers) {
        final exchangeInfoList = PersonalExchangeInfoExtractor.extractExchangeInfo(
          exchangeList: exchangeList,
          teacherName: teacherName,
          weekDates: scheduleState.weekDates,
          substitutionPlanState: substitutionPlanState,
          scheduleState: scheduleState,
        );

        // ExchangeCellInfo를 메시지 형식으로 변환
        teacherMessages.putIfAbsent(teacherName, () => []);
        for (final info in exchangeInfoList) {
          final absenceOrClass = info.isAbsence ? '결강입니다.' : '수업입니다.';
          final dateStr = info.date.isNotEmpty ? '${info.date} ' : '';
          final subjectStr = info.subject ?? '';
          final classStr = info.className ?? '';
          final content = '$dateStr${info.day} ${info.period}교시 $subjectStr $classStr'.trim();
          teacherMessages[teacherName]!.add("'$content' $absenceOrClass");
        }
      }

      // 교사별로 메시지 출력 (간단한 형식)
      final teacherNames = teacherMessages.keys.toList()..sort();
      for (int i = 0; i < teacherNames.length; i++) {
        final teacherName = teacherNames[i];
        final messages = teacherMessages[teacherName]!;

        // "선생님" 제거, 간단하게 출력
        AppLogger.info('$teacherName:');
        for (final message in messages) {
          AppLogger.info(message);
        }

        // 교사 사이에 빈 줄 추가
        if (i < teacherNames.length - 1) {
          AppLogger.info('');
        }
      }

      AppLogger.info('\n=== 교체 정보 추출 완료 ===\n');
    } catch (e) {
      AppLogger.error('교사별 안내 메시지 출력 중 오류: $e', e);
    }
  }
}

