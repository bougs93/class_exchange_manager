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
| S3a | **완료(2026-09-29)** 준비 > 기타 설정에서 학기 기간 확인·반영 | 낮음 — 새 UI 섹션 추가, 기존 설정 카드 다른 부분은 무변경 |
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

### S3a 완료 기록 (2026-09-29)

- **화면 위치**: "준비 > 기타 설정"(`lib/ui/screens/start_content/start_settings_card.dart`)의
  `ExpansionTile` 안, 데이터 저장 위치 섹션과 기본값 복원 카드 사이에 새 섹션 "학기 기간" 추가
  (`lib/ui/screens/start_content/semester_period_section.dart`, 신규 위젯 파일).
- **스키마 변경**: `lessons`·`lesson_snapshots`에 `is_active` 컬럼 추가(스키마 버전 1→2,
  `onUpgrade` 마이그레이션 포함). 기간 축소로 제외된 날짜는 **삭제하지 않고** `is_active=0`으로
  표시만 하고, 재확장 시 그대로 재사용한다(같은 수업 ID 유지). `lesson_snapshots`의 `is_active`는
  항상 1이며 실제로 읽지 않는다 — `Lesson.toMap()`을 두 테이블에 공통으로 쓰기 위한 컬럼 맞춤이다.
- **핵심 로직**: `TimetableRepository.applyPeriodChange()` — 등록 시점 스냅샷에서 (교사, 요일, 교시)별
  대표 내용을 뽑아 템플릿으로 삼고, 새 기간에 필요한 날짜 중 없는 것만 새로 생성(추가), 범위 밖 날짜는
  비활성화(축소), 이미 비활성인 것이 다시 범위에 들어오면 재활성화만 한다(재생성 안 함). 전체 트랜잭션.
  스냅샷 자체는 절대 늘리지 않는다(등록 시점 그대로 고정 — "최초 배치"라는 의미를 유지).
  `getLessonsForDateRange`/`getLessonsForTeacherAndDate`는 기본적으로 활성(`is_active=1`) 수업만 반환하도록
  변경(`includeInactive` 옵션으로 보관분도 조회 가능) — 기존 S2 테스트는 전부 활성 상태만 다뤄서 영향 없음.
- **UI 동작**: 시간표 선택(기본값: 활성 시간표) → 학년도·학기·시작일·종료일 표시(편집 중인 초안과 DB에
  적용된 값 분리) → "기본값으로 복원"(초안만 되돌림, 저장 안 함) → "반영"(실제 저장·재생성, 결과를
  스낵바로 추가/재활성화/보관 건수 표시). 학년도·학기를 바꾸면 그 조합의 기본 기간으로 초안이 자동
  채워진다. 해당 시간표에 SQLite 데이터가 없으면(예: 이 기능 이전에 등록됨) 편집 불가 안내만 표시.
- **의도적으로 생략한 것**: 계획 원문의 "반영 전 교체 이력과 충돌하면 반영 중단" 규칙 — 아직 S5(교체를
  날짜 기반으로 저장)를 하지 않아 이 SQLite 저장소에 교체 이력 자체가 없다. 대상이 없으므로 생략,
  S5에서 실제 교체 이력이 생기면 그때 추가한다.
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 259개 통과(신규 4개: `applyPeriodChange`
  확장/축소/재확장/템플릿-없음 시나리오). 위젯 테스트는 시도했으나 `TimetableRegistryNotifier`가 실제
  파일 I/O 서비스에 강하게 결합돼 있어(비공개 `_initialize`를 하위 클래스에서 안전하게 대체할 수 없음)
  깔끔하게 격리하기 어려워 생략 — `timetable_file_screen.dart` 등 같은 부류의 기존 화면들도 위젯 테스트가
  없어 이 프로젝트의 기존 관례와 같다. **미실행**: 실제 앱에서 화면을 열어 시간표 선택·기간 수정·반영·
  스냅샷에 없는 요일 확장 시 안내 등을 수동 확인 — 사용자 확인 필요.

### 긴급 수정: Windows 실제 빌드에서 "기타 설정" 펼치면 UI가 멈춤 (2026-09-29)

S3a를 실제 Windows 빌드(v1.0.32)에서 확인하던 중 사용자가 발견: 준비 화면에서 "기타 설정"을
펼치면(=`SemesterPeriodSection`이 처음으로 `TimetableRepository`를 통해 DB를 여는 순간) 앱 전체가
응답 없이 멈췄다.

**원인**: `sqflite_common_ffi`는 실제 네이티브 `sqlite3.dll`이 필요한데, 이를 앱에 번들링하는
`sqlite3_flutter_libs` 패키지를 추가하지 않았다. 개발 중 `flutter test`는 이 문제를 드러내지 않았다 —
테스트를 돌리는 개발 PC에는 시스템에 이미 sqlite3가 있어서 우연히 찾아졌지만, 실제로 배포되는 앱
실행 파일 옆에는 그 라이브러리가 없어서 DB를 열려는 시도가 응답 없이 걸린 것으로 보인다(테스트가
녹색이어도 실제 배포 환경에서 실패할 수 있다는 사례 — §"미실행: 실제 앱 확인" 경고가 실제로 근거
있었음을 보여준다).

**수정**: `sqlite3_flutter_libs: ^0.6.0+eol`을 의존성에 추가. 이 패키지는 Windows/Linux/macOS/Android/iOS용
네이티브 sqlite3 라이브러리를 플러그인으로 자동 번들링한다. 코드 변경은 없다(의존성 추가만).
새 네이티브 플러그인이 추가됐으므로 `flutter clean` 후 다시 빌드해야 한다 — 사용자가 직접 재빌드해
**정상 동작 확인 완료(2026-09-29)**.

S4~S5는 이전 시도(`c4867cf`)가 실패한 구간과 겹친다. 이 구간에 진입할 때는 특히 더 잘게 쪼개고,
한 번에 여러 화면·서비스를 동시에 바꾸지 않는다.

### S4 재설계 (2026-09-29, Opus 검토)

