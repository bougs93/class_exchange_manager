import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/exchange_algorithm.dart';
import '../utils/timetable_data_source.dart';
import '../utils/logger.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/exchange_node.dart';
import '../models/circular_exchange_path.dart';

/// 순환교체 서비스 클래스
/// 여러 교사 간의 순환 교체 비즈니스 로직을 담당
class CircularExchangeService {
  // ==================== 상수 정의 ====================
  
  /// 기본 최대 단계 수 (순환 교체에서 최대 몇 단계까지 탐색할지)
  static const int defaultMaxSteps = 3;
  
  /// 기본 단계 검사 방식 (false: 해당 단계까지, true: 정확히 해당 단계만)
  static const bool defaultExactSteps = false;
  
  // ==================== 인스턴스 변수 ====================
  // 교체 관련 상태 변수들
  String? _selectedTeacher;   // 선택된 교사명
  String? _selectedDay;       // 선택된 요일
  int? _selectedPeriod;       // 선택된 교시
  
  // 교체 가능한 시간 관련 변수들
  final List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들
  
  // Getters
  String? get selectedTeacher => _selectedTeacher;
  String? get selectedDay => _selectedDay;
  int? get selectedPeriod => _selectedPeriod;
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
    
    // 교체할 셀의 교사명 찾기 (헤더를 고려한 행 인덱스 계산)
    String teacherName = _getTeacherNameFromCell(details, dataSource);
    
    // 동일한 셀을 다시 클릭했는지 확인 (토글 기능)
    bool isSameCell = _selectedTeacher == teacherName && 
                     _selectedDay == day && 
                     _selectedPeriod == period;
    
