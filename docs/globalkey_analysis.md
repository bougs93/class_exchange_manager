# GlobalKey 사용 시 주의사항 및 대안 분석

## 🔍 GlobalKey 사용 시 잠재적 문제점

### 1. Syncfusion DataGrid에서의 GlobalKey 이슈
**검색 결과**: 현재까지 Syncfusion DataGrid에서 GlobalKey와 관련된 특정 문제는 보고되지 않음

### 2. 일반적인 GlobalKey 문제점

#### **위젯 트리 위치 변경 문제**
```dart
// 문제 상황: GlobalKey를 가진 위젯이 위젯 트리에서 이동할 때
// 예상치 못한 상태 변경이나 동작 오류 발생 가능
```

#### **고유성 문제**
```dart
// 문제 상황: 동일한 GlobalKey를 여러 위젯에 사용
final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
// 여러 DataGrid에서 같은 GlobalKey 사용 시 충돌 발생
```

#### **메모리 누수 가능성**
```dart
// 문제 상황: GlobalKey가 위젯을 계속 참조하여 메모리 해제 방지
// dispose() 시점에 GlobalKey 정리 필요
```

### 3. 현재 구현에서의 잠재적 위험

#### **위젯 트리 구조 변경 시**
- TimetableGridSection이 다른 위치로 이동할 때
- 부모 위젯이 변경될 때
- 조건부 렌더링 시 위젯 트리 구조 변경

#### **메모리 관리**
- GlobalKey가 DataGrid 인스턴스를 계속 참조
- dispose() 시점에 GlobalKey 정리 필요

## 🔧 대안 솔루션 분석

### 대안 1: ValueKey 최적화
```dart
// 현재 문제가 되는 코드
key: ValueKey('grid_${ref.watch(exchangeScreenProvider.select((state) => state.fileLoadId))}')

// 개선된 ValueKey 사용
key: ValueKey('grid_${ref.read(exchangeScreenProvider).fileLoadId}')  // ref.read 사용
```

### 대안 2: AutomaticKeepAliveClientMixin 사용
```dart
class _TimetableGridSectionState extends ConsumerState<TimetableGridSection> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;  // 위젯 상태 유지
  
  @override
  Widget build(BuildContext context) {
    super.build(context);  // 필수 호출
    // ...
  }
}
```

### 대안 3: RepaintBoundary 사용
```dart
RepaintBoundary(
  child: SfDataGrid(
    // DataGrid를 RepaintBoundary로 감싸서 불필요한 재그리기 방지
    key: ValueKey('grid_${ref.read(exchangeScreenProvider).fileLoadId}'),
    // ...
  ),
)
```

### 대안 4: Consumer 분리 최적화
```dart
// DataGrid만 별도 Consumer로 분리
Consumer(
  builder: (context, ref, child) {
    return SfDataGrid(
      key: ValueKey('grid_${ref.read(exchangeScreenProvider).fileLoadId}'),
      // ...
    );
  },
)
```

## 🎯 권장사항

### 단기 해결책 (현재 GlobalKey 유지)
1. **GlobalKey 고유성 보장**: 클래스 내에서만 사용
2. **dispose() 정리**: GlobalKey 참조 해제
3. **위젯 트리 구조 안정화**: DataGrid 위치 고정

### 장기 해결책 (대안 구현)
1. **ValueKey 최적화**: ref.read() 사용으로 재빌드 방지
2. **AutomaticKeepAliveClientMixin**: 위젯 상태 유지
3. **RepaintBoundary**: 렌더링 최적화

## 📊 위험도 평가

### GlobalKey 사용 위험도
- **낮음**: 현재 구현에서는 특별한 문제 없음
- **주의사항**: 위젯 트리 구조 변경 시 주의 필요
- **모니터링**: 메모리 사용량 및 성능 지속 관찰

### 대안 구현 복잡도
- **ValueKey 최적화**: 낮음 (간단한 수정)
- **AutomaticKeepAliveClientMixin**: 중간 (구조 변경 필요)
- **RepaintBoundary**: 낮음 (간단한 래핑)

---

**결론**: 현재 GlobalKey 사용은 안전하지만, 장기적으로는 더 안전한 대안을 고려해볼 수 있습니다.