원래 S4a("전체 조회를 날짜 기반 읽기로 전환")를 그대로 시도하면 이전 실패(`c4867cf`)와 같은 위험 —
교체 후 SQLite 값이 stale해지는 문제, `isExchangeable` 이중 관리, 학기 범위를 SQLite와 기존 JSON 양쪽이
따로 갖는 문제, 동기 조회 경로가 비동기로 전염되는 문제 — 를 그대로 반복할 수 있다는 점을 Opus 검토로
확인했다. 문자 그대로의 "읽기 전환"은 **S5.5로 이름을 바꿔 뒤로 미루고**, 그 전에 안전하게 검증만 하는
단계를 S4.0~S4.4로 새로 채워 넣는다. 사용자 승인 완료("예, 이대로 진행").

| 단계 | 내용 | 비고 |
|---|---|---|
| S4.0 | 읽기 전용 SQLite 확인 패널 (준비 > 기타 설정) | 완료 (아래 기록) |
| S4.1 | `WeekSemesterStatus` 순수 유틸 + `dated_semester_provider.dart` | 아직 어떤 위젯도 사용하지 않음, 미착수 |
| S4.2 | 교체 화면 주간바에 학기 범위 밖 주 안내 아이콘/툴팁 1개 (날짜표시 ON일 때만) | 미착수, OQ-2(아이콘만·비차단)·OQ-3(SQLite `DatedTimetable.semester`를 기준으로)·OQ-5(OFF일 때는 경고 없음) Opus 권장안 반영 예정 |
| S4.3 | 개인 시간표에도 동일 안내 적용 여부 | 별도 승인 필요(OQ-4), 미착수 |
| S4.4 | 표시값과 SQLite 값의 드리프트 자가 점검 패널 | 미착수 |
| S5.5 | (구 S4a) 전체 조회를 날짜 기반 SQLite 읽기로 실제 전환 | 미착수, S5 이후로 순서 이동 |

### S4.0 완료 기록 (2026-09-29)

- **화면 위치**: "준비 > 기타 설정"의 `SemesterPeriodSection` 바로 아래에 새 섹션 "날짜 기반 데이터 확인
  (읽기 전용)" 추가 (`lib/ui/screens/start_content/dated_data_inspector_section.dart`, 신규 위젯 파일).
  `start_settings_card.dart`에 배치만 하고 다른 로직은 건드리지 않았다.
- **표시 내용**: 선택한 시간표의 `timetables` 행(이름·학년도·학기·시작일·종료일·교사명·학교명·등록
  시각), `lessons` 총 개수·활성/보관 개수, `lesson_snapshots` 개수, 저장된 날짜의 최이른/최늦은 값,
  DB 파일 절대 경로(복사 버튼 포함). **쓰기 버튼 없음** — 값을 고치려면 여전히 `SemesterPeriodSection`을
  쓴다.
- **핵심 로직 추가**: `TimetableRepository.getLessonStats(timetableId)` — 전체 행을 메모리에 올리지 않고
  `COUNT(*)`/`MIN(date)`/`MAX(date)` 집계 쿼리만 사용(Opus 권장 그대로). `TimetableDatabase
  .defaultDatabasePath()` — 기존 비공개 `_defaultDatabasePath()`를 감싼 공개 wrapper, 패널에서 DB 경로를
  보여주기 위해서만 추가.
- **연결 상태**: 이 패널은 SQLite를 **읽기만** 한다 — 교체 화면·개인 시간표 등 기존 조회 경로는
  전혀 건드리지 않았다(S5.5에서 실제 전환 예정).
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 262개 통과(신규 3개:
  `getLessonStats` 집계/빈 데이터/시간표 간 격리). 사용자가 실제 Windows 앱에서 패널을 열어
  표시값(수업 40,768건·날짜 범위 등)이 실제 DB 내용과 일치함을 **확인 완료(2026-09-29)**.
- **버그 발견·수정(2026-09-29)**: 위 수동 확인 과정에서 "기타 설정"을 펼치면 예외가 발생하는 문제를
  발견 — S4.0이 아니라 S3a 때 작성된 기존 `SemesterPeriodSection`의 버그였다. 원인: `_isLoadingApplied`
  기본값이 `false`였는데 실제 로드는 `addPostFrameCallback`으로 한 프레임 뒤에 실행되어, 첫 렌더에
  `_draftSemesterNumber`가 `null`인 채로 `SegmentedButton`을 그렸고 `selected` 집합이 비면 안 된다는
  Flutter assertion에 걸렸다. `_isLoadingApplied` 기본값을 `true`로 바꿔 첫 프레임은 항상 로딩
  스피너부터 시작하도록 수정(`lib/ui/screens/start_content/semester_period_section.dart`). 수정 후
  재검증: `flutter analyze` 통과, `flutter test` 전체 262개 통과, 사용자가 재빌드해 정상 동작 확인.

### S4.1 완료 기록 (2026-09-29)

- **신규 파일**: `lib/utils/week_semester_status.dart` — `WeekSemesterStatus` enum
  (`withinRange`/`beforeRange`/`afterRange`/`unknown`) + `WeekSemesterStatusChecker.check()` 순수 함수.
  주(월요일 기준 월~금 5일)와 `SchoolSemester?` 하나를 받아 관계를 판정한다. `semester`가 null이면
  무조건 `unknown` — "범위를 모른다"와 "범위 밖이다"를 구분해서, 날짜 데이터가 없는 시간표를 실수로
  "범위 밖"으로 표시하지 않는다. `lib/providers/dated_semester_provider.dart` — 활성 시간표의 SQLite
  저장 `SchoolSemester`를 비동기로 노출하는 `datedSemesterProvider`(`FutureProvider<SchoolSemester?>`).
  활성 시간표가 없거나 날짜 기반 데이터가 없으면 null.
- **연결 상태**: 어떤 위젯도 이 유틸·Provider를 아직 참조하지 않는다 — S4.2에서 교체 화면 주간바에
  처음 연결할 예정. 순수 로직 추가만이라 기존 기능 회귀 위험 없음.
- **검증**: `test/utils/week_semester_status_test.dart` 신규 7개(범위 안/밖/경계/unknown 시나리오).
  `flutter analyze` 전체 통과, `flutter test` 전체 269개 통과.

### S4.2 완료 기록 (2026-09-29)

