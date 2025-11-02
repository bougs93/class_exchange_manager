# 수업 교체 버튼 클릭 후 셀 색상 변경 로직 분석

## 개요

시간표 테이블에서 수업 교체 버튼을 클릭하면, 교체된 셀들이 시각적으로 구분될 수 있도록 색상이 변경됩니다. 이 문서는 그 동작 흐름을 단계별로 설명합니다.

## 주요 개념

### 교체된 셀의 두 가지 타입

1. **교체된 소스 셀 (Exchanged Source Cell)**
   - 교체 전 원본 수업이 있던 셀
   - 시각적 표시: **파란색 테두리** (2px 실선)
   - 예: "홍길동"의 "월 3교시" 셀 (교체 전)

2. **교체된 목적지 셀 (Exchanged Destination Cell)**
   - 교체 후 새 교사가 배정된 셀
   - 시각적 표시: **연한 파란색 배경색** (RGB: 144, 199, 245)
   - 예: "김철수"가 이동한 "월 3교시" 셀 (교체 후)

## 전체 흐름도

```
[1] 교체 버튼 클릭
    ↓
[2] ExchangeExecutor.executeExchange()
    ↓
[3] ExchangeHistoryService.executeExchange() - 교체 리스트에 추가
    ↓
[4] ExchangeExecutor._executeCommonPostProcess()
    ↓
[5] ExchangeExecutor._updateExchangedCells()
    ↓
[6] 교체된 셀 정보 추출
    ├─ _extractExchangedCells() → 소스 셀 목록
    └─ _extractDestinationCells() → 목적지 셀 목록
    ↓
[7] CellSelectionProvider 상태 업데이트
    ├─ updateExchangedCells() → 소스 셀 Set 저장
    └─ updateExchangedDestinationCells() → 목적지 셀 Set 저장
    ↓
[8] TimetableDataSource 캐시 초기화 및 UI 업데이트
    ├─ _clearCacheAndNotify() → 로컬 캐시 초기화
    └─ notifyDataChanged() → Syncfusion DataGrid 재렌더링 트리거
    ↓
[9] TimetableDataSource.buildRow() - 셀 상태 정보 생성
    ├─ _createDataCellState() → CellStateInfo 생성
    └─ isExchangedSourceCell, isExchangedDestinationCell 플래그 설정
    ↓
[10] SimplifiedTimetableCell 위젯 생성
    ├─ SimplifiedTimetableTheme.getCellStyleFromConfig() 호출
    └─ 셀 스타일 결정 (배경색, 테두리)
    ↓
[11] UI 화면에 색상 변경 반영
```

## 상세 단계 분석

### 1단계: 교체 버튼 클릭

**위치**: `lib/ui/widgets/timetable_grid_section.dart`

```dart
ExchangeActionButtons(
  onExchange: () => _exchangeExecutor.executeExchange(
    currentSelectedPath, 
    context, 
    onInternalPathClear
  ),
)
```

### 2단계: 교체 실행 (ExchangeExecutor.executeExchange)

**위치**: `lib/ui/widgets/timetable_grid/exchange_executor.dart`

```96:129:lib/ui/widgets/timetable_grid/exchange_executor.dart
void executeExchange(
  ExchangePath exchangePath,
  BuildContext context,
  VoidCallback onInternalPathClear,
) {
  final historyService = ref.read(exchangeHistoryServiceProvider);

  // 교체 실행 - 순환교체의 경우 단계 수 전달
  int? stepCount;
  if (exchangePath is CircularExchangePath) {
    stepCount = exchangePath.nodes.length; // 노드 수 = 단계 수
  }
  
  historyService.executeExchange(
    exchangePath,
    customDescription: '교체 실행: ${exchangePath.displayTitle}',
    additionalMetadata: {
      'executionTime': DateTime.now().toIso8601String(),
      'userAction': 'manual',
      'source': 'timetable_grid_section',
    },
    stepCount: stepCount,
  );

  // 공통 후처리
  _executeCommonPostProcess(
    context: context,
    onInternalPathClear: onInternalPathClear,
    message: '교체 경로 "${exchangePath.id}"가 실행되었습니다',
    snackBarColor: Colors.blue,
    undoButtonLabel: '되돌리기',
    onUndoPressed: () => undoLastExchange(context, onInternalPathClear),
  );
}
```

