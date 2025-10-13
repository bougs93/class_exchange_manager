# Provider 리팩토링 가이드

## 개요
셀 선택 상태 관리와 관련된 여러 Provider들을 하나의 통합된 `CellSelectionProvider`로 리팩토링합니다.

## 변경 사항

### 1. 새로운 통합 Provider
- **파일**: `lib/providers/cell_selection_provider.dart`
- **클래스**: `CellSelectionNotifier`, `CellSelectionState`
- **Provider**: `cellSelectionProvider`

### 2. 통합된 기능들

#### 기존 Provider → 새로운 Provider 매핑

| 기존 Provider | 새로운 Provider | 변경 사항 |
|---------------|-----------------|-----------|
| `timetableThemeProvider` | `cellSelectionProvider` | 모든 셀 선택 상태 통합 |
| `arrowDisplayProvider` | `cellSelectionProvider` | 화살표 표시 상태 통합 |
| `exchangeLogicProvider` | `cellSelectionProvider` | 교체 모드 관리 통합 |
| `exchangeScreenProvider` (일부) | `cellSelectionProvider` | 선택된 경로들 통합 |

#### 통합된 상태 관리

```dart
// 기존: 여러 Provider 사용
final themeState = ref.watch(timetableThemeProvider);
final arrowState = ref.watch(arrowDisplayProvider);
final modeState = ref.watch(exchangeLogicProvider);

// 새로운: 하나의 Provider 사용
final cellState = ref.watch(cellSelectionProvider);
```

## 마이그레이션 가이드

### 1. Import 변경

```dart
// 기존
import '../providers/timetable_theme_provider.dart';
import '../providers/arrow_display_provider.dart';
import '../providers/exchange_logic_provider.dart';

// 새로운
import '../providers/cell_selection_provider.dart';
```

### 2. Provider 사용 변경

#### 셀 선택 상태
```dart
// 기존
final themeNotifier = ref.read(timetableThemeProvider.notifier);
themeNotifier.updateSelection(teacher, day, period);

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
cellNotifier.selectCell(teacher, day, period);
```

#### 화살표 표시
```dart
// 기존
final arrowNotifier = ref.read(arrowDisplayProvider.notifier);
arrowNotifier.showArrowForPath(path);

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
cellNotifier.showArrowForPath(path);
```

#### 교체 모드
```dart
// 기존
final modeNotifier = ref.read(exchangeLogicProvider.notifier);
modeNotifier.setMode(ExchangeMode.oneToOneExchange);

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
cellNotifier.setExchangeMode(ExchangeMode.oneToOneExchange);
```

### 3. 상태 접근 변경

#### 선택된 셀 확인
```dart
// 기존
final themeState = ref.watch(timetableThemeProvider);
bool isSelected = themeState.selectedTeacher == teacher && 
                 themeState.selectedDay == day && 
                 themeState.selectedPeriod == period;

// 새로운
final cellNotifier = ref.read(cellSelectionProvider.notifier);
bool isSelected = cellNotifier.isCellSelected(teacher, day, period);
```

#### 화살표 표시 확인
```dart
// 기존
final arrowState = ref.watch(arrowDisplayProvider);
bool isVisible = arrowState.isVisible && arrowState.selectedPath != null;

// 새로운
final cellState = ref.watch(cellSelectionProvider);
bool isVisible = cellState.isArrowVisible;
```

### 4. 편의 Provider 사용

```dart
// 선택된 셀 정보
final selectedCell = ref.watch(selectedCellProvider);

// 현재 교체 모드
final currentMode = ref.watch(currentExchangeModeProvider);

// 화살표 표시 여부
final isArrowVisible = ref.watch(isArrowVisibleProvider);

// 선택된 교체 경로
final selectedPath = ref.watch(selectedExchangePathProvider);
```

## 장점

### 1. 코드 간소화
- 여러 Provider 대신 하나의 Provider 사용
- 상태 관리 로직 중앙화
- 의존성 감소

### 2. 성능 향상
- 불필요한 Provider 간 통신 제거
- 상태 업데이트 최적화
- 메모리 사용량 감소

### 3. 유지보수성 향상
- 단일 책임 원칙 준수
- 코드 가독성 향상
- 디버깅 용이성 증대

### 4. 타입 안전성
- 통합된 상태 클래스로 타입 안전성 보장
- 컴파일 타임 오류 검출
- IDE 자동완성 지원

## 주의사항

### 1. 기존 Provider 제거 전 확인
- 모든 사용처가 새로운 Provider로 마이그레이션되었는지 확인
- 테스트 코드도 함께 업데이트 필요

### 2. 상태 초기화
- 앱 시작 시 새로운 Provider 상태 초기화 확인
- 기존 상태 복원 로직 업데이트 필요

### 3. 성능 모니터링
- 새로운 Provider의 성능 영향 모니터링
- 필요시 추가 최적화 수행

## 다음 단계

1. **기존 Provider 사용처 마이그레이션**
2. **테스트 코드 업데이트**
3. **기존 Provider 파일 제거**
4. **성능 테스트 및 최적화**
