# 날짜 기반 시간표 전환 — 단계별 실행 계획

작성일: 2026-09-29
상태: S1, S1.5 구현 완료 (2026-09-29, 모델 전환 없이 Sonnet 5로 진행). S2 이후는 착수 시점에 사용자와 함께 구체화

상위 문서: [date_based_timetable_plan.md](date_based_timetable_plan.md)
진행 기록: [date_based_timetable_handoff.md](date_based_timetable_handoff.md)

## 진행 방식

이 문서는 한 번에 끝까지 확정하지 않는다. **직전 단계가 끝나고 검증된 뒤, 다음 단계를 사용자와 질문을 통해 구체화**한다.
현재는 S0(조사)·S1(데이터 모델)만 상세화한다. S2 이후는 방향만 적어 두고, 실제 착수 직전에 세부 내용을 확정한다.

저장소는 **SQLite를 유지**한다(사용자 확정, 2026-09-29). 패키지·스키마 세부사항은 S2에서 정한다.
첫 구현 단위는 **데이터 모델만** 먼저 만든다(사용자 확정, 2026-09-29). UI·저장소와 연결하지 않아 회귀 위험이 없다.

## 비파괴 검증 공통 체크리스트

아래 단계 중 **UI·저장소·기존 로직에 실제로 손을 대는 단계**(S3 이후)는 완료 전 아래를 확인한다.
S0·S1(순수 모델 추가만)은 기존 코드를 변경하지 않으므로 아래 체크리스트가 필요 없다.

- [ ] `flutter analyze` 통과
- [ ] 관련 기존 `flutter test` 통과 (회귀 없음)
- [ ] 수동 확인: 교체 화면에서 1:1 교체 1건 정상 동작
- [ ] 수동 확인: 주 이동 시 헤더·표시 내용 기존과 동일
- [ ] 수동 확인: 개인 시간표·PDF 출력 기존과 동일

## S0. 현황 조사

의존: 없음. 구현 지시 후 착수.

- [ ] 현재 HEAD·git status 확인, 사용자 미커밋 변경 식별.
- [ ] `TimeSlot`, `ExchangeHistoryItem`, `ResolvedWeek`의 현재 필드와 날짜 관련 로직을 코드 그래프/원문으로 재확인 (2026-09-28 이후 `293d00d` 커밋에서 이미 한 차례 변경됨 — 최신 상태 기준으로 다시 확인).
- [ ] 기존 `flutter test` 전체 실행 결과를 기준선(baseline)으로 기록.

완료 조건: 현재 코드의 날짜 관련 실제 상태와 기준 테스트 결과를 기록.

## S1. 날짜 전용 데이터 모델 (순수 모델만, UI/저장소 미연결) — DONE (2026-09-29)

의존: S0.

목표: 기존 구조를 건드리지 않고, 날짜 기반 모델을 **독립적으로** 추가한다. 아직 아무 화면도 이 모델을 사용하지 않으므로 회귀 위험이 없다.

- [x] 날짜 전용 값 타입 정의 (타임존 변환으로 날짜가 바뀌지 않는 형태) — `SchoolSemester` 생성자가 시각을 제거하고 날짜만 저장한다.
- [x] 학기 범위 모델 정의: `lib/models/school_semester.dart`의 `SchoolSemester` (학년도, 학기(1/2), 시작일, 종료일). `SchoolSemester.defaultFor()`로 1학기 3/1~7/31, 2학기 8/1~다음 해 1/31 기본값 생성.
- [ ] 날짜별 수업 배치 모델(`Lesson` 등)은 아직 만들지 않음 — S2(저장소) 착수 시점에 다시 설계한다.
- [x] 학기 범위 안의 날짜 목록을 생성하는 순수 함수: `lib/utils/semester_date_generator.dart`의 `SemesterDateGenerator` (`datesForWeekday`/`datesForDayName`/`allDates`).
- [x] 유닛 테스트: `test/models/school_semester_test.dart`(10개), `test/utils/semester_date_generator_test.dart`(6개) — 1학기 양 끝, 2학기 연도 경계, 요일별 독립성·중복 없음 확인.