**주요 작업**:
- 교체 경로를 교체 히스토리 서비스에 추가
- 공통 후처리 메서드 호출

### 3단계: 교체 히스토리 추가 (ExchangeHistoryService.executeExchange)

**위치**: `lib/services/exchange_history_service.dart`

**주요 작업**:
- `ExchangeHistoryItem` 생성 및 `_exchangeList`에 추가
- 로컬 저장소에 저장
- 버전 번호 증가 (UI 업데이트 트리거)

### 4단계: 공통 후처리 (_executeCommonPostProcess)

**위치**: `lib/ui/widgets/timetable_grid/exchange_executor.dart`

**주요 작업**:
- 교체된 셀 상태 업데이트 호출
- UI 업데이트
- 사용자 피드백 (SnackBar 표시)

### 5단계: 교체된 셀 상태 업데이트 (_updateExchangedCells)

**위치**: `lib/ui/widgets/timetable_grid/exchange_executor.dart`

```427:444:lib/ui/widgets/timetable_grid/exchange_executor.dart
void _updateExchangedCells() {
  final cellNotifier = ref.read(cellSelectionProvider.notifier);
  
  // 교체된 셀 정보 추출
  final exchangedCells = _extractExchangedCells();
  final destinationCells = _extractDestinationCells();
  
  AppLogger.exchangeDebug('🔄 [ExchangeExecutor] 교체된 셀 정보 업데이트:');
  AppLogger.exchangeDebug('  - 소스 셀: ${exchangedCells.length}개 - $exchangedCells');
  AppLogger.exchangeDebug('  - 목적지 셀: ${destinationCells.length}개 - $destinationCells');
     
  // 교체된 소스 셀(교체 전 원본 수업이 있던 셀)의 테두리 스타일 업데이트
  cellNotifier.updateExchangedCells(exchangedCells);
  // 교체된 목적지 셀(교체 후 새 교사가 배정된 셀)의 배경색 업데이트
  cellNotifier.updateExchangedDestinationCells(destinationCells);
  
  AppLogger.exchangeDebug('✅ [ExchangeExecutor] 교체된 셀 상태 업데이트 완료');
}
```

**주요 작업**:
- 교체 리스트에서 소스 셀과 목적지 셀 정보 추출
- `CellSelectionProvider`에 상태 업데이트

### 6단계: 교체된 셀 정보 추출

#### 6-1. 소스 셀 추출 (_extractExchangedCells)

**위치**: `lib/ui/widgets/timetable_grid/exchange_executor.dart`

**로직**:
- 교체 리스트의 모든 항목을 순회
- 교체 타입에 따라 소스 셀 키 추출
  - **1:1 교체**: sourceNode와 targetNode 모두 소스 셀
  - **순환교체**: 마지막 노드를 제외한 모든 노드가 소스 셀
  - **연쇄교체**: nodeA, nodeB, node1, node2 모두 소스 셀
  - **보강교체**: sourceNode만 소스 셀

**셀 키 형식**: `"{teacherName}_{day}_{period}"`
예: `"홍길동_월_3"`

#### 6-2. 목적지 셀 추출 (_extractDestinationCells)

**위치**: `lib/ui/widgets/timetable_grid/exchange_executor.dart`

