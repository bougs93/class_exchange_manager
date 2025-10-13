# Provider 마이그레이션 예시

## 실제 코드 변경 예시

### 1. Import 변경

```dart
// 기존 (timetable_grid_section.dart)
import '../../providers/timetable_theme_provider.dart';
import '../../providers/arrow_display_provider.dart';
import '../../providers/exchange_screen_provider.dart';

// 새로운
import '../../providers/cell_selection_provider.dart';
```

### 2. Provider 사용 변경

#### 셀 선택 상태 확인
```dart
// 기존
final themeState = ref.watch(timetableThemeProvider);
bool isSelected = themeState.selectedTeacher == teacherName && 
                 themeState.selectedDay == day && 
                 themeState.selectedPeriod == period;

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
bool isSelected = cellNotifier.isCellSelected(teacherName, day, period);
```

#### 셀 선택 상태 업데이트
```dart
// 기존
final themeNotifier = ref.read(timetableThemeProvider.notifier);
themeNotifier.updateSelection(teacherName, day, period);

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
cellNotifier.selectCell(teacherName, day, period);
```

#### 화살표 표시 관리
```dart
// 기존
final arrowNotifier = ref.read(arrowDisplayProvider.notifier);
arrowNotifier.showArrowForPath(path);

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
cellNotifier.showArrowForPath(path);
```

#### 교체 모드 관리
```dart
// 기존
final modeNotifier = ref.read(exchangeLogicProvider.notifier);
modeNotifier.setMode(ExchangeMode.oneToOneExchange);

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
cellNotifier.setExchangeMode(ExchangeMode.oneToOneExchange);
```

### 3. 상태 접근 변경

#### 선택된 셀 정보 접근
```dart
// 기존
final themeState = ref.watch(timetableThemeProvider);
String? selectedTeacher = themeState.selectedTeacher;
String? selectedDay = themeState.selectedDay;
int? selectedPeriod = themeState.selectedPeriod;

// 새로운
final selectedCell = ref.watch(selectedCellProvider);
String? selectedTeacher = selectedCell?['teacher'];
String? selectedDay = selectedCell?['day'];
int? selectedPeriod = selectedCell?['period'];
```

#### 교체 모드 확인
```dart
// 기존
final modeState = ref.watch(exchangeLogicProvider);
ExchangeMode currentMode = modeState.currentMode;

// 새로운
final currentMode = ref.watch(currentExchangeModeProvider);
```

#### 화살표 표시 확인
```dart
// 기존
final arrowState = ref.watch(arrowDisplayProvider);
bool isVisible = arrowState.isVisible && arrowState.selectedPath != null;

// 새로운
final isVisible = ref.watch(isArrowVisibleProvider);
```

### 4. 전체 위젯 마이그레이션 예시

```dart
// 기존 TimetableGridSection의 일부
class TimetableGridSection extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 기존: 여러 Provider 사용
    final themeState = ref.watch(timetableThemeProvider);
    final arrowState = ref.watch(arrowDisplayProvider);
    final modeState = ref.watch(exchangeLogicProvider);
    
    return Consumer(
      builder: (context, ref, child) {
        // 셀 선택 상태 확인
        bool isSelected = themeState.selectedTeacher == teacherName && 
                         themeState.selectedDay == day && 
                         themeState.selectedPeriod == period;
        
        // 화살표 표시 확인
        bool isArrowVisible = arrowState.isVisible && arrowState.selectedPath != null;
        
        // 교체 모드 확인
        bool isExchangeMode = modeState.currentMode != ExchangeMode.view;
        
        return YourWidget(
          isSelected: isSelected,
          isArrowVisible: isArrowVisible,
          isExchangeMode: isExchangeMode,
        );
      },
    );
  }
}

// 새로운 TimetableGridSection의 일부
class TimetableGridSection extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 새로운: 하나의 Provider 사용
    final cellState = ref.watch(cellSelectionProvider);
    
    return Consumer(
      builder: (context, ref, child) {
        // 셀 선택 상태 확인
        final cellNotifier = ref.read(cellSelectionProvider.notifier);
        bool isSelected = cellNotifier.isCellSelected(teacherName, day, period);
        
        // 화살표 표시 확인
        bool isArrowVisible = cellState.isArrowVisible;
        
        // 교체 모드 확인
        bool isExchangeMode = cellState.currentMode != ExchangeMode.view;
        
        return YourWidget(
          isSelected: isSelected,
          isArrowVisible: isArrowVisible,
          isExchangeMode: isExchangeMode,
        );
      },
    );
  }
}
```

