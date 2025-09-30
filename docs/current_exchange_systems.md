# 현재 구현된 교체 시스템 문서

## 📋 목차

1. [개요](#개요)
2. [1:1 교체 시스템](#1-1-교체-시스템)
3. [순환교체 시스템](#순환교체-시스템)
4. [공통 구조](#공통-구조)
5. [성능 분석](#성능-분석)
6. [사용법 가이드](#사용법-가이드)
7. [API 참조](#api-참조)

## 개요

현재 시스템에는 두 가지 교체 방식이 구현되어 있습니다:

### 교체 방식 비교

| 교체 방식 | 설명 | 특징 | 복잡도 |
|-----------|------|------|--------|
| **1:1 교체** | 두 교사 간의 직접적인 수업 교체 | 간단하고 빠름 | O(T × D × P × N) |
| **순환교체** | 여러 교사가 순환적으로 교체하는 방식 | 복잡하지만 유연함 | O(T × N^S) |

### 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    ExchangeLogicMixin                      │
│  ┌─────────────────┐  ┌─────────────────┐                │
│  │ ExchangeService │  │CircularExchange │                │
│  │   (1:1 교체)    │  │    Service      │                │
│  │                 │  │  (순환교체)     │                │
│  └─────────────────┘  └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ExchangePath                            │
│  ┌─────────────────┐  ┌─────────────────┐                │
│  │OneToOneExchange │  │CircularExchange │                │
│  │     Path        │  │      Path       │                │
│  └─────────────────┘  └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## 1:1 교체 시스템

### 개념

1:1 교체는 두 교사 간의 직접적인 수업 교체를 의미합니다. 같은 학급을 가르치는 교사들끼리만 교체가 가능합니다.

### 교체 조건

1. **동일 학급**: 같은 학급을 가르치는 교사들끼리만 교체 가능
2. **빈 시간**: 교체 대상 교사가 선택된 시간에 빈 시간이어야 함
3. **교체 가능 상태**: `canExchange` 속성이 `true`인 수업만 교체 가능

### 교체 과정

```
초기 상태:
- 김선생: 월요일 1교시 - 3-1반 수학
- 이선생: 화요일 2교시 - 3-1반 사회

교체 후:
- 김선생: 화요일 2교시 - 3-1반 사회
- 이선생: 월요일 1교시 - 3-1반 수학
```

### 핵심 클래스

#### ExchangeService
```dart
class ExchangeService {
  // 교체 관련 상태 변수들
  String? _selectedTeacher;   // 선택된 교사명
  String? _selectedDay;       // 선택된 요일
  int? _selectedPeriod;       // 선택된 교시
  
  // 교체 가능한 시간 관련 변수들
  List<ExchangeOption> _exchangeOptions = [];
  
  /// 1:1 교체 처리 시작
  ExchangeResult startOneToOneExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  );
  
  /// 교체 가능한 시간 업데이트
  List<ExchangeOption> updateExchangeableTimes(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  );
}
```

#### ExchangeOption
```dart
class ExchangeOption {
  final TimeSlot timeSlot;      // 교체 대상 시간표 슬롯
  final String teacherName;     // 교체 대상 교사명
  final ExchangeType type;      // 교체 유형
  final int priority;           // 우선순위
  final String reason;          // 교체 이유
  
  /// 교체 가능 여부
  bool get isExchangeable => type != ExchangeType.notExchangeable;
}

enum ExchangeType {
  sameClass,           // 동일 학급 (교체 가능)
  notExchangeable,     // 교체 불가능
}
```

#### OneToOneExchangePath
```dart
class OneToOneExchangePath implements ExchangePath {
  final ExchangeNode _sourceNode;      // 선택된 원본 노드
  final ExchangeNode _targetNode;      // 교체 대상 노드
  final ExchangeOption _option;        // 원본 교체 옵션
  
  @override
  String get displayTitle => '1:1 교체';
  
  @override
  List<ExchangeNode> get nodes => [_sourceNode, _targetNode];
  
  @override
  ExchangePathType get type => ExchangePathType.oneToOne;
}
```

### 알고리즘

#### 교체 가능한 시간 탐색
```dart
List<ExchangeOption> _generateExchangeOptionsFromGridLogic(
  List<TimeSlot> timeSlots,
  List<Teacher> teachers,
) {
  List<ExchangeOption> exchangeOptions = [];
  
  // 요일별로 빈시간 검사
  const List<String> days = ['월', '화', '수', '목', '금'];
  const List<int> periods = [1, 2, 3, 4, 5, 6, 7];
  
  for (String day in days) {
    for (int period in periods) {
      // 해당 교사의 해당 요일, 교시에 수업이 있는지 확인
      bool hasClass = timeSlots.any((slot) => 
        slot.teacher == _selectedTeacher &&
        slot.dayOfWeek == DayUtils.getDayNumber(day) &&
        slot.period == period &&
        slot.isNotEmpty
      );
      
      if (!hasClass) {
        // 빈시간에 같은 반을 가르치는 교사 찾기
        List<ExchangeOption> dayExchangeOptions = _findSameClassTeachersForExchangeOptions(
          day, period, selectedClassName, timeSlots, teachers
        );
        exchangeOptions.addAll(dayExchangeOptions);
      }
    }
  }
  
  return exchangeOptions;
}
```

### 성능 특성

- **시간 복잡도**: O(T × D × P × N)
- **연산량**: 약 490,000 연산 (일반적인 학교 환경)
- **실행 시간**: ~50ms
- **메모리 사용량**: 낮음

## 순환교체 시스템

### 개념

순환교체는 여러 교사가 순환적으로 교체하는 방식입니다. 교사 A가 결강할 때 교사 B가 A의 수업을 대신하고, 교사 B의 수업은 교사 C가 대신하는 식으로 순환합니다.

### 교체 조건

1. **동일 학급**: 같은 학급을 가르치는 교사들끼리만 교체 가능
2. **한 방향 교체**: 다음 교사가 현재 교사의 시간에 수업 가능해야 함
3. **순환 완성**: 시작점으로 돌아와야 함
4. **최소 단계**: 최소 2단계 이상 필요

### 교체 과정

```
순환교체 예시 (3단계):
김선생(결강) → 이선생(김선생 수업 대신) → 박선생(이선생 수업 대신) → 김선생(박선생 수업 대신)

초기 상태:
- 김선생: 월요일 1교시 - 3-1반 수학
- 이선생: 화요일 2교시 - 3-1반 사회  
- 박선생: 수요일 3교시 - 3-1반 영어

순환교체 후:
- 김선생: 수요일 3교시 - 3-1반 영어
- 이선생: 월요일 1교시 - 3-1반 수학
- 박선생: 화요일 2교시 - 3-1반 사회
```

### 핵심 클래스

#### CircularExchangeService
```dart
class CircularExchangeService {
  // 상수 정의
  static const int defaultMaxSteps = 3;        // 기본 최대 단계 수
  static const bool defaultExactSteps = false;  // 기본 단계 검사 방식
  
  // 교체 관련 상태 변수들
  String? _selectedTeacher;
  String? _selectedDay;
  int? _selectedPeriod;
  
  /// 순환교체 모드에서 셀 탭 처리
  CircularExchangeResult startCircularExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  );
  
  /// 그래프를 구성하고 모든 교체 가능한 경로를 찾는 메서드
  List<CircularExchangePath> findCircularExchangePaths(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    {int maxSteps = defaultMaxSteps,
     bool exactSteps = defaultExactSteps}
  );
}
```

#### CircularExchangePath
```dart
class CircularExchangePath implements ExchangePath {
  final List<ExchangeNode> _nodes;  // 순환 경로에 참여하는 노드들
  final int steps;                   // 순환 단계 수 (시작 교사 제외)
  final String _description;        // 사람이 읽기 쉬운 경로 설명
  
  /// 노드 리스트로부터 자동으로 경로 생성
  factory CircularExchangePath.fromNodes(List<ExchangeNode> nodes) {
    // 순환 경로인지 확인 (시작점과 끝점이 같아야 함)
    if (nodes.first != nodes.last) {
      throw ArgumentError('순환 경로가 아닙니다. 시작점과 끝점이 같아야 합니다.');
    }
    
    int steps = nodes.length - 1; // 시작점 복귀 제외
    String description = _generateDescription(nodes);
    
    return CircularExchangePath(
      nodes: nodes,
      steps: steps,
      description: description,
    );
  }
  
  @override
  String get displayTitle => '순환교체 경로 $steps단계';
  
  @override
  ExchangePathType get type => ExchangePathType.circular;
}
```

### 알고리즘

#### DFS 기반 순환 경로 탐색
```dart
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
      bool shouldAddPath = exactSteps ? 
        (currentStep == maxSteps) :  // 정확히 해당 단계만
        (currentStep <= maxSteps);   // 해당 단계까지
      
      if (shouldAddPath) {
        List<ExchangeNode> completePath = [...currentPath, startNode];
        allPaths.add(completePath);
      }
      return;
    }
    
    // 현재 노드를 경로에 추가
    currentPath.add(currentNode);
    visited.add(currentNode.nodeId);
    
    // 인접 노드들 찾기
    List<ExchangeNode> adjacentNodes = findAdjacentNodes(
      currentNode, timeSlots, teachers
    );
    
    // 각 인접 노드에 대해 재귀 탐색
    for (ExchangeNode nextNode in adjacentNodes) {
      if (visited.contains(nextNode.nodeId) && nextNode.nodeId != startNode.nodeId) {
        continue;
      }
      
      if (_isOneWayExchangeable(currentNode, nextNode, timeSlots)) {
        dfs(nextNode, List.from(currentPath), Set.from(visited), currentStep + 1);
      }
    }
  }
  
  // DFS 시작
  dfs(startNode, [], {}, 0);
  
  return allPaths;
}
```

#### 인접 노드 탐색
```dart
List<ExchangeNode> findAdjacentNodes(
  ExchangeNode currentNode,
  List<TimeSlot> timeSlots,
  List<Teacher> teachers,
) {
  List<ExchangeNode> adjacentNodes = [];
  Set<String> addedNodeIds = {};
  
  // 같은 학급을 가르치는 모든 시간표 슬롯 찾기
  List<TimeSlot> sameClassSlots = timeSlots.where((slot) => 
    slot.className == currentNode.className &&
    slot.isNotEmpty &&
    slot.canExchange &&
    slot.teacher != currentNode.teacherName // 같은 교사 제외
  ).toList();
  
  // 각 슬롯을 ExchangeNode로 변환하고 한 방향 교체 가능성 확인
  for (TimeSlot slot in sameClassSlots) {
    ExchangeNode node = ExchangeNode(
      teacherName: slot.teacher ?? '',
      day: _getDayString(slot.dayOfWeek ?? 0),
      period: slot.period ?? 0,
      className: slot.className ?? '',
    );
    
    if (!addedNodeIds.contains(node.nodeId)) {
      if (_isOneWayExchangeable(currentNode, node, timeSlots)) {
        adjacentNodes.add(node);
        addedNodeIds.add(node.nodeId);
      }
    }
  }
  
  return adjacentNodes;
}
```

### 성능 특성

- **시간 복잡도**: O(T × N^S) (S = 최대 단계 수)
- **연산량**: 
  - 3단계: 약 5,600,000 연산
  - 4단계: 약 112,000,000 연산
- **실행 시간**: 
  - 3단계: ~500ms
  - 4단계: ~11초
- **메모리 사용량**: 중간~높음

## 공통 구조

### ExchangePath 인터페이스

모든 교체 경로는 `ExchangePath` 인터페이스를 구현합니다:

```dart
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

enum ExchangePathType {
  oneToOne,    // 1:1교체 (2개 노드)
  circular,    // 순환교체 (3+ 노드)
}
```

### ExchangeNode

교체 경로의 각 단계를 나타내는 노드:

```dart
class ExchangeNode {
  final String teacherName;  // 교사명
  final String day;           // 요일 (월, 화, 수, 목, 금)
  final int period;           // 교시 (1-7)
  final String className;     // 학급명 (1-1, 2-3 등)
  
  /// 노드의 고유 식별자 생성
  String get nodeId => '${teacherName}_${day}_$period교시_$className';
  
  /// 노드의 표시용 문자열 생성
  String get displayText => '$teacherName($day$period교시, $className)';
}
```

### ExchangeLogicMixin

교체 로직을 담당하는 Mixin:

```dart
mixin ExchangeLogicMixin<T extends StatefulWidget> on State<T> {
  // 추상 속성들 - 구현 클래스에서 제공해야 함
  ExchangeService get exchangeService;
  CircularExchangeService get circularExchangeService;
  TimetableData? get timetableData;
  TimetableDataSource? get dataSource;
  bool get isExchangeModeEnabled;
  bool get isCircularExchangeModeEnabled;
  
  /// 1:1 교체 처리 시작
  void startOneToOneExchange(DataGridCellTapDetails details);
  
  /// 순환교체 처리 시작
  void startCircularExchange(DataGridCellTapDetails details);
  
  /// 교체 가능한 시간 업데이트
  void updateExchangeableTimes();
}
```

## 성능 분석

### 연산량 비교

| 교체 방식 | 시간 복잡도 | 연산량 | 실행 시간 | 메모리 사용량 |
|-----------|-------------|--------|-----------|---------------|
| **1:1 교체** | O(T × D × P × N) | 490,000 | ~50ms | 낮음 |
| **순환교체 3단계** | O(T × N³) | 5,600,000 | ~500ms | 중간 |
| **순환교체 4단계** | O(T × N⁴) | 112,000,000 | ~11초 | 높음 |

### 성능 그래프

```
연산량 (백만 단위)
120 ┤
100 ┤                    ████████████████████████████████████████ 순환교체 4단계
 80 ┤
 60 ┤
 40 ┤
 20 ┤
  5 ┤  ████████████████████████████████████████████████████████████ 순환교체 3단계
  0 ┤  ████████████████████████████████████████████████████████████ 1:1 교체
    └─────────────────────────────────────────────────────────────
     1:1교체  순환교체  순환교체
             3단계    4단계
```

### 최적화 방안

#### 1. 인덱스 활용
```dart
class OptimizedExchangeService {
  Map<String, List<TimeSlot>> _classIndex = {};
  Map<String, List<TimeSlot>> _teacherIndex = {};
  
  void buildIndexes(List<TimeSlot> timeSlots) {
    for (TimeSlot slot in timeSlots) {
      _classIndex.putIfAbsent(slot.className, () => []).add(slot);
      _teacherIndex.putIfAbsent(slot.teacher, () => []).add(slot);
    }
  }
}
```

#### 2. 캐싱 활용
```dart
Map<String, bool> _exchangeabilityCache = {};

bool _isExchangeableCached(String key) {
  return _exchangeabilityCache[key] ??= _calculateExchangeability(key);
}
```

#### 3. 백그라운드 처리
```dart
Future<List<CircularExchangePath>> findCircularPathsAsync(
  List<TimeSlot> timeSlots,
  List<Teacher> teachers,
) async {
  return await compute(_findCircularPathsInBackground, {
    'timeSlots': timeSlots,
    'teachers': teachers,
  });
}
```

## 사용법 가이드

### 1:1 교체 사용법

#### 1단계: 교체 모드 활성화
```dart
// 교체 모드 토글
void _toggleExchangeMode() {
  setState(() {
    _isExchangeModeEnabled = !_isExchangeModeEnabled;
  });
}
```

#### 2단계: 교체할 셀 선택
```dart
// 셀 탭 이벤트 처리
onCellTap: (details) {
  if (_isExchangeModeEnabled) {
    startOneToOneExchange(details);
  }
}
```

#### 3단계: 교체 가능한 옵션 확인
```dart
// 교체 가능한 시간 업데이트
void updateExchangeableTimes() {
  List<ExchangeOption> options = exchangeService.updateExchangeableTimes(
    timetableData!.timeSlots,
    timetableData!.teachers,
  );
  
  // UI에 교체 옵션 표시
  _showExchangeOptions(options);
}
```

#### 4단계: 교체 실행
```dart
// 교체 옵션 선택 시 실행
void _executeExchange(ExchangeOption option) {
  // 실제 교체 로직 실행
  _performExchange(option);
  
  // UI 업데이트
  setState(() {
    // 시간표 새로고침
  });
}
```

### 순환교체 사용법

#### 1단계: 순환교체 모드 활성화
```dart
// 순환교체 모드 토글
void _toggleCircularExchangeMode() {
  setState(() {
    _isCircularExchangeModeEnabled = !_isCircularExchangeModeEnabled;
  });
}
```

#### 2단계: 시작 셀 선택
```dart
// 셀 탭 이벤트 처리
onCellTap: (details) {
  if (_isCircularExchangeModeEnabled) {
    startCircularExchange(details);
  }
}
```

#### 3단계: 순환 경로 탐색
```dart
// 순환 경로 탐색
Future<void> findCircularPathsWithProgress() async {
  // 진행률 표시
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        children: [
          CircularProgressIndicator(),
          Text('순환교체 경로를 탐색 중...'),
        ],
      ),
    ),
  );
  
  try {
    // 백그라운드에서 순환 경로 탐색
    List<CircularExchangePath> paths = await compute(
      _findCircularPathsInBackground,
      {
        'timeSlots': timetableData!.timeSlots,
        'teachers': timetableData!.teachers,
      },
    );
    
    Navigator.of(context).pop();
    
    if (paths.isEmpty) {
      showSnackBar('순환교체 가능한 경로가 없습니다.');
    } else {
      _showCircularPathsDialog(paths);
    }
  } catch (e) {
    Navigator.of(context).pop();
    showSnackBar('순환교체 경로 탐색 중 오류가 발생했습니다: $e');
  }
}
```

#### 4단계: 순환 경로 선택 및 실행
```dart
// 순환 경로 목록 다이얼로그
void _showCircularPathsDialog(List<CircularExchangePath> paths) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('순환교체 경로 목록'),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: paths.length,
          itemBuilder: (context, index) {
            CircularExchangePath path = paths[index];
            return ListTile(
              title: Text(path.displayTitle),
              subtitle: Text(path.description),
              trailing: Icon(Icons.swap_horiz),
              onTap: () {
                Navigator.of(context).pop();
                _executeCircularExchange(path);
              },
            );
          },
        ),
      ),
    ),
  );
}
```

## API 참조

### ExchangeService

#### 주요 메서드

| 메서드 | 설명 | 반환값 |
|--------|------|--------|
| `startOneToOneExchange()` | 1:1 교체 처리 시작 | `ExchangeResult` |
| `updateExchangeableTimes()` | 교체 가능한 시간 업데이트 | `List<ExchangeOption>` |
| `getCurrentExchangeableTeachers()` | 교체 가능한 교사 정보 가져오기 | `List<Map<String, dynamic>>` |
| `clearAllSelections()` | 모든 선택 상태 초기화 | `void` |
| `hasSelectedCell()` | 교체 모드 활성화 상태 확인 | `bool` |

#### ExchangeResult

```dart
class ExchangeResult {
  final bool isSelected;      // 교체 대상이 선택됨
  final bool isDeselected;    // 교체 대상이 해제됨
  final bool isNoAction;      // 아무 동작하지 않음
  final String? teacherName;  // 교사명
  final String? day;          // 요일
  final int? period;          // 교시
}
```

### CircularExchangeService

#### 주요 메서드

| 메서드 | 설명 | 반환값 |
|--------|------|--------|
| `startCircularExchange()` | 순환교체 처리 시작 | `CircularExchangeResult` |
| `findCircularExchangePaths()` | 순환교체 경로 탐색 | `List<CircularExchangePath>` |
| `getCircularExchangeableTeachers()` | 순환교체 가능한 교사 정보 | `List<Map<String, dynamic>>` |
| `clearAllSelections()` | 모든 선택 상태 초기화 | `void` |
| `hasSelectedCell()` | 교체 모드 활성화 상태 확인 | `bool` |

#### CircularExchangeResult

```dart
class CircularExchangeResult {
  final bool isSelected;      // 교체 대상이 선택됨
  final bool isDeselected;    // 교체 대상이 해제됨
  final bool isNoAction;      // 아무 동작하지 않음
  final String? teacherName;  // 교사명
  final String? day;          // 요일
  final int? period;          // 교시
}
```

### ExchangePath

#### 공통 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `id` | `String` | 경로의 고유 식별자 |
| `displayTitle` | `String` | 경로의 표시용 제목 |
| `nodes` | `List<ExchangeNode>` | 경로에 포함된 노드들 |
| `type` | `ExchangePathType` | 교체 경로의 타입 |
| `isSelected` | `bool` | 경로가 선택된 상태인지 여부 |
| `description` | `String` | 경로의 설명 텍스트 |
| `priority` | `int` | 경로의 우선순위 |

#### ExchangePathType

```dart
enum ExchangePathType {
  oneToOne,    // 1:1교체 (2개 노드)
  circular,    // 순환교체 (3+ 노드)
}
```

### ExchangeNode

#### 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `teacherName` | `String` | 교사명 |
| `day` | `String` | 요일 (월, 화, 수, 목, 금) |
| `period` | `int` | 교시 (1-7) |
| `className` | `String` | 학급명 (1-1, 2-3 등) |

#### 메서드

| 메서드 | 반환값 | 설명 |
|--------|--------|------|
| `nodeId` | `String` | 노드의 고유 식별자 생성 |
| `displayText` | `String` | 노드의 표시용 문자열 생성 |

## 결론

현재 구현된 교체 시스템은 다음과 같은 특징을 가집니다:

### 장점
1. **모듈화된 설계**: 각 교체 방식이 독립적으로 구현됨
2. **공통 인터페이스**: `ExchangePath` 인터페이스로 일관성 유지
3. **확장 가능성**: 새로운 교체 방식 추가 용이
4. **성능 최적화**: 인덱스와 캐싱을 통한 성능 개선 가능

### 개선 방안
1. **성능 최적화**: 특히 순환교체의 성능 개선 필요
2. **사용자 경험**: 백그라운드 처리로 UI 블로킹 방지
3. **테스트 커버리지**: 포괄적인 테스트 케이스 추가
4. **문서화**: API 문서 및 사용법 가이드 보완

이 시스템은 학교 시간표 관리에 필요한 기본적인 교체 기능을 제공하며, 향후 연쇄교체와 같은 새로운 교체 방식 추가를 위한 견고한 기반을 제공합니다.