**로직**:
- 교체 리스트의 모든 항목을 순회
- 교체 타입에 따라 목적지 셀 키 추출
  - **1:1 교체**: 교사가 이동한 위치 셀
    - `"{targetTeacher}_{sourceDay}_{sourcePeriod}"`
    - `"{sourceTeacher}_{targetDay}_{targetPeriod}"`
  - **순환교체**: 각 노드가 다음 노드의 위치로 이동
    - `"{currentTeacher}_{nextDay}_{nextPeriod}"`
  - **연쇄교체**: 각 단계별 교체 후 목적지 셀
  - **보강교체**: targetTeacher의 위치가 목적지 셀

```612:663:lib/ui/widgets/timetable_grid/exchange_executor.dart
List<String> _extractDestinationCells() {
  final historyService = ref.read(exchangeHistoryServiceProvider);
  final cellKeys = <String>[];

  for (final item in historyService.getExchangeList()) {
    final path = item.originalPath;

    // 1:1 교체 경로의 목적지 셀 추출
    if (path is OneToOneExchangePath) {
      cellKeys.addAll([
        '${path.targetNode.teacherName}_${path.sourceNode.day}_${path.sourceNode.period}',
        '${path.sourceNode.teacherName}_${path.targetNode.day}_${path.targetNode.period}',
      ]);

        // 순환교체 경로의 목적지 셀 추출 (각 노드가 다음 노드의 위치로 이동)
      } else if (path is CircularExchangePath) {
        final destinationKeys = <String>[];
        
        for (int i = 0; i < path.nodes.length - 1; i++) {
          final currentNode = path.nodes[i];
          final nextNode = path.nodes[i + 1];
          // 현재 노드가 다음 노드의 위치로 이동
          final destinationKey = '${currentNode.teacherName}_${nextNode.day}_${nextNode.period}';
          destinationKeys.add(destinationKey);
        }
        
        cellKeys.addAll(destinationKeys);

        // 연쇄교체 경로의 목적지 셀 추출
        // 연쇄교체는 2단계로 이루어지므로 각 단계별 목적지 셀을 모두 추출
      } else if (path is ChainExchangePath) {
        // 1단계 교체 후 목적지 셀들
        // node1 교사가 node2 위치로 이동
        cellKeys.add('${path.node1.teacherName}_${path.node2.day}_${path.node2.period}');
        // node2 교사가 node1 위치로 이동
        cellKeys.add('${path.node2.teacherName}_${path.node1.day}_${path.node1.period}');

        // 2단계 교체 후 목적지 셀들
        // nodeA 교사가 nodeB 위치로 이동
        cellKeys.add('${path.nodeA.teacherName}_${path.nodeB.day}_${path.nodeB.period}');
        // nodeB 교사가 nodeA 위치로 이동
        cellKeys.add('${path.nodeB.teacherName}_${path.nodeA.day}_${path.nodeA.period}');

        // 보강교체 경로의 목적지 셀 추출
        // 타겟 교사의 위치가 목적지 셀
      } else if (path is SupplementExchangePath) {
        cellKeys.add('${path.targetTeacher}_${path.targetDay}_${path.targetPeriod}');
      }
    }

    return cellKeys;
  }
```

### 7단계: CellSelectionProvider 상태 업데이트

**위치**: `lib/providers/cell_selection_provider.dart`

```249:263:lib/providers/cell_selection_provider.dart
/// 교체된 셀 상태 업데이트
void updateExchangedCells(List<String> cellKeys) {
  state = state.copyWith(
    exchangedCells: cellKeys.toSet(),
    lastUpdated: DateTime.now(),
  );
}

/// 교체된 목적지 셀 상태 업데이트
void updateExchangedDestinationCells(List<String> cellKeys) {
  state = state.copyWith(
    exchangedDestinationCells: cellKeys.toSet(),
    lastUpdated: DateTime.now(),
  );
}
```

**주요 작업**:
- 교체된 소스 셀 목록을 `Set<String>`으로 저장 (`exchangedCells`)
- 교체된 목적지 셀 목록을 `Set<String>`으로 저장 (`exchangedDestinationCells`)
- 상태 변경 시 Riverpod이 자동으로 UI 업데이트 트리거