    if (isSameCell) {
      // 동일한 셀 클릭 시 교체 대상 해제
      _clearCellSelection();
      return CircularExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      _selectCell(teacherName, day, period);
      return CircularExchangeResult.selected(teacherName, day, period);
    }
  }
  
  /// 셀에서 교사명 추출
  String _getTeacherNameFromCell(DataGridCellTapDetails details, TimetableDataSource dataSource) {
    String teacherName = '';
    
    // Syncfusion DataGrid에서 헤더는 다음과 같이 구성됨:
    // - 일반 헤더: 1개 (컬럼명 표시)
    // - 스택된 헤더: 1개 (요일별 병합)
    // 총 2개의 헤더 행이 있으므로 실제 데이터 행 인덱스는 2를 빼야 함
    int actualRowIndex = details.rowColumnIndex.rowIndex - 2;
    
    if (actualRowIndex >= 0 && actualRowIndex < dataSource.rows.length) {
      DataGridRow row = dataSource.rows[actualRowIndex];
      for (DataGridCell rowCell in row.getCells()) {
        if (rowCell.columnName == 'teacher') {
          teacherName = rowCell.value.toString();
          break;
        }
      }
    }
    return teacherName;
  }
  
  /// 셀 선택 상태 설정
  void _selectCell(String teacherName, String day, int period) {
    _selectedTeacher = teacherName;
    _selectedDay = day;
    _selectedPeriod = period;
  }
  
  /// 셀 선택 해제
  void _clearCellSelection() {
    _selectedTeacher = null;
    _selectedDay = null;
    _selectedPeriod = null;
  }
  
  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    _clearCellSelection();
    _exchangeOptions.clear();
  }
  
  /// 교체 모드 활성화 상태 확인
  bool hasSelectedCell() {
    return _selectedTeacher != null && _selectedDay != null && _selectedPeriod != null;
  }
  
  /// 순환교체용 교체 가능한 교사 정보 가져오기 (1스탭: 같은 학급, 다른 시간대, 양쪽 빈시간)
  /// 
  /// 1개 스탭 교체에서는:
  /// - 같은 학급만 교체 가능
  /// - 다른 시간대여야 함
  /// - 양쪽 모두 빈 시간이어야 함
  /// 예: 김선생(월1교시, 1학년 1반) ↔ 이선생(화2교시, 1학년 1반) - 둘 다 빈시간
  List<Map<String, dynamic>> getCircularExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return [];
    }
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = _getSelectedClassName(timeSlots);
    if (selectedClassName == null) return [];
    
    List<Map<String, dynamic>> exchangeableTeachers = [];
    
    // 같은 학급을 가르치는 교사들 중에서 찾기
    for (Teacher teacher in teachers) {
      if (teacher.name == _selectedTeacher) continue; // 자기 자신 제외
      
      // 해당 교사가 다른 시간대에 같은 학급을 가르치는지 확인
      List<TimeSlot> teacherSlots = timeSlots.where((slot) => 
        slot.teacher == teacher.name &&
        slot.className == selectedClassName &&
        slot.isNotEmpty &&
        !(slot.dayOfWeek == _getDayNumber(_selectedDay!) && slot.period == _selectedPeriod) // 다른 시간대
      ).toList();
      
      for (TimeSlot teacherSlot in teacherSlots) {
        // 양쪽 모두 빈 시간인지 확인
        bool selectedTeacherHasEmptyTime = _isTeacherEmptyAtTime(
          _selectedTeacher!, _selectedDay!, _selectedPeriod!, timeSlots);
        bool otherTeacherHasEmptyTime = _isTeacherEmptyAtTime(
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
  
  /// 선택된 셀의 학급 정보 가져오기
  String? _getSelectedClassName(List<TimeSlot> timeSlots) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return null;
    }
    
    TimeSlot? selectedSlot = timeSlots.firstWhere(
      (slot) => slot.teacher == _selectedTeacher &&
                slot.dayOfWeek == _getDayNumber(_selectedDay!) &&
                slot.period == _selectedPeriod &&
                slot.isNotEmpty,
      orElse: () => TimeSlot.empty(),
    );
    
    return selectedSlot.isNotEmpty ? selectedSlot.className : null;
  }
  
  /// 교사가 특정 시간에 빈 시간인지 확인
  bool _isTeacherEmptyAtTime(String teacherName, String day, int period, List<TimeSlot> timeSlots) {
    return !timeSlots.any((slot) => 
      slot.teacher == teacherName &&
      slot.dayOfWeek == _getDayNumber(day) &&
      slot.period == period &&
      slot.isNotEmpty
    );
  }
  
  /// 요일 문자열을 숫자로 변환하는 헬퍼 메서드
  int _getDayNumber(String day) {
    const Map<String, int> dayMap = {
      '월': 1, '화': 2, '수': 3, '목': 4, '금': 5
    };
    return dayMap[day] ?? 0;
  }
  
  /// 요일 숫자를 문자열로 변환하는 헬퍼 메서드
  String _getDayString(int dayNumber) {
    const Map<int, String> dayMap = {
      1: '월', 2: '화', 3: '수', 4: '목', 5: '금'
    };
    return dayMap[dayNumber] ?? '알 수 없음';
  }

  // ==================== 그래프 구성 메서드들 START ====================
  /*
  [순환 경로 찾기]
    모든 가능한 교체 경로를 찾아서 리스트로 만듦
    예: "김선생 → 이선생 → 박선생 → 김선생" 같은 순환 경로
  */

  /// 그래프를 구성하고 모든 교체 가능한 경로를 찾는 메서드
  /// 
  /// 반환값:
  /// - `List<CircularExchangePath>`: 찾은 모든 순환 교체 경로들
  List<CircularExchangePath> findCircularExchangePaths(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    {int maxSteps = defaultMaxSteps,  // 최대 단계 수 (기본값: 상수 사용)
     bool exactSteps = defaultExactSteps}  // 정확히 해당 단계만 검사할지 여부 (기본값: 상수 사용)
  ) {
    List<CircularExchangePath> allPaths = [];
    
    // 선택된 노드가 없으면 빈 리스트 반환
    ExchangeNode? startNode = getSelectedNode(timeSlots);  // 1단계 : 시작 노트 찾기 (getSelectedNode)
    if (startNode == null) {
      AppLogger.exchangeDebug('시작 노드를 찾을 수 없습니다.');
      return allPaths;
    }
    
    AppLogger.exchangeDebug('순환 경로 탐색 시작: ${startNode.displayText}');
    
    // DFS로 순환 경로 탐색
    List<List<ExchangeNode>> foundPaths = _findCircularPathsDFS(  //2단계: DFS 탐색 (_findCircularPathsDFS)
      startNode, 
      timeSlots, 
      teachers, 
      maxSteps,
      exactSteps
    );
    
    // 찾은 경로들을 CircularExchangePath로 변환
    for (List<ExchangeNode> path in foundPaths) {
      try {
        CircularExchangePath circularPath = CircularExchangePath.fromNodes(path);
        if (circularPath.isValid) {
          allPaths.add(circularPath);
        }
      } catch (e) {
        // 유효하지 않은 경로는 무시
        continue;
      }
    }
    
    // 우선순위별로 정렬 (단계 수가 적은 것부터)
    allPaths.sort((a, b) => a.steps.compareTo(b.steps));
    
    return allPaths;
  }

  /* 1단계 : 시작 노트 찾기
    시작 노트 찾기 : 사용자가 클릭한 셀 정보를 노드로 만듦
    예: "김선생님, 월요일 1교시, 3-1반" → ExchangeNode 생성
  */
  /// 선택된 셀을 ExchangeNode로 변환
  /// 
  /// 
  ExchangeNode? getSelectedNode(List<TimeSlot> timeSlots) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return null;
    }
    
    // 선택된 셀의 학급 정보 가져오기
    String? className = _getSelectedClassName(timeSlots);
    if (className == null) {
      AppLogger.exchangeDebug('학급 정보를 찾을 수 없습니다: $_selectedTeacher, $_selectedDay, $_selectedPeriod');
      return null;
    }
    
    return ExchangeNode(
      teacherName: _selectedTeacher!,
      day: _selectedDay!,
      period: _selectedPeriod!,
      className: className,
    );
  }


  /*
  2단계: DFS 탐색 (_findCircularPathsDFS)
  깊이 우선 탐색으로 모든 경우의 수를 체크:
  김선생(시작)
  ├── 이선생 탐색
  │   ├── 박선생 탐색
  │   │   └── 김선생(끝) ✅ 순환 완성!
  │   └── 최선생 탐색
  │       └── ... 계속 탐색
  └── 박선생 탐색
      └── ... 계속 탐색
  */
  /// DFS를 사용하여 순환 경로를 찾는 재귀 메서드
  List<List<ExchangeNode>> _findCircularPathsDFS(
    ExchangeNode startNode,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    int maxSteps,
    bool exactSteps,
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
      if (currentStep >= 2 && currentNode.nodeId == startNode.nodeId) {
        // exactSteps 옵션에 따라 조건 확인
        bool shouldAddPath = exactSteps ? 
          (currentStep == maxSteps) :  // 정확히 해당 단계만
          (currentStep <= maxSteps);   // 해당 단계까지
        
        if (shouldAddPath) {
          // 시작점을 경로 끝에 추가하여 완전한 연쇄 교체 경로 생성
          List<ExchangeNode> completePath = List.from(currentPath)..add(startNode);
          allPaths.add(completePath);
        }
        return;
      }
      
      // 현재 노드를 경로에 추가
      currentPath.add(currentNode);
      visited.add(currentNode.nodeId);
      
      // 인접 노드들 찾기
      List<ExchangeNode> adjacentNodes = findAdjacentNodes(
        currentNode, 
        timeSlots, 
        teachers,
        showLog: currentStep == 0, // 첫 번째 호출에서만 로그 출력
      );
      
      // 각 인접 노드에 대해 재귀 탐색
      for (ExchangeNode nextNode in adjacentNodes) {
        // 이미 방문한 노드는 제외 (시작점 제외)
        if (visited.contains(nextNode.nodeId) && nextNode.nodeId != startNode.nodeId) {
          continue;
        }
        
        // 방향 그래프 교체 가능성 검증 (한 방향만)
        if (_isOneWayExchangeable(currentNode, nextNode, timeSlots)) {
          dfs(nextNode, List.from(currentPath), Set.from(visited), currentStep + 1);
        }
      }
    }
    
    // DFS 시작 (시작점은 visited에 추가하지 않음)
    dfs(startNode, [], {}, 0);
    
    return allPaths;
  }


  /*
  3단계 : 같은 학급(3-1반)을 가르치는 다른 교사들 찾기
    시작: 김선생 - 월요일 1교시 - 3-1반
    찾은 친구들:
    → 이선생 - 화요일 3교시 - 3-1반
    → 박선생 - 수요일 2교시 - 3-1반
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
    List<Teacher> teachers, {
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
        );
        
        // 중복 노드 방지
        if (!addedNodeIds.contains(node.nodeId)) {
          // 한 방향 교체 가능성 확인 (다음 교사가 현재 교사의 시간에 수업 가능한가?)
          if (_isOneWayExchangeable(currentNode, node, timeSlots)) {
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
  4단계: 교체 가능성 검증 (_isOneWayExchangeable)
    조건: 한 방향 교체 가능 (다음 교사가 현재 교사의 시간에 수업 가능)
  */
  
  /// 방향 그래프를 위한 한 방향 교체 가능성을 확인하는 메서드
  /// 
  /// 조건:
  /// 1. to 교사가 from 교사의 시간에 수업 가능해야 함
  /// 2. 연쇄 교체 방식: from이 결강할 때 to가 from 대신 수업
  bool _isOneWayExchangeable(
    ExchangeNode from,
    ExchangeNode to,
    List<TimeSlot> timeSlots,
  ) {
    // to 교사가 from 교사의 시간에 수업 가능한지 확인
    // (to 교사가 from 교사의 시간에 빈 시간이어야 함)
    bool toEmptyAtFromTime = !timeSlots.any((slot) => 
      slot.teacher == to.teacherName &&
      slot.dayOfWeek == _getDayNumber(from.day) &&
      slot.period == from.period &&
      slot.isNotEmpty
    );
    
    return toEmptyAtFromTime;
  }
  

  /// 노드에 과목 정보를 포함한 문자열 생성
  String _getNodeWithSubject(ExchangeNode node, List<TimeSlot> timeSlots) {
    // 해당 노드의 TimeSlot 찾기
    TimeSlot? slot = timeSlots.firstWhere(
      (s) => s.teacher == node.teacherName &&
             s.dayOfWeek == _getDayNumber(node.day) &&
             s.period == node.period &&
             s.className == node.className,
      orElse: () => TimeSlot.empty(),
    );
    
    String subject = slot.isNotEmpty ? (slot.subject ?? '과목없음') : '과목없음';
    return '${node.teacherName}(${node.day}${node.period}교시, ${node.className}, $subject)';
  }

  /// 교체 가능한 교사 정보를 로그로 출력
  void logCircularExchangeInfo(List<CircularExchangePath> paths, List<TimeSlot> timeSlots) {
    if (_selectedTeacher == null) return;
    
    if (paths.isEmpty) {
      AppLogger.exchangeInfo('순환 교체 가능한 경로가 없습니다.');
    } else {
      for (int i = 0; i < paths.length; i++) {
        CircularExchangePath path = paths[i];
        
        // 과목 정보를 포함한 경로 설명 생성
        String pathWithSubjects = path.nodes.map((n) => _getNodeWithSubject(n, timeSlots)).join(' → ');
        
        AppLogger.exchangeInfo('경로 ${i + 1} [${path.steps}단계]: $pathWithSubjects');
      }
    }
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