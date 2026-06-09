# 창 최대화 후 교체 경로 화살표 좌표 어긋남 문제 해결 문서

> **상태**: ✅ 해결 완료 (2026-06-09)
> **핵심 해결책**: 레이아웃 크기 변경 감지 후 실제 스크롤 컨트롤러 오프셋으로 `scrollProvider` 재동기화
> **관련 파일**: `lib/ui/widgets/timetable_grid_section.dart`

## 📋 문제 상황

### 발생한 문제
- 교체 관리 화면에서 **창 최대화 버튼**을 누른 후
- 검색된 **교체 경로를 선택(클릭)**하면
- 경로를 나타내는 **화살표가 잘못된 위치(어긋난 좌표)에 표시**됨

### 핵심 단서
- 어긋난 상태에서 **그리드를 조금이라도 스크롤하면 화살표가 즉시 정상 위치로 보정**됨
- 즉, 화살표를 그리는 좌표 계산 자체는 정상이며, **입력으로 들어가는 스크롤 오프셋 값이 실제와 어긋나 있던 것**이 원인

## 🔍 원인 분석

### 화살표 좌표 계산 구조
화살표는 `ExchangeArrowPainter`(`lib/ui/widgets/timetable_grid/exchange_arrow_painter.dart`)가 그리며,
셀 위치 좌표는 다음 두 입력으로 계산됩니다.

| 입력 | 출처 | 특성 |
|------|------|------|
| `zoomFactor` | `zoomProvider` | 셀 너비/높이를 결정 (고정 상수 × 배율) |
| `scrollOffset` | `scrollProvider` | 스크롤 위치에 따라 화살표를 이동시킴 |

셀 크기는 `AppConstants` 상수 × `zoomFactor`로 **고정**이므로, 화살표 위치를 좌우하는
**동적 변수는 사실상 `scrollOffset` 하나뿐**입니다. 따라서 화살표가 어긋났다는 것은
`scrollProvider`의 오프셋 값이 **실제 그리드 스크롤 위치와 불일치**한다는 의미입니다.

### `scrollProvider`가 stale 값으로 남는 이유

`scrollProvider`는 **다음 두 경로로만** 갱신됩니다.

1. `NotificationListener<ScrollNotification>` → `ScrollUpdateNotification` 발생 시
   (`timetable_grid_section.dart`의 `_buildDataGrid()` 내부)
2. `ScrollManagementMixin._onScrollChanged()` → 스크롤 컨트롤러 리스너 발동 시

문제는 **창 최대화 시 스크롤 오프셋이 바뀌는 방식**에 있습니다.

- 창을 최대화하면 그리드 뷰포트가 커지고, 스크롤 가능 범위(`maxScrollExtent`)가 줄어듭니다.
- Syncfusion 내부 스크롤 컨트롤러는 현재 오프셋을 새 범위에 맞게 **clamp(보정)**합니다.
- 그런데 이 보정은 Flutter의 **`ScrollPosition.correctPixels`** 경로로 일어납니다.
  `correctPixels`는 레이아웃 단계에서 알림 루프를 막기 위해 **`notifyListeners`를 호출하지 않습니다.**
- 결과적으로 **`ScrollUpdateNotification`도, 컨트롤러 리스너도 발동하지 않아**
  `scrollProvider`는 **최대화 이전의 오프셋 값을 그대로 유지**합니다.

```
[최대화 전] 실제 오프셋 = 300, scrollProvider = 300  (일치 ✓)
   │  창 최대화 → 뷰포트 확대 → maxScrollExtent 축소
   ▼
[최대화 후] 실제 오프셋 = 100 (correctPixels로 조용히 clamp)
            scrollProvider = 300 (갱신 안 됨)  → 불일치 ✗
   │  → 화살표가 200px 어긋나서 그려짐
   ▼
[수동 스크롤] 리스너 발동 → scrollProvider = 실제값 → 화살표 정상화 ✓
```

이것이 "최대화 후 경로 선택 시 어긋나지만, 스크롤하면 즉시 정상화"되는 현상의 원인입니다.

## 🛠️ 해결 방법