- **화면 위치**: 교체 화면 상단 주차 바(`lib/ui/screens/exchange_screen/widgets/exchange_week_bar.dart`),
  날짜 범위·교체 건수 텍스트 바로 뒤에 작은 안내 아이콘(`Icons.info_outline`) 1개 추가.
- **표시 조건**: `showWeekHeaderProvider`(날짜표시)가 **ON일 때만** 표시(OQ-5 확정 — OFF일 때는 애초에
  실제 날짜 개념 자체가 화면에 드러나지 않으므로 경고도 함께 숨긴다). 그리고 선택된 주가
  `WeekSemesterStatusChecker.check()` 결과 `beforeRange`/`afterRange`일 때만 표시(`withinRange`·
  `unknown`이면 표시 안 함 — 날짜 기반 데이터가 없는 시간표는 "범위 밖"으로 단정하지 않는다, S4.1 설계
  그대로). 학기 범위는 `datedSemesterProvider`(S4.1, 활성 시간표의 SQLite 저장 `SchoolSemester`)에서
  가져온다(OQ-3 확정 — SQLite `DatedTimetable.semester`가 기준).
- **표시 방식**: 아이콘 하나 + 툴팁("학기 시작 전 주입니다"/"학기 종료 후 주입니다")뿐이며 클릭 동작이나
  다이얼로그가 없다(OQ-2 확정 — 비차단·정보 제공만, 사용자 흐름을 막지 않음).
- **가시성 개선(2026-09-29)**: 실제 앱 확인 중 사용자가 아이콘을 찾지 못함 — 원래 회색 계열
  (`theme.colorScheme.tertiary`, 14px)이라 텍스트에 묻혀 눈에 안 띄었다. 주황색(`Colors.orange.shade700`,
  16px)으로 강조하도록 수정, 위치(날짜 범위 텍스트와 "날짜표시" 스위치 사이)는 그대로 유지. 이어서
  사용자가 "날짜도 같이 강조해달라" 요청 — 날짜 범위·건수 텍스트 자체도 학기 범위 밖일 때 같은
  주황색 + 굵게(`FontWeight.w600`)로 바뀌도록 추가 수정.
- **기존 동작 영향**: 없음 — 새 아이콘 하나가 조건부로 추가됐을 뿐, 주차 이동·칩 선택·날짜표시 토글 등
  기존 로직은 한 글자도 바꾸지 않았다.
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 269개 통과(회귀 없음, 이 위젯 자체는
  기존에도 위젯 테스트가 없어 신규 테스트도 추가하지 않음 — 순수 로직인 `WeekSemesterStatusChecker`는
  S4.1에서 이미 검증됨). **사용자 확인 완료(2026-09-29)**: 실제 Windows 앱에서 학기 범위 밖 주(5월1주,
  활성 시간표는 2026년 2학기 8월~1월)로 이동 시 주황색 아이콘·강조된 날짜 텍스트가 정상 동작함을 확인.

### S4.3 보류 (2026-09-29)

개인 시간표 화면에도 같은 안내를 적용할지(OQ-4)는 사용자가 "지금은 적용 안 함"으로 결정 —
교체 화면(S4.2)에만 두고, 필요해지면 나중에 별도로 추가한다. 코드 변경 없음.

### S4.4 완료 기록 (2026-09-29)

- **배경**: 교체 실행·되돌리기는 아직 기존 JSON 저장소(`ExchangeHistoryService`)에만 기록되고
  SQLite로는 전혀 전달되지 않는다(연결은 S5 이후). 그래서 S4.0 확인 패널의 수업 데이터는 항상
  "최초 등록 시점" 기준으로 고정돼 있다 — 사용자가 교체를 여러 건 실행한 뒤 이 패널을 다시 보면
  아무것도 안 바뀐 것처럼 보여 오해할 수 있다.
- **구현**: 범위를 최소화 — 복잡한 행 단위 비교 로직 없이, `dated_data_inspector_section.dart`
  (S4.0 패널)에 안내 한 줄만 추가. 현재 선택한 시간표가 **활성** 시간표일 때만
  "현재 교체 이력: N건 (참고: 이 수치는 위 SQLite 수업 데이터에 아직 반영되지 않습니다 — 추후 단계에서
  연결 예정)"을 보여준다. 다른(비활성) 시간표를 보는 중에는 비교 대상이 아니므로 표시하지 않는다.
  건수는 `exchangeHistoryServiceProvider.getActiveExchangeList().length`, `exchangeListVersionProvider`를
  watch해 교체 리스트가 바뀔 때마다 갱신된다.
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 269개 통과(회귀 없음, 신규 테스트는
  추가하지 않음 — 순수 문자열 조합 + 기존에 이미 검증된 Provider 조회뿐). **미실행**: 실제 앱에서
  교체를 실행한 뒤 이 안내 문구가 정확한 건수로 보이는지 수동 확인 — 사용자 확인 필요.


## S5. 교체 실행·되돌리기를 날짜 기반 저장으로 전환

### S5 설계 검토 (2026-09-29, Opus 5)

S1.6~S1.10·S3a·S4 재설계와 같은 방식으로, 실제 실행 로직에 손을 대는 이 구간은 Opus 5 서브에이전트
설계 검토를 먼저 받았다. 전체 검토서 원문은 세션 기록에 있으며, 핵심만 요약한다.

**핵심 설계 결정**: "교체 실행을 날짜 기반 저장으로 전환한다"를 "SQLite `lessons` 행을 교체 시점에
직접 고쳐쓰기"로 해석하면 `c4867cf`와 같은 실패(진실 원본 2개, 서로 어긋나면 복구 불가)가 재현된다.
대신 **"교체 이벤트 저널(`exchange_events`)을 SQLite에 두고, `lessons`는 그 저널을 재생(replay)해
만드는 파생 뷰로만 취급"**하는 방식을 채택한다. 저널이 진실 원본, `lessons`는 언제든 다시 계산해
복구 가능한 캐시.

`ExchangeHistoryService`의 **동기 public API는 한 글자도 바꾸지 않는다** — 이미 존재하는 비동기
저장 큐(`_enqueueStorageOperation`) 뒤쪽에만 SQLite 미러 쓰기를 추가한다. 이것이 기존 소비자
30여 곳(표시·검증·계획서·개인 시간표·PDF 출력)을 전부 무변경으로 지키는 유일한 방법이다.

