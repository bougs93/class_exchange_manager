import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/exchange_node.dart';
import '../models/chain_exchange_path.dart';
import '../utils/timetable_data_source.dart';
import '../utils/logger.dart';
import '../utils/day_utils.dart';
import '../utils/non_exchangeable_manager.dart';
import 'base_exchange_service.dart';

/// 연쇄교체 서비스 클래스
///
/// 연쇄교체는 결강한 수업(A)을 다른 교사(B)가 대체하려고 할 때,
/// A 교사가 B 시간에 다른 수업이 있어 직접 교체가 불가능한 경우,
/// A 교사의 해당 시간 수업을 먼저 다른 교사와 교체하여 빈 시간을 만든 후
/// 최종 교체를 완성하는 방식입니다.
class ChainExchangeService extends BaseExchangeService {
  // 싱글톤 인스턴스
  static final ChainExchangeService _instance = ChainExchangeService._internal();
  
  // 싱글톤 생성자
  factory ChainExchangeService() => _instance;
  
  // 내부 생성자
  ChainExchangeService._internal();
  
  // ==================== 상수 정의 ====================

  /// 연쇄교체 경로 디버그 콘솔 출력 여부
  static const bool enablePathDebugLogging = true;

  // ==================== 인스턴스 변수 ====================

  // A 위치 (결강 수업) 학급 정보
  String? _selectedClass;        // 선택된 학급 (연쇄 교체 전용)

  // 교체 불가 관리자
  final NonExchangeableManager _nonExchangeableManager = NonExchangeableManager();

  // Getter: 선택된 학급 정보만 제공 (연쇄 교체 전용)
  String? get selectedClass => _selectedClass;

  /// 셀 선택 상태 설정 (연쇄교체 전용 오버라이드)
  /// BaseExchangeService의 selectCell을 오버라이드하여 _selectedClass도 함께 설정
  @override
  void selectCell(String teacherName, String day, int period) {
    super.selectCell(teacherName, day, period);
    // _selectedClass는 findChainExchangePaths에서 자동으로 설정됨
    _selectedClass = null; // 초기화하여 다음에 다시 찾도록 함
  }

