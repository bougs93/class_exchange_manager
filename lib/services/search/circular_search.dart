import '../../models/time_slot.dart';
import '../../models/teacher.dart';
import '../../models/exchange_node.dart';
import '../../models/circular_exchange_path.dart';
import '../../utils/day_utils.dart';
import '../../utils/logger.dart';
import '../../utils/non_exchangeable_manager.dart';
import 'exchange_search_context.dart';

mixin CircularSearch on ExchangeSearchContext {
  static const int defaultMaxSteps = 3;
  static const bool defaultExactSteps = false;
  static const bool enablePathDebugLogging = false;
  final Map<String, List<ExchangeNode>> _adjacency = {};
  final NonExchangeableManager _nonExchangeableManager =
      NonExchangeableManager();
  List<CircularExchangePath> findCircularExchangePaths(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers, {
    int maxSteps = defaultMaxSteps, // 최대 단계 수 (기본값: 상수 사용)
    bool exactSteps = defaultExactSteps, // 정확히 해당 단계만 검사할지 여부 (기본값: 상수 사용)
    bool prioritizeShortSteps = true, // 짧은 단계부터 우선 탐색 (성능 최적화)
  }) {
    List<CircularExchangePath> allPaths = [];

    // 성능 최적화: 빈 셀과 교체불가능한 셀을 사전 필터링
    // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
    List<TimeSlot> validTimeSlots =
        timeSlots.where((slot) => slot.canExchange).toList();
    prepareSearch(validTimeSlots);
    _adjacency.clear();

    AppLogger.exchangeDebug(
      '순환교체 최적화: 전체 ${timeSlots.length}개 → 유효한 ${validTimeSlots.length}개 TimeSlot',
    );

    // 교체 불가 관리자에 TimeSlot 설정
    _nonExchangeableManager.setTimeSlots(timeSlots);

    // 성능 최적화: 교사별 시간 인덱스 생성
    Map<String, Set<String>> teacherTimeIndex = _buildTeacherTimeIndex(
      validTimeSlots,
    );
    AppLogger.exchangeDebug('교사별 시간 인덱스 생성 완료: ${teacherTimeIndex.length}명 교사');

    // 선택된 노드가 없으면 빈 리스트 반환
    ExchangeNode? startNode = getSelectedNode(
      validTimeSlots,
    ); // [1단계] : 시작 노트 찾기 (getSelectedNode)
    if (startNode == null) {
      AppLogger.exchangeDebug('시작 노드를 찾을 수 없습니다.');
      return allPaths;
    }

    AppLogger.exchangeDebug('순환 경로 탐색 시작: ${startNode.displayText}');

    // 캐시 로직 제거됨 - 매번 새로 계산하여 복잡도 감소
    // 단계별 우선순위 탐색
    List<List<ExchangeNode>> foundPaths =
        prioritizeShortSteps
            ? _findCircularPathsBySteps(
              startNode,
              validTimeSlots,
              teachers,
              teacherTimeIndex,
              maxSteps,
              exactSteps,
            )
            : _findCircularPathsDFS(
              startNode,
              validTimeSlots,
              teachers,
              teacherTimeIndex,
              maxSteps,
              exactSteps,
            );

    // 찾은 경로들을 CircularExchangePath로 변환하고 검증
    List<CircularExchangePath> validPaths = [];
    for (List<ExchangeNode> path in foundPaths) {
      try {
        CircularExchangePath circularPath = CircularExchangePath.fromNodes(
          path,
        );
        if (circularPath.isValid) {
          // 교체 순서 검증
          if (validateExchangeSequence(
            circularPath,
            validTimeSlots,
            teacherTimeIndex: teacherTimeIndex,
          )) {
            validPaths.add(circularPath);
          } else {
            AppLogger.exchangeDebug(
              '유효하지 않은 교체 순서: ${circularPath.nodes.map((n) => n.teacherName).join(' → ')}',
            );
          }
        }
      } catch (e) {
        // 유효하지 않은 경로는 무시
        AppLogger.exchangeDebug('경로 생성 오류: $e');
        continue;
      }
    }

    // 우선순위별로 정렬 (단계 수가 적은 것부터)
    validPaths.sort((a, b) => a.steps.compareTo(b.steps));

    // 불필요한 긴 단계 경로 제외 (더 짧은 단계로 같은 결과를 얻을 수 있는 경우)
    allPaths = _removeRedundantPaths(
      validPaths,
    ); // [5단계] : 불필요한 긴 단계 경로 제외 (_removeRedundantPaths)

    // 캐시 로직 제거됨 - 복잡도 감소를 위해 매번 새로 계산
    AppLogger.exchangeDebug('경로 탐색 완료: ${allPaths.length}개 경로 발견');

    return allPaths;
  }

  /* [1단계] : 시작 노트 찾기
    시작 노트 찾기 : 사용자가 클릭한 셀 정보를 노드로 만듦
    예: "A교사님, 월요일 1교시, 3-1반" → ExchangeNode 생성
  */
  /// 선택된 셀을 ExchangeNode로 변환
  ///
  ///
  ExchangeNode? getSelectedNode(List<TimeSlot> timeSlots) {
    AppLogger.exchangeDebug(
      'getSelectedNode 호출 - 선택된 셀: $selectedTeacher, $selectedDay, $selectedPeriod',
    );

    if (selectedTeacher == null ||
        selectedDay == null ||
        selectedPeriod == null) {
      AppLogger.exchangeDebug(
        '선택된 셀 정보가 불완전합니다: teacher=$selectedTeacher, day=$selectedDay, period=$selectedPeriod',
      );
      return null;
    }

    // 선택된 셀의 학급 정보 가져오기
    String? className = getSelectedClassName(timeSlots);
    if (className == null) {
      AppLogger.exchangeDebug(
        '학급 정보를 찾을 수 없습니다: $selectedTeacher, $selectedDay, $selectedPeriod',
      );
      return null;
    }

    AppLogger.exchangeDebug(
      '시작 노드 생성 성공: $selectedTeacher, $selectedDay, $selectedPeriod, $className',
    );

    // 과목명 가져오기 (베이스 클래스 메서드 사용)
    String subjectName = getSubjectFromTimeSlot(
      selectedTeacher!,
      selectedDay!,
      selectedPeriod!,
      timeSlots,
    );

    return ExchangeNode(
      teacherName: selectedTeacher!,
      day: selectedDay!,
      period: selectedPeriod!,
      className: className,
      subjectName: subjectName,
    );
  }

  /*
  [2단계]: DFS 탐색 (_findCircularPathsDFS)
  깊이 우선 탐색으로 모든 경우의 수를 체크:
  A교사(시작)
  ├── B교사 탐색
  │   ├── C교사 탐색
  │   │   └── A교사(끝) ✅ 순환 완성!
  │   └── D교사 탐색
  │       └── ... 계속 탐색
  └── C교사 탐색
      └── ... 계속 탐색
  */
  /// 교사별 시간 인덱스 생성 (성능 최적화)
  Map<String, Set<String>> _buildTeacherTimeIndex(List<TimeSlot> timeSlots) {
    Map<String, Set<String>> index = {};
    for (TimeSlot slot in timeSlots) {
      String teacher = slot.teacher ?? '';
      String timeKey = '${slot.dayOfWeek}_${slot.period}';
      index.putIfAbsent(teacher, () => <String>{});
      index[teacher]!.add(timeKey);
    }
    return index;
  }

  /// 단계별 우선순위 탐색 (성능 최적화)
  /// 짧은 단계부터 탐색하여 빠른 결과 제공
  List<List<ExchangeNode>> _findCircularPathsBySteps(
    ExchangeNode startNode,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    Map<String, Set<String>> teacherTimeIndex,
    int maxSteps,
    bool exactSteps,
  ) {
    List<List<ExchangeNode>> allPaths = [];

    // 단계별로 탐색 (2단계부터 시작)
    for (int targetSteps = 2; targetSteps <= maxSteps; targetSteps++) {
      AppLogger.exchangeDebug('단계별 탐색: $targetSteps단계 경로 탐색 시작');

      List<List<ExchangeNode>> stepPaths = _findCircularPathsDFS(
        startNode,
        timeSlots,
        teachers,
        teacherTimeIndex,
        targetSteps,
        true, // 정확히 해당 단계만
      );

      allPaths.addAll(stepPaths);
      AppLogger.exchangeDebug('$targetSteps단계 경로 ${stepPaths.length}개 발견');
    }

    return allPaths;
  }

  /// DFS를 사용하여 순환 경로를 찾는 재귀 메서드
  List<List<ExchangeNode>> _findCircularPathsDFS(
    ExchangeNode startNode,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    Map<String, Set<String>> teacherTimeIndex, // 인덱스 추가
    int maxSteps, // 최대 단계 수
    bool exactSteps, // 정확히 해당 단계만 검사할지 여부
  ) {
    List<List<ExchangeNode>> allPaths = [];

    void dfs(
      ExchangeNode currentNode,
      List<ExchangeNode> currentPath,
      Set<String> visited,
      int currentStep,
    ) {
      // 최대 단계 수 초과 시 종료
      if (currentStep > maxSteps) return;

      // 2중 교체 완료 확인 (시작점으로 돌아옴)
      // 조건: 최소 2단계 이상이고, 시작점(결강 교사)으로 돌아옴
      // 의미: 결강 교사가 마지막 교사의 수업을 대신하여 2중 교체 완료
      if (currentStep >= 2 && currentNode.nodeId == startNode.nodeId) {
        // exactSteps 옵션에 따라 조건 확인
        bool shouldAddPath =
            exactSteps
                ? (currentStep == maxSteps)
                : // 정확히 해당 단계만
                (currentStep <= maxSteps); // 해당 단계까지

        if (shouldAddPath) {
          // 시작점으로 끝나는 완전한 순환 경로 생성
          // currentPath는 이미 시작점을 포함하고 있으므로 마지막에 시작점만 추가
          List<ExchangeNode> completePath = [...currentPath, startNode];
          allPaths.add(completePath);
        }
        return;
      }

      // 현재 노드를 경로에 추가
      currentPath.add(currentNode);
      visited.add(currentNode.nodeId);

      // 인접 노드들 찾기
      List<ExchangeNode> adjacentNodes = _adjacency.putIfAbsent(
        currentNode.nodeId,
        () => findAdjacentNodes(
          // [3단계] : 인접 노드들 찾기 (findAdjacentNodes)
          currentNode,
          timeSlots,
          teachers,
          teacherTimeIndex, // 인덱스 전달
          showLog: currentStep == 0, // 첫 번째 호출에서만 로그 출력
        ),
      );

      // 각 인접 노드에 대해 재귀 탐색
      for (ExchangeNode nextNode in adjacentNodes) {
        // 이미 방문한 노드는 제외 (시작점은 순환 완성을 위해 허용)
        if (visited.contains(nextNode.nodeId) &&
            nextNode.nodeId != startNode.nodeId) {
          continue;
        }

        // 방향 그래프 교체 가능성 검증 (한 방향만) - 인덱스 사용
        if (_isOneWayExchangeableOptimized(
          currentNode,
          nextNode,
          teacherTimeIndex,
        )) {
          dfs(
            nextNode,
            List.from(currentPath),
            Set.from(visited),
            currentStep + 1,
          );
        }
      }
    }

    // DFS 시작 (시작점을 경로에 포함하지 않음)
    dfs(startNode, [], {}, 0);

    return allPaths;
  }

  /*
  [3단계] : 같은 학급(3-1반)을 가르치는 다른 교사들 찾기
    시작: A교사 - 월요일 1교시 - 3-1반
    찾은 친구들:
    → B교사 - 화요일 3교시 - 3-1반
    → C교사 - 수요일 2교시 - 3-1반
  */
  /// 방향 그래프를 위한 인접 노드들을 찾는 메서드
  ///
  /// 조건:
  /// 1. 같은 학급을 가르치는 교사들
  /// 2. 다른 시간대 (요일 또는 교시가 다름)
  /// 3. 교체 가능한 상태 (isExchangeable = true)
  /// 4. 실제 수업이 있는 상태 (isNotEmpty = true)
  /// 5. 한 방향 교체 가능 (다음 교사가 현재 교사의 시간에 수업 가능)
  List<ExchangeNode> findAdjacentNodes(
    ExchangeNode currentNode,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    Map<String, Set<String>> teacherTimeIndex, { // 인덱스 추가
    bool showLog = false, // 로그 출력 여부
  }) {
    List<ExchangeNode> adjacentNodes = [];
    Set<String> addedNodeIds = {}; // 중복 방지를 위한 Set

    // 같은 학급을 가르치는 모든 시간표 슬롯 찾기
    List<TimeSlot> sameClassSlots =
        slotsForClass(currentNode.className, timeSlots)
            .where(
              (slot) =>
                  slot.className == currentNode.className &&
                  slot.isNotEmpty &&
                  slot.canExchange &&
                  slot.teacher != currentNode.teacherName, // 같은 교사 제외
            )
            .toList();

    // 각 슬롯을 ExchangeNode로 변환하고 한 방향 교체 가능성 확인
    for (TimeSlot slot in sameClassSlots) {
      String dayString = DayUtils.getDayName(slot.dayOfWeek ?? 0);

      if (dayString != '알 수 없음') {
        ExchangeNode node = ExchangeNode(
          teacherName: slot.teacher ?? '',
          day: dayString,
          period: slot.period ?? 0,
          className: slot.className ?? '',
          subjectName: slot.subject ?? '과목명 없음',
        );

        // 중복 노드 방지
        if (!addedNodeIds.contains(node.nodeId)) {
          // 한 방향 교체 가능성 확인 (다음 교사가 현재 교사의 시간에 수업 가능한가?) - 인덱스 사용
          if (_isOneWayExchangeableOptimized(
            currentNode,
            node,
            teacherTimeIndex,
          )) {
            // [4단계] : 한 방향 교체 가능성 확인 (_isOneWayExchangeableOptimized)
            adjacentNodes.add(node);
            addedNodeIds.add(node.nodeId);
          }
        }
      }
    }

    if (showLog) {
      AppLogger.exchangeDebug(
        '인접 노드 ${adjacentNodes.length}개 발견: ${adjacentNodes.map((n) => n.displayText).join(', ')}',
      );
    }

    return adjacentNodes;
  }

  /* 
  [4단계]: 교체 가능성 검증 (_isOneWayExchangeable)
    조건: 한 방향 교체 가능 (다음 교사가 현재 교사의 시간에 수업 가능)
  */

  /// 방향 그래프를 위한 한 방향 교체 가능성을 확인하는 메서드 (최적화 버전)
  ///
  /// 교체 시나리오: from 교사가 결강할 때 to 교사가 from 교사의 수업을 대신
  ///
  /// 조건:
  /// 1. to 교사가 from 교사의 시간에 빈 시간이어야 함 (수업 가능)
  /// 2. 교체 불가 충돌 검증 추가
  /// 3. 2중 교체 방식: A(결강) → B(대신 수업) → C(대신 수업) → D(대신 수업)
  ///
  /// 예시: A교사(월 1교시) → B교사(화 3교시)
  /// - A교사가 결강할 때 B교사가 A교사의 수업(월 1교시)을 대신
  /// - B교사가 월 1교시에 빈 시간이어야 함 (수업 가능)
  bool _isOneWayExchangeableOptimized(
    ExchangeNode from,
    ExchangeNode to,
    Map<String, Set<String>> teacherTimeIndex,
  ) {
    // 같은 교사끼리의 교체는 항상 가능 (순환 완료 시)
    if (from.teacherName == to.teacherName) {
      return true;
    }

    // 인덱스를 사용한 빠른 검증: from 교사가 to 교사의 시간에 수업이 있는지 확인
    String toTimeKey = '${DayUtils.getDayNumber(to.day)}_${to.period}';
    Set<String>? teacherTimes = teacherTimeIndex[from.teacherName];
    bool fromEmptyAtToTime =
        teacherTimes == null || !teacherTimes.contains(toTimeKey);

    // 추가 검증: 같은 학급이어야 순환교체 가능
    bool sameClass = from.className == to.className;

    // 교체 불가 충돌 검증 추가: from 교사가 to 교사 시간에 교체 불가 셀이 있는지
    bool noExchangeableConflict =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          from.teacherName,
          to.day,
          to.period,
        );

    return fromEmptyAtToTime && sameClass && noExchangeableConflict;
  }

  /// 방향 그래프를 위한 한 방향 교체 가능성을 확인하는 메서드 (TimeSlot 사용)
  /// 인덱스가 없을 때 사용되는 폴백 메서드
  /// 노드에 과목 정보를 포함한 문자열 생성
  String _getNodeWithSubject(ExchangeNode node, List<TimeSlot> timeSlots) {
    // BaseExchangeService의 공통 메서드 사용 (중복 로직 제거)
    TimeSlot? slot = findTimeSlot(
      node.teacherName,
      node.day,
      node.period,
      timeSlots,
    );

    // className이 일치하는지 추가 확인
    if (slot != null && slot.className != node.className) {
      slot = null;
    }

    String subject =
        slot?.isNotEmpty == true ? (slot?.subject ?? '과목없음') : '과목없음';
    return '${node.teacherName}(${node.day}${node.period}교시, ${node.className}, $subject)';
  }

  /// 순환교체 경로의 교체 과정을 시뮬레이션하여 검증
  ///
  /// 각 단계에서 교사가 실제로 수업할 수 있는지 확인
  bool validateExchangeSequence(
    CircularExchangePath path,
    List<TimeSlot> timeSlots, {
    Map<String, Set<String>>? teacherTimeIndex,
  }) {
    final index = teacherTimeIndex ?? _buildTeacherTimeIndex(timeSlots);
    if (path.nodes.length < 2) return false;

    // 각 교체 단계 검증
    for (int i = 0; i < path.nodes.length - 1; i++) {
      ExchangeNode from = path.nodes[i];
      ExchangeNode to = path.nodes[i + 1];

      if (!_isOneWayExchangeableOptimized(from, to, index)) {
        return false;
      }
    }

    // 첫 번째 교사가 마지막 교사의 시간에 수업 가능한지 확인 (순환 완료)
    ExchangeNode lastNode = path.nodes.last;
    ExchangeNode firstNode = path.nodes.first;

    if (!_isOneWayExchangeableOptimized(lastNode, firstNode, index)) {
      return false;
    }

    return true;
  }

  /// 교체 가능한 교사 정보를 로그로 출력
  void logCircularExchangeInfo(
    List<CircularExchangePath> paths,
    List<TimeSlot> timeSlots,
  ) {
    if (!enablePathDebugLogging || selectedTeacher == null) return;

    if (paths.isEmpty) {
      AppLogger.exchangeInfo('순환 교체 가능한 경로가 없습니다.');
    } else {
      for (int i = 0; i < paths.length; i++) {
        CircularExchangePath path = paths[i];

        // 과목 정보를 포함한 경로 설명 생성
        String pathWithSubjects = path.nodes
            .map((n) => _getNodeWithSubject(n, timeSlots))
            .join(' → ');

        if (enablePathDebugLogging) {
          AppLogger.exchangeInfo(
            '경로 ${i + 1} [${path.steps}단계]: $pathWithSubjects',
          );
        }
      }
    }
  }

  /// 불필요한 긴 단계 경로를 제거하는 메서드
  /// 더 짧은 단계로 같은 결과를 얻을 수 있다면 긴 단계 경로는 제외
  List<CircularExchangePath> _removeRedundantPaths(
    List<CircularExchangePath> paths,
  ) {
    List<CircularExchangePath> optimizedPaths = [];

    for (int i = 0; i < paths.length; i++) {
      CircularExchangePath currentPath = paths[i];
      bool isRedundant = false;

      // 현재 경로보다 짧은 경로들과 비교
      for (int j = 0; j < i; j++) {
        CircularExchangePath shorterPath = paths[j];

        // 더 짧은 경로가 현재 경로의 결과를 포함하는지 확인
        if (_isPathRedundant(currentPath, shorterPath)) {
          isRedundant = true;
          AppLogger.exchangeDebug(
            '불필요한 긴 단계 경로 제외: ${currentPath.nodes.length}단계 → ${shorterPath.nodes.length}단계로 충분',
          );
          break;
        }
      }

      if (!isRedundant) {
        optimizedPaths.add(currentPath);
      }
    }

    return optimizedPaths;
  }

  /// 현재 경로가 더 짧은 경로로 대체 가능한지 확인
  /// 두 경로의 시작점과 끝점이 같고, 중간에 불필요한 단계가 있는지 확인
  bool _isPathRedundant(
    CircularExchangePath longerPath,
    CircularExchangePath shorterPath,
  ) {
    // 길이가 같거나 더 긴 경로는 중복이 아님
    if (longerPath.nodes.length <= shorterPath.nodes.length) {
      return false;
    }

    // 시작점과 끝점이 같아야 함
    ExchangeNode longerStart = longerPath.nodes.first;
    ExchangeNode longerEnd = longerPath.nodes.last;
    ExchangeNode shorterStart = shorterPath.nodes.first;
    ExchangeNode shorterEnd = shorterPath.nodes.last;

    if (longerStart.nodeId != shorterStart.nodeId ||
        longerEnd.nodeId != shorterEnd.nodeId) {
      return false;
    }

    // 더 긴 경로가 더 짧은 경로의 모든 노드를 포함하는지 확인
    // (순서는 다를 수 있지만, 같은 교체 결과를 얻을 수 있는지 확인)
    Set<String> shorterNodeIds = shorterPath.nodes.map((n) => n.nodeId).toSet();
    Set<String> longerNodeIds = longerPath.nodes.map((n) => n.nodeId).toSet();

    // 더 짧은 경로의 모든 노드가 더 긴 경로에 포함되어 있는지 확인
    bool containsAllNodes = shorterNodeIds.every(
      (nodeId) => longerNodeIds.contains(nodeId),
    );

    if (containsAllNodes) {
      AppLogger.exchangeDebug(
        '중복 경로 감지: ${longerPath.nodes.length}단계 경로는 ${shorterPath.nodes.length}단계로 충분',
      );
      return true;
    }

    return false;
  }
}

class CircularSearchEngine extends ExchangeSearchContext with CircularSearch {}
