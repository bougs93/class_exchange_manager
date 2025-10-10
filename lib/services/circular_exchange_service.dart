import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/exchange_algorithm.dart';
import '../utils/timetable_data_source.dart';
import '../utils/logger.dart';
import '../utils/day_utils.dart';
import '../utils/non_exchangeable_manager.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/exchange_node.dart';
import '../models/circular_exchange_path.dart';
import 'base_exchange_service.dart';

/// 순환교체 서비스 클래스
/// 여러 교사 간의 순환 교체 비즈니스 로직을 담당
class CircularExchangeService extends BaseExchangeService {
  // 싱글톤 인스턴스
  static final CircularExchangeService _instance = CircularExchangeService._internal();
  
  // 싱글톤 생성자
  factory CircularExchangeService() => _instance;
  
  // 내부 생성자
  CircularExchangeService._internal();
  
  // ==================== 상수 정의 ====================
  
  /// 기본 최대 단계 수 (순환 교체에서 최대 몇 단계까지 탐색할지)
  static const int defaultMaxSteps = 3;
  
  /// 기본 단계 검사 방식 (false: 해당 단계까지, true: 정확히 해당 단계만)
  static const bool defaultExactSteps = false;
  
  // ==================== 성능 최적화 ====================
  // 캐시 로직 제거됨 - 복잡도 감소를 위해 매번 새로 계산

  /// 순환교체 경로 디버그 콘솔 출력 여부
  static const bool enablePathDebugLogging = false;

  // ==================== 인스턴스 변수 ====================

  // 교체 가능한 시간 관련 변수들
  final List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들
  
  // 교체 불가 관리자
  final NonExchangeableManager _nonExchangeableManager = NonExchangeableManager();

  // Getters
  List<ExchangeOption> get exchangeOptions => _exchangeOptions;
  
