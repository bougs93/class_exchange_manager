# Syncfusion DataGrid 재생성 문제 해결 문서

## 📋 문제 상황

### 발생한 문제
- **1:1 교체** → 셀선택 → 스크롤 유지
- **사이드 경로 보여짐** → 사이드바 경로 선택 → **Syncfusion DataGrid 스크롤 처음 위치로 이동**
- **다른 경로 선택** → 스크롤 유지
- **새로운 셀 선택** → **Syncfusion DataGrid 스크롤 처음 위치로 이동**

### 문제 원인 분석
초기에는 스크롤 문제로 생각했지만, 실제로는 **Syncfusion DataGrid가 재생성되는 문제**였습니다.

## 🔍 원인 분석

### 과거 커밋 (3ac58475)과 현재 코드 비교

#### 과거 커밋의 구조 (정상 동작)
```dart
class _TimetableGridSectionState extends State<TimetableGridSection> {
  // DataGrid 재생성을 위한 GlobalKey
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
  
  Widget _buildDataGrid() {
    return Container(
      child: SfDataGrid(
        key: _dataGridKey,  // GlobalKey 사용
        source: widget.dataSource!,
        columns: widget.columns,  // 직접 전달
        stackedHeaderRows: widget.stackedHeaders,  // 직접 전달
        headerRowHeight: AppConstants.headerRowHeight,  // 고정값
        rowHeight: AppConstants.dataRowHeight,  // 고정값
        // ...
      ),
    );
  }
}
```

#### 현재 코드의 문제점 (재생성 발생)
```dart
class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> {
  Widget build(BuildContext context) {
    // ❌ 문제: ref.watch() 호출로 인한 위젯 재빌드
    final resetState = ref.watch(stateResetProvider);
    // ...
  }
  
  Widget _buildDataGrid() {
    return Consumer(
      builder: (context, ref, child) {
        // ❌ 문제: ref.watch() 호출로 인한 위젯 재빌드
        final zoomFactor = ref.watch(zoomFactorProvider);
        
        return SfDataGrid(
          // ❌ 문제: ValueKey에서 ref.watch() 호출
          key: ValueKey('grid_${ref.watch(exchangeScreenProvider.select((state) => state.fileLoadId))}'),
          source: widget.dataSource!,
          // ❌ 문제: 동적 생성으로 인한 재빌드
          columns: _getScaledColumns(zoomFactor),
          stackedHeaderRows: _getScaledStackedHeaders(zoomFactor),
          headerRowHeight: _getScaledHeaderHeight(zoomFactor),
          rowHeight: _getScaledRowHeight(zoomFactor),
          // ...
        );
      },
    );
  }
}
```

### 핵심 문제점
1. **`ref.watch()` 호출**: build 메서드와 Consumer 내부에서 `ref.watch()` 호출
2. **ValueKey 사용**: `ref.watch()`를 포함한 ValueKey로 인한 위젯 재생성
3. **동적 생성**: `_getScaledColumns()`, `_getScaledStackedHeaders()` 등 동적 생성
4. **복잡한 Provider 시스템**: 여러 Provider가 상호작용하여 재빌드 유발

## 🔧 해결 방안

### 1. GlobalKey 사용으로 DataGrid 재생성 방지

#### 수정 전
```dart
class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> {
  // GlobalKey 없음
}
```

#### 수정 후
```dart
class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> {
  // 🔥 DataGrid 재생성 문제 해결: 과거 커밋의 단순한 구조를 참고하여 GlobalKey 사용
  // DataGrid 재생성을 위한 GlobalKey (과거 커밋과 동일한 방식)
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
}
```

### 2. SfDataGrid에서 GlobalKey 사용

#### 수정 전
```dart
SfDataGrid(
  // ❌ ValueKey에서 ref.watch() 호출로 인한 재생성
  key: ValueKey('grid_${ref.watch(exchangeScreenProvider.select((state) => state.fileLoadId))}'),
  // ...
)
```

#### 수정 후
```dart
SfDataGrid(
  // 🔥 DataGrid 재생성 문제 해결: 과거 커밋의 단순한 구조를 참고하여 GlobalKey 사용
  // GlobalKey를 사용하여 DataGrid 재생성 완전 방지 (과거 커밋과 동일한 방식)
  // 경로 선택, 셀 선택, 헤더 업데이트 등에서도 DataGrid가 재생성되지 않음
  key: _dataGridKey,
  // ...
)
```

### 3. 직접 전달 방식으로 변경

#### 수정 전
```dart
SfDataGrid(
  // ❌ 동적 생성으로 인한 재빌드
  columns: _getScaledColumns(zoomFactor),
  stackedHeaderRows: _getScaledStackedHeaders(zoomFactor),
  headerRowHeight: _getScaledHeaderHeight(zoomFactor),
  rowHeight: _getScaledRowHeight(zoomFactor),
  // ...
)
```