### 5. 이벤트 핸들러 마이그레이션

```dart
// 기존 셀 탭 핸들러
void _onCellTap(DataGridCellTapDetails details) {
  // 기존: 여러 Provider 업데이트
  final themeNotifier = ref.read(timetableThemeProvider.notifier);
  final arrowNotifier = ref.read(arrowDisplayProvider.notifier);
  
  themeNotifier.updateSelection(teacherName, day, period);
  arrowNotifier.showArrowForPath(path);
}

// 새로운 셀 탭 핸들러
void _onCellTap(DataGridCellTapDetails details) {
  // 새로운: 하나의 Provider 업데이트
  final cellNotifier = ref.read(cellSelectionProvider.notifier);
  
  cellNotifier.selectCell(teacherName, day, period);
  cellNotifier.showArrowForPath(path);
}
```

### 6. 상태 초기화 마이그레이션

```dart
// 기존 상태 초기화
void _clearAllStates() {
  final themeNotifier = ref.read(timetableThemeProvider.notifier);
  final arrowNotifier = ref.read(arrowDisplayProvider.notifier);
  final modeNotifier = ref.read(exchangeLogicProvider.notifier);
  
  themeNotifier.clearAllSelections();
  arrowNotifier.hideArrow();
  modeNotifier.setMode(ExchangeMode.view);
}

// 새로운 상태 초기화
void _clearAllStates() {
  final cellNotifier = ref.read(cellSelectionProvider.notifier);
  
  cellNotifier.clearAllSelections();
  cellNotifier.hideArrow();
  cellNotifier.setExchangeMode(ExchangeMode.view);
}
```

## 마이그레이션 체크리스트

### 1. Import 변경
- [ ] `timetable_theme_provider.dart` 제거
- [ ] `arrow_display_provider.dart` 제거  
- [ ] `exchange_logic_provider.dart` 제거
- [ ] `cell_selection_provider.dart` 추가

### 2. Provider 사용 변경
- [ ] `timetableThemeProvider` → `cellSelectionProvider`
- [ ] `arrowDisplayProvider` → `cellSelectionProvider`
- [ ] `exchangeLogicProvider` → `cellSelectionProvider`

### 3. 메서드 호출 변경
- [ ] `updateSelection()` → `selectCell()`
- [ ] `showArrowForPath()` → `showArrowForPath()`
- [ ] `setMode()` → `setExchangeMode()`
- [ ] `clearAllSelections()` → `clearAllSelections()`

### 4. 상태 접근 변경
- [ ] 직접 상태 접근 → 편의 Provider 사용
- [ ] 여러 Provider 조합 → 단일 Provider 사용

### 5. 테스트 업데이트
- [ ] 단위 테스트 업데이트
- [ ] 위젯 테스트 업데이트
- [ ] 통합 테스트 업데이트

## 주의사항

1. **점진적 마이그레이션**: 한 번에 모든 Provider를 변경하지 말고 단계적으로 진행
2. **테스트 우선**: 각 변경 후 테스트를 실행하여 기능이 정상 작동하는지 확인
3. **백업**: 마이그레이션 전 기존 코드를 백업
4. **문서화**: 변경 사항을 문서화하여 팀원들이 이해할 수 있도록 함
