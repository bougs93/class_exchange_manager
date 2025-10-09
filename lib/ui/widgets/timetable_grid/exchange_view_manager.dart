import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/time_slot.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/exchange_history_item.dart';
import '../../../services/exchange_service.dart';
import '../../../services/excel_service.dart';
import '../../../utils/timetable_data_source.dart';
import '../../../utils/logger.dart';
import '../../../providers/state_reset_provider.dart';

/// 교체 뷰 관리 클래스
class ExchangeViewManager {
  final WidgetRef ref;
  final TimetableDataSource? dataSource;
  final TimetableData? timetableData;
  final ExchangeService exchangeService;

  ExchangeViewManager({
    required this.ref,
    required this.dataSource,
    required this.timetableData,
    required this.exchangeService,
  });

  /// TimeSlots 비교 및 로깅
  void compareTimeSlots(
    List<TimeSlot> beforeSlots,
    List<TimeSlot> afterSlots,
    String operation,
  ) {
    try {
      AppLogger.exchangeInfo('=== TimeSlots 비교: $operation ===');

      if (beforeSlots.length != afterSlots.length) {
        AppLogger.exchangeInfo('슬롯 개수 변경: ${beforeSlots.length} → ${afterSlots.length}');
        return;
      }

      int changedCount = 0;
      int unchangedCount = 0;
      List<String> changedSlots = [];

      for (int i = 0; i < beforeSlots.length; i++) {
        final beforeSlot = beforeSlots[i];
        final afterSlot = afterSlots[i];

        // TimeSlot 비교
        bool isChanged = beforeSlot.teacher != afterSlot.teacher ||
            beforeSlot.subject != afterSlot.subject ||
            beforeSlot.className != afterSlot.className ||
            beforeSlot.isExchangeable != afterSlot.isExchangeable;

        if (isChanged) {
          changedCount++;

          // 위치 정보 생성
          String positionInfo = '';
          if (beforeSlot.dayOfWeek != null && beforeSlot.period != null) {
            String dayName = _getDayName(beforeSlot.dayOfWeek!);
            positionInfo = ' ($dayName ${beforeSlot.period}교시)';
          }

          AppLogger.exchangeInfo('변경된 슬롯 $i$positionInfo:');

          // 각 필드별 변경사항 로깅
          if (beforeSlot.teacher != afterSlot.teacher) {
            AppLogger.exchangeInfo('  교사: ${beforeSlot.teacher ?? "없음"} → ${afterSlot.teacher ?? "없음"}');
          }
          if (beforeSlot.subject != afterSlot.subject) {
            AppLogger.exchangeInfo('  과목: ${beforeSlot.subject ?? "없음"} → ${afterSlot.subject ?? "없음"}');
          }
          if (beforeSlot.className != afterSlot.className) {
            AppLogger.exchangeInfo('  학급: ${beforeSlot.className ?? "없음"} → ${afterSlot.className ?? "없음"}');
          }
          if (beforeSlot.isExchangeable != afterSlot.isExchangeable) {
            AppLogger.exchangeInfo('  교체가능: ${beforeSlot.isExchangeable} → ${afterSlot.isExchangeable}');
          }

          changedSlots.add('슬롯$i$positionInfo');
        } else {
          unchangedCount++;
        }
      }

      AppLogger.exchangeInfo('변경 요약: 변경됨 $changedCount개, 변경안됨 $unchangedCount개');
      if (changedSlots.isNotEmpty) {
        AppLogger.exchangeInfo('변경된 슬롯 목록: ${changedSlots.join(", ")}');
      }
      AppLogger.exchangeInfo('========================');
    } catch (e) {
      AppLogger.exchangeDebug('TimeSlots 비교 중 오류 발생: $e');
    }
  }