  /// 연쇄교체 모드에서 셀 탭 처리
  ///
  /// 매개변수:
  /// - `details`: 셀 탭 상세 정보
  /// - `dataSource`: 데이터 소스
  ///
  /// 반환값:
  /// - `ChainExchangeResult`: 처리 결과
  ChainExchangeResult startChainExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
    List<TimeSlot> timeSlots,
  ) {
    // 교사명 열 클릭은 교사 이름 선택 기능으로 처리
    if (details.column.columnName == 'teacher') {
      return ChainExchangeResult.noAction(); // 교사 이름 선택은 별도 처리
    }

    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      return ChainExchangeResult.noAction();
    }

    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;

    // 교체할 셀의 교사명 찾기 (베이스 클래스 메서드 사용)
    String teacherName = getTeacherNameFromCell(details, dataSource);

    // 해당 시간의 학급 정보 찾기 (베이스 클래스 메서드 사용)
    String className = getClassNameFromTimeSlot(teacherName, day, period, timeSlots);

    // 동일한 셀을 다시 클릭했는지 확인 (베이스 클래스 메서드 사용)
    if (isSameCell(teacherName, day, period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      clearAllSelections();
      return ChainExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      selectCell(teacherName, day, period);
      _selectedClass = className;

      AppLogger.exchangeInfo('연쇄교체: A 위치 선택 - $teacherName $day $period교시 $className');

      return ChainExchangeResult.selected(teacherName, day, period);
    }
  }


  /// 연쇄 교체 가능한 경로들 찾기
  ///
  /// 매개변수:
  /// - `timeSlots`: 전체 시간표 슬롯
  /// - `teachers`: 교사 목록
  ///
  /// 반환값:
  /// - `List<ChainExchangePath>`: 가능한 연쇄교체 경로 목록
  List<ChainExchangePath> findChainExchangePaths(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (!hasSelectedCell()) {
      AppLogger.exchangeInfo('연쇄교체: A 위치가 선택되지 않았습니다.');
      return [];
    }

    // 성능 최적화: 빈 셀과 교체불가능한 셀을 사전 필터링
    // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
    List<TimeSlot> validTimeSlots = timeSlots.where((slot) => 
      slot.canExchange
    ).toList();
    
    AppLogger.exchangeDebug('연쇄교체 최적화: 전체 ${timeSlots.length}개 → 유효한 ${validTimeSlots.length}개 TimeSlot');
    
    // 교체 불가 관리자에 TimeSlot 설정
    _nonExchangeableManager.setTimeSlots(timeSlots);

    // _selectedClass가 null이면 validTimeSlots에서 찾기 (백그라운드 실행 시)
    _selectedClass ??= getClassNameFromTimeSlot(
      selectedTeacher!,
      selectedDay!,
      selectedPeriod!,
      validTimeSlots,
    );

    if (_selectedClass == null || _selectedClass!.isEmpty) {
      AppLogger.exchangeInfo('연쇄교체: A 위치의 학급 정보를 찾을 수 없습니다.');
      return [];
    }

    if (enablePathDebugLogging) {
      AppLogger.exchangeDebug('연쇄교체 경로 탐색 시작');
      AppLogger.exchangeDebug('A 위치: $selectedTeacher $selectedDay $selectedPeriod교시 $_selectedClass');
    }

    List<ChainExchangePath> paths = [];

    // A 위치 노드 생성 (과목명 포함)
    String nodeASubject = getSubjectFromTimeSlot(selectedTeacher!, selectedDay!, selectedPeriod!, validTimeSlots);
    ExchangeNode nodeA = ExchangeNode(
      teacherName: selectedTeacher!,
      day: selectedDay!,
      period: selectedPeriod!,
      className: _selectedClass!,
      subjectName: nodeASubject,
    );

    // B 위치 후보들 찾기 (A와 같은 학급, B 교사가 A 시간 비어있음)
    List<ExchangeNode> nodeBCandidates = _findSameClassSlots(nodeA, validTimeSlots);

    if (enablePathDebugLogging) {
      AppLogger.exchangeDebug('B 위치 후보: ${nodeBCandidates.length}개');
    }

    int pathCount = 0;

    for (ExchangeNode nodeB in nodeBCandidates) {
      // A 교사가 B 시간에 다른 수업(2번)이 있는지 확인
      ExchangeNode? node2 = _findBlockingSlot(selectedTeacher!, nodeB, validTimeSlots);

      if (node2 == null) {
        // A와 B가 직접 교체 가능하면 연쇄교체 불필요
        if (enablePathDebugLogging) {
          AppLogger.exchangeDebug('B=${nodeB.displayText}: 직접 교체 가능 (연쇄교체 불필요)');
        }
        continue;
      }

      if (enablePathDebugLogging) {
        AppLogger.exchangeDebug('B=${nodeB.displayText}, node2=${node2.displayText} 발견');
      }

      // 2번 수업과 1:1 교체 가능한 같은 학급 수업(1번) 찾기
      List<ExchangeNode> node1Candidates = _findSameClassSlots(node2, validTimeSlots);

      for (ExchangeNode node1 in node1Candidates) {
        // 1단계: node1 ↔ node2 교체 가능한지 확인
        if (!_canDirectExchange(node1, node2, validTimeSlots)) {
          continue;
        }

        // 2단계: A ↔ B 교체 가능한지 확인 (node2가 비워진 상태 가정)
        if (!_canExchangeAfterClearing(nodeA, nodeB, node2, validTimeSlots)) {
          continue;
        }

        // 유효한 연쇄교체 경로 발견
        ChainExchangePath path = ChainExchangePath.build(
          nodeA: nodeA,
          nodeB: nodeB,
          node1: node1,
          node2: node2,
        );

        paths.add(path);
        pathCount++;

        if (enablePathDebugLogging) {
          AppLogger.exchangeDebug('경로 $pathCount: ${path.description}');
        }
      }
    }

    AppLogger.exchangeInfo('연쇄교체: 총 ${paths.length}개 경로 발견');

    return paths;
  }

  /// A와 같은 학급을 가르치는 교사들의 시간 찾기
  /// (해당 교사가 A 시간에 비어있어야 함)
  List<ExchangeNode> _findSameClassSlots(ExchangeNode nodeA, List<TimeSlot> timeSlots) {
    List<ExchangeNode> nodes = [];
    Set<String> addedNodeIds = {};
    int nodeADayNumber = DayUtils.getDayNumber(nodeA.day);

    // 같은 학급을 가르치는 모든 시간표 슬롯 찾기
    // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
    List<TimeSlot> sameClassSlots = timeSlots.where((slot) =>
      slot.className == nodeA.className &&
      slot.canExchange && // isNotEmpty 포함
      slot.teacher != nodeA.teacherName
    ).toList();

    for (TimeSlot slot in sameClassSlots) {
      // Early return: 유효하지 않은 슬롯 건너뛰기
      if (!_isValidSameClassSlot(slot, nodeA, nodeADayNumber, timeSlots)) {
        continue;
      }

      ExchangeNode node = _createNodeFromSlot(slot);
      if (!addedNodeIds.contains(node.nodeId)) {
        nodes.add(node);
        addedNodeIds.add(node.nodeId);
      }
    }

    return nodes;
  }

  /// 같은 학급 슬롯이 유효한지 검증
  /// 
  /// 공통 메서드 사용으로 중복 로직 제거
  bool _isValidSameClassSlot(
    TimeSlot slot,
    ExchangeNode nodeA,
    int nodeADayNumber,
    List<TimeSlot> timeSlots,
  ) {
    String slotTeacher = slot.teacher ?? '';

    // BaseExchangeService의 공통 메서드 사용 (중복 로직 제거)
    // 해당 교사가 A 시간에 비어있는지 확인
    return isTeacherEmptyAtTime(
      slotTeacher,
      nodeA.day,
      nodeA.period,
      timeSlots,
    );
  }

  /// TimeSlot에서 ExchangeNode 생성
  ExchangeNode _createNodeFromSlot(TimeSlot slot) {
    return ExchangeNode(
      teacherName: slot.teacher ?? '',
      day: DayUtils.getDayName(slot.dayOfWeek ?? 0),
      period: slot.period ?? 0,
      className: slot.className ?? '',
      subjectName: slot.subject ?? '과목명 없음',
    );
  }

  /// A 교사의 B 시간 수업 찾기 (node2)
  ///
  /// A 교사가 B 시간에 수업이 있으면 그 수업을 반환
  /// 없으면 null 반환 (직접 교체 가능)
  ExchangeNode? _findBlockingSlot(String teacherA, ExchangeNode nodeB, List<TimeSlot> timeSlots) {
    // BaseExchangeService의 공통 메서드 사용 (중복 로직 제거)
    TimeSlot? blockingSlot = findTimeSlot(
      teacherA,
      nodeB.day,
      nodeB.period,
      timeSlots,
    );
    
    // 교체 가능한 셀만 고려
    // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
    if (blockingSlot != null && !blockingSlot.canExchange) {
      blockingSlot = null;
    }

    if (blockingSlot == null) {
      return null;
    }

    return ExchangeNode(
      teacherName: blockingSlot.teacher ?? '',
      day: DayUtils.getDayName(blockingSlot.dayOfWeek ?? 0),
      period: blockingSlot.period ?? 0,
      className: blockingSlot.className ?? '',
      subjectName: blockingSlot.subject ?? '과목명 없음',
    );
  }

  /// 1단계 검증: node1과 node2가 직접 1:1 교체 가능한지
  bool _canDirectExchange(
    ExchangeNode node1,
    ExchangeNode node2,
    List<TimeSlot> timeSlots,
  ) {
    int node1DayNumber = DayUtils.getDayNumber(node1.day);
    int node2DayNumber = DayUtils.getDayNumber(node2.day);

    // node1 교사가 node2 시간에 비어있는가?
    bool teacher1EmptyAtNode2Time = !timeSlots.any((slot) =>
      slot.teacher == node1.teacherName &&
      slot.dayOfWeek == node2DayNumber &&
      slot.period == node2.period &&
      slot.isNotEmpty
    );

    // node2 교사가 node1 시간에 비어있는가?
    bool teacher2EmptyAtNode1Time = !timeSlots.any((slot) =>
      slot.teacher == node2.teacherName &&
      slot.dayOfWeek == node1DayNumber &&
      slot.period == node1.period &&
      slot.isNotEmpty
    );

    // 같은 학급인가?
    bool sameClass = node1.className == node2.className;

    // 교체 불가 충돌 검증 추가
    bool teacher1CanMoveToNode2 = !_isNonExchangeableClash(node1.teacherName, node2.day, node2.period);
    bool teacher2CanMoveToNode1 = !_isNonExchangeableClash(node2.teacherName, node1.day, node1.period);

    return teacher1EmptyAtNode2Time && 
           teacher2EmptyAtNode1Time && 
           sameClass && 
           teacher1CanMoveToNode2 && 
           teacher2CanMoveToNode1;
  }

  /// 2단계 검증: A와 B가 1:1 교체 가능한지 (node2 위치가 비워진 후)
  bool _canExchangeAfterClearing(
    ExchangeNode nodeA,
    ExchangeNode nodeB,
    ExchangeNode node2,
    List<TimeSlot> timeSlots,
  ) {
    int nodeADayNumber = DayUtils.getDayNumber(nodeA.day);
    int nodeBDayNumber = DayUtils.getDayNumber(nodeB.day);
    int node2DayNumber = DayUtils.getDayNumber(node2.day);

    // A 교사(nodeA.teacher)가 B 시간(nodeB.time)에 비어있는가?
    // node2가 1단계에서 비워질 예정이으므로 node2 위치는 무시
    bool teacherAEmptyAtBTime = !timeSlots.any((slot) =>
      slot.teacher == nodeA.teacherName &&
      slot.dayOfWeek == nodeBDayNumber &&
      slot.period == nodeB.period &&
      slot.isNotEmpty &&
      !(slot.dayOfWeek == node2DayNumber && slot.period == node2.period) // node2 제외
    );

    // B 교사(nodeB.teacher)가 A 시간(nodeA.time)에 비어있는가?
    bool teacherBEmptyAtATime = !timeSlots.any((slot) =>
      slot.teacher == nodeB.teacherName &&
      slot.dayOfWeek == nodeADayNumber &&
      slot.period == nodeA.period &&
      slot.isNotEmpty
    );

    // 같은 학급인가?
    bool sameClass = nodeA.className == nodeB.className;

    // 교체 불가 충돌 검증 추가
    bool teacherACanMoveToB = !_isNonExchangeableClash(nodeA.teacherName, nodeB.day, nodeB.period);
    bool teacherBCanMoveToA = !_isNonExchangeableClash(nodeB.teacherName, nodeA.day, nodeA.period);

    return teacherAEmptyAtBTime && 
           teacherBEmptyAtATime && 
           sameClass && 
           teacherACanMoveToB && 
           teacherBCanMoveToA;
  }

  /// 교체 불가 충돌 검증
  /// 교사가 특정 시간대로 이동할 때 교체 불가 셀이 있는지 확인
  bool _isNonExchangeableClash(String teacherName, String day, int period) {
    return _nonExchangeableManager.isNonExchangeableTimeSlot(teacherName, day, period);
  }

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    clearCellSelection();
    _selectedClass = null;

    if (enablePathDebugLogging) {
      AppLogger.exchangeDebug('연쇄교체: 모든 선택 초기화');
    }
  }


  /// 연쇄교체 가능한 교사 정보 가져오기 (UI 표시용)
  List<Map<String, dynamic>> getChainExchangeableTeachers(
    List<ChainExchangePath> paths,
  ) {
    List<Map<String, dynamic>> result = [];

    for (ChainExchangePath path in paths) {
      result.add({
        'path': path,
        'description': path.description,
        'detailedDescription': path.detailedDescription,
      });
    }

    return result;
  }
}

/// 연쇄교체 처리 결과를 나타내는 클래스
class ChainExchangeResult {
  final bool isSelected;      // 교체 대상이 선택됨
  final bool isDeselected;    // 교체 대상이 해제됨
  final bool isNoAction;      // 아무 동작하지 않음
  final String? teacherName;  // 교사명
  final String? day;          // 요일
  final int? period;          // 교시

  ChainExchangeResult._({
    required this.isSelected,
    required this.isDeselected,
    required this.isNoAction,
    this.teacherName,
    this.day,
    this.period,
  });

  /// 교체 대상이 선택됨
  factory ChainExchangeResult.selected(String teacherName, String day, int period) {
    return ChainExchangeResult._(
      isSelected: true,
      isDeselected: false,
      isNoAction: false,
      teacherName: teacherName,
      day: day,
      period: period,
    );
  }

  /// 교체 대상이 해제됨
  factory ChainExchangeResult.deselected() {
    return ChainExchangeResult._(
      isSelected: false,
      isDeselected: true,
      isNoAction: false,
    );
  }

  /// 아무 동작하지 않음
  factory ChainExchangeResult.noAction() {
    return ChainExchangeResult._(
      isSelected: false,
      isDeselected: false,
      isNoAction: true,
    );
  }
}