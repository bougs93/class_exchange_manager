/// 안내 메시지 관련 모델 클래스들
library;

/// 교체 유형 열거형
enum ExchangeType {
  /// 수업교체 (substitutionDate가 비어있지 않음)
  substitution,
  
  /// 보강 (substitutionDate가 비어있음)
  supplement,
}

/// ExchangeType 확장 메서드
extension ExchangeTypeExtension on ExchangeType {
  /// 교체 유형별 표시 이름
  String get displayName {
    switch (this) {
      case ExchangeType.substitution:
        return '수업교체';
      case ExchangeType.supplement:
        return '보강';
    }
  }
}

/// 메시지 옵션 열거형
enum MessageOption {
  /// 옵션1: 교체 형태로 표시
  option1,
  
  /// 옵션2: 분리된 형태로 표시
  option2,
}

/// MessageOption 확장 메서드
extension MessageOptionExtension on MessageOption {
  /// 옵션별 표시 이름
  String get displayName {
    switch (this) {
      case MessageOption.option1:
        return '옵션1';
      case MessageOption.option2:
        return '옵션2';
    }
  }
}

/// 개별 안내 메시지 모델
class NoticeMessage {
  /// 메시지 식별자 (학급명 또는 교사명)
  final String identifier;
  
  /// 메시지 내용
  final String content;
  
  /// 교체 유형
  final ExchangeType exchangeType;
  
  /// 메시지 옵션
  final MessageOption messageOption;
  
  /// 원본 데이터의 교체 ID (참조용)
  final String exchangeId;

  NoticeMessage({
    required this.identifier,
    required this.content,
    required this.exchangeType,
    required this.messageOption,
    required this.exchangeId,
  });

  /// 복사 생성자
  NoticeMessage copyWith({
    String? identifier,
    String? content,
    ExchangeType? exchangeType,
    MessageOption? messageOption,
    String? exchangeId,
  }) {
    return NoticeMessage(
      identifier: identifier ?? this.identifier,
      content: content ?? this.content,
      exchangeType: exchangeType ?? this.exchangeType,
      messageOption: messageOption ?? this.messageOption,
      exchangeId: exchangeId ?? this.exchangeId,
    );
  }

  @override
  String toString() {
    return 'NoticeMessage(identifier: $identifier, content: $content, exchangeType: ${exchangeType.displayName}, messageOption: ${messageOption.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoticeMessage &&
        other.identifier == identifier &&
        other.content == content &&
        other.exchangeType == exchangeType &&
        other.messageOption == messageOption &&
        other.exchangeId == exchangeId;
  }

  @override
  int get hashCode {
    return Object.hash(identifier, content, exchangeType, messageOption, exchangeId);
  }
}

/// 그룹화된 안내 메시지 모델
class NoticeMessageGroup {
  /// 그룹 식별자 (학급명 또는 교사명)
  final String groupIdentifier;
  
  /// 그룹에 속한 메시지 리스트
  final List<NoticeMessage> messages;
  
  /// 그룹 타입 (학급 또는 교사)
  final GroupType groupType;

  NoticeMessageGroup({
    required this.groupIdentifier,
    required this.messages,
    required this.groupType,
  });

  /// 복사 생성자
  NoticeMessageGroup copyWith({
    String? groupIdentifier,
    List<NoticeMessage>? messages,
    GroupType? groupType,
  }) {
    return NoticeMessageGroup(
      groupIdentifier: groupIdentifier ?? this.groupIdentifier,
      messages: messages ?? this.messages,
      groupType: groupType ?? this.groupType,
    );
  }

  /// 그룹의 모든 메시지를 하나의 문자열로 합치기
  String get combinedContent {
    return messages.map((msg) => msg.content).join('\n\n');
  }

  /// 그룹의 교체 유형별 메시지 개수
  Map<ExchangeType, int> get exchangeTypeCounts {
    final counts = <ExchangeType, int>{};
    for (final message in messages) {
      counts[message.exchangeType] = (counts[message.exchangeType] ?? 0) + 1;
    }
    return counts;
  }

  @override
  String toString() {
    return 'NoticeMessageGroup(groupIdentifier: $groupIdentifier, messages: ${messages.length}개, groupType: ${groupType.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoticeMessageGroup &&
        other.groupIdentifier == groupIdentifier &&
        other.messages.length == messages.length &&
        other.groupType == groupType;
  }

  @override
  int get hashCode {
    return Object.hash(groupIdentifier, messages.length, groupType);
  }
}

/// 그룹 타입 열거형
enum GroupType {
  /// 학급별 그룹
  classGroup,
  
  /// 교사별 그룹
  teacherGroup,
}

/// GroupType 확장 메서드
extension GroupTypeExtension on GroupType {
  /// 그룹 타입별 표시 이름
  String get displayName {
    switch (this) {
      case GroupType.classGroup:
        return '학급';
      case GroupType.teacherGroup:
        return '교사';
    }
  }
}
