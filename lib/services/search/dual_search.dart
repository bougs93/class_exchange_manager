import '../../models/time_slot.dart';
import '../../models/teacher.dart';
import '../../models/exchange_node.dart';
import '../../models/dual_exchange_path.dart';
import '../../utils/day_utils.dart';
import '../../utils/logger.dart';
import '../../utils/non_exchangeable_manager.dart';
import 'exchange_search_context.dart';

mixin DualSearch on ExchangeSearchContext {
  static const bool enablePathDebugLogging = false;
  // A 위치 (결강 수업) 학급 정보
  String? _selectedClass; // 선택된 학급 (2중 교체 전용)

  // 교체 불가 관리자
  final NonExchangeableManager _nonExchangeableManager =
      NonExchangeableManager();

  // Getter: 선택된 학급 정보만 제공 (2중 교체 전용)
  String? get selectedClass => _selectedClass;

  /// 셀 선택 상태 설정 (2중교체 전용 오버라이드)
  /// BaseExchangeService의 selectCell을 오버라이드하여 _selectedClass도 함께 설정
  @override
  void selectCell(
    String teacherName,
    String day,
    int period, {
    String? className,
  }) {
    super.selectCell(teacherName, day, period);
    // _selectedClass는 findDualExchangePaths에서 자동으로 설정됨
    _selectedClass = className;
  }

  List<DualExchangePath> findDualExchangePaths(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (!hasSelectedCell()) {
      AppLogger.exchangeInfo('2중교체: A 위치가 선택되지 않았습니다.');
      return [];
    }

    // 성능 최적화: 빈 셀과 교체불가능한 셀을 사전 필터링
    // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
    List<TimeSlot> validTimeSlots =
        timeSlots.where((slot) => slot.canExchange).toList();
    prepareSearch(validTimeSlots);

    AppLogger.exchangeDebug(
      '2중교체 최적화: 전체 ${timeSlots.length}개 → 유효한 ${validTimeSlots.length}개 TimeSlot',
    );

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
      AppLogger.exchangeInfo('2중교체: A 위치의 학급 정보를 찾을 수 없습니다.');
      return [];
    }

    if (enablePathDebugLogging) {
      AppLogger.exchangeDebug('2중교체 경로 탐색 시작');
      AppLogger.exchangeDebug(
        'A 위치: $selectedTeacher $selectedDay $selectedPeriod교시 $_selectedClass',
      );
    }

    List<DualExchangePath> paths = [];

    // A 위치 노드 생성 (과목명 포함)
    String nodeASubject = getSubjectFromTimeSlot(
      selectedTeacher!,
      selectedDay!,
      selectedPeriod!,
      validTimeSlots,
    );
    ExchangeNode nodeA = ExchangeNode(
      teacherName: selectedTeacher!,
      day: selectedDay!,
      period: selectedPeriod!,
      className: _selectedClass!,
      subjectName: nodeASubject,
    );

    // B 위치 후보들 찾기 (A와 같은 학급, B 교사가 A 시간 비어있음)
    List<ExchangeNode> nodeBCandidates = _findSameClassSlots(
      nodeA,
      validTimeSlots,
    );

    if (enablePathDebugLogging) {
      AppLogger.exchangeDebug('B 위치 후보: ${nodeBCandidates.length}개');
    }

    int pathCount = 0;

    for (ExchangeNode nodeB in nodeBCandidates) {
      // A 교사가 B 시간에 다른 수업(2번)이 있는지 확인
      ExchangeNode? node2 = _findBlockingSlot(
        selectedTeacher!,
        nodeB,
        validTimeSlots,
      );

      if (node2 == null) {
        // A와 B가 직접 교체 가능하면 2중교체 불필요
        if (enablePathDebugLogging) {
          AppLogger.exchangeDebug(
            'B=${nodeB.displayText}: 직접 교체 가능 (2중교체 불필요)',
          );
        }
        continue;
      }

      if (enablePathDebugLogging) {
        AppLogger.exchangeDebug(
          'B=${nodeB.displayText}, node2=${node2.displayText} 발견',
        );
      }

      // 2번 수업과 1:1 교체 가능한 같은 학급 수업(1번) 찾기
      List<ExchangeNode> node1Candidates = _findSameClassSlots(
        node2,
        validTimeSlots,
      );

      for (ExchangeNode node1 in node1Candidates) {
        // 1단계: node1 ↔ node2 교체 가능한지 확인
        if (!_canDirectExchange(node1, node2, validTimeSlots)) {
          continue;
        }

        // 2단계: A ↔ B 교체 가능한지 확인 (node2가 비워진 상태 가정)
        if (!_canExchangeAfterClearing(nodeA, nodeB, node2, validTimeSlots)) {
          continue;
        }

        // 유효한 2중교체 경로 발견
        DualExchangePath path = DualExchangePath.build(
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

    AppLogger.exchangeInfo('2중교체: 총 ${paths.length}개 경로 발견');

    return paths;
  }

  /// A와 같은 학급을 가르치는 교사들의 시간 찾기
  /// (해당 교사가 A 시간에 비어있어야 함)
  List<ExchangeNode> _findSameClassSlots(
    ExchangeNode nodeA,
    List<TimeSlot> timeSlots,
  ) {
    List<ExchangeNode> nodes = [];
    Set<String> addedNodeIds = {};
    int nodeADayNumber = DayUtils.getDayNumber(nodeA.day);

    // 같은 학급을 가르치는 모든 시간표 슬롯 찾기
    // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
    List<TimeSlot> sameClassSlots =
        slotsForClass(nodeA.className, timeSlots)
            .where(
              (slot) =>
                  slot.className == nodeA.className &&
                  slot.canExchange && // isNotEmpty 포함
                  slot.teacher != nodeA.teacherName,
            )
            .toList();

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
  ExchangeNode? _findBlockingSlot(
    String teacherA,
    ExchangeNode nodeB,
    List<TimeSlot> timeSlots,
  ) {
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
    final teacher1EmptyAtNode2Time = isTeacherEmptyAtTime(
      node1.teacherName,
      node2.day,
      node2.period,
      timeSlots,
    );
    final teacher2EmptyAtNode1Time = isTeacherEmptyAtTime(
      node2.teacherName,
      node1.day,
      node1.period,
      timeSlots,
    );

    // 같은 학급인가?
    bool sameClass = node1.className == node2.className;

    // 교체 불가 충돌 검증 추가
    bool teacher1CanMoveToNode2 =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          node1.teacherName,
          node2.day,
          node2.period,
        );
    bool teacher2CanMoveToNode1 =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          node2.teacherName,
          node1.day,
          node1.period,
        );

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
    final teacherAEmptyAtBTime =
        (nodeB.day == node2.day && nodeB.period == node2.period) ||
        isTeacherEmptyAtTime(
          nodeA.teacherName,
          nodeB.day,
          nodeB.period,
          timeSlots,
        );
    final teacherBEmptyAtATime = isTeacherEmptyAtTime(
      nodeB.teacherName,
      nodeA.day,
      nodeA.period,
      timeSlots,
    );

    // 같은 학급인가?
    bool sameClass = nodeA.className == nodeB.className;

    // 교체 불가 충돌 검증 추가
    bool teacherACanMoveToB =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          nodeA.teacherName,
          nodeB.day,
          nodeB.period,
        );
    bool teacherBCanMoveToA =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          nodeB.teacherName,
          nodeA.day,
          nodeA.period,
        );

    return teacherAEmptyAtBTime &&
        teacherBEmptyAtATime &&
        sameClass &&
        teacherACanMoveToB &&
        teacherBCanMoveToA;
  }

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    clearCellSelection();
    _selectedClass = null;

    if (enablePathDebugLogging) {
      AppLogger.exchangeDebug('2중교체: 모든 선택 초기화');
    }
  }

  /// 2중교체 가능한 교사 정보 가져오기 (UI 표시용)
  List<Map<String, dynamic>> getDualExchangeableTeachers(
    List<DualExchangePath> paths,
  ) {
    List<Map<String, dynamic>> result = [];

    for (DualExchangePath path in paths) {
      result.add({
        'path': path,
        'description': path.description,
        'detailedDescription': path.detailedDescription,
      });
    }

    return result;
  }
}

class DualSearchEngine extends ExchangeSearchContext with DualSearch {}
