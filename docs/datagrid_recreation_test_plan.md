# Syncfusion DataGrid 재생성 문제 원인 파악 테스트 계획

## 🎯 테스트 목적
수정된 5가지 핵심 사항을 하나씩 되돌리면서 어떤 수정사항이 핵심적인 역할을 하는지 파악

## 📋 테스트 시나리오
각 수정사항을 되돌린 후 다음 동작을 테스트:
1. **1:1 교체** → 셀선택 → 스크롤 유지 여부
2. **사이드 경로 보여짐** → 사이드바 경로 선택 → 스크롤 유지 여부
3. **다른 경로 선택** → 스크롤 유지 여부
4. **새로운 셀 선택** → 스크롤 유지 여부

## 🔧 테스트 순서 (우선순위별)

### 테스트 1: GlobalKey 제거 (가장 중요할 것으로 예상)
**되돌릴 내용**: GlobalKey 사용을 ValueKey로 변경
```dart
// 되돌리기 전 (수정된 상태)
final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
SfDataGrid(key: _dataGridKey, ...)

// 되돌리기 후 (문제 상태로 복원)
SfDataGrid(
  key: ValueKey('grid_${ref.watch(exchangeScreenProvider.select((state) => state.fileLoadId))}'),
  ...
)
```

**예상 결과**: DataGrid 재생성 문제 재발생
**테스트 방법**: 사이드바 경로 선택 시 스크롤이 처음 위치로 이동하는지 확인

---

### 테스트 2: 직접 전달 방식 되돌리기
**되돌릴 내용**: 직접 전달을 동적 생성으로 변경
```dart
// 되돌리기 전 (수정된 상태)
columns: widget.columns,
stackedHeaderRows: widget.stackedHeaders,
headerRowHeight: AppConstants.headerRowHeight,
rowHeight: AppConstants.dataRowHeight,

// 되돌리기 후 (문제 상태로 복원)
columns: _getScaledColumns(zoomFactor),
stackedHeaderRows: _getScaledStackedHeaders(zoomFactor),
headerRowHeight: _getScaledHeaderHeight(zoomFactor),
rowHeight: _getScaledRowHeight(zoomFactor),
```

**예상 결과**: 확대/축소 시에만 문제 발생 가능
**테스트 방법**: 줌 변경 시 스크롤 위치 유지 여부 확인

---

### 테스트 3: Transform.scale 제거
**되돌릴 내용**: Transform.scale을 제거하고 직접 반환
```dart
// 되돌리기 전 (수정된 상태)
return Transform.scale(
  scale: zoomFactor,
  alignment: Alignment.topLeft,
  child: dataGridContainer,
);

// 되돌리기 후 (문제 상태로 복원)
return dataGridContainer;
```

**예상 결과**: 확대/축소 기능만 영향받을 가능성
**테스트 방법**: 확대/축소 기능 동작 여부 확인

---

### 테스트 4: ref.watch() 호출 복원
**되돌릴 내용**: Consumer 분리를 제거하고 직접 호출
```dart
// 되돌리기 전 (수정된 상태)
return Consumer(
  builder: (context, ref, child) {
    final resetState = ref.watch(stateResetProvider);
    // ...
  },
);

// 되돌리기 후 (문제 상태로 복원)
@override
Widget build(BuildContext context) {
  final resetState = ref.watch(stateResetProvider);
  // ...
}
```

**예상 결과**: Provider 상태 변경 시 문제 발생 가능
**테스트 방법**: 상태 초기화 시 스크롤 위치 유지 여부 확인

---

### 테스트 5: GlobalKey 추가만 테스트
**테스트 내용**: 다른 모든 수정사항을 되돌리고 GlobalKey만 유지
```dart
// GlobalKey만 유지하고 나머지는 모두 되돌리기
final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
SfDataGrid(key: _dataGridKey, ...)
// 나머지는 모두 원래 문제 상태로 복원
```

**예상 결과**: GlobalKey만으로도 문제 해결 가능성 확인
**테스트 방법**: 핵심 문제인 DataGrid 재생성 방지 여부 확인

## 📊 테스트 결과 기록

### 테스트 1: GlobalKey 제거
- [x] 테스트 완료
- [x] 결과: 문제 재발생 ✅
- [x] 영향도: 높음 ✅
- [x] 비고: GlobalKey가 핵심 원인임이 확인됨. ValueKey 사용 시 스크롤 문제 재발생

### 테스트 2: 직접 전달 방식 되돌리기
- [ ] 테스트 완료
- [ ] 결과: 문제 재발생 / 정상 동작
- [ ] 영향도: 높음 / 중간 / 낮음
- [ ] 비고:

### 테스트 3: Transform.scale 제거
- [ ] 테스트 완료
- [ ] 결과: 문제 재발생 / 정상 동작
- [ ] 영향도: 높음 / 중간 / 낮음
- [ ] 비고:

### 테스트 4: ref.watch() 호출 복원
- [ ] 테스트 완료
- [ ] 결과: 문제 재발생 / 정상 동작
- [ ] 영향도: 높음 / 중간 / 낮음
- [ ] 비고:

### 테스트 5: GlobalKey만 유지
- [ ] 테스트 완료
- [ ] 결과: 문제 재발생 / 정상 동작
- [ ] 영향도: 높음 / 중간 / 낮음
- [ ] 비고:

## 🎯 최종 결론
- **핵심 원인**: 
- **보조 원인**: 
- **영향 없는 수정사항**: 
- **권장사항**: 

---

**테스트 시작일**: 2025년 1월 27일  
**테스트자**: 사용자  
**상태**: 준비 완료 ✅