완료 조건: 신규 모델과 생성 함수가 UI·저장소 없이 유닛 테스트로 검증됨 — 총 16개 테스트 통과, `flutter analyze` 문제 없음.
기존 파일은 수정하지 않음(신규 파일만 추가) — 그대로 지켜짐. 날짜별 수업 배치 모델은 범위를 좁혀 다음 단계로 넘겼다.

## S1.5 (후보) "날짜표시" 스위치 — 교체 페이지 표시 전환

2026-09-29 사용자 확정: [계획서 §5 화면 표시 사양](date_based_timetable_plan.md#5-화면-표시-사양-확정-2026-09-29) 참조.

이 기능은 `ExchangeHistoryItem`이 이미 결강일·보강일을 저장하고 있으므로,
학기 전체 날짜 기반 전환(S2 SQLite 등)을 기다리지 않고 **더 먼저 착수 가능한 후보**다.
다만 실제 화면(`SimplifiedTimetableCell`, `TimetableDataSource`, 헤더 빌더)에 손을 대므로 S1보다는 회귀 위험이 있다.

### 코드 조사 결과 (2026-09-29) — 현재는 스위치 없이 날짜 표시가 상시 ON

- `lib/utils/fixed_header_style_manager.dart`의 `buildDayHeaderCell()`(83~85행)이 `date` 인자가 있으면
  **무조건** `"월 (10/6)"` 형식으로 날짜를 붙인다. 조건 분기가 없다.
- 이를 호출하는 `lib/utils/syncfusion_timetable_helper.dart`(91행 `buildStackedHeaderRow`)는
  `weekMonday`를 **항상** 전달하므로, 현재 요일 헤더는 항상 날짜가 붙은 상태다.
- `lib/ui/screens/exchange_screen/widgets/exchange_week_bar.dart`(96행)도 상단에
  `"2026.10.05 ~ 2026.10.09 · 교체 N건"`을 항상 표시한다 (사용자가 캡처로 확인시킨 화면).
- 사용자 요구: 교체 실행 직후 날짜가 바로 펼쳐지는 지금 동작 대신, **기존처럼 날짜 미선택(요일만) 상태를 기본값으로 유지**하고 싶다.

→ 즉, "OFF 모드(요일만, 날짜 없음)"는 지금 존재하지 않는 상태이며 새로 만들어야 한다.
"ON 모드"에 해당하는 상시 날짜 표시만 이미 구현되어 있다. **큰 기능을 제거할 필요는 없고**,
`buildDayHeaderCell`의 날짜 표시를 무조건 → 스위치 값에 따른 조건부로 바꾸는 작은 변경이면 된다.

- [x] 날짜표시 스위치 Provider 추가 — `lib/providers/show_week_header_provider.dart`의 `showWeekHeaderProvider`, **기본값 false(OFF)**.
- [x] `buildDayHeaderCell` 호출부(`grid_header_manager.dart`의 `createSyncfusionGridData`/`updateHeaderTheme` 양쪽)에서 스위치가 OFF면 `weekMonday: null`을 전달해 상시 날짜 표시를 끈다 (요일만 표시로 복귀). `updateHeaderTheme`은 기존에 `weekMonday`를 아예 넘기지 않던 잠재 결함도 함께 바로잡았다.
- [x] `exchange_week_bar.dart`의 날짜 범위 텍스트: OFF일 때 `교체 N건`만 남기고 실제 날짜 범위(`2026.10.05~10.09`)는 숨긴다. 같은 바에 "날짜표시" `Switch` UI 추가 (기존 툴바의 폭 계산 로직(`exchange_control_panel.dart`)은 건드리지 않기 위해 별도 위치에 배치).
- [x] (2026-09-29 추가 확인) 주차 칩(`10월1주`, `9월4주` 등)도 실제 월·주 정보를 드러내므로 OFF일 때 전체 숨김 — 대신 이전/다음 주 화살표로만 이동. 숨긴 자리는 `Spacer()`로 채워 레이아웃 유지.
- [x] 스위치 토글 시 `onShowWeekHeaderChanged` 콜백 → `_updateHeaderTheme(forceUpdate: true)` 경로로 헤더를 강제 재생성 (구조적 변경 감지 로직은 날짜 유무를 컬럼명 변경으로 보지 않으므로 forceUpdate가 필요했다).
- [x] OFF 모드: 요일만 표시 + 교체된 칸(소스/목적지)에 작은 날짜 꼬리표 오버레이 추가 — `TimetableDataSource._resolveOverlayDate` + `SimplifiedTimetableCell`의 `_OverlayDateTag` (우측 상단, 기존 X/○ 심볼과 겹치지 않는 위치).
- [x] **(2026-09-29 버그 수정)** 날짜 꼬리표가 계획서 화면의 실제 결강일·교체일과 다르게 표시되는 문제 발견·수정.
  최초 구현은 `선택 주 월요일 + 요일 오프셋`으로 날짜를 계산했는데, `isExchangedSourceCell`/`isExchangedDestinationCell`가
  전체 히스토리를 `교사_요일_교시` 키로만(주 구분 없이) 판정하기 때문에 실제 결강일·교체일과 무관하게
  "현재 보고 있는 주"의 날짜가 찍히는 오류였다(사용자가 계획서-교체 화면 스크린샷 대조로 발견).
  `lib/utils/exchanged_cell_overlay_dates.dart`(`ExchangedCellOverlayDates.build`)를 신설해
  `ExchangeHistoryItem.absenceDate`/`substitutionDate`를 노드의 요일 기준으로 직접 매핑하도록 교체.
  1:1·보강 교체는 정확히 매핑되고, 순환·2중 교체는 노드 수(3개 이상)가 저장된 날짜(2개)보다 많아
  정확한 매핑이 불가능하므로 **의도적으로 꼬리표를 생략**한다(틀린 날짜 표시보다 안전, S5에서 노드별 날짜 저장으로 재설계 필요).
  회귀 테스트: `test/utils/exchanged_cell_overlay_dates_test.dart`(4개, 사용자 보고 사례 그대로 재현).
- [x] ON 모드: 기존에 이미 있던 `🔲 빠진 수업 / ○ 맡은 수업` 오버레이(`cellStatusSymbolVisibilityProvider`, 날짜표시와 무관하게 항상 존재)를 그대로 재사용 — 별도 구현 불필요했음.
- [x] **(2026-09-29 버그 수정 #2)** 계획서 화면에서 결강일·교체일을 수정해도 "교체" 화면 날짜 꼬리표가 즉시 갱신되지 않는 문제 발견·수정.
  `ExchangeHistoryService.updateDates()`는 `exchangeListVersionProvider`를 올리지만, "교체" 화면의 `TimetableDataSource`는
  이 값을 구독하지 않아 탭을 나갔다 들어오는 등 다른 계기가 있어야만 반영됐다. `TimetableTabContent.build`에
  `ref.listen(exchangeListVersionProvider, ...)`를 추가해 버전이 바뀌면 `dataSource.notifyDataChanged()`를 호출하도록 연결.
  앱 상단 탭은 `IndexedStack`이라 "교체" 탭이 화면에 없어도 위젯이 계속 마운트되어 있으므로, 계획서 탭에서 저장하는 즉시 반영된다.
- [x] **(2026-09-29 버그 수정 #3)** 계획서에서 교체일(substitutionDate)만 수정해도 불필요하게 "다른 주로 이동" 확인
  다이얼로그가 뜨는 문제 발견·수정 (사용자 스크린샷 보고). §10.5 A안(`exchange_week_summary_provider.dart` 주석,
  `ExchangeHistoryItem.weekMonday`)에 따르면 교체 건의 "소속 주"는 **결강일(absenceDate)만으로** 결정되며,
  교체일이 결강일과 다른 주로 넘어가는 것은 정상 동작이다(예: 결강 금요일 → 보강 다음 주 월요일).
  기존 `content_input_grid.dart`의 `_applyDateSelection`은 수정 중인 필드 자체의 주가 바뀌는지로 판단해서,
  교체일 수정 시에도 (결강일 기준 주는 그대로인데) 다이얼로그가 떴다. `columnName == 'absenceDate'`일 때만
  이동 여부를 검사하도록 1차 수정했다.
- [x] **(2026-09-29 사용자 확정)** 위 1차 수정 이후에도 결강일 자체를 다른 주로 옮길 때는 다이얼로그가 여전히 떴는데,
  사용자가 이 확인 자체를 완전히 없애 달라고 요청했다. `_applyDateSelection`에서 `movesWeek` 판정·
  `DialogHelper.showConfirmDialog` 호출을 모두 제거 — 이제 결강일·교체일 모두 다른 주로 옮겨도
  확인 없이 즉시 저장된다. 불필요해진 `week_date_calculator.dart` import도 함께 정리.
- [x] `flutter analyze`(전체) 문제 없음, `flutter test`(전체 216개, 신규 20개 포함) 통과 확인. **미실행**: Windows 데스크톱 앱을 실제로 띄워 스위치 수동 조작·계획서 날짜 수정 즉시 반영·다이얼로그 제거 확인은 아직 못 함 — 사용자 확인 필요.

### 알려진 제한 (S5 이전까지)

순환 교체·2중 교체로 발생한 교체된 칸은 OFF 모드에서 날짜 꼬리표가 보이지 않는다(생략).
X/○ 오버레이 자체는 기존과 동일하게 계속 표시된다 — 날짜 꼬리표만 없다.
`ExchangeHistoryItem`이 참여 노드마다 개별 날짜를 저장하도록 데이터 모델을 확장해야 해결 가능하며, S5(날짜별 교체 검증·저장) 범위다.

**필수 완료 조건 (2026-09-29 사용자 재확인, 최우선순위)**: 앱을 처음 열거나 교체를 처음 실행하는 시점의 기본 상태는
반드시 **날짜 미선택(요일만 표시)** 이어야 한다. 교체를 실행하자마자 날짜가 자동으로 펼쳐지는 지금의 동작(위 조사 결과)은
회귀로 간주한다. `showWeekHeaderProvider` 기본값 false는 이 조건을 만족하기 위한 것이며, 구현 중 어떤 경로로든
교체 직후 자동으로 true가 되거나 날짜가 표시되면 안 된다.

`exchange_week_bar.dart`의 날짜 범위 텍스트 처리 방식(완전히 숨김 vs 주차 라벨만 유지)은 아직 미확정 — 기본값은
"주차 라벨만 유지, 실제 날짜 범위 숨김"으로 제안하되 착수 전 사용자 확인 필요.

착수 시점과 S2~S8과의 순서는 사용자와 다시 확인한다. 이 단계는 두 개 이상의 화면 모드가 생기므로
각 모드를 별도 커밋으로 쪼갠다 (스위치+OFF 모드 먼저 → ON 모드에 새 오버레이 추가 순서를 권장).

## S1.6~S1.10 — 날짜표시 ON일 때 다른 주 교체를 실제 날짜 기준으로 반영

2026-09-29 사용자 보고로 발견: 지금은 교체(결강일 기준)와 실제 보강 날짜가 서로 다른 주에 걸쳐도,
**결강일이 속한 주에만** 양쪽이 몰려서 표시되고, 실제 보강 날짜가 속한 주로 가면 아무것도 안 보인다.
X/○ 하이라이트도 같은 원인(요일·교시 키만 보고 어느 주인지 전혀 구분 안 함)으로 모든 주에 항상 켜져 있다.

Opus 5 설계 검토 완료(2026-09-29). 두 문제 모두 "이벤트 전체가 어느 주에 속하는가"만 보고
"각 참여 칸이 실제로 어느 날짜에 있는가"를 안 보는 같은 근본 원인이다. 아래는 검토 결과와
사용자 확정 사항을 반영한 실행 계획이다.

### 확정 사항 (2026-09-29 사용자 결정)

| 항목 | 결정 |
|---|---|
| 검증(이중배정 방지) 로직 | 화면 표시와 **함께** 이번에 고친다 (표시만 먼저 하고 검증은 나중으로 미루지 않는다) |
| ON/OFF 전환 시 X/○ 칸이 달라지는 것 | 허용한다 — ON(실제 날짜 기준)과 OFF(요일표 기준)는 서로 다른 관점이므로 다른 게 정상 |
| 순환·2중 교체(노드 3개 이상, 저장된 날짜는 2개) | 지금처럼 결강일 주에 몰아서 표시하되 **"?" 표시**로 날짜 미확정임을 알린다. 억지로 날짜를 추정하지 않는다 |
| 요일·실제 날짜 불일치(계획서에서 수요일 칸인데 날짜를 월요일로 고친 경우) | 새 날짜 기반 로직을 적용하지 않고 기존 방식(결강일 주에 표시)으로 안전하게 폴백한다 |
| 교체 화면에서 다른 주를 직접 선택해 새로 교체를 만드는 기능(D2) | 이번 범위 밖. 계획서에서 날짜를 수정해 다른 주로 보내는 기존 방법만 지원 (표시·검증만 고침) |

### 핵심 설계

- **새 순수 유틸 `lib/utils/exchange_cell_dates.dart`**: `ExchangedCellOverlayDates`(이미 있음, 1:1·보강만 지원)의
  날짜 매핑 로직을 일반화해서, 이벤트 하나가 건드리는 각 칸에 실제 날짜를 매핑한다(`ExchangeCellDates`).
  요일·실제 날짜가 일치하지 않으면 `supported = false`로 안전 폴백.
- **`ResolvedWeek.dateAware(...)`** (신규 함수, 기존 `ResolvedWeek.of`는 한 글자도 안 바꿈): 이동의 "빠진 쪽"과
  "채워지는 쪽"을 각자의 실제 날짜가 속한 주에 독립적으로 반영한다. 같은 주 안의 교체는 `of`와 결과가 완전히
  동일해야 한다(회귀 테스트로 보장).
- **X/○ 하이라이트도 같은 방식으로 주별 스코프** — `exchange_executor.dart`의 키 생성 로직을 스위치 ON일 때만
  실제 날짜 기준으로 필터링.
- **검증(`resolvedTimetableProvider`)도 ON일 때 `dateAware`를 쓰도록 연결** (2026-09-29 확정 — 이중배정 방지).
- 모든 변경은 `showWeekHeaderProvider`가 **ON일 때만** 새 경로를 타고, OFF일 때는 기존 함수를 그대로 호출한다
  (호출부에서 분기, 기존 함수 내부는 수정하지 않음) — 이게 회귀 안전성의 핵심이다.

### 단계 분해 (각 단계 완료 조건: `flutter analyze` 전체 통과 + `flutter test` 전체 통과)

- [x] **S1.6 (완료, 2026-09-29)** `lib/utils/exchange_cell_dates.dart` 신설 (순수 유틸, 기존 코드 무변경). `ExchangedCellOverlayDates.build`가
  이 유틸에 위임하도록 리팩터링(출력 동일 확인 — 기존 4개 테스트 그대로 통과). `exchange_executor.dart`의
  `_getCellKeysFromPathStatic`/`_getDestinationCellsFromPathStatic`을 이 유틸로 이동(동작 동일, 위치만 이동, 얇은 위임 함수로 대체).
  요일·실제 날짜 불일치 시 `unsupported` 폴백 가드 포함. 신규 테스트 `test/utils/exchange_cell_dates_test.dart`(8개):
  1:1 4칸 매핑, 요일 불일치 폴백, 보강 2칸 매핑, 순환·2중 unsupported, 다른 주 교체(10.14/10.26 사례) `forWeek` 스코핑,
  legacy 키 동일성. `flutter analyze` 전체 통과, `flutter test` 전체 224개 통과(신규 8개 포함).
- [x] **S1.7 (완료, 2026-09-29)** `ResolvedWeek.dateAware` 추가(아직 연결 안 함, `of`/`exchangePathMoves`/`_applyMove`는
  한 글자도 안 바꿈). 신규 테스트 `test/utils/resolved_week_date_aware_test.dart`(7개): 같은 주 케이스는 `of`와
  결과 100% 동일(1:1·보강), 다른 주로 넘어가는 1:1 교체(결강 10.14 수/10월2주, 교체 10.26 월/10월4주)가 각 주에
  독립 반영, 관계없는 주는 원본 그대로, 순환 교체(날짜 미확정)는 `of`와 동일하게 폴백, 요일 불일치도 폴백.
  `flutter analyze` 전체 통과, `flutter test` 전체 231개 통과(기존 `resolved_week_test.dart` 무수정 통과 포함).
- [x] **S1.8 (완료, 2026-09-29)** `exchange_view_provider.dart`(교체 뷰 표시)와 `resolved_timetable_provider.dart`
  (교체 가능성 **검증**)가 모두 `showWeekHeaderProvider` ON이면 `ResolvedWeek.dateAware`, OFF면 기존 `of`를
  쓰도록 연결(2026-09-29 사용자 확정 — 이중배정 방지를 위해 검증도 표시와 함께 고침). 스위치 토글 시
  `timetable_tab_content.dart`에서 `exchangeViewProvider.refreshIfEnabled(...)`도 함께 호출해 교체 뷰가 켜져
  있으면 그리드가 새 방식으로 다시 합성되게 함. `flutter analyze` 전체 통과, `flutter test` 전체 231개 통과.
  **미실행**: 실제 앱에서 스위치를 켜고 다른 주로 이동해 시간표 내용이 바뀌는지 수동 확인 — 사용자 확인 필요.
- [x] **S1.9 (완료, 2026-09-29)** X/○ 하이라이트를 같은 방식으로 주별 스코프 처리.
  `exchange_executor.dart`의 `_extractExchangedCells`/`_extractDestinationCells`/`restoreExchangedCells`가
  공통 정적 헬퍼 `_computeCellKeys`를 거치도록 통합 — OFF면 `ExchangeCellDates.legacySourceKeys`/
  `legacyDestinationKeys`(기존과 동일), ON이면 `ExchangeCellDates.forWeek`(실제 날짜 기준 주별 스코프).
  더 이상 쓰이지 않는 `_getCellKeysFromPathStatic`/`_getDestinationCellsFromPathStatic` 얇은 위임 메서드는 삭제.
  주 이동·스위치 토글 시 `ExchangeExecutor.restoreExchangedCells(ref)`를 호출하도록 `timetable_tab_content.dart`에
  트리거 추가(지금까지는 주가 바뀌어도 하이라이트가 재계산되지 않던 것도 이번에 같이 고침).
  `flutter analyze` 전체 통과, `flutter test` 전체 231개 통과.
- [x] **S1.10 (완료, 2026-09-29)** 순환·2중 교체의 "?" 미확정 표시 추가. `TimetableDataSource._resolveOverlayDate`가
  ON일 때 `ExchangeCellDates.forWeek`의 `undatedKeys`에 속한 칸에 "?"를 반환하도록 확장 (OFF 동작은 무변경).
  `SimplifiedTimetableCell`의 셀 전체 툴팁에 "순환/2중 교체는 노드별 날짜가 저장되지 않아 결강일 주에 표시합니다"
  설명을 덧붙임. `flutter analyze` 전체 통과, `flutter test` 전체 231개 통과.

**S1.6~S1.10 전체 요약**: 다른 주로 넘어가는 1:1·보강 교체가 날짜표시 ON일 때 각자의 실제 날짜가 속한 주에
독립적으로 반영되고(화면 표시 + 검증 둘 다), X/○ 하이라이트도 같은 기준으로 스코프된다. 순환·2중 교체는
날짜 미확정이라 기존처럼 결강일 주에 묶어 표시하되 "?"로 명시한다. OFF일 때는 기존 동작이 전혀 바뀌지 않는다
(`ResolvedWeek.of`, `exchangePathMoves`, `_applyMove`, `CellStateManager`는 이번 작업 내내 한 글자도 수정하지 않음).
**미실행**: 실제 앱에서 다른 주 교체 시나리오를 눈으로 확인하는 수동 테스트 — 사용자 확인 필요.

각 단계는 별도 커밋으로 진행하고, 완료할 때마다 이 체크리스트를 갱신한다.

## S2 이후 (방향만 기록, 착수 전 재확정)

아래는 이번 계획의 큰 흐름이다. 각 단계 착수 직전에 사용자와 함께 세부 항목·완료 조건·회귀 체크포인트를 다시 정한다.

2026-09-29 사용자 확정: S2~S8은 한 번에 밀어붙이지 않고 **S2부터 하나씩** 진행한다.
미결정 정책(D1·D4·D5·D6·D8)은 해당 단계 진입 직전에 사용자에게 확인한다 — 임의로 정하지 않는다.

| 단계(가안) | 방향 | 기존 기능 영향 |
|---|---|---|
| S2 | **완료(2026-09-29)** SQLite 스키마·Repository 추가 (기존 JSON 저장과 병행, 아직 미사용) | 없음 — 신규 저장소만 추가, 어떤 화면도 아직 참조하지 않음 |
| S3 | **완료(2026-09-29)** 엑셀 등록 시 날짜별 데이터도 함께 생성·저장 (기존 주단위 저장 경로는 그대로 유지) | 낮음 — 부가 기록만 추가 |
| S4 | 전체/개인 시간표 "조회"만 날짜 기반으로 전환 (쓰기는 기존 경로 유지) | 중간 — 여기서부터 실제 화면 검증 필요 |
| S5 | 교체 실행·되돌리기를 날짜 기반 저장으로 전환 (날짜 데이터가 진실 원본이 됨) | 높음 — 핵심 회귀 위험 구간 |
| S6 | 다른 주 교체 UI·표시 | 중간 |
| S7 | 계획서·PDF 출력 날짜 기반 전환 | 중간 |
| S8 | 기존 주단위 전용 코드 제거, 최종 통합 검증 | 정리 단계 — 전체 회귀 테스트 |

### S3 완료 기록 (2026-09-29)

- **확정 정책**: D1(방학·공휴일 — 전체 생성 후 나중에 수업 없는 날 지정), D4(학기 중 재등록 — 별도 새
  시간표로 등록), D5(같은 학기 재가져오기 — 새 시간표로 등록해 기존 데이터 보존) 모두 사용자가 권장안대로 확정.
  현재 등록 흐름 자체가 "새 파일 = 새 시간표" 방식이라 D4·D5는 추가 구현 없이 기존 흐름과 이미 일치한다.
- **학년도·학기 결정 방식**: 등록 화면에 학년도·학기를 직접 고르는 UI가 없어서(기존 "학기 기간" 다이얼로그는
  §10.6 결보강 연도 추정용 날짜 두 개일 뿐, 학년도/학기 필드가 아님), `SchoolSemester.containing(등록시각)`으로
  추정한다(신규 팩토리, `test/models/school_semester_test.dart`에 4개 테스트 추가). 이 값은 아직 어떤 화면도
  노출·수정하지 않는 배경 데이터라 부정확해도 사용자에게 보이는 영향이 없다 — 정확한 값이 필요해지면 S3a
  ("준비 > 기타 설정")에서 사용자가 직접 확인·수정하게 한다.
- **생성 로직**: `lib/services/semester_timetable_generator.dart`의 `SemesterTimetableGenerator.generate`
  (순수 함수, `TimeSlot` 목록 + `SchoolSemester` → `Lesson` 목록). 요일·교시·교사 중 하나라도 없거나 토·일
  칸은 건너뛴다. 신규 테스트 6개(`test/services/semester_timetable_generator_test.dart`).
- **연결 지점**: `lib/ui/screens/timetable_file_screen.dart`의 `_addTimetable()` — 기존 레지스트리 등록
  (`entry` 생성) **직후**, 활성 전환(5단계) **직전**에 삽입. `TimetableRepository`(신규 Riverpod Provider
  `lib/providers/timetable_repository_provider.dart`)로 `DatedTimetable` 메타데이터 + 생성된 `Lesson` 전체를
  현재 배치·스냅샷 양쪽에 저장. **전체를 자체 `try/catch`로 감싸서 실패해도 기존 등록 흐름(레지스트리·JSON
  저장·화면 전환)에는 전혀 영향이 없다** — 에러는 로그만 남긴다.
- **연결 안 된 것 확인**: 조회 화면·개인 시간표·교체 로직 등 기존 코드는 이 저장소를 전혀 읽지 않는다
  (S4에서 연결 예정). 기존 JSON 등록 경로(`TimetableStorageService`, `TimetableRegistryService`)는 한 글자도
  수정하지 않았다.
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 255개 통과(신규 10개: `SchoolSemester.containing`
  4개 + `SemesterTimetableGenerator` 6개). **미실행**: 실제 앱에서 엑셀을 등록해 SQLite에 날짜별 수업이
  실제로 쌓이는지(DB 파일 생성 위치, 행 개수) 수동 확인 — 화면에 노출되는 지점이 아직 없어 지금은 DB 파일을
  직접 열어보는 방법으로만 확인 가능하다.

S4~S5는 이전 시도(`c4867cf`)가 실패한 구간과 겹친다. 이 구간에 진입할 때는 특히 더 잘게 쪼개고,
한 번에 여러 화면·서비스를 동시에 바꾸지 않는다.

### S2 완료 기록 (2026-09-29)

- **패키지 선택**: `sqflite` + `sqflite_common_ffi`. 이 앱은 Windows 데스크톱이 주 대상이라 `sqflite` 단독으로는
  부족하고, `sqflite_common_ffi`가 Windows/Linux/macOS를 지원한다. `drift` 같은 코드 생성 기반 패키지는
  build_runner 의존성이 추가되므로, 이 프로젝트의 "직접 작성" 스타일에 맞춰 더 가벼운 조합을 선택했다.
  `path` 패키지도 직접 의존성으로 추가(기존에는 전이 의존성으로만 존재).
- **스키마**: `timetables`(시간표 메타데이터), `lessons`(현재 배치), `lesson_snapshots`(최초 등록 스냅샷,
  원본 비교 기준 — §10.4 원칙과 동일). 외래키는 선언하되 sqflite가 기본적으로 강제하지 않으므로,
  삭제는 `deleteTimetable`에서 트랜잭션으로 명시적으로 처리한다(외래키 강제 설정에 의존하지 않음).
- **파일**: `lib/data/timetable_database.dart`(DB 열기·스키마 생성, 데스크톱에서 ffi 팩토리 자동 설정),
  `lib/models/lesson.dart`(날짜별 수업 배치 순수 모델), `lib/models/dated_timetable.dart`(시간표 메타데이터,
  `SchoolSemester` 재사용), `lib/repositories/timetable_repository.dart`(CRUD).
- **연결 상태**: 어떤 화면·Provider도 이 저장소를 참조하지 않는다(주석 1건 제외, 코드로 확인). 기존 JSON
  저장 경로는 전혀 건드리지 않았다.
- **검증**: `test/repositories/timetable_repository_test.dart`(9개, 실제 `sqflite_common_ffi` 인메모리 DB로
  검증 — mock 아님), `test/models/lesson_test.dart`(5개). `flutter analyze` 전체 통과, `flutter test` 전체
  245개 통과. **미실행**: 실제 Windows 앱 빌드에서 DB 파일이 정상 생성되는지(`getApplicationSupportDirectory`
  경로) 수동 확인 — 아직 어떤 화면도 이 경로를 타지 않으므로 지금은 확인할 방법이 없고, S3에서 연결한 뒤 확인한다.

## 미결정 제품 정책

아래 항목은 해당 단계 진입 전 사용자 확인이 필요하다. 임의로 확정하지 않는다.

| ID | 항목 | 관련 단계 |
|---|---|---|
| D1 | 방학·공휴일 처리 방식 | **확정(2026-09-29)**: 전체 생성 후 수업 없는 날 별도 지정. 실제 "지정" 기능은 아직 미구현(S3 이후) |
| D2 | 다른 주 교체 UI 방식 | S6, 미결정 |
| D3 | 다른 주 교체에서 순환·2중 지원 범위 | S5, 미결정 (S1.6~S1.10에서 표시·검증은 "?"로 폴백 확정) |
| D4 | 학기 중 새 엑셀 적용 방식 | **확정(2026-09-29)**: 별도 새 시간표로 등록. 기존 등록 흐름과 이미 일치, 추가 구현 없음 |
| D5 | 같은 학기 재등록 시 동작 | **확정(2026-09-29)**: 새 시간표로 등록해 기존 데이터 보존. 기존 등록 흐름과 이미 일치, 추가 구현 없음 |
| D6 | 후속 교체가 있는 되돌리기 정책 | S5, 미결정 |
| D7 | 기본 화면(교체 반영본 vs 원본 비교) | S4, 미결정 |
| D8 | 계획서 날짜 수정의 의미 | S7, 미결정 |

D2·D7과 별개로, "교체" 페이지의 날짜표시 ON/OFF 두 모드 표시 방식 자체는 2026-09-29 확정되었다 (S1.5, 계획서 §5 참조).
D2(다른 주 교체 시 상대 날짜를 어떻게 선택하는가)와 D7(기본 화면이 교체 반영본인지 원본 비교인지)은 이 확정과 별개로 여전히 미결정이다.

## 변경 기록

| 날짜 | 내용 |
|---|---|
| 2026-09-29 | `c4867cf` 실패 이후 재작성. S0·S1만 상세화, SQLite 유지·데이터 모델 우선 착수로 확정 |
