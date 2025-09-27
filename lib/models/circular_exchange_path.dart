import 'exchange_node.dart';

/// 순환 교체 경로를 나타내는 모델 클래스
/// 여러 교사 간의 순환 교체 경로를 관리
class CircularExchangePath {
  final List<ExchangeNode> nodes;  // 순환 경로에 참여하는 노드들
  final int steps;                  // 순환 단계 수 (시작 교사 제외)
  final String description;        // 사람이 읽기 쉬운 경로 설명
  
  CircularExchangePath({
    required this.nodes,
    required this.steps,
    required this.description,
  });

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
    if (nodes.length < 3) return false; // 최소 3개 노드 필요 (시작 → 중간 → 시작)
    if (nodes.first != nodes.last) return false; // 시작점과 끝점이 같아야 함
    if (steps < 2) return false; // 최소 2단계 필요
    
    // 1개 스탭 교체에서는 같은 학급만 가능
    // 모든 노드가 같은 학급이어야 함
    String? firstClassName = nodes.first.className;
    for (ExchangeNode node in nodes) {
      if (node.className != firstClassName) return false;
    }
    
    return true;
  }

  /// 참여 교사 수 반환
  int get participantCount => steps;

  /// 참여 교사명 리스트 반환 (중복 제거)
  List<String> get participantTeachers {
    Set<String> teachers = {};
    for (int i = 0; i < nodes.length - 1; i++) { // 마지막 노드 제외
      teachers.add(nodes[i].teacherName);
    }
    return teachers.toList();
  }

  /// 경로의 길이 반환 (노드 수)
  int get pathLength => nodes.length;

  /// 두 경로가 같은지 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CircularExchangePath &&
        other.steps == steps &&
        other.description == description &&
        _listEquals(other.nodes, nodes);
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
    return steps.hashCode ^ description.hashCode ^ nodes.hashCode;
  }

  /// 문자열 표현
  @override
  String toString() {
    return 'CircularExchangePath(steps: $steps, description: $description)';
  }
}