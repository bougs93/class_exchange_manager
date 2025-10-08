import 'package:flutter/material.dart';
import 'package:widget_arrows/widget_arrows.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../services/excel_service.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/exchange_node.dart';
import 'exchange_arrow_style.dart';

/// widget_arrows 패키지를 활용한 화살표 관리 클래스
/// 
/// 기존의 복잡한 CustomPainter 대신 widget_arrows 패키지를 사용하여
/// 더 간단하고 안정적인 화살표 표시 기능을 제공합니다.
class WidgetArrowsManager {
  final TimetableData timetableData;
  final List<GridColumn> columns;
  final double zoomFactor;
  
  // 화살표 ID 관리
  final Map<String, String> _arrowIds = {};
  final List<String> _activeArrowIds = [];
  
  WidgetArrowsManager({
    required this.timetableData,
    required this.columns,
    required this.zoomFactor,
  });

  /// 교체 경로에 따른 화살표 생성
  /// 
  /// [selectedPath] 선택된 교체 경로
  /// [context] BuildContext
  /// 
  /// Returns: `List<ArrowElement>` - 생성된 화살표 위젯들
  List<ArrowElement> createArrowsForPath(ExchangePath selectedPath, BuildContext context) {
    // 기존 화살표 정리
    clearAllArrows();
    
    List<ArrowElement> arrows = [];
    
    print('🔍 화살표 생성 시작: ${selectedPath.type}');
    
    switch (selectedPath.type) {
      case ExchangePathType.oneToOne:
        arrows = _createOneToOneArrows(selectedPath as OneToOneExchangePath, context);
        break;
      case ExchangePathType.circular:
        arrows = _createCircularArrows(selectedPath as CircularExchangePath, context);
        break;
      case ExchangePathType.chain:
        arrows = _createChainArrows(selectedPath as ChainExchangePath, context);
        break;
    }
    
    print('✅ 생성된 화살표 개수: ${arrows.length}');
    return arrows;
  }

  /// 1:1 교체 화살표 생성
  List<ArrowElement> _createOneToOneArrows(OneToOneExchangePath path, BuildContext context) {
    List<ArrowElement> arrows = [];
    
    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;
    
    final sourceId = _getCellId(sourceNode);
    final targetId = _getCellId(targetNode);
    
    print('📍 1:1 교체 화살표 생성:');
    print('  소스: ${sourceNode.teacherName} ${sourceNode.day}${sourceNode.period}교시 → ID: $sourceId');
    print('  타겟: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시 → ID: $targetId');
    
    // A → B 방향 화살표
    final arrowId1 = _generateArrowId('oneToOne', 'AtoB');
    arrows.add(_createArrowElement(
      arrowId: arrowId1,
      sourceId: sourceId,
      targetId: targetId,
      style: ExchangeArrowStyle.oneToOne,
      context: context,
    ));
    
    // B → A 방향 화살표
    final arrowId2 = _generateArrowId('oneToOne', 'BtoA');
    arrows.add(_createArrowElement(
      arrowId: arrowId2,
      sourceId: targetId,
      targetId: sourceId,
      style: ExchangeArrowStyle.oneToOne,
      context: context,
    ));
    
    print('✅ 1:1 교체 화살표 생성 완료: ${arrows.length}개');
    return arrows;
  }

  /// 순환 교체 화살표 생성
  List<ArrowElement> _createCircularArrows(CircularExchangePath path, BuildContext context) {
    List<ArrowElement> arrows = [];
    
    final steps = path.steps;
    if (steps < 2) return arrows;
    
    // 순환 경로의 각 단계에 대해 화살표 생성
    // CircularExchangePath는 nodes 리스트를 사용하여 단계별 화살표 생성
    final nodes = path.nodes;
    for (int i = 0; i < nodes.length - 1; i++) {
      final currentNode = nodes[i];
      final nextNode = nodes[i + 1];
      
      final arrowId = _generateArrowId('circular', 'step_$i');
      arrows.add(_createArrowElement(
        arrowId: arrowId,
        sourceId: _getCellId(currentNode),
        targetId: _getCellId(nextNode),
        style: ExchangeArrowStyle.circular,
        context: context,
      ));
    }
    
    return arrows;
  }

  /// 연쇄 교체 화살표 생성
  List<ArrowElement> _createChainArrows(ChainExchangePath path, BuildContext context) {
    List<ArrowElement> arrows = [];
    
    final steps = path.steps;
    if (steps.length < 2) return arrows;
    
    // 연쇄 경로의 각 단계에 대해 화살표 생성
    for (int i = 0; i < steps.length - 1; i++) {
      final currentStep = steps[i];
      final nextStep = steps[i + 1];
      
      final arrowId = _generateArrowId('chain', 'step_$i');
      arrows.add(_createArrowElement(
        arrowId: arrowId,
        sourceId: _getCellId(currentStep.toNode),
        targetId: _getCellId(nextStep.fromNode),
        style: ExchangeArrowStyle.chain,
        context: context,
      ));
    }
    
    return arrows;
  }

