import 'package:flutter/material.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../../services/exchange_service.dart';
import '../../../services/circular_exchange_service.dart';
import '../../../services/chain_exchange_service.dart';
import '../../../services/excel_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/timetable_data_source.dart';

/// 타겟 셀 설정 관련 핸들러
mixin TargetCellHandler<T extends StatefulWidget> on State<T> {
  // 인터페이스 - 구현 클래스에서 제공해야 함
  ExchangeService get exchangeService;
  CircularExchangeService get circularExchangeService;
  ChainExchangeService get chainExchangeService;
  TimetableData? get timetableData;
  TimetableDataSource? get dataSource; // TimetableDataSource - ExchangeLogicMixin에서 제공

  // dataSource는 ExchangeLogicMixin에서 상속받음

  /// 1:1 교체 경로에서 타겟 셀 설정
  void setTargetCellFromPath(OneToOneExchangePath path) {
    if (!exchangeService.hasSelectedCell() || timetableData == null) {
      AppLogger.exchangeDebug('1:1 교체 타겟 셀 설정 실패: 조건 불충족');
      return;
    }

    // 교체 대상의 요일과 교시 가져오기
    String targetDay = path.targetNode.day;
    int targetPeriod = path.targetNode.period;

    // 선택된 셀의 교사명 가져오기
    String selectedTeacher = exchangeService.selectedTeacher!;

    // ExchangeService에 타겟 셀 설정
    exchangeService.setTargetCell(selectedTeacher, targetDay, targetPeriod);

    // 데이터 소스에 타겟 셀 정보 전달
    dataSource?.updateTargetCell(selectedTeacher, targetDay, targetPeriod);

    AppLogger.exchangeDebug('타겟 셀 설정: $selectedTeacher $targetDay $targetPeriod교시');
  }

  /// 순환교체 경로에서 타겟 셀 설정 (교체 대상의 같은 행 셀)
  /// 교체 대상이 월1교시라면, 선택된 셀의 같은 행의 월1교시를 타겟으로 설정
  void setTargetCellFromCircularPath(CircularExchangePath path) {
    if (!circularExchangeService.hasSelectedCell() || timetableData == null || path.nodes.length < 2) {
      AppLogger.exchangeDebug('순환교체 타겟 셀 설정 실패: 조건 불충족');
      return;
    }

    // 순환교체 경로의 첫 번째 노드는 선택된 셀, 두 번째 노드는 교체 대상
    ExchangeNode sourceNode = path.nodes[0]; // 선택된 셀
    ExchangeNode targetNode = path.nodes[1]; // 교체 대상

    // 교체 대상의 요일과 교시 가져오기
    String targetDay = targetNode.day;
    int targetPeriod = targetNode.period;

    // 선택된 셀의 교사명 가져오기
    String selectedTeacher = sourceNode.teacherName;

    // ExchangeService에 타겟 셀 설정
    exchangeService.setTargetCell(selectedTeacher, targetDay, targetPeriod);

    // 데이터 소스에 타겟 셀 정보 전달
    dataSource?.updateTargetCell(selectedTeacher, targetDay, targetPeriod);

    AppLogger.exchangeDebug('순환교체 타겟 셀 설정: $selectedTeacher $targetDay $targetPeriod교시');
  }

  /// 연쇄교체 경로에서 타겟 셀 설정 (마지막 교체 대상의 같은 행 셀)
  /// 마지막 교체 대상이 수1교시라면, 선택된 셀의 같은 행의 수1교시를 타겟으로 설정
  void setTargetCellFromChainPath(ChainExchangePath path) {
    if (!chainExchangeService.hasSelectedCell() || timetableData == null) {
      AppLogger.exchangeDebug('연쇄교체 타겟 셀 설정 실패: 조건 불충족');
      return;
    }

    // 연쇄교체 경로의 마지막 교체 대상은 nodeB (최종 교체 대상)
    ExchangeNode targetNode = path.nodeB; // 마지막 교체 대상

    // 교체 대상의 요일과 교시 가져오기
    String targetDay = targetNode.day;
    int targetPeriod = targetNode.period;

    // 선택된 셀의 교사명 가져오기 (nodeA의 교사명)
    String selectedTeacher = path.nodeA.teacherName;

    // ExchangeService에 타겟 셀 설정
    exchangeService.setTargetCell(selectedTeacher, targetDay, targetPeriod);

    // 데이터 소스에 타겟 셀 정보 전달
    dataSource?.updateTargetCell(selectedTeacher, targetDay, targetPeriod);

    AppLogger.exchangeDebug('연쇄교체 타겟 셀 설정: $selectedTeacher $targetDay $targetPeriod교시 (마지막 교체 대상)');
  }

  /// 타겟 셀 해제
  void clearTargetCell() {
    exchangeService.updateTargetCellState(null, null, null);
    dataSource?.updateTargetCell(null, null, null);
    AppLogger.exchangeDebug('타겟 셀 해제 (UI 핸들러)');
  }
}
