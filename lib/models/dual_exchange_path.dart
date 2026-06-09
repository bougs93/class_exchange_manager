import 'exchange_node.dart';
import 'exchange_path.dart';
import 'dual_step.dart';

/// 2중교체 경로를 나타내는 모델 클래스
///
/// 2중교체는 결강한 수업(A)을 다른 교사(B)가 대체하려고 할 때,
/// A 교사가 B 시간에 다른 수업이 있어 직접 교체가 불가능한 경우,
/// A 교사의 해당 시간 수업을 먼저 다른 교사와 교체하여 빈 시간을 만든 후
/// 최종 교체를 완성하는 방식입니다.
///
/// 예시:
/// ```
/// 초기: 이숙희 월1 결강, 손혜옥이 대체 가능하지만 이숙희 월4에 수업 있음
/// 1단계: 박지혜 월5 ↔ 이숙희 월4 교체 (이숙희 월4 비우기)
/// 2단계: 이숙희 월1 ↔ 손혜옥 월4 교체 (결강 해결)
/// ```
class DualExchangePath implements ExchangePath {
  final ExchangeNode nodeA;         // A 위치 (결강 수업)
  final ExchangeNode nodeB;         // B 위치 (대체 가능 수업)
  final ExchangeNode node1;         // 1번 위치 (1단계 교환 대상)
  final ExchangeNode node2;         // 2번 위치 (A 교사의 B 시간 수업)
  final int dualDepth;             // 2중 깊이 (기본값: 2)
  final List<DualStep> steps;      // 교체 단계들
  bool _isSelected = false;         // 선택 상태
  String? _customId;                // 사용자 정의 ID

  DualExchangePath({
    required this.nodeA,
    required this.nodeB,
    required this.node1,
    required this.node2,
    this.dualDepth = 2,
    required this.steps,
    String? customId,
  }) : _customId = customId;

  /// 노드들로부터 자동으로 경로 생성하는 팩토리 메서드
  factory DualExchangePath.build({
    required ExchangeNode nodeA,
    required ExchangeNode nodeB,
    required ExchangeNode node1,
    required ExchangeNode node2,
  }) {
    // 단계별 설명 자동 생성
    List<DualStep> steps = [
      DualStep.exchange(
        stepNumber: 1,
        fromNode: node1,
        toNode: node2,
      ),
      DualStep.exchange(
        stepNumber: 2,
        fromNode: nodeA,
        toNode: nodeB,
      ),
    ];

    return DualExchangePath(
      nodeA: nodeA,
      nodeB: nodeB,
      node1: node1,
      node2: node2,
      dualDepth: 2,
      steps: steps,
    );
  }

  // ExchangePath 인터페이스 구현
  @override
  String get id {
    if (_customId != null) return _customId!;
    
    // 원하는 형태: chain_1단계_문유란_수2교시_↔_정영훈, 목4교시_2단계_문유란_월5교시_↔_정수정_수2교시
    // 1단계: node1 ↔ node2 (교사명_요일교시 형태)
    String step1From = '${node1.teacherName}_${node1.day}${node1.period}교시';
    String step1To = '${node2.teacherName}, ${node2.day}${node2.period}교시';
    
    // 2단계: nodeA ↔ nodeB (교사명_요일교시 형태)
    String step2From = '${nodeA.teacherName}_${nodeA.day}${nodeA.period}교시';
    String step2To = '${nodeB.teacherName}_${nodeB.day}${nodeB.period}교시';
    
    return 'chain_1단계_${step1From}_↔_${step1To}_2단계_${step2From}_↔_$step2To';
  }

  /// 사용자 정의 ID 설정
  void setCustomId(String id) {
    _customId = id;
  }

  @override
  String get displayTitle => '2중교체 $dualDepth단계';

  @override
  List<ExchangeNode> get nodes => [node1, node2, nodeA, nodeB];

  @override
  ExchangePathType get type => ExchangePathType.chain;

  @override
  bool get isSelected => _isSelected;

  @override
  void setSelected(bool selected) {
    _isSelected = selected;
  }

