import '../utils/exchange_algorithm.dart';
import '../models/time_slot.dart';
import 'exchange_path.dart';
import 'exchange_node.dart';

/// 1:1 교체 경로를 나타내는 클래스
/// ExchangeOption을 ExchangePath 인터페이스에 맞게 래핑
class OneToOneExchangePath implements ExchangePath {
  final ExchangeNode _sourceNode;      // 선택된 원본 노드
  final ExchangeNode _targetNode;      // 교체 대상 노드
  final ExchangeOption _option;        // 원본 교체 옵션
  bool _isSelected = false;            // 선택 상태
  String? _customId;                   // 사용자 정의 ID
  
  OneToOneExchangePath({
    required ExchangeNode sourceNode,
    required ExchangeNode targetNode,
    required ExchangeOption option,
    String? customId,
  }) : _sourceNode = sourceNode,
       _targetNode = targetNode,
       _option = option,
       _customId = customId;
  
  /// ExchangeOption에서 OneToOneExchangePath 생성하는 팩토리 메서드
  factory OneToOneExchangePath.fromExchangeOption(
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
    
    // 선택된 셀의 노드 생성
    ExchangeNode sourceNode = ExchangeNode(
      teacherName: selectedTeacher,
      day: selectedDay,
      period: selectedPeriod,
      className: selectedClassName,
      subjectName: sourceSubjectName, // 실제 과목명 사용
    );
    
    // 교체 대상 셀의 노드 생성
    String targetDay = _getDayString(option.timeSlot.dayOfWeek ?? 0);
    ExchangeNode targetNode = ExchangeNode(
      teacherName: option.teacherName,
      day: targetDay,
      period: option.timeSlot.period ?? 0,
      className: option.timeSlot.className ?? '',
      subjectName: option.timeSlot.subject ?? '과목명 없음',
    );
    
    return OneToOneExchangePath(
      sourceNode: sourceNode,
      targetNode: targetNode,
      option: option,
    );
  }
  
  @override
  String get id {
    // 사용자 정의 ID가 있으면 사용, 없으면 해시코드 기반
    return _customId ?? 'onetoone_${hashCode.abs()}';
  }
  
  /// 사용자 정의 ID 설정
  void setCustomId(String id) {
    _customId = id;
  }
  
  @override
  String get displayTitle => '1:1 교체';
  
  @override
  List<ExchangeNode> get nodes => [_sourceNode, _targetNode];
  
  @override
  ExchangePathType get type => ExchangePathType.oneToOne;
  
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
        return '동일 학급 교체 가능';
      case ExchangeType.notExchangeable:
        return '교체 불가능';
    }
  }
  
  @override
  int get priority => _option.priority;
  
  /// 원본 교체 옵션 접근자
  ExchangeOption get option => _option;
  
  /// 교체 가능 여부
  bool get isExchangeable => _option.isExchangeable;
  
  /// 교체 사유
  String get reason => _option.reason;
  
  /// 원본 노드 접근자
  ExchangeNode get sourceNode => _sourceNode;
  
  /// 대상 노드 접근자
  ExchangeNode get targetNode => _targetNode;
  
  /// 요일 번호를 문자열로 변환하는 헬퍼 메서드
  static String _getDayString(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      case 6: return '토';
      case 7: return '일';
      default: return '알 수 없음';
    }
  }
  
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
    return other is OneToOneExchangePath &&
        other._sourceNode == _sourceNode &&
        other._targetNode == _targetNode;
  }
  
  /// 해시코드 생성
  @override
  int get hashCode => _sourceNode.hashCode ^ _targetNode.hashCode;
  
  /// 디버그용 문자열 표현
  @override
  String toString() {
    return 'OneToOneExchangePath(${_sourceNode.displayText} ↔ ${_targetNode.displayText})';
  }
}
