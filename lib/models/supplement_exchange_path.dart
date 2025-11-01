import '../utils/exchange_algorithm.dart';
import '../models/time_slot.dart';
import '../utils/day_utils.dart';
import 'exchange_path.dart';
import 'exchange_node.dart';

/// 보강 교체 경로를 나타내는 클래스
/// OneToOneExchangePath와 동일한 구조로 보강 교체를 처리
class SupplementExchangePath implements ExchangePath {
  final ExchangeNode _sourceNode;      // 선택된 원본 노드 (보강할 셀)
  final ExchangeNode _targetNode;      // 보강 대상 노드 (보강할 교사)
  final ExchangeOption _option;        // 원본 교체 옵션
  bool _isSelected = false;            // 선택 상태
  String? _customId;                   // 사용자 정의 ID
  
  SupplementExchangePath({
    required ExchangeNode sourceNode,
    required ExchangeNode targetNode,
    required ExchangeOption option,
    String? customId,
  }) : _sourceNode = sourceNode,
       _targetNode = targetNode,
       _option = option,
       _customId = customId;
  
  /// 간단한 보강교체 경로 생성 (새로운 패턴용)
  factory SupplementExchangePath.simple({
    required String id,
    required String sourceTeacher,
    required String sourceDay,
    required int sourcePeriod,
    required String targetTeacher,
    required String targetDay,
    required int targetPeriod,
    required String className,
    required String subject,
  }) {
    final sourceNode = ExchangeNode(
      teacherName: sourceTeacher,
      day: sourceDay,
      period: sourcePeriod,
      className: className,
      subjectName: subject,
    );
    
    final targetNode = ExchangeNode(
      teacherName: targetTeacher,
      day: targetDay,
      period: targetPeriod,
      className: '', // 빈 셀
      subjectName: '', // 빈 셀
    );
    
    final option = ExchangeOption(
      teacherName: targetTeacher,
      timeSlot: TimeSlot(
        teacher: targetTeacher,
        dayOfWeek: _getDayNumber(targetDay),
        period: targetPeriod,
        className: '',
        subject: '',
      ),
      type: ExchangeType.sameClass,
      priority: 1,
      reason: '보강교체',
    );
    
    return SupplementExchangePath(
      sourceNode: sourceNode,
      targetNode: targetNode,
      option: option,
      customId: id,
    );
  }

  /// ExchangeOption에서 SupplementExchangePath 생성하는 팩토리 메서드
  factory SupplementExchangePath.fromExchangeOption(
    String selectedTeacher,
    String selectedDay,
    int selectedPeriod,
    String selectedClassName,
    ExchangeOption option,
    List<TimeSlot> timeSlots, // 시간표 데이터 추가
  ) {
    // 선택된 셀의 실제 과목명 가져오기
    String sourceSubjectName = _getSubjectFromTimeSlot(
      selectedTeacher, 
      selectedDay, 
      selectedPeriod, 
      timeSlots
    );
    
    // 선택된 셀의 노드 생성 (보강할 셀)
    ExchangeNode sourceNode = ExchangeNode(
      teacherName: selectedTeacher,
      day: selectedDay,
      period: selectedPeriod,
      className: selectedClassName,
      subjectName: sourceSubjectName, // 실제 과목명 사용
    );
    
    // 보강 대상 셀의 노드 생성 (보강할 교사)
    String targetDay = DayUtils.getDayName(option.timeSlot.dayOfWeek ?? 0);
    ExchangeNode targetNode = ExchangeNode(
      teacherName: option.teacherName,
      day: targetDay,
      period: option.timeSlot.period ?? 0,
      className: option.timeSlot.className ?? '',
      subjectName: option.timeSlot.subject ?? '',
    );
    
    return SupplementExchangePath(
      sourceNode: sourceNode,
      targetNode: targetNode,
      option: option,
    );
  }
  
  @override
  String get id {
    // 사용자 정의 ID가 있으면 사용, 없으면 해시코드 기반
    return _customId ?? 'supplement_${hashCode.abs()}';
  }
  
  /// 사용자 정의 ID 설정
  void setCustomId(String id) {
    _customId = id;
  }
  
  @override
  String get displayTitle => '보강 교체';
  
  @override
  List<ExchangeNode> get nodes => [_sourceNode, _targetNode];
  
  @override
  ExchangePathType get type => ExchangePathType.supplement;
  
  @override
  bool get isSelected => _isSelected;
  
  @override
  void setSelected(bool selected) {
    _isSelected = selected;
  }
  