#### 수정 후
```dart
SfDataGrid(
  // ✅ 직접 전달로 재빌드 방지
  columns: widget.columns,
  stackedHeaderRows: widget.stackedHeaders,
  headerRowHeight: AppConstants.headerRowHeight,
  rowHeight: AppConstants.dataRowHeight,
  // ...
)
```

### 4. Transform.scale을 사용한 확대/축소

#### 수정 전
```dart
// ❌ 동적 생성으로 인한 재빌드
return dataGridContainer;
```

#### 수정 후
```dart
// 🔥 DataGrid 재생성 문제 해결: 과거 커밋의 단순한 구조를 참고하여 Transform.scale 사용
// 확대/축소 효과를 적용하여 반환 (과거 커밋과 동일한 방식)
return Transform.scale(
  scale: zoomFactor,
  alignment: Alignment.topLeft,
  child: dataGridContainer,
);
```

### 5. ref.watch() 호출 최소화

#### 수정 전
```dart
@override
Widget build(BuildContext context) {
  // ❌ 직접 ref.watch() 호출로 인한 재빌드
  final resetState = ref.watch(stateResetProvider);
  // ...
}
```

#### 수정 후
```dart
@override
Widget build(BuildContext context) {
  // 🔥 DataGrid 재생성 문제 해결: 과거 커밋의 단순한 구조를 참고하여 ref.watch 최소화
  // StateResetProvider 상태 감지는 별도 Consumer로 분리하여 DataGrid 재생성 방지
  return Consumer(
    builder: (context, ref, child) {
      // StateResetProvider 상태 감지만 처리
      final resetState = ref.watch(stateResetProvider);
      // ...
    },
  );
}
```

## 📊 수정 결과

### 수정 전 (문제 상황)
- **사이드바 경로 선택 시**: DataGrid 재생성 → 스크롤 초기화
- **새로운 셀 선택 시**: DataGrid 재생성 → 스크롤 초기화
- **Provider 상태 변경 시**: DataGrid 재생성 → 스크롤 초기화

### 수정 후 (정상 동작)
- **사이드바 경로 선택 시**: DataGrid 유지 → 스크롤 유지 ✅
- **새로운 셀 선택 시**: DataGrid 유지 → 스크롤 유지 ✅
- **Provider 상태 변경 시**: DataGrid 유지 → 스크롤 유지 ✅

## 🎯 핵심 개선사항

### 1. 과거 커밋의 단순한 구조 복원
- **GlobalKey 사용**: DataGrid 재생성을 완전히 방지
- **직접 전달**: `widget.columns`, `widget.stackedHeaders` 직접 사용
- **고정값 사용**: `AppConstants`의 고정 높이값 사용

### 2. Transform.scale을 사용한 확대/축소
- **과거 커밋과 동일한 방식**: `Transform.scale` 사용
- **DataGrid 재생성 없이**: 확대/축소 효과 구현

### 3. ref.watch() 호출 최소화
- **Consumer 분리**: StateResetProvider 상태 감지만 별도 처리
- **불필요한 재빌드 방지**: DataGrid와 관련 없는 상태 변경에서 재빌드 방지

## 📝 테스트 시나리오

### 정상 동작 확인
1. **1:1 교체** → 셀선택 → **DataGrid 유지** ✅
2. **사이드 경로 보여짐** → 사이드바 경로 선택 → **DataGrid 유지** ✅
3. **다른 경로 선택** → **DataGrid 유지** ✅
4. **새로운 셀 선택** → **DataGrid 유지** ✅

## 🔍 기술적 배경

### Flutter 위젯 재생성 원리
- **Key 변경**: 위젯의 Key가 변경되면 위젯이 재생성됨
- **ref.watch() 호출**: Provider 상태 변경 시 위젯이 재빌드됨
- **GlobalKey vs ValueKey**: GlobalKey는 위젯 재생성을 방지, ValueKey는 조건부 재생성

### Syncfusion DataGrid 특성
- **스크롤 상태 유지**: 위젯이 재생성되면 스크롤 위치가 초기화됨
- **성능 최적화**: 불필요한 재생성을 방지해야 함

## 📚 참고 자료

- **과거 커밋**: 3ac58475 (정상 동작하는 버전)
- **수정 파일**: `lib/ui/widgets/timetable_grid_section.dart`
- **관련 Provider**: `state_reset_provider.dart`, `scroll_provider.dart`

---

**작성일**: 2025년 1월 27일  
**작성자**: AI Assistant  
**상태**: 완료 ✅