  /// 요일 번호를 요일명으로 변환
  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      default:
        return '요일$dayOfWeek';
    }
  }

  /// 교체 히스토리에서 교체 실행
  void executeExchangeFromHistory(dynamic exchangeItem) {
    try {
      AppLogger.exchangeDebug('교체 히스토리 실행 시작: ${exchangeItem.runtimeType}');

      ExchangePath? path;
      if (exchangeItem is ExchangeHistoryItem) {
        path = exchangeItem.originalPath;
        AppLogger.exchangeDebug('ExchangeHistoryItem에서 경로 추출: ${path.runtimeType}');
      } else if (exchangeItem is ExchangePath) {
        path = exchangeItem;
      }

      if (path != null) {
        if (path is OneToOneExchangePath) {
          _executeOneToOneExchangeFromPath(path);
        } else if (path is CircularExchangePath) {
          _executeCircularExchangeFromPath(path);
        } else if (path is ChainExchangePath) {
          _executeChainExchangeFromPath(path);
        } else {
          AppLogger.exchangeDebug('알 수 없는 교체 경로 타입: ${path.runtimeType}');
        }
      } else {
        AppLogger.exchangeDebug('교체 경로를 찾을 수 없음: ${exchangeItem.runtimeType}');
      }
    } catch (e) {
      AppLogger.exchangeDebug('교체 히스토리 실행 중 오류 발생: $e');
    }
  }

  /// 1:1 교체 경로에서 교체 실행
  void _executeOneToOneExchangeFromPath(OneToOneExchangePath path) {
    if (timetableData == null || dataSource == null) {
      AppLogger.exchangeDebug('1:1 교체 실행 실패: timetableData 또는 dataSource가 null');
      return;
    }

    AppLogger.exchangeInfo('1:1 교체 실행 시작: ${path.id}');

    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;

    AppLogger.exchangeInfo('교체 전:');
    AppLogger.exchangeInfo('  └─ ${sourceNode.day}|${sourceNode.period}|${sourceNode.className}|${sourceNode.teacherName}|${sourceNode.subjectName}');
    AppLogger.exchangeInfo('  └─ ${targetNode.day}|${targetNode.period}|${targetNode.className}|${targetNode.teacherName}|${targetNode.subjectName}');

    AppLogger.exchangeInfo('1:1 교체 실행: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');

    // 1:1 교체 실행
    bool success = exchangeService.performOneToOneExchange(
      dataSource!.timeSlots,
      sourceNode.teacherName,
      sourceNode.day,
      sourceNode.period,
      targetNode.teacherName,
      targetNode.day,
      targetNode.period,
    );

    if (success) {
      AppLogger.exchangeInfo('교체 후:');
      AppLogger.exchangeInfo('  └─ ${sourceNode.day}|${sourceNode.period}|${sourceNode.className}|${targetNode.teacherName}|${targetNode.subjectName}');
      AppLogger.exchangeInfo('  └─ ${targetNode.day}|${targetNode.period}|${targetNode.className}|${sourceNode.teacherName}|${sourceNode.subjectName}');
      AppLogger.exchangeInfo('✅ 1:1 교체 성공: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');

      // TimetableDataSource 업데이트
      ref.read(stateResetProvider.notifier).resetExchangeStates(
            reason: '1:1 교체 실행 - DataSource 업데이트',
          );
      dataSource?.updateData(dataSource!.timeSlots, timetableData!.teachers);
    } else {
      AppLogger.exchangeDebug('❌ 1:1 교체 실패: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');
    }
  }

  /// 순환 교체 경로에서 교체 실행
  void _executeCircularExchangeFromPath(CircularExchangePath path) {
    AppLogger.exchangeInfo('순환 교체 실행 (구현 예정): ${path.id}');
    AppLogger.exchangeDebug('순환 교체 노드 수: ${path.nodes.length}개');
    for (int i = 0; i < path.nodes.length; i++) {
      var node = path.nodes[i];
      AppLogger.exchangeDebug('노드 ${i + 1}: ${node.teacherName}(${node.day}${node.period}교시)');
    }
  }

  /// 연쇄 교체 경로에서 교체 실행
  void _executeChainExchangeFromPath(ChainExchangePath path) {
    AppLogger.exchangeInfo('연쇄 교체 실행 (구현 예정): ${path.id}');
    AppLogger.exchangeDebug('연쇄 교체 단계 수: ${path.steps.length}개');
    AppLogger.exchangeDebug('목표 노드: ${path.nodeA.teacherName}(${path.nodeA.day}${path.nodeA.period}교시)');
    AppLogger.exchangeDebug('대체 노드: ${path.nodeB.teacherName}(${path.nodeB.day}${path.nodeB.period}교시)');
  }

  /// 상세한 교체 정보 로깅
  void logDetailedExchangeInfo(int exchangeNumber, dynamic exchangeItem) {
    try {
      dynamic path = exchangeItem;
      if (exchangeItem is ExchangeHistoryItem) {
        path = exchangeItem.originalPath;
      }

      if (path is OneToOneExchangePath) {
        final sourceNode = path.sourceNode;
        final targetNode = path.targetNode;

        AppLogger.exchangeInfo('교체 $exchangeNumber: 1:1 교체');
        AppLogger.exchangeInfo('  └─ ${sourceNode.day}|${sourceNode.period}|${sourceNode.className}|${sourceNode.teacherName}|${sourceNode.subjectName}');
        AppLogger.exchangeInfo('  └─ ${targetNode.day}|${targetNode.period}|${targetNode.className}|${targetNode.teacherName}|${targetNode.subjectName}');
        AppLogger.exchangeInfo('  └─ 결과: ${sourceNode.teacherName}(${sourceNode.day}${sourceNode.period}교시) ↔ ${targetNode.teacherName}(${targetNode.day}${targetNode.period}교시)');
      } else if (path is CircularExchangePath) {
        AppLogger.exchangeInfo('교체 $exchangeNumber: 순환 교체 (구현 예정)');
        AppLogger.exchangeInfo('  └─ 순환 노드 수: ${path.nodes.length}개');
        for (int i = 0; i < path.nodes.length; i++) {
          var node = path.nodes[i];
          AppLogger.exchangeInfo('  └─ 노드 ${i + 1}: ${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}');
        }
      } else if (path is ChainExchangePath) {
        AppLogger.exchangeInfo('교체 $exchangeNumber: 연쇄 교체 (구현 예정)');
        AppLogger.exchangeInfo('  └─ 목표: ${path.nodeA.day}|${path.nodeA.period}|${path.nodeA.className}|${path.nodeA.teacherName}|${path.nodeA.subjectName}');
        AppLogger.exchangeInfo('  └─ 대체: ${path.nodeB.day}|${path.nodeB.period}|${path.nodeB.className}|${path.nodeB.teacherName}|${path.nodeB.subjectName}');
        AppLogger.exchangeInfo('  └─ 단계 수: ${path.steps.length}개');
      } else {
        AppLogger.exchangeInfo('교체 $exchangeNumber: 알 수 없는 교체 타입 (${exchangeItem.runtimeType})');
      }
    } catch (e) {
      AppLogger.exchangeDebug('교체 $exchangeNumber 상세 정보 로깅 중 오류: $e');
    }
  }
}