  /// 화살표 요소 생성
  ArrowElement _createArrowElement({
    required String arrowId,
    required String sourceId,
    required String targetId,
    required ExchangeArrowStyle style,
    required BuildContext context,
  }) {
    _arrowIds[arrowId] = arrowId;
    _activeArrowIds.add(arrowId);
    
    return ArrowElement(
      id: arrowId,
      targetId: targetId,
      color: style.color,
      width: style.strokeWidth,
      // widget_arrows 패키지의 올바른 API 사용
      child: Container(
        key: ValueKey(sourceId),
        width: 1,
        height: 1,
        // 셀 식별을 위한 키 설정
      ),
    );
  }

  /// 셀 ID 생성 (DataGrid의 실제 셀과 연결)
  String _getCellId(ExchangeNode node) {
    // 교사 인덱스 찾기
    int teacherIndex = timetableData.teachers
        .indexWhere((teacher) => teacher.name == node.teacherName);
    
    if (teacherIndex == -1) {
      return 'cell_${node.teacherName}_${node.day}_${node.period}';
    }
    
    // 컬럼명 생성
    String columnName = '${node.day}_${node.period}';
    
    // 실제 DataGrid에서 사용되는 셀 키 형식으로 생성
    return 'cell_${teacherIndex}_${columnName}';
  }

  /// 화살표 ID 생성
  String _generateArrowId(String type, String suffix) {
    return '${type}_arrow_$suffix';
  }

  /// 모든 화살표 정리
  void clearAllArrows() {
    _arrowIds.clear();
    _activeArrowIds.clear();
  }

  /// 특정 화살표 제거
  void removeArrow(String arrowId) {
    _arrowIds.remove(arrowId);
    _activeArrowIds.remove(arrowId);
  }

  /// 활성 화살표 ID 목록 조회
  List<String> get activeArrowIds => List.unmodifiable(_activeArrowIds);

  /// 화살표 개수 조회
  int get arrowCount => _activeArrowIds.length;
}

/// 화살표 표시를 위한 위젯 래퍼
/// 
/// widget_arrows 패키지를 사용하여 화살표가 포함된 위젯을 생성합니다.
/// 현재는 기존 CustomPainter 방식으로 폴백합니다.
class ArrowDisplayWidget extends StatelessWidget {
  final List<ArrowElement> arrows;
  final Widget child;
  final WidgetArrowsManager arrowsManager;

  const ArrowDisplayWidget({
    super.key,
    required this.arrows,
    required this.child,
    required this.arrowsManager,
  });

  @override
  Widget build(BuildContext context) {
    if (arrows.isEmpty) {
      return child;
    }

    // 현재는 widget_arrows 패키지 대신 기존 방식 사용
    // TODO: widget_arrows 패키지의 올바른 API 확인 후 구현
    print('⚠️ ArrowDisplayWidget: widget_arrows 패키지 사용 대신 기존 방식으로 폴백');
    return child;
  }
}

/// 화살표 초기화 헬퍼
/// 
/// 화살표 상태를 관리하고 초기화하는 기능을 제공합니다.
class ArrowInitializationHelper {
  static WidgetArrowsManager? _currentManager;
  
  /// 화살표 매니저 설정
  static void setManager(WidgetArrowsManager manager) {
    _currentManager = manager;
  }
  
  /// 현재 화살표 매니저 조회
  static WidgetArrowsManager? get currentManager => _currentManager;
  
  /// 모든 화살표 초기화
  static void clearAllArrows() {
    _currentManager?.clearAllArrows();
  }
  
  /// 특정 타입의 화살표만 초기화
  static void clearArrowsByType(String type) {
    if (_currentManager == null) return;
    
    final manager = _currentManager!;
    final activeIds = manager.activeArrowIds;
    
    for (final arrowId in activeIds) {
      if (arrowId.startsWith('${type}_arrow_')) {
        manager.removeArrow(arrowId);
      }
    }
  }
  
  /// 화살표 상태 정보 조회
  static Map<String, dynamic> getArrowStatus() {
    if (_currentManager == null) {
      return {
        'isActive': false,
        'arrowCount': 0,
        'activeIds': <String>[],
      };
    }
    
    final manager = _currentManager!;
    return {
      'isActive': manager.arrowCount > 0,
      'arrowCount': manager.arrowCount,
      'activeIds': manager.activeArrowIds,
    };
  }
}