**상태 확인 메서드**:
```426:436:lib/providers/cell_selection_provider.dart
/// 특정 셀이 교체된 소스 셀인지 확인
bool isCellExchangedSource(String teacherName, String day, int period) {
  final cellKey = '${teacherName}_${day}_$period';
  return state.exchangedCells.contains(cellKey);
}

/// 특정 셀이 교체된 목적지 셀인지 확인
bool isCellExchangedDestination(String teacherName, String day, int period) {
  final cellKey = '${teacherName}_${day}_$period';
  return state.exchangedDestinationCells.contains(cellKey);
}
```

### 8단계: TimetableDataSource 캐시 초기화 및 UI 업데이트

**위치**: `lib/utils/timetable_data_source.dart`

```568:579:lib/utils/timetable_data_source.dart
/// 교체된 셀 상태 업데이트 (교체 리스트 변경 시 호출)
void updateExchangedCells(List<String> exchangedCellKeys) {
  ref.read(cellSelectionProvider.notifier).updateExchangedCells(exchangedCellKeys);
  _clearCacheAndNotify();
}

/// 교체된 목적지 셀 상태 업데이트
void updateExchangedDestinationCells(List<String> destinationCellKeys) {
  ref.read(cellSelectionProvider.notifier).updateExchangedDestinationCells(destinationCellKeys);
  _localCache.clear(); // 로컬 캐시 초기화
  notifyDataSourceListeners(); // Syncfusion DataGrid 전용 메서드 사용
}
```

**주요 작업**:
- 로컬 캐시 초기화 (`_localCache.clear()`)
- Syncfusion DataGrid에 변경 알림 (`notifyDataSourceListeners()`)
- DataGrid가 `buildRow()` 메서드를 재호출하여 UI 업데이트

### 9단계: 셀 상태 정보 생성 (buildRow)

**위치**: `lib/utils/timetable_data_source.dart`

```208:244:lib/utils/timetable_data_source.dart
DataGridRowAdapter? buildRow(DataGridRow row) {
  return DataGridRowAdapter(
    cells: row.getCells().asMap().entries.map<Widget>((entry) {
      DataGridCell dataGridCell = entry.value;
      bool isTeacherColumn = dataGridCell.columnName == 'teacher';
      
      // 교사명 추출
      String teacherName = _extractTeacherName(row);
      
      // 셀 상태 정보 생성
      CellStateInfo cellState = _createCellStateInfo(
        dataGridCell, 
        teacherName, 
        isTeacherColumn
      );
      
      return SimplifiedTimetableCell(
        content: dataGridCell.value.toString(),
        isTeacherColumn: isTeacherColumn,
        isSelected: cellState.isSelected,
        isExchangeable: cellState.isExchangeableTeacher,
        isLastColumnOfDay: cellState.isLastColumnOfDay,
        isFirstColumnOfDay: cellState.isFirstColumnOfDay,
        isInCircularPath: cellState.isInCircularPath,
        circularPathStep: cellState.circularPathStep,
        isInSelectedPath: cellState.isInSelectedPath,
        isInChainPath: cellState.isInChainPath,
        chainPathStep: cellState.chainPathStep,
        isTargetCell: cellState.isTargetCell,
        isNonExchangeable: cellState.isNonExchangeable,
        isExchangedSourceCell: cellState.isExchangedSourceCell,
        isExchangedDestinationCell: cellState.isExchangedDestinationCell,
        isTeacherNameSelected: cellState.isTeacherNameSelected, // 새로 추가
      );
    }).toList(),
  );
}
```

**셀 상태 확인 로직**:
```345:346:lib/utils/timetable_data_source.dart
isExchangedSourceCell: cellNotifier.isCellExchangedSource(teacherName, day, period),
isExchangedDestinationCell: cellNotifier.isCellExchangedDestination(teacherName, day, period),
```