**소비자 전수 조사에서 발견한 것 2건**:
- `lib/utils/personal_exchange_view_manager.dart`(276줄)는 `ResolvedWeek`를 쓰지 않는 **제2의
  교체 적용 경로**인데 현재 어디서도 호출되지 않는 죽은 코드다. S5에서 재연결하지 않는다(삭제는 S8).
- 개인 시간표는 `ResolvedWeek`가 아니라 `SubstitutionPlanViewModel.loadPlanData()`가 만드는
  계획서 데이터로 교체를 표시한다 — S5가 `loadPlanData()`를 건드리지 않는 한 개인 시간표는
  자동으로 보호된다.

**단계 분해 (S5.0~S5.4b, 각 단계 커밋 분리)**:

| 단계 | 내용 | 화면 영향 |
|---|---|---|
| S5.0 | `exchange_events` 저널 스키마 + Repository CRUD | 없음(완전 비연결) |
| S5.1 | 교체 실행·삭제·되돌리기 시 저널에도 부가 기록(JSON이 여전히 진실 원본) | 없음(쓰기 전용 미러) |
| S5.2 | S4.4 드리프트 패널을 "JSON N건 / SQLite M건 / 불일치 K건"으로 확장 | 읽기 전용 패널만 |
| S5.3 | 저널 재생 순수 함수 + `ResolvedWeek.dateAware`와 결과 일치 검증(DB 미기록) | 없음 |
| S5.4 | 되돌리기 의존성 경고(비차단, 스낵바 문구만) | 문구 추가만 |
| S5.4a | `lessons` 실제 투영 기록 시작(파생 뷰 갱신) | 없음(여전히 아무 화면도 `lessons` 안 읽음) |
| S5.4b | 저널을 SQLite에서 읽어오도록 전환 — **"여기서부터 신규가 진실 원본"** | JSON→SQLite 1회 자동 이관 |

**S5와 S5.5의 관계**: S5는 **저장(쓰기) 계층**만 바꾸고, 기존에 이름이 확정된 S5.5(구 S4a)는
**조회(읽기) 계층**을 SQLite로 전환하는 별개 단계다. 순서는 S5 전체 완료 → S5.5. S5.4a(투영 실제
기록)가 없으면 S5.5는 정체된 데이터를 읽게 되므로, S5.4a는 S5.5의 기술적 선행 조건이다.

### 공개 질문(OQ-1~8) 확정 사항 (2026-09-29 사용자 승인 — "전체적으로 진행해줘")

Opus 권장안을 전부 그대로 채택한다.

| ID | 결정 |
|---|---|
| OQ-1 | 순환·2중 교체에 `nodeDates`(노드별 날짜) 저장 지원. 단 S5 범위에서는 "모든 노드가 결강일과 같은 주"로만 자동 채움 — 노드별로 다른 주를 지정하는 UI는 만들지 않음(S6 이후) |
| OQ-2 | 후속 교체가 있는 되돌리기는 **막지 않고** 스낵바에 "이후 교체 N건이 이 교체를 전제로 합니다" 경고만 추가 |
| OQ-3 | 기본 화면(교체 반영본 vs 원본, D7)은 S5에서 바꾸지 않음 — 확정은 S5.5/S7로 이월 |
| OQ-4 | 기존 JSON 교체 목록은 앱 시작 시 SQLite에 없으면 1회 자동 임포트, 원본은 `*.v2.bak`으로 보관, 임포트 실패 시 JSON 경로로 자동 폴백 |
| OQ-5 | 되돌리기/다시실행 스택은 계속 메모리 전용(현행 유지) — 재시작 후에도 되돌리기 가능해지는 기능 변화 없음 |
| OQ-6 | 빈 칸에 보강이 채워질 때 `lessons`에 새 행을 삽입 — 단 결정적 ID(`evt_<eventId>_<date>_<period>_<teacher>`)로 재생이 여러 번 돌아도 중복 안 되게(멱등) |
| OQ-7 | 학기 기간 축소가 활성 교체와 겹치면 **유일하게 차단** — 데이터 유실 방지(다른 곳은 전부 비차단 원칙, 여기만 예외) |
| OQ-8 | 위 8단계 분해 + S5→S5.5 순서(S5가 S5.5를 포함하지 않음)에 동의 |

### S5.0 완료 기록 (2026-09-29)

- **신규 파일**: `lib/models/exchange_event_record.dart` — `ExchangeEventRecord` 클래스. 이 단계에서는
  교체 로직을 전혀 갖지 않고 `toMap()`/`fromMap()`(SQLite 직렬화)만 담당한다. `pathJson` 필드는
  `ExchangePath.toJson()` 결과를 그대로 문자열로 담아서, `ExchangeListStorageService`가 JSON 파일에
  쓰는 것과 **같은 직렬화 포맷**을 재사용하도록 설계했다(S5 설계 검토 R1 — 직렬화기 이원화 금지).
- **스키마 변경**: `timetable_database.dart` 스키마 버전 2→3. 새 테이블 `exchange_events`
  (id, timetable_id, seq, type, absence_date, substitution_date, is_reverted, path_json,
  node_dates_json(OQ-1용, 현재 항상 null), description, notes, tags_json, profile_id, metadata_json,
  created_at) + `(timetable_id, seq)` 인덱스. `onUpgrade`에 `oldVersion < 3` 분기 추가, 신규 설치는
  `_createSchema`에서 바로 생성.
- **Repository**: `TimetableRepository`에 `upsertExchangeEvents`(배치 upsert, `ConflictAlgorithm.replace`
  — JSON 저장의 "리스트 전체 다시 쓰기"와 같은 멱등성 유지), `getExchangeEvents`(seq 순 조회),
  `deleteExchangeEventsFor` 추가. `deleteTimetable` 트랜잭션에 `exchange_events` 삭제도 포함시킴
  (기존 lessons/lesson_snapshots 삭제와 같은 트랜잭션).
- **연결 상태**: 이 시점에는 **어떤 서비스·화면도 이 테이블을 읽거나 쓰지 않는다.** `ExchangeHistoryService`
  등 기존 코드는 한 글자도 바뀌지 않았다 — 순수 추가.