  /// 순환교체 모드에서 셀 탭 처리
  /// 
  /// 매개변수:
  /// - `details`: 셀 탭 상세 정보
  /// - `dataSource`: 데이터 소스
  /// 
  /// 반환값:
  /// - `CircularExchangeResult`: 처리 결과
  CircularExchangeResult startCircularExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  ) {
    // 교사명 열은 선택하지 않음
    if (details.column.columnName == 'teacher') {
      return CircularExchangeResult.noAction();
    }
    
    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      return CircularExchangeResult.noAction();
    }
    
    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;

    // 교체할 셀의 교사명 찾기 (베이스 클래스 메서드 사용)
    String teacherName = getTeacherNameFromCell(details, dataSource);

    // 동일한 셀을 다시 클릭했는지 확인 (베이스 클래스 메서드 사용)
    if (isSameCell(teacherName, day, period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      clearCellSelection();
      return CircularExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      selectCell(teacherName, day, period);
      return CircularExchangeResult.selected(teacherName, day, period);
    }
  }

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    clearCellSelection();
    _exchangeOptions.clear();
    // 캐시 로직 제거됨
  }
  
  /// 순환교체용 교체 가능한 교사 정보 가져오기 (1스탭: 같은 학급, 다른 시간대, 양쪽 빈시간)
  /// 
  /// 1개 스탭 교체에서는:
  /// - 같은 학급만 교체 가능
  /// - 다른 시간대여야 함
  /// - 양쪽 모두 빈 시간이어야 함
  /// 예: A교사(월1교시, 1학년 1반) ↔ B교사(화2교시, 1학년 1반) - 둘 다 빈시간
  List<Map<String, dynamic>> getCircularExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (selectedTeacher == null || selectedDay == null || selectedPeriod == null) {
      return [];
    }
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = getSelectedClassName(timeSlots);
    if (selectedClassName == null) return [];
    
    List<Map<String, dynamic>> exchangeableTeachers = [];
    
    // 같은 학급을 가르치는 교사들 중에서 찾기
    for (Teacher teacher in teachers) {
      if (teacher.name == selectedTeacher) continue; // 자기 자신 제외
      
      // 해당 교사가 다른 시간대에 같은 학급을 가르치는지 확인
      List<TimeSlot> teacherSlots = timeSlots.where((slot) => 
        slot.teacher == teacher.name &&
        slot.className == selectedClassName &&
        slot.isNotEmpty &&
        !(slot.dayOfWeek == DayUtils.getDayNumber(selectedDay!) && slot.period == selectedPeriod) // 다른 시간대
      ).toList();
      
      for (TimeSlot teacherSlot in teacherSlots) {
        // 양쪽 모두 빈 시간인지 확인
        bool selectedTeacherHasEmptyTime = isTeacherEmptyAtTime(
          selectedTeacher!, selectedDay!, selectedPeriod!, timeSlots);
        bool otherTeacherHasEmptyTime = isTeacherEmptyAtTime(
          teacher.name, _getDayString(teacherSlot.dayOfWeek ?? 0), teacherSlot.period ?? 0, timeSlots);
        
        if (selectedTeacherHasEmptyTime && otherTeacherHasEmptyTime) {
          exchangeableTeachers.add({
            'teacherName': teacher.name,
            'day': _getDayString(teacherSlot.dayOfWeek ?? 0),
            'period': teacherSlot.period ?? 0,
            'className': selectedClassName,
            'subject': teacherSlot.subject ?? '과목 없음',
          });
        }
      }
    }
    
    return exchangeableTeachers;
  }
  
  /// 요일 숫자를 문자열로 변환하는 헬퍼 메서드
  String _getDayString(int dayNumber) {
    return DayUtils.getDayName(dayNumber);
  }

  // ==================== 그래프 구성 메서드들 START ====================
  /*
  [순환 경로 찾기]
    모든 가능한 교체 경로를 찾아서 리스트로 만듦
    예: "A교사 → B교사 → C교사 → A교사" 같은 순환 경로
  */

  /// 그래프를 구성하고 모든 교체 가능한 경로를 찾는 메서드
  /// 
  /// 반환값:
  /// - `List<CircularExchangePath>`: 찾은 모든 순환 교체 경로들
  List<CircularExchangePath> findCircularExchangePaths(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    {int maxSteps = defaultMaxSteps,  // 최대 단계 수 (기본값: 상수 사용)
     bool exactSteps = defaultExactSteps,  // 정확히 해당 단계만 검사할지 여부 (기본값: 상수 사용)
     bool prioritizeShortSteps = true}  // 짧은 단계부터 우선 탐색 (성능 최적화)
  ) {
    List<CircularExchangePath> allPaths = [];
    
    // 성능 최적화: 빈 셀과 교체불가능한 셀을 사전 필터링
    List<TimeSlot> validTimeSlots = timeSlots.where((slot) => 
      slot.isNotEmpty && slot.canExchange
    ).toList();
    
    AppLogger.exchangeDebug('순환교체 최적화: 전체 ${timeSlots.length}개 → 유효한 ${validTimeSlots.length}개 TimeSlot');
    
    // 교체 불가 관리자에 TimeSlot 설정
    _nonExchangeableManager.setTimeSlots(timeSlots);
    
    // 성능 최적화: 교사별 시간 인덱스 생성
    Map<String, Set<String>> teacherTimeIndex = _buildTeacherTimeIndex(validTimeSlots);
    AppLogger.exchangeDebug('교사별 시간 인덱스 생성 완료: ${teacherTimeIndex.length}명 교사');
    
    // 선택된 노드가 없으면 빈 리스트 반환
    ExchangeNode? startNode = getSelectedNode(validTimeSlots);       // [1단계] : 시작 노트 찾기 (getSelectedNode)
    if (startNode == null) {
      AppLogger.exchangeDebug('시작 노드를 찾을 수 없습니다.');
      return allPaths;
    }
    
    AppLogger.exchangeDebug('순환 경로 탐색 시작: ${startNode.displayText}');
    
    // 캐시 로직 제거됨 - 매번 새로 계산하여 복잡도 감소
    // 단계별 우선순위 탐색
    List<List<ExchangeNode>> foundPaths = prioritizeShortSteps 
      ? _findCircularPathsBySteps(startNode, validTimeSlots, teachers, teacherTimeIndex, maxSteps, exactSteps)
      : _findCircularPathsDFS(startNode, validTimeSlots, teachers, teacherTimeIndex, maxSteps, exactSteps);
    
    // 찾은 경로들을 CircularExchangePath로 변환하고 검증
    List<CircularExchangePath> validPaths = [];
    for (List<ExchangeNode> path in foundPaths) {
      try {
        CircularExchangePath circularPath = CircularExchangePath.fromNodes(path);
        if (circularPath.isValid) {
          // 교체 순서 검증
          if (validateExchangeSequence(circularPath, validTimeSlots)) {
            validPaths.add(circularPath);
          } else {
            AppLogger.exchangeDebug('유효하지 않은 교체 순서: ${circularPath.nodes.map((n) => n.teacherName).join(' → ')}');
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
    allPaths = _removeRedundantPaths(validPaths);         // [5단계] : 불필요한 긴 단계 경로 제외 (_removeRedundantPaths)
    
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
    AppLogger.exchangeDebug('getSelectedNode 호출 - 선택된 셀: $selectedTeacher, $selectedDay, $selectedPeriod');
    
    if (selectedTeacher == null || selectedDay == null || selectedPeriod == null) {
      AppLogger.exchangeDebug('선택된 셀 정보가 불완전합니다: teacher=$selectedTeacher, day=$selectedDay, period=$selectedPeriod');
      return null;
    }
    
    // 선택된 셀의 학급 정보 가져오기
    String? className = getSelectedClassName(timeSlots);
    if (className == null) {
      AppLogger.exchangeDebug('학급 정보를 찾을 수 없습니다: $selectedTeacher, $selectedDay, $selectedPeriod');
      return null;
    }
    
    AppLogger.exchangeDebug('시작 노드 생성 성공: $selectedTeacher, $selectedDay, $selectedPeriod, $className');
    
    // 과목명 가져오기 (베이스 클래스 메서드 사용)
    String subjectName = getSubjectFromTimeSlot(selectedTeacher!, selectedDay!, selectedPeriod!, timeSlots);
    
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
        true // 정확히 해당 단계만
      );
      
      allPaths.addAll(stepPaths);
      AppLogger.exchangeDebug('$targetSteps단계 경로 $stepPaths.length개 발견');
    }
    
    return allPaths;
  }

  /// DFS를 사용하여 순환 경로를 찾는 재귀 메서드
  List<List<ExchangeNode>> _findCircularPathsDFS(
    ExchangeNode startNode,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    Map<String, Set<String>> teacherTimeIndex, // 인덱스 추가
    int maxSteps,         // 최대 단계 수
    bool exactSteps,     // 정확히 해당 단계만 검사할지 여부
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
      
      // 연쇄 교체 완료 확인 (시작점으로 돌아옴)
      // 조건: 최소 2단계 이상이고, 시작점(결강 교사)으로 돌아옴
      // 의미: 결강 교사가 마지막 교사의 수업을 대신하여 연쇄 교체 완료
      if (currentStep >= 2 && currentNode.nodeId == startNode.nodeId) {
        // exactSteps 옵션에 따라 조건 확인
        bool shouldAddPath = exactSteps ? 
          (currentStep == maxSteps) :  // 정확히 해당 단계만
          (currentStep <= maxSteps);   // 해당 단계까지
        
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
      List<ExchangeNode> adjacentNodes = findAdjacentNodes(    // [3단계] : 인접 노드들 찾기 (findAdjacentNodes)  
        currentNode, 
        timeSlots, 
        teachers,
        teacherTimeIndex, // 인덱스 전달
        showLog: currentStep == 0, // 첫 번째 호출에서만 로그 출력
      );
      
      // 각 인접 노드에 대해 재귀 탐색
      for (ExchangeNode nextNode in adjacentNodes) {
        // 이미 방문한 노드는 제외 (시작점은 순환 완성을 위해 허용)
        if (visited.contains(nextNode.nodeId) && nextNode.nodeId != startNode.nodeId) {
          continue;
        }
        
        // 방향 그래프 교체 가능성 검증 (한 방향만) - 인덱스 사용
        if (_isOneWayExchangeableOptimized(currentNode, nextNode, teacherTimeIndex)) {
          dfs(nextNode, List.from(currentPath), Set.from(visited), currentStep + 1);
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
    List<TimeSlot> sameClassSlots = timeSlots.where((slot) => 
      slot.className == currentNode.className &&
      slot.isNotEmpty &&
      slot.canExchange &&
      slot.teacher != currentNode.teacherName // 같은 교사 제외
    ).toList();
    
    // 각 슬롯을 ExchangeNode로 변환하고 한 방향 교체 가능성 확인
    for (TimeSlot slot in sameClassSlots) {
      String dayString = _getDayString(slot.dayOfWeek ?? 0);
      
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
          if (_isOneWayExchangeableOptimized(currentNode, node, teacherTimeIndex)) {    // [4단계] : 한 방향 교체 가능성 확인 (_isOneWayExchangeableOptimized)
            adjacentNodes.add(node);
            addedNodeIds.add(node.nodeId);
          }
        }
      }
    }
    
    if (showLog) {
      AppLogger.exchangeDebug('인접 노드 ${adjacentNodes.length}개 발견: ${adjacentNodes.map((n) => n.displayText).join(', ')}');
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
  /// 3. 연쇄 교체 방식: A(결강) → B(대신 수업) → C(대신 수업) → D(대신 수업)
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
    bool fromEmptyAtToTime = teacherTimes == null || !teacherTimes.contains(toTimeKey);
    
    // 추가 검증: 같은 학급이어야 순환교체 가능
    bool sameClass = from.className == to.className;
    
    // 교체 불가 충돌 검증 추가: from 교사가 to 교사 시간에 교체 불가 셀이 있는지
    bool noExchangeableConflict = !_isNonExchangeableClash(from.teacherName, to.day, to.period);
    
    return fromEmptyAtToTime && sameClass && noExchangeableConflict;
  }

  /// 방향 그래프를 위한 한 방향 교체 가능성을 확인하는 메서드 (TimeSlot 사용)
  /// 인덱스가 없을 때 사용되는 폴백 메서드
  bool _isOneWayExchangeable(
    ExchangeNode from,
    ExchangeNode to,
    List<TimeSlot> timeSlots,
  ) {
    // 인덱스 생성하여 최적화 버전 호출
    Map<String, Set<String>> teacherTimeIndex = _buildTeacherTimeIndex(timeSlots);
    return _isOneWayExchangeableOptimized(from, to, teacherTimeIndex);
  }
  

  /// 노드에 과목 정보를 포함한 문자열 생성
  String _getNodeWithSubject(ExchangeNode node, List<TimeSlot> timeSlots) {
    // 해당 노드의 TimeSlot 찾기
    TimeSlot? slot;
    try {
      slot = timeSlots.firstWhere(
        (s) => s.teacher == node.teacherName &&
               s.dayOfWeek == DayUtils.getDayNumber(node.day) &&
               s.period == node.period &&
               s.className == node.className,
      );
    } catch (e) {
      slot = null;
    }
    
    String subject = slot?.isNotEmpty == true ? (slot?.subject ?? '과목없음') : '과목없음';
    return '${node.teacherName}(${node.day}${node.period}교시, ${node.className}, $subject)';
  }

  /// 교체 불가 충돌 검증
  /// 교사가 특정 시간대로 이동할 때 교체 불가 셀이 있는지 확인
  bool _isNonExchangeableClash(String teacherName, String day, int period) {
    return _nonExchangeableManager.isNonExchangeableTimeSlot(teacherName, day, period);
  }

  /// 순환교체 경로의 교체 과정을 시뮬레이션하여 검증
  /// 
  /// 각 단계에서 교사가 실제로 수업할 수 있는지 확인
  bool validateExchangeSequence(CircularExchangePath path, List<TimeSlot> timeSlots) {
    if (path.nodes.length < 2) return false;
    
    // 각 교체 단계 검증
    for (int i = 0; i < path.nodes.length - 1; i++) {
      ExchangeNode from = path.nodes[i];
      ExchangeNode to = path.nodes[i + 1];
      
      if (!_isOneWayExchangeable(from, to, timeSlots)) {
        return false;
      }
    }
    
    // 첫 번째 교사가 마지막 교사의 시간에 수업 가능한지 확인 (순환 완료)
    ExchangeNode lastNode = path.nodes.last;
    ExchangeNode firstNode = path.nodes.first;
    
    if (!_isOneWayExchangeable(lastNode, firstNode, timeSlots)) {
      return false;
    }
    
    return true;
  }

  /// 교체 가능한 교사 정보를 로그로 출력
  void logCircularExchangeInfo(List<CircularExchangePath> paths, List<TimeSlot> timeSlots) {
    if (selectedTeacher == null) return;
    
    if (paths.isEmpty) {
      AppLogger.exchangeInfo('순환 교체 가능한 경로가 없습니다.');
    } else {
      for (int i = 0; i < paths.length; i++) {
        CircularExchangePath path = paths[i];
        
        // 과목 정보를 포함한 경로 설명 생성
        String pathWithSubjects = path.nodes.map((n) => _getNodeWithSubject(n, timeSlots)).join(' → ');
        
        if (enablePathDebugLogging) {
          AppLogger.exchangeInfo('경로 ${i + 1} [${path.steps}단계]: $pathWithSubjects');
        }
      }
    }
  }
  

  /// 불필요한 긴 단계 경로를 제거하는 메서드
  /// 더 짧은 단계로 같은 결과를 얻을 수 있다면 긴 단계 경로는 제외
  List<CircularExchangePath> _removeRedundantPaths(List<CircularExchangePath> paths) {
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
          AppLogger.exchangeDebug('불필요한 긴 단계 경로 제외: ${currentPath.nodes.length}단계 → ${shorterPath.nodes.length}단계로 충분');
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
  bool _isPathRedundant(CircularExchangePath longerPath, CircularExchangePath shorterPath) {
    // 길이가 같거나 더 긴 경로는 중복이 아님
    if (longerPath.nodes.length <= shorterPath.nodes.length) {
      return false;
    }
    
    // 시작점과 끝점이 같아야 함
    ExchangeNode longerStart = longerPath.nodes.first;
    ExchangeNode longerEnd = longerPath.nodes.last;
    ExchangeNode shorterStart = shorterPath.nodes.first;
    ExchangeNode shorterEnd = shorterPath.nodes.last;
    
    if (longerStart.nodeId != shorterStart.nodeId || longerEnd.nodeId != shorterEnd.nodeId) {
      return false;
    }
    
    // 더 긴 경로가 더 짧은 경로의 모든 노드를 포함하는지 확인
    // (순서는 다를 수 있지만, 같은 교체 결과를 얻을 수 있는지 확인)
    Set<String> shorterNodeIds = shorterPath.nodes.map((n) => n.nodeId).toSet();
    Set<String> longerNodeIds = longerPath.nodes.map((n) => n.nodeId).toSet();
    
    // 더 짧은 경로의 모든 노드가 더 긴 경로에 포함되어 있는지 확인
    bool containsAllNodes = shorterNodeIds.every((nodeId) => longerNodeIds.contains(nodeId));
    
    if (containsAllNodes) {
      AppLogger.exchangeDebug('중복 경로 감지: ${longerPath.nodes.length}단계 경로는 ${shorterPath.nodes.length}단계로 충분');
      return true;
    }
    
    return false;
  }

  // ==================== 그래프 구성 메서드들 END====================


  /// 순환교체용 오버레이 위젯 생성 예시
  /// 
  /// 사용법:
  /// ```dart
  /// // 기본 사용법
  /// Widget overlay1 = CircularExchangeService.createOverlay(
  ///   color: Colors.blue.shade600,
  ///   number: '2',
  /// );
  /// 
  /// // 크기와 폰트 크기 지정
  /// Widget overlay2 = CircularExchangeService.createOverlay(
  ///   color: Colors.green.shade600,
  ///   number: '3',
  ///   size: 12.0,
  ///   fontSize: 9.0,
  /// );
  /// ```
  static Widget createOverlay({
    required Color color,
    required String number,
    double size = 10.0,
    double fontSize = 8.0,
  }) {
    return SimplifiedTimetableTheme.createExchangeableOverlay(
      color: color,
      number: number,
      size: size,
      fontSize: fontSize,
    );
  }
}

/// 순환교체 결과를 나타내는 클래스
class CircularExchangeResult {
  final bool isSelected;
  final bool isDeselected;
  final bool isNoAction;
  final String? teacherName;
  final String? day;
  final int? period;
  
  CircularExchangeResult._({
    required this.isSelected,
    required this.isDeselected,
    required this.isNoAction,
    this.teacherName,
    this.day,
    this.period,
  });
  
  /// 교체 대상이 선택됨
  factory CircularExchangeResult.selected(String teacherName, String day, int period) {
    return CircularExchangeResult._(
      isSelected: true,
      isDeselected: false,
      isNoAction: false,
      teacherName: teacherName,
      day: day,
      period: period,
    );
  }
  
  /// 교체 대상이 해제됨
  factory CircularExchangeResult.deselected() {
    return CircularExchangeResult._(
      isSelected: false,
      isDeselected: true,
      isNoAction: false,
    );
  }
  
  /// 아무 동작하지 않음
  factory CircularExchangeResult.noAction() {
    return CircularExchangeResult._(
      isSelected: false,
      isDeselected: false,
      isNoAction: true,
    );
  }
}