### 10단계: 셀 스타일 결정 (SimplifiedTimetableTheme)

**위치**: `lib/utils/simplified_timetable_theme.dart`

#### 10-1. 배경색 결정

```224:232:lib/utils/simplified_timetable_theme.dart
// 교체된 목적지 셀인 경우 연한 파란색 배경
if (isExchangedDestinationCell && showExchangedDestinationCellBackground) {
  return exchangedDestinationCellBackgroundColor;
}

// 교체불가 셀인 경우 빨간색 배경 (저장된 색상 또는 기본값)
if (isNonExchangeable) {
  return _nonExchangeableColor;
}
```

**목적지 셀 배경색**:
- 색상: `Color.fromARGB(255, 144, 199, 245)` (연한 파란색)
- 조건: `isExchangedDestinationCell == true`

#### 10-2. 테두리 결정

```298:306:lib/utils/simplified_timetable_theme.dart
// 교체된 소스 셀의 경우 파란색 테두리 (표시 여부 설정에 따라)
// 헤더 셀과 일반 셀 모두에 적용 (최우선순위)
if (isExchangedSourceCell && showExchangedSourceCellBorder) {
  return Border.all(
    color: exchangedSourceCellBorderColor, 
    width: exchangedSourceCellBorderWidth,
    style: exchangedSourceCellBorderStyle, // 점선 또는 실선 스타일 적용
  );
}
```

**소스 셀 테두리**:
- 색상: `Color(0xFF2196F3)` (파란색)
- 두께: `2px`
- 스타일: `BorderStyle.solid` (실선)

### 11단계: UI 렌더링

**위치**: `lib/ui/widgets/simplified_timetable_cell.dart`

`SimplifiedTimetableCell` 위젯이 `SimplifiedTimetableTheme`에서 결정된 스타일을 적용하여 실제 화면에 표시합니다.

## 교체 타입별 셀 색상 동작

### 1:1 교체 (OneToOneExchangePath)

**소스 셀**:
- `sourceNode`: 파란색 테두리
- `targetNode`: 파란색 테두리

**목적지 셀**:
- `"{targetTeacher}_{sourceDay}_{sourcePeriod}"`: 연한 파란색 배경
- `"{sourceTeacher}_{targetDay}_{targetPeriod}"`: 연한 파란색 배경

### 순환교체 (CircularExchangePath)

**소스 셀**:
- 마지막 노드를 제외한 모든 노드에 파란색 테두리

**목적지 셀**:
- 각 노드가 다음 노드의 위치로 이동한 셀에 연한 파란색 배경

### 연쇄교체 (ChainExchangePath)

**소스 셀**:
- `nodeA`, `nodeB`, `node1`, `node2` 모두 파란색 테두리

**목적지 셀**:
- 각 단계별 교체 후 새 교사가 배정된 셀에 연한 파란색 배경

### 보강교체 (SupplementExchangePath)

**소스 셀**:
- `sourceNode`에 파란색 테두리

**목적지 셀**:
- `targetNode`에 연한 파란색 배경

## 색상 상수 정의

**위치**: `lib/utils/simplified_timetable_theme.dart`

```114:121:lib/utils/simplified_timetable_theme.dart
// 교체된 소스 셀 테두리 색상 상수 (교체가 완료된 소스 셀의 테두리) - 원본 수업이 있던 셀
static const Color exchangedSourceCellBorderColor = Color(0xFF2196F3); // 교체된 소스 셀 테두리 색상 (파란색)
static const double exchangedSourceCellBorderWidth = 2; // 교체된 소스 셀 테두리 두께
static BorderStyle exchangedSourceCellBorderStyle = BorderStyle.solid; // 교체된 소스 셀 테두리 스타일
static const bool showExchangedSourceCellBorder = true; // 교체된 소스 셀 테두리 표시 여부
// 교체된 목적지 셀 배경색 상수 (교체가 완료된 목적지 셀의 배경색) - 교체 후 새 교사가 배정된 셀
static const Color exchangedDestinationCellBackgroundColor = Color.fromARGB(255, 144, 199, 245); // 교체된 목적지 셀 배경색 (연한 파란색)
static const bool showExchangedDestinationCellBackground = true; // 교체된 목적지 셀 배경색 표시 여부
```