- **검증**: `test/repositories/timetable_repository_test.dart`에 "교체 이벤트 저널 (S5.0)" 그룹 신규
  6개(seq 순서 조회, upsert 멱등성, 시간표 간 격리, `deleteExchangeEventsFor`, `deleteTimetable` 연쇄
  삭제, 저장·조회 왕복 시 path_json·태그·메타데이터 보존). `flutter analyze` 전체 통과, `flutter test`
  전체 275개 통과(회귀 없음). **미실행**: 스키마 마이그레이션(버전 2→3) 자체는 별도 테스트하지 않음 —
  기존 v1→v2 마이그레이션도 같은 방식으로 테스트 없이 진행된 전례를 따름. 실제 앱 동작은 이 단계에서
  전혀 바뀌지 않으므로 사용자 수동 확인 불필요.

### S5.1 완료 기록 (2026-09-29)

- **신규 파일**: `lib/services/exchange_event_mirror.dart` — `toExchangeEventRecords(items, timetableId)`
  순수 변환 함수. `List<ExchangeHistoryItem>` → `List<ExchangeEventRecord>`로 변환하며 SQLite에
  직접 쓰지 않는다. `seq`는 목록 순서(= 실행 순서)를 그대로 사용, `pathJson`은
  `jsonEncode(item.originalPath.toJson())`로 기존 JSON 저장과 같은 포맷을 재사용한다.
- **Repository 확장**: `TimetableRepository.replaceExchangeEventsFor(timetableId, events)` 추가 —
  삭제 후 삽입을 한 트랜잭션으로 묶어 "리스트 전체를 매번 다시 쓰기"라는 기존 JSON 저장과 같은
  멱등적 의미론을 재현한다. `removeFromExchangeList`로 메모리에서 삭제된 교체 건이 저널에 유령처럼
  남지 않는 이유가 이것이다(S5.0의 `upsertExchangeEvents`는 갱신만 하고 삭제를 못 하므로 이 메서드로
  보완).
- **`ExchangeHistoryService` 확장**: 선택적 보조 싱크 `mirrorSink`
  (`Future<void> Function(List<ExchangeHistoryItem>, String) ?`)와 `mirrorClearSink`
  (`Future<void> Function(String)?`) 필드 추가, 기본값 둘 다 null. `_enqueueExchangeListSave`가 JSON
  저장을 큐에 넣은 **직후 같은 큐**에 `mirrorSink` 호출을 추가(순서 보장), `_clearLocalStorage`도
  동일하게 `mirrorClearSink`를 추가. **동기 public API 시그니처는 한 글자도 바뀌지 않았다** — 이미
  있던 `_enqueueStorageOperation`(내부에서 예외를 잡아 로그만 남김) 뒤쪽에만 훅을 추가했으므로,
  `addExchange`/`undoLastExchange`/`updateDates` 등은 전부 여전히 동기 `void`다(S5 설계 검토 R3
  "동기→비동기 전염" 위험 회피).
- **Provider 연결**: `services_provider.dart`의 `exchangeHistoryServiceProvider`에서 두 싱크를
  주입 — `mirrorSink`는 `TimetableRepository.replaceExchangeEventsFor`를, `mirrorClearSink`는
  `deleteExchangeEventsFor`를 호출한다. `ExchangeHistoryService`는 싱글톤이므로
  `resetForTesting()`에 `mirrorSink`/`mirrorClearSink` 초기화도 추가해, 위젯 테스트가 먼저 이
  Provider를 빌드해도 이후 순수 유닛 테스트가 오염되지 않도록 방어했다.
- **의도적으로 지금은 하지 않는 것**: `loadFromLocalStorage()`는 여전히 JSON에서만 읽는다 — **JSON이
  계속 진실 원본**이다. SQLite 쓰기가 실패해도(예: DB 아직 미준비) 앱 동작에 전혀 영향이 없다.
- **검증**: `test/services/exchange_event_mirror_test.dart` 신규 5개(빈 목록, seq 매핑, pathJson
  왕복, 필드 1:1 매핑, supplement 타입), `test/repositories/timetable_repository_test.dart`에
  `replaceExchangeEventsFor` 테스트 3개 추가(삭제된 건 제거, 시간표 간 격리, 빈 목록으로 전체 비움).
  `flutter analyze` 전체 통과, `flutter test` 전체 283개 통과(회귀 없음 — 기존
  `exchange_history_service_test.dart`, 위젯 테스트 전부 무수정 통과). **사용자 확인 완료
  (2026-09-29)**: 실제 앱에서 1:1/순환/2중/보강 교체 실행·되돌리기·삭제 조작 후 기존과 동일하게
  정상 동작함을 확인.

### S5.2 완료 기록 (2026-09-29)

- **배경**: S5.1로 SQLite에 부가 기록이 시작됐지만, 이 기록이 실제로 잘 쌓이고 있는지 확인할 화면이
  아직 없었다(S4.0/S4.4 패널은 여전히 "미반영" 안내만 보여줌). S5.2는 이 확인 화면을 실제 비교로
  바꾼다.
- **구현**: `dated_data_inspector_section.dart`의 드리프트 안내 한 줄을 확장 — "교체 이력: JSON N건
  · SQLite 저널 M건 · 일치" 또는 불일치 시 "· 불일치 K건"을 주황색 강조 테두리·굵은 글씨와 함께
  표시한다(S4.2와 같은 강조 스타일). `TimetableRepository.getExchangeEvents(timetableId)`를
  `_load()`에서 함께 조회해 `is_reverted=0`인 건수만 SQLite 쪽 값으로 센다(JSON의
  `getActiveExchangeList()`와 같은 기준 — 되돌린 건은 양쪽 다 제외).
- **실시간성에 대한 설계 결정**: JSON 쪽 건수는 `exchangeListVersionProvider`를 watch해 실시간
  갱신되지만, SQLite 쪽은 `_load()` 시점의 스냅샷이다 — 미러 쓰기가 비동기 큐라 "지금 이 순간"
  완전히 같다고 보장할 수 없기 때문이다. 대신 작은 새로고침 아이콘을 추가해 사용자가 언제든
  다시 셀 수 있게 했다. 두 값이 순간적으로 다르게 보이는 것 자체는 정상(큐가 아직 안 비워짐)이며,
  새로고침 후에도 계속 다르면 그것이 진짜 드리프트다.
