import 'package:flutter/material.dart';
import '../../../models/exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../utils/logger.dart';
import '../../state_managers/path_selection_manager.dart';
import '../../../utils/timetable_data_source.dart';

/// 경로 선택 처리 관련 핸들러
mixin PathSelectionHandlerMixin<T extends StatefulWidget> on State<T> {
  // 인터페이스 - 구현 클래스에서 제공해야 함
  PathSelectionManager get pathSelectionManager;
  TimetableDataSource? get dataSource; // TimetableDataSource - ExchangeLogicMixin에서 제공

  // 타겟 셀 핸들러 메서드들
  void setTargetCellFromPath(OneToOneExchangePath path);
  void setTargetCellFromCircularPath(CircularExchangePath path);
  void setTargetCellFromChainPath(ChainExchangePath path);
  void setTargetCellFromSupplementPath(SupplementExchangePath path);
  void clearTargetCell();
  void updateHeaderTheme();
  void showSnackBar(String message, {Color? backgroundColor});
  void onPathSelected(CircularExchangePath path);
  void onPathDeselected();

  // 상태 변수 setter
  void Function(OneToOneExchangePath?) get setSelectedOneToOnePath;
  void Function(ChainExchangePath?) get setSelectedChainPath;
  void Function(SupplementExchangePath?) get setSelectedSupplementPath;

  /// 통합 경로 선택 처리 (PathSelectionManager 사용)
  void onUnifiedPathSelected(ExchangePath path) {
    AppLogger.exchangeDebug('통합 경로 선택: ${path.id}, 타입: ${pathSelectionManager.getPathTypeName(path)}');
    
    // 선택된 경로의 한 줄 요약 정보 출력
    String pathSummary = _generatePathSummary(path);
    AppLogger.exchangeDebug('📋 [선택된 경로 요약] $pathSummary');
    
    // 경로 유형별 적절한 핸들러 호출
    switch (path.type) {
      case ExchangePathType.circular:
        handleCircularPathChanged(path as CircularExchangePath);
        break;
      case ExchangePathType.chain:
        handleChainPathChanged(path as ChainExchangePath);
        break;
      case ExchangePathType.oneToOne:
        handleOneToOnePathChanged(path as OneToOneExchangePath);
        break;
      case ExchangePathType.supplement:
        handleSupplementPathChanged(path as SupplementExchangePath);
        break;
    }
    
    pathSelectionManager.selectPath(path);
  }

  /// 경로 모델에 저장된 모든 정보를 한 줄로 출력 (내부 동작 확인용)
  String _generatePathSummary(ExchangePath path) {
    // 경로 기본 정보
    String basicInfo = 'ID: ${path.id}, Title: ${path.displayTitle}, Type: ${path.type.name}, Priority: ${path.priority}, Selected: ${path.isSelected}';
    
    // 노드들의 상세 정보
    String nodesInfo = 'Nodes[${path.nodes.length}]: ';
    List<String> nodeDetails = [];
    
    for (int i = 0; i < path.nodes.length; i++) {
      ExchangeNode node = path.nodes[i];
      String nodeDetail = '[$i]${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}|ID:${node.nodeId}';
      nodeDetails.add(nodeDetail);
    }
       
    nodesInfo += nodeDetails.join(', ');
    
    // 전체 정보 합치기
    return '$basicInfo | $nodesInfo';
  }

  /// 1:1 교체 경로 변경 핸들러
  void handleOneToOnePathChanged(OneToOneExchangePath? path) {
    setSelectedOneToOnePath(path);
    dataSource?.updateSelectedOneToOnePath(path);

    if (path != null) {
      AppLogger.exchangeDebug('1:1교체 경로 선택: ${path.id}');
      setTargetCellFromPath(path);
      updateHeaderTheme();
    } else {
      AppLogger.exchangeDebug('1:1교체 경로 선택 해제');
      clearTargetCell();
      updateHeaderTheme();
      showSnackBar(
        '1:1교체 경로 선택이 해제되었습니다.',
        backgroundColor: Colors.grey.shade600,
      );
    }
  }

  /// 순환 교체 경로 변경 핸들러
  void handleCircularPathChanged(CircularExchangePath? path) {
    if (path != null) {
      AppLogger.exchangeDebug('순환교체 경로 선택: ${path.id}');
      onPathSelected(path);
      setTargetCellFromCircularPath(path);
    } else {
      AppLogger.exchangeDebug('순환교체 경로 선택 해제');
      onPathDeselected();
      clearTargetCell();
      showSnackBar(
        '순환교체 경로 선택이 해제되었습니다.',
        backgroundColor: Colors.grey.shade600,
      );
    }
  }

  /// 연쇄 교체 경로 변경 핸들러
  void handleChainPathChanged(ChainExchangePath? path) {
    setSelectedChainPath(path);
    dataSource?.updateSelectedChainPath(path);

    if (path != null) {
      AppLogger.exchangeDebug('연쇄교체 경로 선택: ${path.id}');
      setTargetCellFromChainPath(path);
      updateHeaderTheme();
    } else {
      AppLogger.exchangeDebug('연쇄교체 경로 선택 해제');
      clearTargetCell();
      updateHeaderTheme();
      showSnackBar(
        '연쇄교체 경로 선택이 해제되었습니다.',
        backgroundColor: Colors.grey.shade600,
      );
    }
  }

  /// 보강 교체 경로 변경 핸들러
  void handleSupplementPathChanged(SupplementExchangePath? path) {
    setSelectedSupplementPath(path);
    // dataSource에 보강 경로 업데이트 메서드가 있다면 추가
    // dataSource?.updateSelectedSupplementPath(supplementPath);

    if (path != null) {
      AppLogger.exchangeDebug('보강교체 경로 선택: ${path.id}');
      setTargetCellFromSupplementPath(path);
      updateHeaderTheme();
    } else {
      AppLogger.exchangeDebug('보강교체 경로 선택 해제');
      clearTargetCell();
      updateHeaderTheme();
      showSnackBar(
        '보강교체 경로 선택이 해제되었습니다.',
        backgroundColor: Colors.grey.shade600,
      );
    }
  }
}