## 중요 포인트

### 1. 상태 관리 계층 구조

```
ExchangeHistoryService (_exchangeList)
    ↓
ExchangeExecutor (셀 정보 추출)
    ↓
CellSelectionProvider (상태 저장)
    ↓
TimetableDataSource (UI 상태 결정)
    ↓
SimplifiedTimetableTheme (스타일 결정)
    ↓
SimplifiedTimetableCell (실제 렌더링)
```

### 2. 캐시 메커니즘

- `TimetableDataSource`는 로컬 캐시를 사용하여 성능 최적화
- 교체된 셀 정보 변경 시 캐시를 초기화하여 최신 상태 반영
- `_getCachedOrCompute()` 메서드로 캐시된 값 재사용

### 3. UI 업데이트 최적화

- `notifyDataSourceListeners()`로 Syncfusion DataGrid에만 변경 알림
- 전체 재렌더링이 아닌 필요한 셀만 업데이트
- 스크롤 위치 보존

### 4. 교체 리스트 기반 동작

- 모든 교체된 셀 색상은 교체 리스트(`_exchangeList`)를 기반으로 결정
- 교체 리스트가 변경되면 자동으로 셀 색상도 업데이트
- 되돌리기, 삭제 등 모든 작업이 색상에 반영됨

## 디버깅 팁

### 로그 확인

교체된 셀 상태 업데이트 시 다음 로그가 출력됩니다:

```
🔄 [ExchangeExecutor] 교체된 셀 정보 업데이트:
  - 소스 셀: 2개 - [홍길동_월_3, 김철수_월_5]
  - 목적지 셀: 2개 - [김철수_월_3, 홍길동_월_5]
✅ [ExchangeExecutor] 교체된 셀 상태 업데이트 완료
```

### 상태 확인 메서드

```dart
// CellSelectionProvider에서 직접 확인
final cellState = ref.read(cellSelectionProvider);
print('교체된 소스 셀: ${cellState.exchangedCells}');
print('교체된 목적지 셀: ${cellState.exchangedDestinationCells}');
```

## 관련 파일 목록

1. **교체 실행 로직**
   - `lib/ui/widgets/timetable_grid/exchange_executor.dart`

2. **상태 관리**
   - `lib/providers/cell_selection_provider.dart`
   - `lib/services/exchange_history_service.dart`

3. **UI 데이터 소스**
   - `lib/utils/timetable_data_source.dart`

4. **스타일 테마**
   - `lib/utils/simplified_timetable_theme.dart`

5. **셀 위젯**
   - `lib/ui/widgets/simplified_timetable_cell.dart`

6. **UI 렌더링**
   - `lib/ui/widgets/timetable_grid_section.dart`

## 요약

수업 교체 버튼 클릭 후 셀 색상이 변경되는 과정은 다음과 같습니다:

1. **교체 실행**: 교체 경로를 교체 리스트에 추가
2. **셀 정보 추출**: 교체 리스트에서 소스 셀과 목적지 셀 키 추출
3. **상태 업데이트**: `CellSelectionProvider`에 교체된 셀 정보 저장
4. **캐시 초기화**: `TimetableDataSource` 캐시 초기화 및 UI 업데이트 트리거
5. **스타일 결정**: 각 셀의 상태에 따라 배경색/테두리 결정
6. **UI 렌더링**: 변경된 스타일이 화면에 반영

이 과정을 통해 교체된 셀들이 시각적으로 구분되어 표시됩니다.

