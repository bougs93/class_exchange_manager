import 'exchange_path.dart';

/// 교체 히스토리 항목을 나타내는 클래스
/// 교체 실행의 모든 정보를 담는 데이터 모델
class ExchangeHistoryItem {
  /// 고유 식별자
  final String id;
  
  /// 실행 시간
  final DateTime timestamp;
  
  /// 원본 교체 경로
  final ExchangePath originalPath;
  
  /// 사용자 친화적 설명
  final String description;
  
  /// 교체 타입 (1:1, 순환, 연쇄)
  final ExchangePathType type;
  
  /// 추가 메타데이터
  final Map<String, dynamic> metadata;
  
  /// 사용자 메모
  final String? notes;
  
  /// 태그 목록
  final List<String> tags;
  
  /// 되돌리기 여부
  bool isReverted;

  /// 생성자
  ExchangeHistoryItem({
    required this.id,
    required this.timestamp,
    required this.originalPath,
    required this.description,
    required this.type,
    required this.metadata,
    this.notes,
    required this.tags,
    this.isReverted = false,
  });

  /// ExchangePath로부터 ExchangeHistoryItem 생성하는 팩토리 생성자
  factory ExchangeHistoryItem.fromExchangePath(
    ExchangePath path, {
    String? customId,
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
    int? stepCount, // 순환교체 단계 수 (선택적)
  }) {
    final pathType = _getPathType(path);
    final generatedId = customId ?? _generateId(pathType, stepCount);
    
    return ExchangeHistoryItem(
      id: generatedId,
      timestamp: DateTime.now(),
      originalPath: path,
      description: customDescription ?? path.displayTitle,
      type: pathType,
      metadata: {
        'executionTime': DateTime.now().toIso8601String(),
        'userAction': 'manual',
        'pathId': path.id,
        if (stepCount != null) 'stepCount': stepCount,
        ...?additionalMetadata,
      },
      notes: notes,
      tags: tags ?? [],
      isReverted: false,
    );
  }

  /// 고유 ID 생성 (교체 유형 및 단계 정보 포함)
  static String _generateId(ExchangePathType pathType, [int? stepCount]) {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}_${now.millisecond.toString().padLeft(3, '0')}';
    
    switch (pathType) {
      case ExchangePathType.oneToOne:
        return 'one_to_one_exchange_$timestamp';
      case ExchangePathType.circular:
        if (stepCount != null) {
          return 'circular_exchange_${stepCount}_$timestamp';
        }
        return 'circular_exchange_$timestamp';
      case ExchangePathType.chain:
        return 'chain_exchange_$timestamp';
      case ExchangePathType.supplement:
        return 'supplement_exchange_$timestamp';
    }
  }

  /// ExchangePath의 타입을 ExchangePathType으로 변환
  static ExchangePathType _getPathType(ExchangePath path) {
    if (path.toString().contains('OneToOneExchangePath')) {
      return ExchangePathType.oneToOne;
    } else if (path.toString().contains('CircularExchangePath')) {
      return ExchangePathType.circular;
    } else if (path.toString().contains('ChainExchangePath')) {
      return ExchangePathType.chain;
    } else if (path.toString().contains('SupplementExchangePath')) {
      return ExchangePathType.supplement;
    }
    return ExchangePathType.oneToOne; // 기본값
  }

  /// 되돌리기 상태 변경
  ExchangeHistoryItem copyWithReverted(bool reverted) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: notes,
      tags: tags,
      isReverted: reverted,
    );
  }

  /// 메모 업데이트
  ExchangeHistoryItem copyWithNotes(String? newNotes) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: newNotes,
      tags: tags,
      isReverted: isReverted,
    );
  }

  /// 태그 업데이트
  ExchangeHistoryItem copyWithTags(List<String> newTags) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: metadata,
      notes: notes,
      tags: newTags,
      isReverted: isReverted,
    );
  }

  /// 메타데이터 업데이트
  ExchangeHistoryItem copyWithMetadata(Map<String, dynamic> newMetadata) {
    return ExchangeHistoryItem(
      id: id,
      timestamp: timestamp,
      originalPath: originalPath,
      description: description,
      type: type,
      metadata: {...metadata, ...newMetadata},
      notes: notes,
      tags: tags,
      isReverted: isReverted,
    );
  }

  /// 실행 시간을 포맷된 문자열로 반환
  String get formattedTimestamp {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
           '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// 교체 타입의 한국어 이름 반환
  String get typeDisplayName => type.displayName;

  /// 교체 타입의 아이콘 반환
  String get typeIcon => type.icon;

  /// 참여 교사 목록 반환 (메타데이터에서 추출)
  List<String> get involvedTeachers {
    return metadata['involvedTeachers']?.cast<String>() ?? [];
  }

  /// 참여 학급 목록 반환 (메타데이터에서 추출)
  List<String> get involvedClasses {
    return metadata['involvedClasses']?.cast<String>() ?? [];
  }

  /// 참여 과목 목록 반환 (메타데이터에서 추출)
  List<String> get involvedSubjects {
    return metadata['involvedSubjects']?.cast<String>() ?? [];
  }

  /// 교체 효율성 점수 반환 (메타데이터에서 추출)
  double get efficiencyScore {
    return metadata['efficiencyScore']?.toDouble() ?? 0.0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeHistoryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ExchangeHistoryItem(id: $id, timestamp: $timestamp, type: $typeDisplayName, description: $description, isReverted: $isReverted)';
  }
}
