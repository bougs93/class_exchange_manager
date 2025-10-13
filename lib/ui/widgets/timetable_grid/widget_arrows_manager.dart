import 'package:flutter/material.dart';
import 'package:widget_arrows/widget_arrows.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../services/excel_service.dart';
import '../../../models/exchange_path.dart';
import '../../../models/one_to_one_exchange_path.dart';
import '../../../models/circular_exchange_path.dart';
import '../../../models/chain_exchange_path.dart';
import '../../../models/supplement_exchange_path.dart';
import '../../../models/exchange_node.dart';
import '../../../utils/logger.dart';
import 'exchange_arrow_style.dart';

/// widget_arrows 패키지를 활용한 화살표 관리 클래스 (싱글톤)
/// 
/// 기존의 복잡한 CustomPainter 대신 widget_arrows 패키지를 사용하여
/// 더 간단하고 안정적인 화살표 표시 기능을 제공합니다.
class WidgetArrowsManager {
  // 싱글톤 인스턴스
  static final WidgetArrowsManager _instance = WidgetArrowsManager._internal();
  
  // 싱글톤 생성자
  factory WidgetArrowsManager() => _instance;
  
  // 내부 생성자
  WidgetArrowsManager._internal();
  
  // 현재 설정된 데이터 (동적으로 업데이트 가능)
  TimetableData? _timetableData;
  List<GridColumn>? _columns;
  
  // 화살표 ID 관리
  final Map<String, String> _arrowIds = {};
  final List<String> _activeArrowIds = [];
  
  /// 데이터 설정 (초기화 시 호출)
  void initialize({
    required TimetableData timetableData,
    required List<GridColumn> columns,
    double? zoomFactor, // 호환성을 위해 유지
  }) {
    _timetableData = timetableData;
    _columns = columns;
    AppLogger.exchangeDebug('WidgetArrowsManager 싱글톤 초기화 완료');
  }
  
  /// 데이터 업데이트 (동적 변경 시 호출)
  void updateData({
    TimetableData? timetableData,
    List<GridColumn>? columns,
    double? zoomFactor, // 호환성을 위해 유지
  }) {
    if (timetableData != null) _timetableData = timetableData;
    if (columns != null) _columns = columns;
  }

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
    
    AppLogger.exchangeDebug('화살표 생성 시작: ${selectedPath.type}');
    
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
      case ExchangePathType.supplement:
        arrows = _createSupplementArrows(selectedPath as SupplementExchangePath, context);
        break;
    }
    
    AppLogger.exchangeDebug('생성된 화살표 개수: ${arrows.length}');
    return arrows;
  }

  /// 1:1 교체 화살표 생성
  List<ArrowElement> _createOneToOneArrows(OneToOneExchangePath path, BuildContext context) {
    List<ArrowElement> arrows = [];
    
    final sourceNode = path.sourceNode;
    final targetNode = path.targetNode;
    
    final sourceId = _getCellId(sourceNode);
    final targetId = _getCellId(targetNode);
    
    AppLogger.exchangeDebug('1:1 교체 화살표 생성:');
    AppLogger.exchangeDebug('  소스: ${sourceNode.teacherName} ${sourceNode.day}${sourceNode.period}교시 → ID: $sourceId');
    AppLogger.exchangeDebug('  타겟: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시 → ID: $targetId');
    
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
    
    AppLogger.exchangeDebug('1:1 교체 화살표 생성 완료: ${arrows.length}개');
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

  /// 보강 교체 화살표 생성
  /// 
  /// 보강 교체는 단방향 화살표로 표시됩니다.
  /// 보강할 셀(sourceNode)에서 보강할 교사(targetNode)로의 화살표를 생성합니다.
  List<ArrowElement> _createSupplementArrows(SupplementExchangePath path, BuildContext context) {
    List<ArrowElement> arrows = [];
    
    final sourceNode = path.sourceNode;  // 보강할 셀
    final targetNode = path.targetNode;  // 보강할 교사
    
    final sourceId = _getCellId(sourceNode);
    final targetId = _getCellId(targetNode);
    
    AppLogger.exchangeDebug('보강 교체 화살표 생성:');
    AppLogger.exchangeDebug('  보강할 셀: ${sourceNode.teacherName} ${sourceNode.day}${sourceNode.period}교시 → ID: $sourceId');
    AppLogger.exchangeDebug('  보강할 교사: ${targetNode.teacherName} ${targetNode.day}${targetNode.period}교시 → ID: $targetId');
    
    // 보강할 셀에서 보강할 교사로의 단방향 화살표
    final arrowId = _generateArrowId('supplement', 'supplement');
    arrows.add(_createArrowElement(
      arrowId: arrowId,
      sourceId: sourceId,
      targetId: targetId,
      style: ExchangeArrowStyle.supplement,
      context: context,
    ));
    
    AppLogger.exchangeDebug('보강 교체 화살표 생성 완료: ${arrows.length}개');
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
      child: SizedBox(
        key: ValueKey(sourceId),
        width: 1,
        height: 1,
        // 셀 식별을 위한 키 설정
      ),
    );
  }

  /// 셀 ID 생성 (DataGrid의 실제 셀과 연결)
  String _getCellId(ExchangeNode node) {
    if (_timetableData == null) {
      return 'cell_${node.teacherName}_${node.day}_${node.period}';
    }
    
    // 교사 인덱스 찾기
    int teacherIndex = _timetableData!.teachers
        .indexWhere((teacher) => teacher.name == node.teacherName);
    
    if (teacherIndex == -1) {
      return 'cell_${node.teacherName}_${node.day}_${node.period}';
    }
    
    // 컬럼명 생성
    String columnName = '${node.day}_${node.period}';
    
    // 실제 DataGrid에서 사용되는 셀 키 형식으로 생성
    return 'cell_$teacherIndex' '_' '$columnName';
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

  /// 화살표 상태 정보 조회
  Map<String, dynamic> getArrowStatus() {
    return {
      'isActive': arrowCount > 0,
      'arrowCount': arrowCount,
      'activeIds': activeArrowIds,
    };
  }
  
  /// 초기화 상태 확인
  bool get isInitialized => _timetableData != null && _columns != null;
}