  @override
  String get description {
    // 새로운 형식: [T] 목표노드→대체노드, [1] 1단계교체, [2] 2단계교체
    StringBuffer buffer = StringBuffer();
    
    // 목표 노드와 대체 노드 표시 (학급 정보 포함)
    buffer.write('[T] ${nodeA.day}${nodeA.period}|${nodeA.className}|${nodeA.teacherName}|${nodeA.subjectName}→${nodeB.day}${nodeB.period}|${nodeB.className}|${nodeB.teacherName}|${nodeB.subjectName}, ');
    
    // 각 단계별 교체 정보
    for (int i = 0; i < steps.length; i++) {
      if (i > 0) buffer.write(', ');
      buffer.write(steps[i].description);
    }
    
    return buffer.toString();
  }

  @override
  int get priority => dualDepth; // 깊이가 적을수록 높은 우선순위

  /// 2중교체 경로가 유효한지 확인
  bool get isValid {
    if (steps.length != 2) return false;
    if (steps[0].stepType != 'exchange') return false;
    if (steps[1].stepType != 'exchange') return false;

    // 1단계: node1과 node2는 같은 학급이어야 함
    if (node1.className != node2.className) return false;

    // 2단계: nodeA와 nodeB는 같은 학급이어야 함
    if (nodeA.className != nodeB.className) return false;

    // node2는 nodeA 교사의 수업이어야 함
    if (node2.teacherName != nodeA.teacherName) return false;

    return true;
  }

  /// 상세 설명 생성
  String get detailedDescription {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('🔗 2중교체 $dualDepth단계');
    buffer.writeln('');
    buffer.writeln('📍 목표: ${nodeA.displayText} 결강 해결');
    buffer.writeln('');
    buffer.writeln('1단계: ${node2.teacherName} ${node2.day}${node2.period}교시 비우기');
    buffer.writeln('  ${steps[0].description}');
    buffer.writeln('');
    buffer.writeln('2단계: 최종 교체');
    buffer.writeln('  ${steps[1].description}');
    return buffer.toString();
  }

  /// 두 경로가 같은지 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DualExchangePath &&
        other.nodeA == nodeA &&
        other.nodeB == nodeB &&
        other.node1 == node1 &&
        other.node2 == node2;
  }

  /// 해시코드 생성
  @override
  int get hashCode {
    return nodeA.hashCode ^
        nodeB.hashCode ^
        node1.hashCode ^
        node2.hashCode;
  }

  /// 디버그용 문자열 표현
  @override
  String toString() {
    return 'DualExchangePath(depth: $dualDepth, A: ${nodeA.displayText}, B: ${nodeB.displayText})';
  }
  
  /// JSON 직렬화 (저장용)
  /// 
  /// ExchangePath를 JSON으로 저장할 때 타입 정보와 함께 저장합니다.
  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'chain',
      'id': id,
      'nodeA': nodeA.toJson(),
      'nodeB': nodeB.toJson(),
      'node1': node1.toJson(),
      'node2': node2.toJson(),
      'dualDepth': dualDepth,
      'steps': steps.map((step) => step.toJson()).toList(),
      'description': description,
      'priority': priority,
      'isSelected': _isSelected,
    };
  }
  
  /// JSON 역직렬화 (로드용)
  /// 
  /// JSON에서 DualExchangePath를 복원합니다.
  factory DualExchangePath.fromJson(Map<String, dynamic> json) {
    final nodeA = ExchangeNode.fromJson(json['nodeA'] as Map<String, dynamic>);
    final nodeB = ExchangeNode.fromJson(json['nodeB'] as Map<String, dynamic>);
    final node1 = ExchangeNode.fromJson(json['node1'] as Map<String, dynamic>);
    final node2 = ExchangeNode.fromJson(json['node2'] as Map<String, dynamic>);
    
    final stepsJson = json['steps'] as List<dynamic>;
    final steps = stepsJson
        .map((stepJson) => DualStep.fromJson(stepJson as Map<String, dynamic>))
        .toList();
    
    return DualExchangePath(
      nodeA: nodeA,
      nodeB: nodeB,
      node1: node1,
      node2: node2,
      dualDepth: json['dualDepth'] as int? ?? 2,
      steps: steps,
      customId: json['id'] as String?,
    )..setSelected(json['isSelected'] as bool? ?? false);
  }
}