- **연결 상태**: 여전히 읽기 전용. 쓰기 버튼 없음.
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 283개 통과(회귀 없음, 신규 테스트는
  추가하지 않음 — 이미 S5.0·S5.1에서 검증된 Repository 메서드(`getExchangeEvents`)를 UI에서
  조합해 보여줄 뿐이라 새 로직이 없다).

### S5.1 보완: 기존 이력이 계속 "불일치"로 뜨는 문제 발견·수정 (2026-09-29)

사용자가 S5.2 화면을 실제로 열어보니 "JSON 2건 · SQLite 저널 0건 · 불일치 2건"으로 표시됨 —
버그로 의심됐으나 원인 조사 결과 **설계상 당연한 틈**이었다.

**원인**: `mirrorSink`는 `_enqueueExchangeListSave`/`_clearLocalStorage`, 즉 "새로 저장할 때"만
호출된다. 이 2건은 S5.1 코드가 생기기 전부터 이미 JSON 파일에 있던 이력이라, 앱 시작 시
`loadFromLocalStorage()`로 메모리에만 올라왔을 뿐 SQLite에는 한 번도 쓰인 적이 없었다.
디버그 테스트(`ProviderContainer` + 인메모리 DB로 실제 서비스 배선을 그대로 재현)로 재현·확인:
mirrorSink를 끈 채 교체 1건을 저장 → SQLite 0건(사용자가 본 증상과 동일) → 그 상태에서 **새
교체를 1건 더 실행**하면 그 순간 메모리의 전체 리스트(기존 것 포함)가 다시 저장되면서 SQLite에
2건 모두 나타남을 확인 — 즉 "아무 새 조작이나 한 번 하면 자연히 따라잡는" 구조였다.
- **수정**: 매번 새 조작을 기다리지 않도록, `loadFromLocalStorage()`가 JSON 로드를 마친 직후
  한 번 `mirrorSink`를 호출해 방금 불러온 전체 목록을 SQLite에도 밀어 넣도록 보완했다
  (`lib/services/exchange_history_service.dart`). 여전히 같은 저장 큐(`_enqueueStorageOperation`)
  뒤쪽에만 붙였으므로 JSON은 계속 진실 원본이고, 동기 API도 무변경이다.
- **검증**: `test/services/exchange_history_mirror_sync_test.dart` 신규 1개 — mirrorSink 없이
  저장된 기존 이력이 `loadFromLocalStorage()` 한 번으로 SQLite에 반영됨을 확인. `flutter analyze`
  전체 통과, `flutter test` 전체 284개 통과. **사용자 확인 완료(2026-09-29)**: 재빌드 후 S5.2
  패널이 "JSON 2건 · SQLite 저널 2건 · 일치"로 표시됨을 확인 — **S5.3 진입 게이트 통과**.

### S5.3 완료 기록 (2026-09-29)

- **신규 파일**: `lib/utils/lesson_projection.dart` — `project({snapshot, activeEvents, timetableId})`
  순수 함수. `List<Lesson>`(날짜별 수업 배치)에 활성 교체 이벤트를 재생(replay)한 결과를
  `List<Lesson>`으로 반환한다. **SQLite에 아무것도 쓰지 않는다** — 계산만 한다(실제 기록은
  S5.4a에서 이 함수를 재사용).
- **핵심 설계**: `ResolvedWeek.dateAware`가 이미 쓰는 `exchangePathMoves`(`resolved_week.dart`)와
  `ExchangeCellDates.forItem`을 **그대로 재사용**한다 — 새 규칙을 따로 만들지 않아, 화면 합성
  로직과 투영 로직이 구조적으로 어긋날 수 없다(S1.6에서 세운 "판단 기준을 한 곳에 모은다" 원칙을
  그대로 이어받음). 순환·2중 교체(노드별 날짜 없음)는 OQ-1 채택안대로 "결강일이 속한 주의 월~금"
  으로 폴백해 채운다.
- **핵심 회귀 테스트(등식 증명)**: `test/utils/lesson_projection_test.dart` 신규 6개 — 1:1 같은 주,
  보강 같은 주, 1:1 다른 주(결강일 주·교체일 주·관계없는 주 3곳 모두), 순환 교체(날짜 미확정 폴백),
  요일-실제날짜 불일치 폴백, 이벤트 없을 때 원본과 동일. 각각 `project(...)`를 특정 주로 필터한
  결과와 `ResolvedWeek.dateAware(...).toTimeSlots(...)`가 **완전히 일치**함을 확인했다 — 기존
  `resolved_week_date_aware_test.dart`의 픽스처(정원길/박은선 3-8 기술가정, 10.14/10.26, 8.24
  순환 A/B/C)를 그대로 재사용해 두 검증 사이에 괴리가 없게 했다.
- **연결 상태**: 어떤 화면·서비스도 이 함수를 아직 호출하지 않는다 — 순수 추가.
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 290개 통과(신규 6개, 회귀 없음).
  화면 동작은 전혀 바뀌지 않으므로 사용자 수동 확인 불필요.

### S5.4 완료 기록 (2026-09-29)

- **배경**: D6(후속 교체가 있는 되돌리기 정책) — 예: A선생님 결강으로 빈 칸을 B선생님 보강이
  나중에 사용하고 있는데, A의 원래 교체를 되돌리면? Opus 권장안(OQ-2)은 "막지 않고 비차단
  경고만" — S4.2에서 이미 채택한 "비차단·정보 제공만" 원칙과 동일선상.
- **신규 파일**: `lib/utils/exchange_dependency_checker.dart` — `findDependentExchanges({target,
  allEventsInOrder})` 순수 함수. 되돌리려는 교체(`target`)가 만든 칸(목적지)을, `target` 이후에
  실행된 **활성** 교체가 source/destination으로 쓰고 있으면 의존으로 판정해 목록을 반환한다.
  좌표는 `ExchangeCellDates.legacySourceKeys`/`legacyDestinationKeys`(요일·교시 기준, 날짜 무관)를
  재사용 — 기존 `isCellExchanged` 등과 같은 판정 기준이라 새 규칙을 만들지 않았다. 실제 날짜까지
  구분하지 않아 다른 주의 같은 요일·교시를 과대 감지할 수 있지만, 이 함수는 차단이 아니라 안내일
  뿐이므로 과대 감지 쪽이 안전하다는 판단(놓치는 것보다 낫다).