**레이아웃 크기가 바뀌는 시점(= 최대화/리사이즈)을 감지하여,
프레임 종료 후 실제 스크롤 컨트롤러의 오프셋으로 `scrollProvider`를 강제 재동기화**합니다.

`correctPixels`에 의한 오프셋 보정은 해당 프레임의 **레이아웃 단계에서 완료**되므로,
`addPostFrameCallback`(프레임 종료 콜백)에서 컨트롤러의 `.offset`을 읽으면
**보정이 끝난 실제 값**을 얻을 수 있습니다.

### 변경 위치
`lib/ui/widgets/timetable_grid_section.dart`

#### 1. 그리드 영역을 `LayoutBuilder`로 감싸 크기 변화 감지
화살표 표시 여부와 무관하게 **항상 빌드되는** `_buildDataGridWithArrows()`에 배치하여,
경로 선택 이전(최대화 시점)에 **미리 오프셋을 보정**해 둡니다. 따라서 이후 경로를
선택하면 화살표가 처음부터 올바른 위치에 그려집니다.

```dart
Widget _buildDataGridWithArrows() {
  return LayoutBuilder(
    builder: (context, constraints) {
      // 🔧 창 최대화/리사이즈 시 화살표 좌표 어긋남 방지
      final gridSize = Size(constraints.maxWidth, constraints.maxHeight);
      if (_lastGridSize != gridSize) {
        _lastGridSize = gridSize;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncScrollOffsetFromControllers();
        });
      }

      return Consumer(
        builder: (context, ref, child) {
          // ... 기존 화살표/그리드 구성 로직 ...
        },
      );
    },
  );
}
```

#### 2. 실제 컨트롤러 오프셋으로 동기화하는 메서드 추가
```dart
void _syncScrollOffsetFromControllers() {
  final horizontal = horizontalScrollController.hasClients
      ? horizontalScrollController.offset
      : 0.0;
  final vertical = verticalScrollController.hasClients
      ? verticalScrollController.offset
      : 0.0;

  final current = ref.read(scrollProvider);
  // 미세한 차이는 무시하여 불필요한 재빌드 방지
  if ((current.horizontalOffset - horizontal).abs() > 0.5 ||
      (current.verticalOffset - vertical).abs() > 0.5) {
    ref.read(scrollProvider.notifier).updateOffset(horizontal, vertical);
  }
}
```

#### 3. 중복 호출 방지용 필드
```dart
// 그리드 영역의 마지막 레이아웃 크기 (창 최대화/리사이즈 감지용)
Size? _lastGridSize;
```

### 동작 원리 요약
1. 창 최대화 → `Expanded` 그리드 영역 크기 변경 → `LayoutBuilder` 재빌드 (constraints 변경)
2. `_lastGridSize`와 비교해 크기 변화 감지 → `addPostFrameCallback` 등록
3. 프레임 종료(= Syncfusion의 `correctPixels` 보정 완료) 후 콜백 실행
4. 실제 컨트롤러 오프셋을 읽어 `scrollProvider`에 반영
5. `scrollProvider`를 구독하는 화살표 Consumer가 재빌드 → 화살표가 올바른 좌표로 재계산

> 최대화 애니메이션처럼 여러 프레임에 걸쳐 크기가 변해도, 매 constraints 변경마다
> 동기화가 호출되므로 최종 크기에서 자동으로 정확히 보정됩니다.

## ✅ 결과
- **최대화 → 경로 선택** 순서에서 화살표가 처음부터 정위치에 표시됨 (수동 스크롤 불필요)
- 일반 리사이즈, 분할 화면 등 **모든 뷰포트 크기 변경**에 동일하게 대응
- `flutter analyze`: No issues found

## 📌 참고 (디버깅)
- 동기화 발생 시 `🔄 [스크롤 동기화]` 로그가 출력됨 (`AppLogger.exchangeDebug`, 디버그 모드 한정)
- 원인 파악 단계에서 사용했던 `[화살표진단]` 임시 로그(`kArrowDebugLogging`)는 해결 후 제거됨

## 🔗 관련 문서
- `syncfusion_datagrid_recreation_fix.md` — DataGrid 재생성/스크롤 위치 보존 문제
- `technical_issues.md` — 기타 기술 이슈 모음
