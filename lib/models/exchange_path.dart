import 'exchange_node.dart';

/// 교체 경로의 공통 인터페이스
/// 1:1교체와 순환교체 모두에서 사용할 수 있는 공통 구조 정의
abstract class ExchangePath {
  /// 경로의 고유 식별자
  String get id;
  
  /// 경로의 표시용 제목
  String get displayTitle;
  
  /// 경로에 포함된 노드들
  List<ExchangeNode> get nodes;
  
  /// 교체 경로의 타입
  ExchangePathType get type;
  
  /// 경로가 선택된 상태인지 여부
  bool get isSelected;
  
  /// 경로 선택 상태 설정
  void setSelected(bool selected);
  
  /// 경로의 설명 텍스트
  String get description;
  
  /// 경로의 우선순위 (낮을수록 높은 우선순위)
  int get priority;
}

/// 교체 경로의 타입
enum ExchangePathType {
  oneToOne,    // 1:1교체 (2개 노드)
  circular,    // 순환교체 (3+ 노드)
}

/// 교체 경로 타입별 확장 메서드
extension ExchangePathTypeExtension on ExchangePathType {
  /// 타입별 표시 이름
  String get displayName {
    switch (this) {
      case ExchangePathType.oneToOne:
        return '1:1 교체';
      case ExchangePathType.circular:
        return '순환교체';
    }
  }
  
  /// 타입별 아이콘
  String get icon {
    switch (this) {
      case ExchangePathType.oneToOne:
        return '🔄';
      case ExchangePathType.circular:
        return '🔄';
    }
  }
}