- **연결**: `exchange_executor.dart`의 `undoLastExchange`에서 되돌리기를 **그대로 수행한 뒤**
  `findDependentExchanges`로 의존 건을 확인, 있으면 기존 스낵바 메시지 뒤에 "(참고: 이후 교체
  N건이 이 교체를 전제로 합니다)"만 덧붙인다. **되돌리기 로직 자체는 한 글자도 바꾸지 않았다** —
  `historyService.undoLastExchange()` 호출과 그 결과 처리는 그대로이고, 메시지 조합 단계에만
  분기를 추가했다.
- **검증**: `test/utils/exchange_dependency_checker_test.dart` 신규 6개(의존 없음/있음/되돌린
  건 제외/겹치지 않음/target 이전 이벤트 제외/보강 경로). `flutter analyze` 전체 통과,
  `flutter test` 전체 296개 통과(회귀 없음). **미실행**: 의존 있는 시나리오를 만들어 안내 문구가
  실제로 붙는지 수동 확인 — 아직 사용자 확인 전.
- **곁가지 조사(2026-09-29)**: 사용자가 이 수동 확인을 시도하다가 "날짜표시 ON 상태에서 원본/교체
  스위치를 눌러도 화면이 안 바뀐다"는 별개 증상을 보고 — 이 세션의 S5 작업과 무관한 기존 기능
  (`ExchangeViewProvider`, S1.x)의 문제로 추정해 두 차례 조사했다. 정적 코드 추적 + 실제 재현
  테스트(`ExchangeViewNotifier.enableExchangeView()`를 직접 호출해 `TimetableDataSource` 내용
  변화를 검증) 모두 **결함을 찾지 못함** — 같은 주 1:1 교체로 재현했을 때 로직은 정상적으로
  교체를 반영했다. 사용자가 재확인 후 "정상인 것 같다"고 답해 **코드 수정 없이 종료**했다.
  (재현용으로 만든 임시 디버그 테스트는 삭제, 정식 변경 없음.)

### S5.4a 완료 기록 (2026-09-29)

- **배경**: S5.4까지는 `lessons` 테이블에 아무것도 쓰지 않았다. 이 단계부터 실제로 SQLite
  `lessons`(현재 배치)를 교체 이벤트 저널의 **파생 뷰**로 갱신하기 시작한다 — S5 설계 검토서가
  가장 위험하다고 지목한 지점이라, 착수 전 S5.3의 등식 증명(`project()` == 화면 합성 결과)이
  이미 끝나 있었기에 안전하게 진행할 수 있었다.
- **S5.3 보완(착수 전 발견)**: `lesson_projection.dart`의 `project()`가 새로 생기는 칸에
  `Lesson.generateId()`(매번 랜덤)를 쓰고 있었다 — `replayInto`가 매 교체마다 반복 호출되므로,
  랜덤 ID는 호출할 때마다 같은 칸에 새 행을 쌓이게 만드는 실제 버그였다(OQ-6 "결정적 ID" 요구를
  아직 못 지키고 있었음). `_deterministicId(timetableId, teacher, date, period)` — **좌표 기반**
  결정적 ID로 교체. 이벤트 ID가 아니라 좌표를 기준으로 삼은 이유: 칸의 정체성은 "언제 누가
  만들었나"가 아니라 "지금 이 시간표의 이 날짜·교시가 누구 것인가"이기 때문. 기존 6개 등식
  테스트는 내용만 비교해 이 변경으로 깨지지 않았다.
- **스키마 변경**: `timetable_database.dart` 스키마 버전 3→4. `timetables`에 `projected_seq`
  컬럼 추가(기본값 -1 = "아직 재생 안 함"). 화면 조회는 여전히 SQLite로 전환되지 않았으므로
  (S5.5), 이 값은 나중에 "재생이 밀렸는지" 확인하는 용도로만 쓸 예정 — 현재는 UI에 노출하지
  않는다(범위 최소화 결정, 핵심은 실제 `lessons` 내용의 정확성이었다).
- **핵심 신규**: `TimetableRepository.replayInto(timetableId)`. 한 트랜잭션에서
  ① `lesson_snapshots` 템플릿으로 현재 `lessons`의 **내용만** 리셋(id·date·period·teacher·
  is_active는 그대로 유지 — S3a가 관리하는 값을 건드리지 않는다)
  ② 활성(`is_reverted=0`) 이벤트를 `seq` 순으로 `project()`에 재생
  ③ 리셋 상태와 실제로 달라진 행만 갱신하고(불필요한 쓰기 방지) 새 칸만 삽입, `projected_seq`를
  이벤트 중 가장 큰 `seq`로 갱신(이벤트가 없으면 -1).
  이벤트 → `ExchangeHistoryItem` 역직렬화는 `exchange_event_mirror.dart`에 추가한
  `toExchangeHistoryItem()`이 `ExchangeHistoryItem.fromJson`을 그대로 재사용해서 처리한다
  (직렬화 규칙을 두 곳에 두지 않기 위해).
- **OQ-7 구현**: `applyPeriodChange`에 활성 교체 이벤트가 새 학기 범위 밖으로 나가면 차단하는
  검사를 트랜잭션 시작 **전**에 추가 — `PeriodChangeConflictException`을 던지고 아무것도 바꾸지
  않는다. 다른 모든 S5 안내는 비차단인데 여기만 예외인 이유: 기간을 줄이면 그 교체가 참조하던
  날짜가 조용히 보관 처리되어 데이터가 실질적으로 유실될 수 있는 유일한 지점이기 때문(다른
  경우는 되돌리기로 복구 가능하거나 안내만으로 충분).
- **연결 지점**: `replayInto`는 새 호출부를 늘리지 않고 **S5.1의 기존 훅 2곳**
  (`services_provider.dart`의 `mirrorSink`/`mirrorClearSink`)에 이어붙였다 — 교체 실행·삭제·
  되돌리기·다시실행·날짜수정·전체삭제·로드 동기화가 전부 이 두 훅을 이미 거치므로 별도 배선이
  필요 없었다. `semester_period_section.dart`의 `_apply()`에도 `applyPeriodChange` 직후
  `replayInto` 호출을 추가(기간 반영으로 템플릿이 재생성되므로 교체를 다시 얹어야 한다).