  @override
  String get description {
    switch (_option.type) {
      case ExchangeType.sameClass:
        return '동일 학급 보강 가능';
      case ExchangeType.notExchangeable:
        return '보강 불가능';
    }
  }
  
  @override
  int get priority => _option.priority;
  
  /// 원본 교체 옵션 접근자
  ExchangeOption get option => _option;
  
  /// 보강 가능 여부
  bool get isSupplementable => _option.isExchangeable;
  
  /// 보강 사유
  String get reason => _option.reason;
  
  /// 원본 노드 접근자 (보강할 셀)
  ExchangeNode get sourceNode => _sourceNode;
  
  /// 대상 노드 접근자 (보강할 교사)
  ExchangeNode get targetNode => _targetNode;

  /// 간단한 접근자들 (새로운 패턴용)
  String get sourceTeacher => _sourceNode.teacherName;
  String get sourceDay => _sourceNode.day;
  int get sourcePeriod => _sourceNode.period;
  String get targetTeacher => _targetNode.teacherName;
  String get targetDay => _targetNode.day;
  int get targetPeriod => _targetNode.period;
  String get className => _sourceNode.className;
  String get subject => _sourceNode.subjectName;

  /// 시간표 데이터에서 특정 시간의 과목명을 가져오는 헬퍼 메서드
  static String _getSubjectFromTimeSlot(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots,
  ) {
    // 요일 문자열을 숫자로 변환
    int dayNumber = _getDayNumber(day);
    
    // 해당 교사, 요일, 교시의 TimeSlot 찾기
    TimeSlot? slot = timeSlots.firstWhere(
      (slot) => slot.teacher == teacherName &&
                slot.dayOfWeek == dayNumber &&
                slot.period == period &&
                slot.isNotEmpty,
      orElse: () => TimeSlot(), // 빈 TimeSlot 반환
    );
    
    return slot.subject ?? '과목명 없음';
  }
  
  /// 요일 문자열을 숫자로 변환하는 헬퍼 메서드
  static int _getDayNumber(String day) {
    switch (day) {
      case '월': return 1;
      case '화': return 2;
      case '수': return 3;
      case '목': return 4;
      case '금': return 5;
      case '토': return 6;
      case '일': return 7;
      default: return 0;
    }
  }
  
  /// 두 경로가 같은지 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplementExchangePath &&
        other._sourceNode == _sourceNode &&
        other._targetNode == _targetNode;
  }
  
  /// 해시코드 생성
  @override
  int get hashCode => _sourceNode.hashCode ^ _targetNode.hashCode;
  
  /// 디버그용 문자열 표현
  @override
  String toString() {
    return 'SupplementExchangePath(${_sourceNode.displayText} → ${_targetNode.displayText})';
  }
  
  /// JSON 직렬화 (저장용)
  /// 
  /// ExchangePath를 JSON으로 저장할 때 타입 정보와 함께 저장합니다.
  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'supplement',
      'id': id,
      'sourceNode': _sourceNode.toJson(),
      'targetNode': _targetNode.toJson(),
      'description': description,
      'priority': priority,
      'isSelected': _isSelected,
    };
  }
  
  /// JSON 역직렬화 (로드용)
  /// 
  /// JSON에서 SupplementExchangePath를 복원합니다.
  /// ExchangeOption은 재생성할 수 없으므로, 기본 옵션을 생성합니다.
  factory SupplementExchangePath.fromJson(Map<String, dynamic> json) {
    final sourceNode = ExchangeNode.fromJson(json['sourceNode'] as Map<String, dynamic>);
    final targetNode = ExchangeNode.fromJson(json['targetNode'] as Map<String, dynamic>);
    
    // ExchangeOption 재생성 (기본값 사용)
    final option = ExchangeOption(
      teacherName: targetNode.teacherName,
      timeSlot: TimeSlot(
        teacher: targetNode.teacherName,
        dayOfWeek: DayUtils.getDayNumber(targetNode.day),
        period: targetNode.period,
        className: targetNode.className,
        subject: targetNode.subjectName,
      ),
      type: ExchangeType.sameClass,
      priority: json['priority'] as int? ?? 1,
      reason: json['description'] as String? ?? '보강교체',
    );
    
    return SupplementExchangePath(
      sourceNode: sourceNode,
      targetNode: targetNode,
      option: option,
      customId: json['id'] as String?,
    )..setSelected(json['isSelected'] as bool? ?? false);
  }
}
