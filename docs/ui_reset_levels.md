# UI 초기화 레벨 정의

프로젝트 전체에서 사용하는 UI 초기화 방법을 3단계 레벨로 통합 정리합니다.

## 초기화 레벨 구조

```
Level 1: 경로 선택만 초기화 (가장 가벼움)
  └─ 현재 선택된 교체 경로만 해제
  └─ 사용 시점: 새로운 경로 선택 직전

Level 2: 이전 교체 상태 초기화 (중간)
  └─ 교체 경로 + 경로 리스트 + UI 상태
  └─ 현재 선택된 셀은 유지
  └─ 사용 시점: 모드 내에서 새로운 셀 선택 시

Level 3: 전체 상태 초기화 (가장 강함)
  └─ 모든 교체 상태 + 선택 셀 + 캐시
  └─ 사용 시점: 모드 전환, 파일 변경 시
```

## 각 레벨별 상세 설명

### Level 1: 경로 선택만 초기화
**메서드명**: `resetSelectedPath()`

**초기화 대상**:
- ✅ 선택된 교체 경로 (OneToOne/Circular/Chain)
- ✅ DataSource의 경로 선택 상태
- ❌ 선택된 셀 (유지)
- ❌ 경로 리스트 (유지)
- ❌ UI 상태 (유지)

**호출 시점**:
- 새로운 경로를 선택하기 직전
- 교체 실행 직후 (경로만 해제)

**예시**:
```dart
// 교체된 셀 클릭 시 새 경로 선택 전
resetSelectedPath();
_selectExchangePath(newPath);
```

---

### Level 2: 이전 교체 상태 초기화
**메서드명**: `resetExchangeStates()`

**초기화 대상**:
- ✅ 선택된 교체 경로 (모든 타입)
- ✅ 경로 리스트 (circular/oneToOne/chain)
- ✅ 사이드바 표시 상태
- ✅ 로딩 상태
- ✅ 필터 상태
- ❌ 선택된 셀 (유지)
- ❌ 전역 캐시 (유지)

**호출 시점**:
- 동일 모드 내에서 다른 셀 선택 시
- 교체 후 다음 작업 준비 시

**예시**:
```dart
// 1:1 교체 모드에서 새로운 셀 선택 시
resetExchangeStates();
_handleNewCellSelection(cell);
```

---

### Level 3: 전체 상태 초기화
**메서드명**: `resetAllStates()`

**초기화 대상**:
- ✅ 모든 교체 서비스 상태
- ✅ 선택된 교체 경로
- ✅ 경로 리스트
- ✅ 선택된 셀 (source/target)
- ✅ 전역 Provider 캐시
- ✅ DataSource 캐시
- ✅ UI 상태 (사이드바, 로딩 등)
- ✅ 헤더 테마

**호출 시점**:
- 교체 모드 전환 시 (1:1 ↔ 순환 ↔ 연쇄)
- 파일 선택/해제 시
- 교체불가 편집 모드 진입 시

**예시**:
```dart
// 1:1 교체 모드에서 순환 교체 모드로 전환 시
resetAllStates();
enableCircularExchangeMode();
```

---

## 주요 파일별 구현 위치

### timetable_grid_section.dart
```dart
// Level 1: 경로 선택만 초기화
void _resetSelectedPath() { ... }

// Level 2: 이전 교체 상태 초기화
void _resetExchangeStates() { ... }

// Level 3: 이 위젯에서는 직접 사용하지 않음
// exchange_screen.dart의 resetAllStates()가 onRestoreUIToDefault 콜백을 통해 트리거

// 외부 호출용 메서드 (타겟 셀 초기화 시 사용)
void clearAllArrowStates() {
  _resetExchangeStates(); // Level 2 초기화
}
```

### state_reset_handler.dart (Mixin)
```dart
// Level 2: 이전 교체 상태 초기화
void resetExchangeStates() { ... }

// Level 3: 전체 상태 초기화
void resetAllStates() { ... }
```

### exchange_operation_manager.dart
```dart
// Level 3: 전체 상태 초기화 (모드 전환 시 사용)
void toggleExchangeMode() {
  if (enabled) {
    resetAllStates();
  }
}
```

---

## 마이그레이션 가이드

### 기존 메서드 → 새 메서드 매핑

| 기존 메서드 | 새 메서드 | 레벨 |
|-----------|---------|------|
| `_resetPathSelections()` | `resetSelectedPath()` | Level 1 |
| `_clearExchangePathSelection()` | `resetSelectedPath()` | Level 1 |
| `clearPreviousExchangeStates()` | `resetExchangeStates()` | Level 2 |
| `clearAllExchangeStates()` | `resetAllStates()` | Level 3 |
| `restoreUIToDefault()` | `resetAllStates()` | Level 3 |
| `onRestoreUIToDefault?.call()` | `onResetAllStates?.call()` | Level 3 |

---

## 사용 예시

### 예시 1: 교체된 셀 클릭 시
```dart
void _handleExchangedCellClick(String teacherName, String day, int period) {
  final exchangePath = _historyService.findExchangePathByCell(teacherName, day, period);

  if (exchangePath != null) {
    // Level 1: 기존 경로만 초기화 (선택된 셀 유지)
    resetSelectedPath();

    // 새로운 경로 선택
    _selectExchangePath(exchangePath);

    // 헤더 업데이트
    widget.onHeaderThemeUpdate?.call();
  }
}
```

### 예시 2: 일반 셀 클릭 시
```dart
void _handleCellTap(DataGridCellTapDetails details) {
  if (isExchangedCell) {
    // 교체된 셀 처리
    _handleExchangedCellClick(...);
  } else {
    // Level 2: 이전 교체 상태 초기화 (현재 셀은 새로 설정됨)
    resetExchangeStates();

    // 새로운 셀 선택 처리
    widget.onCellTap(details);

    // 헤더 업데이트
    widget.onHeaderThemeUpdate?.call();
  }
}
```

### 예시 3: 모드 전환 시
```dart
void toggleCircularExchangeMode() {
  // 다른 모드 비활성화
  if (hasOtherModesActive) {
    setOtherModesDisabled();
  }

  // Level 3: 전체 상태 초기화
  resetAllStates();

  // 새로운 모드 활성화
  setCircularExchangeModeEnabled(true);
}
```

---

## 주의사항

1. **레벨 선택 원칙**: 필요한 최소 레벨만 사용
   - 불필요한 초기화는 성능 저하와 UX 저하 초래
   - 예: 경로만 바꿀 때 Level 3 사용 ❌

2. **헤더 업데이트 타이밍**:
   - Level 1, 2: 수동으로 `onHeaderThemeUpdate()` 호출
   - Level 3: `resetAllStates()` 내부에서 자동 호출

3. **UI 업데이트**:
   - DataSource 변경 후 반드시 `notifyListeners()` 호출
   - 캐시 무효화가 필요한 경우 `clearAllCaches()` 먼저 호출

4. **교체 뷰 체크박스**:
   - 활성화 시: Level 2 초기화 (백업 적용)
   - 비활성화 시: Level 3 초기화 (원본 복원)
