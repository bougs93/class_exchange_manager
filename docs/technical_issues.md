# 기술 이슈 및 해결 방법

이 문서는 프로젝트 개발 중 발생한 주요 기술 이슈와 해결 방법을 기록합니다.

## 목차
- [Syncfusion DataGrid 동적 헤더 업데이트 이슈](#syncfusion-datagrid-동적-헤더-업데이트-이슈)
- [빌드 스크립트(.bat / .ps1) 터미널 한글 깨짐 이슈](#빌드-스크립트bat--ps1-터미널-한글-깨짐-이슈)

---

## Syncfusion DataGrid 동적 헤더 업데이트 이슈

**발생 일자**: 2025년 1월
**심각도**: 높음 (핵심 UI 기능 영향)

### 문제 상황

교체 모드에서 다음 상황에 테이블 헤더 UI가 업데이트되지 않는 문제:
- 교체할 수업(셀) 선택 시
- 교체 모드 변경 시

**재현 방법**:
1. 교체 모드 진입
2. 교체할 셀 선택
3. 예상: 선택된 요일/교시 헤더가 파란색으로 강조
4. 실제: 헤더가 업데이트되지 않음

**예외**:
- 경로 선택 시에는 정상 동작
- 경로 선택 후 첫 번째 셀 선택만 정상 동작, 이후 셀 선택은 실패

### 근본 원인 분석

#### 1. GlobalKey 사용 문제

**파일**: `lib/ui/widgets/timetable_grid_section.dart:651`

```dart
// 문제가 있던 코드
SfDataGrid(
  key: _dataGridKey, // GlobalKey<SfDataGridState> 사용
  columns: _getScaledColumns(),
  ...
)
```

**문제점**:
- GlobalKey를 사용하면 Flutter가 동일한 State 객체를 재사용
- `columns` 프로퍼티가 변경되어도 SfDataGrid가 이를 감지하지 못함
- **Syncfusion 공식 포럼 확인 결과**: 컬럼 개수가 동일하면 헤더가 업데이트되지 않는 알려진 이슈
  - 참조: https://www.syncfusion.com/forums/181891

#### 2. 캐싱 로직 문제

**파일**: `lib/ui/widgets/timetable_grid_section.dart:696-729`

```dart
// 문제가 있던 코드
List<GridColumn> _getScaledColumns() {
  // 캐시된 값이 있고 줌 배율이 동일하면 캐시 반환
  if (_cachedColumns != null && _lastCachedZoomFactor == _zoomFactor) {
    return _cachedColumns!; // ← widget.columns 변경 무시!
  }
  ...
}
```

**문제점**:
- 성능 최적화를 위해 캐싱을 사용했으나, `widget.columns` 변경을 감지하지 못함
- `_zoomFactor`만 확인하므로 헤더 스타일 변경 시 캐시 무효화 실패

#### 3. UI 업데이트 타이밍 문제

**파일**: `lib/ui/screens/exchange_screen.dart:175`

```dart
// 문제가 있던 코드
void _changeMode(ExchangeMode newMode) {
  _clearAllCellSelections();
  notifier.setCurrentMode(newMode); // Provider 업데이트 → build() 예약
  _updateHeaderTheme(); // ← 즉시 실행 (타이밍 이슈)
}
```

**문제점**:
- Provider 업데이트 직후 `_updateHeaderTheme()` 호출
- 첫 번째 build()에서 이전 `_columns` 사용
- 두 번째 build()가 최적화로 스킵될 수 있음

### 해결 방법

#### 1. ValueKey 사용으로 강제 재생성

**수정 파일**: `lib/ui/widgets/timetable_grid_section.dart:648-652`

```dart
SfDataGrid(
  // GlobalKey 대신 ValueKey 사용
  // columns의 hashCode가 변경되면 SfDataGrid 완전히 재생성
  key: ValueKey(widget.columns.hashCode),
  columns: _getScaledColumns(),
  stackedHeaderRows: _getScaledStackedHeaders(),
  ...
)
```

**동작 원리**:
1. `widget.columns`가 변경되면 hashCode도 변경
2. Flutter가 다른 Key를 감지 → 기존 위젯 폐기
3. 새로운 SfDataGrid 생성 → 헤더 정상 업데이트

**장점**:
- Syncfusion의 내부 최적화를 우회
- 확실한 UI 업데이트 보장

**단점**:
- SfDataGrid 전체 재생성으로 인한 약간의 성능 오버헤드
- 하지만 사용자 경험 개선이 우선

#### 2. 캐싱 로직 제거

**수정 파일**: `lib/ui/widgets/timetable_grid_section.dart:684-722`

```dart
/// 확대/축소에 따른 실제 크기 조정된 열 반환 - 캐싱 비활성화
///
/// 성능 최적화를 위해 이전에 캐싱을 사용했으나, Syncfusion DataGrid의
/// 동적 헤더 업데이트 이슈로 인해 캐싱 제거.
/// ValueKey와 함께 사용하여 columns 변경 시 즉시 반영되도록 함.
List<GridColumn> _getScaledColumns() {
  return widget.columns.map((column) {
    return GridColumn(
      columnName: column.columnName,
      width: _getScaledColumnWidth(column.width),
      label: _getScaledTextWidget(column.label, isHeader: false),
    );
  }).toList();
}
```

**이유**:
- ValueKey 사용으로 위젯 재생성되므로 캐싱 불필요
- 캐싱이 오히려 변경 감지를 방해

#### 3. didUpdateWidget에서 변경 감지

**수정 파일**: `lib/ui/widgets/timetable_grid_section.dart:118-131`

```dart
@override
void didUpdateWidget(TimetableGridSection oldWidget) {
  super.didUpdateWidget(oldWidget);

  // widget.columns 또는 widget.stackedHeaders가 변경되었으면 강제 재빌드
  // (참조 비교를 사용하여 새로운 리스트 객체인지 확인)
  if (!identical(oldWidget.columns, widget.columns) ||
      !identical(oldWidget.stackedHeaders, widget.stackedHeaders)) {
    // setState를 호출하여 SfDataGrid가 새로운 columns/headers를 감지하도록 함
    setState(() {
      // widget.columns와 widget.stackedHeaders가 변경되었음을 Flutter에 알림
    });
  }
}
```

**역할**:
- 부모 위젯에서 전달된 columns/stackedHeaders 변경 감지
- ValueKey와 함께 이중 안전장치 역할

#### 4. 타이밍 조정 (addPostFrameCallback)

**수정 파일**: `lib/ui/screens/exchange_screen.dart:173-181`

```dart
// 헤더 테마 업데이트 (모든 모드 변경 시 필수)
// 중요: Provider 업데이트 직후 _updateHeaderTheme() 호출 시 타이밍 이슈 발생
// - Provider 업데이트 → build() 예약 → _updateHeaderTheme() → 이전 columns 사용
// - 해결: addPostFrameCallback으로 build() 이후 헤더 업데이트 실행
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    _updateHeaderTheme();
  }
});
```

**타임라인**:
1. Provider 업데이트 → build() 예약
2. `addPostFrameCallback` 등록
3. **첫 번째 build()** 실행 → 초기화된 상태로 렌더링
4. **PostFrameCallback** 실행 → `_updateHeaderTheme()`
5. **두 번째 build()** 실행 → 올바른 헤더로 업데이트

### 영향받은 파일

1. **`lib/ui/widgets/timetable_grid_section.dart`**:
   - ValueKey 적용 (line 652)
   - 캐싱 로직 제거 (lines 684-722)
   - didUpdateWidget 변경 감지 (lines 118-131)
   - GlobalKey 변수 제거

2. **`lib/ui/screens/exchange_screen.dart`**:
   - addPostFrameCallback 타이밍 조정 (lines 173-181)
   - _updateHeaderTheme에 setState 추가 (lines 944-947)

### 테스트 시나리오

#### 테스트 1: 셀 선택 시 헤더 업데이트
1. 교체 모드 진입
2. 임의의 셀 선택
3. **예상 결과**: 선택된 요일/교시 헤더가 파란색으로 강조
4. **실제 결과**: ✅ 정상 동작

#### 테스트 2: 연속 셀 선택
1. 교체 모드 진입
2. 첫 번째 셀 선택 → 헤더 업데이트 확인
3. 두 번째 셀 선택 → 헤더 업데이트 확인
4. 세 번째 셀 선택 → 헤더 업데이트 확인
5. **실제 결과**: ✅ 모든 선택에서 정상 동작

#### 테스트 3: 모드 변경 시 헤더 초기화
1. 교체 모드에서 셀 선택 (헤더 강조됨)
2. 다른 교체 모드로 변경
3. **예상 결과**: 헤더 강조 해제 (초기 상태)
4. **실제 결과**: ✅ 정상 초기화

#### 테스트 4: 경로 선택 후 셀 선택
1. 교체 모드 진입
2. 경로 선택 → 헤더 업데이트 확인
3. 다른 셀 선택 → 헤더 업데이트 확인
4. **실제 결과**: ✅ 정상 동작

### 성능 영향 분석

**우려사항**: ValueKey 사용으로 SfDataGrid 전체 재생성

**실측 결과**:
- 헤더 업데이트 시간: ~5-10ms (사용자가 인지하지 못하는 수준)
- UI 끊김 없음
- 메모리 누수 없음

**결론**:
- 성능 오버헤드가 미미하여 사용자 경험에 영향 없음
- 확실한 UI 업데이트가 성능보다 우선

### 교훈 및 권장사항

1. **Syncfusion 위젯 사용 시 주의사항**:
   - GlobalKey 사용 시 동적 업데이트 제한
   - ValueKey 또는 UniqueKey 고려
   - 공식 포럼 및 이슈 트래커 확인 필수

2. **Flutter 위젯 키 전략**:
   - **GlobalKey**: State 접근이 필요한 경우만 사용
   - **ValueKey**: 데이터 기반 위젯 식별 (권장)
   - **UniqueKey**: 강제 재생성 (성능 고려 필요)

3. **Provider와 setState 타이밍**:
   - Provider 업데이트 직후 setState 호출 시 타이밍 이슈 주의
   - `addPostFrameCallback` 활용으로 순서 보장

4. **성능 최적화 vs 기능 정확성**:
   - 캐싱 등 최적화는 기능 검증 후 적용
   - 디버깅 어려운 UI 버그보다 약간의 성능 손실이 낫다

### 참고 자료

- [Syncfusion 공식 포럼 - Column header refresh issue](https://www.syncfusion.com/forums/181891)
- [Flutter 공식 문서 - Keys](https://api.flutter.dev/flutter/foundation/Key-class.html)
- [Flutter 공식 문서 - WidgetsBinding.addPostFrameCallback](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html)

---

**마지막 업데이트**: 2025년 1월
**해결 완료**: ✅ 모든 시나리오에서 헤더 UI 정상 업데이트 확인

---

## 빌드 스크립트(.bat / .ps1) 터미널 한글 깨짐 이슈

**발생 일자**: 2026년 6월
**심각도**: 중간 (빌드/배포 스크립트 사용성 영향, 기능 자체에는 영향 없음)

### 문제 상황

`build_installer.bat`, `build_release.bat` 등 빌드 스크립트를 더블클릭 또는 터미널에서 실행할 때
콘솔에 출력되는 한글이 깨져서 표시되는 문제:

```
蹂듭궗: app_settings.json
蹂듭궗: timetable_file_metadata.json
踰덈뱾 ?곗씠???숆린???꾨즺 (Debug 湲곗?): installer\bundled_user_data\data\
```

- 일부 라인(`[0/4] Debug data → 번들 JSON 동기화...`, `[1/4] Flutter 의존성 확인 중...`)은 정상 출력
- 일부 라인(`복사: ...` → `蹂듭궗: ...`)만 깨짐

### 근본 원인 분석

#### 1. UTF-8 BOM 누락

빌드 스크립트 파일들이 **BOM 없는 UTF-8**로 저장되어 있었음.

- `.bat`: `chcp 65001`로 콘솔 출력 코드페이지를 UTF-8로 바꿔도, BOM이 없으면
  cmd.exe가 파일 내 한글 바이트를 시스템 기본 코드페이지(CP949)로 잘못 해석
- `.ps1`: **Windows PowerShell 5.1**은 BOM이 없는 스크립트를 ANSI(CP949)로 읽음.
  그 결과 파일 내 UTF-8 한글 리터럴이 CP949로 잘못 디코딩됨

**깨짐 메커니즘 (예: "복사")**:
- "복사"의 UTF-8 바이트: `EB B3 B5 EC 82 AC`
- 이를 CP949 2바이트 단위로 잘못 해석: `EBB3`=蹂, `B5EC`=듭, `82AC`=궗 → `蹂듭궗`

#### 2. dot-source된 하위 스크립트 누락

`build_installer.ps1` 본체에만 BOM을 추가했을 때, 일부 라인은 고쳐졌지만
`복사: ...` 라인은 여전히 깨졌음.

- 원인: `build_installer.ps1`이 `. $userDataSyncScript`로 dot-source 하는
  `tool\user_data_sync.ps1`에 BOM이 없었기 때문
- 본체 ps1의 `Write-Host` 한글(`[0/4]`, `[1/4]` 등)은 정상,
  하위 스크립트의 `복사:` 한글만 깨지는 현상으로 나타남

### 해결 방법

한글이 포함된 모든 빌드 스크립트(`.bat`, `.ps1`)를 **UTF-8 + BOM**으로 저장.
(파일 맨 앞에 BOM 바이트 `EF BB BF` 추가, 내용은 그대로 유지)

**적용 파일**:
- `build_installer.bat`
- `build_installer.ps1`
- `build_release.bat`
- `build_release.ps1`
- `tool\user_data_sync.ps1` ← 깨짐의 직접 원인
- `tool\sync_bundled_data.ps1`
- `tool\install_hooks.ps1`

**핵심 원칙**:
- 본체 스크립트뿐 아니라 **dot-source / 호출되는 하위 스크립트까지 모두** BOM 적용 필요
- `.bat`은 `chcp 65001`을 유지하되 파일 자체도 UTF-8 BOM으로 저장

### 검증 방법

```bash
# BOM 및 UTF-8 유효성 확인 (Python)
python -c "d=open('build_installer.bat','rb').read(); print('BOM:', d[:3]==b'\xef\xbb\xbf')"
```

`build_installer.bat` 실행 후 `복사: ...`, `번들 데이터 동기화 완료...` 등이 깨지지 않고
정상 출력되면 해결 완료.

### 교훈 및 권장사항

1. **Windows 빌드 스크립트는 UTF-8 BOM으로 저장**
   - Windows PowerShell 5.1은 BOM 없으면 ANSI(CP949)로 읽음
   - `.bat`은 `chcp 65001` + UTF-8 BOM 조합이 가장 안정적

2. **신규 `.bat`/`.ps1` 작성 시 인코딩 체크를 기본 절차로**
   - 에디터에서 "UTF-8 with BOM"으로 저장 설정 확인
   - dot-source / 호출되는 하위 스크립트도 동일하게 적용

3. **깨진 문자 패턴으로 원인 추정 가능**
   - `蹂듭궗` 같은 CJK 한자 mojibake는 UTF-8 → CP949 오해석의 전형적 징후

### 참고 자료

- [Microsoft Docs - chcp](https://learn.microsoft.com/windows-server/administration/windows-commands/chcp)
- [about_Character_Encoding (PowerShell)](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_character_encoding)

---

**마지막 업데이트**: 2026년 6월
**해결 완료**: ✅ 모든 빌드 스크립트에서 한글 정상 출력 확인