- **여전히 어떤 화면도 SQLite `lessons`를 읽지 않는다** — 조회 전환은 S5.5.
- **검증**: `test/repositories/timetable_repository_test.dart`에 "투영 재생 (S5.4a)" 그룹 신규
  5개(1:1 교체 재생 시 두 교사 자기 행이 정확히 스왑됨, 되돌린 이벤트는 재생 안 됨, 재생 멱등성,
  `projected_seq` 갱신, `applyPeriodChange` 충돌 차단 및 무변경). `flutter analyze` 전체 통과,
  `flutter test` 전체 301개 통과(회귀 없음).

### S5.4a 성능 수정: 스낵바 뜰 때 버벅임 (2026-09-29)

사용자가 실제 앱에서 교체 실행 직후 "스낵바 메시지가 나올 때 동작이 느리고 반응이 느립니다"라고
보고 — S5 설계 검토서가 착수 전부터 지목했던 바로 그 위험("학기 전체 4만 행 규모이므로 주 단위
부분 재생 최적화가 필요한지 측정")이 실제로 드러난 것이었다.

**원인**: `replayInto`가 호출될 때마다 `lesson_snapshots`와 `lessons`를 **매번 통째로**
(한 학기 분량, 실측 4만 건 수준) 다시 읽어 Dart 객체로 매핑하고 있었다. 이 작업이 메인 아이소레이트
에서 한 번에 끝까지 동기적으로 도는 동안 UI 프레임이 멈춘 것처럼 보였다 — 교체를 실행할 때마다
(즉 스낵바가 뜰 때마다) 매번 일어나므로 체감이 뚜렷했다.

**1차 수정** (캐싱 + 양보): `lesson_snapshots` 템플릿을 인스턴스 단위로 캐시하고, 무거운
루프에 500건마다 이벤트 루프 양보 지점을 추가했다. 전체 작업량 자체는 그대로였다.

사용자가 재확인한 결과 — 스낵바가 사라진 뒤에야 클릭이 지연 반응했다("잠시 후 클릭이 먹힌다").
`sqflite_common_ffi`가 실제 SQLite 쿼리는 **별도 백그라운드 아이솔레이트**에서 돌린다는 것을
소스로 직접 확인했다(`isolate_io.dart`) — 즉 DB I/O 자체는 화면을 막지 않는다. 진짜 병목은
그 결과를 메인 아이솔레이트에서 Dart 객체로 변환·비교하는 부분이었고, 1차 수정(캐싱+양보)은
작업량 자체를 줄이지 못해 체감 개선이 제한적이었다.

**2차 수정 — 범위를 "건드린 좌표"로 좁힘** (`lib/repositories/timetable_repository.dart`,
`lib/utils/lesson_projection.dart`, 스키마 v4→v5):
- 새 표 `dirty_lesson_keys(timetable_id, teacher, date, period)` 추가 — "한 번이라도 교체가
  건드린 적 있는 좌표"를 계속 쌓기만 하는(grow-only) 표. 처음 우려했던 문제(삭제된 교체 건의
  좌표를 "지금 존재하는 이벤트"만으로는 알 수 없다)를 이 표로 해결 — 좌표가 한 번 기록되면
  그 교체가 나중에 완전히 삭제돼도 이 표에는 남아 있으므로, 다음 재생 때 그 칸도 계산 범위에
  계속 포함된다.
- `lesson_projection.dart`에 `touchedCellsFor(event)`(+`TouchedCell`) 추가 — 이벤트 하나가
  실제로 건드리는 좌표 목록을 `project()`와 **똑같은 날짜 해석 규칙**으로 계산한다(같은
  `_resolveDateByDay`를 공유하므로 둘이 어긋날 수 없다).
- `replayInto`가 이제 "이 시간표의 모든 이벤트(활성+되돌림)가 건드리는 좌표 ∪ `dirty_lesson_keys`
  누적분"만 리셋·재계산한다 — 실제 교체가 건드리는 칸은 보통 학기 전체(수만 행)의 극히 일부이므로,
  작업량이 "총 교체 횟수 × 이동당 칸 수" 수준으로 줄어든다(수십~수백 건이면 수십~수백 칸).
  `lessons`/`lesson_snapshots` 조회도 `teacher IN (...) AND date IN (...)`로 좁혀서 한다.
- **부수 발견 — 별개의 실제 버그**: 이 재설계 과정에서 만든 회귀 테스트("교체 건을 완전히 삭제한
  뒤 재생하면 예전에 건드렸던 칸도 템플릿으로 되돌아온다")가 **처음부터 있던 정합성 버그**를
  잡아냈다 — diff 비교를 "이번 호출에서 메모리로만 만든 리셋 값"끼리 비교하고 있어서, 활성
  이벤트가 하나도 안 건드리는 칸은 항상 "리셋값 == 투영결과"로 보여 "변경 없음"으로 오판했다.
  실제 DB에는 옛 스왑 내용이 그대로 남아있는데도 절대 안 지워지는 버그였다(교체를 완전히
  지워도 그 흔적이 영원히 남음) — 4개짜리 S5.4a 등식/멱등 테스트로는 못 잡았던 문제로, "삭제
  후 재생" 시나리오를 명시적으로 테스트해서야 드러났다. 비교 대상을 **실제 DB에서 방금 읽은
  값**(`currentByCoord`)으로 바꿔 수정했다.
- **검증**: `test/repositories/timetable_repository_test.dart`에 "교체 건을 완전히 삭제한 뒤
  재생하면 예전에 건드렸던 칸도 템플릿으로 되돌아온다" 테스트 신규 1개(위 버그를 재현·방지).
  `flutter analyze` 전체 통과, `flutter test` 전체 302개 통과(회귀 없음 — 기존 S5.4a 테스트
  전부 새 로직에서도 동일하게 통과). **미실행**: 실제 앱에서 교체 실행 직후 체감 버벅임·클릭
  지연이 실제로 없어졌는지 — 사용자 재확인 필요.

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
