import 'exchange_node.dart';

/// 연쇄교체의 각 단계를 나타내는 모델 클래스
///
/// 연쇄교체는 2단계로 구성됩니다:
/// - 1단계: 1번 ↔ 2번 교체 (A 교사의 B 시간을 비우기)
/// - 2단계: A ↔ B 교체 (결강 해결)
class ChainStep {
  final int stepNumber;           // 단계 번호 (1, 2)
  final String stepType;          // 단계 타입 ('exchange')
  final ExchangeNode fromNode;    // 교환 시작 노드
  final ExchangeNode toNode;      // 교환 대상 노드
  final String description;       // 단계 설명

  ChainStep({
    required this.stepNumber,
    required this.stepType,
    required this.fromNode,
    required this.toNode,
    required this.description,
  });

  /// 단계 설명을 자동 생성하는 팩토리 메서드
  factory ChainStep.exchange({
    required int stepNumber,
    required ExchangeNode fromNode,
    required ExchangeNode toNode,
  }) {
    // 새로운 형식: [단계번호] 요일교시|학급|교사명|과목명↔요일교시|학급|교사명|과목명
    String description = '[$stepNumber] ${fromNode.day}${fromNode.period}|${fromNode.className}|${fromNode.teacherName}|${fromNode.subjectName}↔${toNode.day}${toNode.period}|${toNode.className}|${toNode.teacherName}|${toNode.subjectName}';

    return ChainStep(
      stepNumber: stepNumber,
      stepType: 'exchange',
      fromNode: fromNode,
      toNode: toNode,
      description: description,
    );
  }

  /// 두 단계가 같은지 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChainStep &&
        other.stepNumber == stepNumber &&
        other.stepType == stepType &&
        other.fromNode == fromNode &&
        other.toNode == toNode;
  }

  /// 해시코드 생성
  @override
  int get hashCode {
    return stepNumber.hashCode ^
        stepType.hashCode ^
        fromNode.hashCode ^
        toNode.hashCode;
  }

  /// 문자열 표현
  @override
  String toString() {
    return 'ChainStep($stepNumber: $description)';
  }
  
  /// JSON 직렬화 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'stepNumber': stepNumber,
      'stepType': stepType,
      'fromNode': fromNode.toJson(),
      'toNode': toNode.toJson(),
      'description': description,
    };
  }
  
  /// JSON 역직렬화 (로드용)
  factory ChainStep.fromJson(Map<String, dynamic> json) {
    return ChainStep(
      stepNumber: json['stepNumber'] as int,
      stepType: json['stepType'] as String,
      fromNode: ExchangeNode.fromJson(json['fromNode'] as Map<String, dynamic>),
      toNode: ExchangeNode.fromJson(json['toNode'] as Map<String, dynamic>),
      description: json['description'] as String,
    );
  }
}