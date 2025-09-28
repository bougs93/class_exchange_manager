import 'exchange_node.dart';
import 'exchange_path.dart';

/// 순환 교체 경로를 나타내는 모델 클래스
/// 여러 교사 간의 순환 교체 경로를 관리
class CircularExchangePath implements ExchangePath {
  final List<ExchangeNode> _nodes;  // 순환 경로에 참여하는 노드들
  final int steps;                   // 순환 단계 수 (시작 교사 제외)
  final String _description;        // 사람이 읽기 쉬운 경로 설명
  bool _isSelected = false;         // 선택 상태
  
  CircularExchangePath({
    required List<ExchangeNode> nodes,
    required this.steps,
    required String description,
  }) : _nodes = nodes,
       _description = description;

  /// 노드 리스트로부터 자동으로 경로 생성
  factory CircularExchangePath.fromNodes(List<ExchangeNode> nodes) {
    if (nodes.isEmpty) {
      throw ArgumentError('노드 리스트가 비어있습니다.');
    }
    
    // 순환 경로인지 확인 (시작점과 끝점이 같아야 함)
    if (nodes.first != nodes.last) {
      throw ArgumentError('순환 경로가 아닙니다. 시작점과 끝점이 같아야 합니다.');
    }
    
    int steps = nodes.length - 1; // 시작점 복귀 제외
    String description = _generateDescription(nodes);
    
    return CircularExchangePath(
      nodes: nodes,
      steps: steps,
      description: description,
    );
  }

  // ExchangePath 인터페이스 구현
  @override
  String get id => _nodes.map((node) => node.nodeId).join('_');
  
  @override
  String get displayTitle => '순환교체 경로 ${steps}단계';
  
  @override
  List<ExchangeNode> get nodes => _nodes;
  
  @override
  ExchangePathType get type => ExchangePathType.circular;
  
  @override
  bool get isSelected => _isSelected;
  
  @override
  void setSelected(bool selected) {
    _isSelected = selected;
  }
  
  @override
  String get description => _description;
  
  @override
  int get priority => steps; // 단계가 적을수록 높은 우선순위

  /// 경로 설명 자동 생성
  static String _generateDescription(List<ExchangeNode> nodes) {
    if (nodes.isEmpty) return '';
    
    List<String> descriptions = [];
    for (int i = 0; i < nodes.length - 1; i++) { // 마지막 노드(시작점 복귀) 제외
      descriptions.add(nodes[i].displayText);
    }
    
    return '${descriptions.join(' → ')} → ${nodes.first.displayText}';
  }

  /// 순환 경로가 유효한지 확인
  bool get isValid {
    if (_nodes.length < 3) return false; // 최소 3개 노드 필요 (시작 → 중간 → 시작)
    if (_nodes.first != _nodes.last) return false; // 시작점과 끝점이 같아야 함
    if (steps < 2) return false; // 최소 2단계 필요
    
    // 1개 스탭 교체에서는 같은 학급만 가능
    // 모든 노드가 같은 학급이어야 함
    String? firstClassName = _nodes.first.className;
    for (ExchangeNode node in _nodes) {
      if (node.className != firstClassName) return false;
    }
    
    return true;
  }

  /// 참여 교사 수 반환
  int get participantCount => steps;

  /// 참여 교사명 리스트 반환 (중복 제거)
  List<String> get participantTeachers {
    Set<String> teachers = {};
    for (int i = 0; i < _nodes.length - 1; i++) { // 마지막 노드 제외
      teachers.add(_nodes[i].teacherName);
    }
    return teachers.toList();
  }

  /// 경로의 길이 반환 (노드 수)
  int get pathLength => _nodes.length;

  /// 두 경로가 같은지 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CircularExchangePath &&
        other.steps == steps &&
        other.description == description &&
        _listEquals(other._nodes, _nodes);
  }

  /// 리스트 비교 헬퍼 메서드
  bool _listEquals(List<ExchangeNode> a, List<ExchangeNode> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 해시코드 생성
  @override
  int get hashCode {
    return steps.hashCode ^ _description.hashCode ^ _nodes.hashCode;
  }

  /// 문자열 표현
  @override
  String toString() {
    return 'CircularExchangePath(steps: $steps, description: $_description)';
  }
}