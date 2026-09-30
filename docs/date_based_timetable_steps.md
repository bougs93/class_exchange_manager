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
  `flutter test` 전체 296개 통과(회귀 없음). **수동 확인 불가로 판정(2026-09-29)**: 사용자가
  실제로 재현을 시도한 결과, 이미 교체된(X 표시) 칸을 클릭하면 그 교체 내역을 화살표로 보여줄
  뿐 새 교체의 대상으로 다시 선택할 수 없음을 확인 — 이는 기존부터 의도된 보호장치다. 즉 "A
  교체 결과를 B 교체가 이미 쓰고 있는" 의존 상황 자체가 지금 UI로는 만들어지지 않는다. 로직은
  유닛 테스트로 이미 검증돼 있으므로(회귀 없음, 안전하게 존재) 더 이상 수동 확인을 시도하지
  않는다 — 향후 이 제약이 풀리거나 다른 경로로 의존이 생길 경우를 위한 안전장치로 남겨둔다.
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
  경우는 되돌리기로 복구 가능하거나 안내만으로 충분). **사용자 확인 완료(2026-09-29)**: 학기
  기간을 활성 교체 4건이 걸린 날짜 밖으로 줄이려 하자 "학기 기간을 줄이면 활성 교체 4건과
  충돌합니다: ..." 메시지가 정확히 뜨고 반영이 차단됨을 실제 앱에서 확인.
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
  전부 새 로직에서도 동일하게 통과). **사용자 확인 완료(2026-09-29)**: 재빌드 후 교체 실행 시
  버벅임·클릭 지연 증상이 사라짐을 확인.

### S5.4a OQ-7 사용자 확인 (2026-09-29)

학기 기간(2026년 2학기)을 활성 교체 4건이 걸린 날짜 밖으로 줄이려 하자 "학기 기간을 줄이면
활성 교체 4건과 충돌합니다: 교체 실행: 1:1 교체, ..." 메시지가 정확히 뜨고 반영이 차단됨을
실제 앱에서 확인 — **OQ-7 정상 동작 확인 완료**.

되돌리기 의존성 경고(D6/OQ-2, S5.4) 실제 확인은 **UI 구조상 불가로 판정**하고 종료했다 — 이미
교체된(X 표시) 칸을 클릭하면 그 교체 내역을 화살표로 보여줄 뿐 새 교체의 대상으로 다시 선택할
수 없다는 것을 사용자가 확인해 줬다(기존부터 의도된 보호장치). 즉 "A 교체 결과를 B 교체가 이미
쓰고 있는" 의존 상황 자체가 지금 UI로는 만들어지지 않는다 — `findDependentExchanges` 로직은
유닛 테스트로 이미 검증돼 있으므로(회귀 없음) 안전장치로 그대로 남겨두고, 이 항목의 수동 확인은
더 이상 시도하지 않는다.

### S5.4b 완료 기록 (2026-09-29) — S5 최종 단계

- **배경**: "여기서부터 신규가 진실 원본"이 되는 지점. `ExchangeHistoryService.loadFromLocalStorage()`
  가 지금까지는 항상 JSON만 읽었는데, 이제 SQLite `exchange_events`가 이미 있으면 그것을 읽도록
  바꾼다.
- **핵심 신규**: `ExchangeHistoryService`에 `loadSink`(`Future<List<ExchangeHistoryItem>> Function
  (String timetableId)?`) 필드 추가 — 기본 null(주입 안 하면 완전히 예전과 동일). `services_provider
  .dart`에서 `TimetableRepository.getExchangeEvents(timetableId)`를 `toExchangeHistoryItem`으로
  변환해 반환하도록 연결.
- **`loadFromLocalStorage()` 변경**: 스코프 시간표 ID가 있으면 먼저 `loadSink`로 SQLite를 확인한다.
  - **결과가 있으면**(이미 이관됐거나 SQLite에서 계속 써온 시간표) → 그 내용을 그대로 진실 원본으로
    쓰고 **여기서 끝낸다** — JSON은 읽지 않는다.
  - **비어 있으면**(아직 한 번도 이관 안 됨) → 기존 JSON 경로로 그대로 폴백한다. 이후 이어지는
    S5.1 보완 로직(로드 직후 `mirrorSink`로 SQLite에 밀어 넣기)이 **그대로 최초 1회 이관 역할을
    겸한다** — 새 이관 코드를 따로 만들지 않았다.
  - `loadSink`가 예외를 던지면(예: DB 아직 미준비) 로그만 남기고 역시 JSON 경로로 폴백한다.
- **설계에서 의도적으로 바꾼 부분(OQ-4 대비)**: 원래 설계는 "이관 후 JSON 원본을 `*.v2.bak`으로
  보관"이었다. 구현 중 재검토해 **파일 이름을 바꾸지 않기로 했다** — 이관 이후에도 JSON 쓰기는
  계속 살아있고(`mirrorSink`가 여전히 매번 JSON도 같이 쓴다) 매번 최신 상태로 갱신되므로, 굳이
  옛 스냅샷을 얼려두는 것보다 **항상 최신인 JSON 파일을 그대로 살려 두는 편이 복구용으로 더
  낫다고 판단**했다(문제가 생기면 `loadSink`만 다시 끄면 즉시 JSON으로 되돌아간다).
- **여전히 안 바꾼 것**: 쓰기 경로(`addExchange`/`undoLastExchange`/`updateDates`/`removeFromExchangeList`
  /`clearExchangeList` 등)는 전혀 손대지 않았다 — 전부 동기 API 그대로이고, JSON+SQLite 이중
  쓰기도 그대로 유지된다(당분간 유지, 문제 생기면 한 줄만 되돌리면 복구되는 안전판).
- **검증**: `test/services/exchange_history_sqlite_source_test.dart` 신규 2개 — (1) SQLite에
  이미 저널이 있으면 JSON 내용이 달라도 SQLite를 그대로 쓰는지, (2) SQLite가 비어 있으면 JSON
  경로로 폴백해 기존 이력을 그대로 불러오고 이후 자동으로 이관되는지. `flutter analyze` 전체
  통과, `flutter test` 전체 304개 통과(회귀 없음 — 기존 S5.1 로드 동기화 테스트도 무수정 통과).
- **사용자 확인 완료(2026-09-29)**: 기존 JSON 교체 이력이 있는 상태로 앱을 열어 교체 목록이
  그대로 보임을 확인. **앱을 재시작해도 교체 이력이 그대로 유지됨을 확인**(SQLite로 이관된 뒤에도
  유지됨 — 가장 핵심적인 확인 항목). 이로써 **S5(S5.0~S5.4b) 전체가 완료됐다.**

### S5.4b 확인 중 발견: 2중·순환 교체는 날짜 꼬리표가 아예 안 보임 (2026-09-29)

사용자가 S5.4b를 확인하다가 "2중 교체의 경우 날짜가 보이지 않습니다"라고 보고. 확인 결과
**버그가 아니라 S1.10에서 의도적으로 만든 제한**이었다 — 순환·2중은 참여 노드가 3개 이상인데
저장된 날짜는 2개(결강일·교체일)뿐이라 정확한 매핑이 안 되므로, 지금까지는 날짜표시 OFF 모드에서
꼬리표를 아예 생략했다(ON 모드는 "?"만 표시).

사용자 요청: "모든 교체에서 날짜가 지정되지 않는 경우 ?로 표시하고, 날짜가 지정된 경우 날짜를
표시해야 합니다." — 이미 승인된 OQ-1("결강일이 속한 주"라는 가정으로 노드별 날짜 추정)을 화면
표시에도 적용해 달라는 요청.

**구현 범위(안전하게 최소화)**: `lib/utils/exchanged_cell_overlay_dates.dart`의
`ExchangedCellOverlayDates.build()`만 수정 — `ExchangeCellDates.forItem`이 순환·2중이라
`unsupported`를 반환하면, `lesson_projection.dart`의 `touchedCellsFor()`(S5.4a에서 만든 OQ-1
추정 규칙, `project()`와 정확히 같은 날짜 해석을 공유)를 재사용해 각 노드의 추정 날짜를 채운다.

**의도적으로 건드리지 않은 것**:
- `ExchangeCellDates.forItem`의 `supported` 플래그 자체는 그대로 둔다 — 이 플래그는
  `ExchangeCellDates.forWeek`(X/○ 하이라이트 범위)와 `ResolvedWeek.dateAware`(다른 주 교체 분리
  표시)에서도 쓰이는데, S1.6~S1.10에서 공들여 검증한 그 로직들을 건드리지 않기 위해서다. 이번
  수정은 OFF 모드 꼬리표 표시 딱 한 곳에만 영향을 준다.
- **1:1·보강의 요일 불일치 폴백은 여전히 생략한다.** 순환·2중은 "노드에 진짜 날짜가 없어서" 추정
  하는 것이지만, 1:1·보강의 요일 불일치는 "사용자가 이상한 날짜를 입력해서" 생기는 것이라 노드
  요일로 되짚어 추정하면 사용자가 실제로 지정한 값과 다른 틀린 날짜를 보여줄 위험이 있다 — 이
  둘은 성격이 다르므로 구분해서 유지했다.
- ON 모드는 그대로 "?"를 표시한다 — 헤더에 이미 실제 날짜가 있는 상태에서, 이 값은 확정이 아니라
  추정이라는 것을 계속 구분해서 알려주기 위해서다.
- **검증**: `test/utils/exchanged_cell_overlay_dates_test.dart` 신규 3개(순환 교체 추정 날짜,
  2중 교체 추정 날짜, 1:1 요일 불일치는 여전히 생략됨을 회귀 확인). `flutter analyze` 전체 통과,
  `flutter test` 전체 307개 통과(회귀 없음 — 기존 1:1·보강 테스트 4개 무수정 통과).
  **사용자 확인 완료(2026-09-29)**: 재빌드 후 순환·2중 교체 칸에 날짜가 표시됨을 확인.

## S5.5. 교체 화면의 시간표 그리드 표시·검증을 SQLite 읽기로 전환

### S5.5 설계 검토 (2026-09-29, Opus 5)

S5(S5.0~S5.4b)로 SQLite `lessons`가 진실 원본이 됐지만, 아직 **어떤 화면도 이를 읽지 않는다** —
교체 화면 그리드는 여전히 `TimeSlot`(주 단위)과 `ResolvedWeek`(JSON 이력 기반 합성)만 사용한다.
S5.5는 이 마지막 조회 경로를 SQLite로 전환하는 단계.

**검토가 바로잡은 3가지 사실**: ① 그리드 기본 상태는 `ResolvedWeek`가 아니라 `TimeSlot` 원본을
그대로 그린다 — `ResolvedWeek` 합성은 "교체 뷰" 체크박스(`exchange_view_provider.dart`)가 ON일
때만 적용된다. ② 검증용 `resolvedTimetableProvider`는 그 체크박스와 무관하게 항상 동작한다.
③ **새로 발견한 실제 버그**: SQLite에서 곧바로 이력을 불러오는 시간표(`loadSink`가 값을 반환해
`return`하는 경로, S5.4b)는 로드 시 `replayInto`를 타지 않는다 — S5.5가 `lessons`를 읽기 시작하는
순간부터 의미가 생기는 간극이다(S5.5.2/S5.5.3에서 반드시 처리).

**전략 결정**: "오버레이"(기존 `TimeSlot` 위에 `dirty_lesson_keys`로 건드린 칸만 SQLite 값으로
덮어씀) 채택, "전면 교체"는 기각(원본 호환·순환/2중 폴백 등 위험이 큼). 새 팩토리
`ResolvedWeek.fromLessons({base, touchedLessons, weekMonday})`가 `of`/`dateAware`와 동일한
`toTimeSlots()` 출력 형태를 내도록 만든다. 동기 읽기(`lessonsFor()`) + 비동기 워머
(`ensureLoaded()`)를 가진 프리페치 캐시(`WeekLessonsCacheNotifier`)로 sync→async 오염을 막는다.
날짜표시 OFF 모드는 영구히 `ResolvedWeek.of`에 고정(날짜 키 데이터로 "결강일 주 몰아보기"를
재현할 수 없고, "OFF는 날짜 정보 유출 금지" 불변조건 보호 목적). 신선도 게이트
(`getProjectionStatus` 비교, 오래됐으면 `replayInto()` 1회 재시도 후 조용히 폴백)와, 실제 전환 전
반드시 거쳐야 하는 "화면 합성 N칸 · SQLite M칸 · 불일치 K칸" 섀도우 비교 패널(S5.5.2)을 게이트로
둔다. 개인 시간표·PDF 출력은 범위 밖(코드 확인 결과 `ResolvedWeek`를 전혀 쓰지 않음, S7에서 별도 처리).

**6단계 분해** (사용자 승인 — "이 설계대로 진행 (권장)", 2026-09-29):
- **S5.5.0**: Repository 조회 헬퍼 2개(`getProjectionStatus`, `getTouchedLessonsForWeek`) 추가, 완전
  비연결.
- **S5.5.1**: 순수 `ResolvedWeek.fromLessons` 어댑터, S5.3 픽스처로 동등성 증명.
- **S5.5.2**: S4.0 패널에 읽기 전용 섀도우 비교 추가 — **"불일치 0칸"을 여러 교체 유형·여러 주에서
  사용자가 직접 확인해야 S5.5.3 진행 가능(필수 게이트)**.
- **S5.5.3**: 프리페치 캐시 + `lessonReadPathEnabledProvider`(기본 OFF), 여전히 비연결.
- **S5.5.4**: 실제 전환 — `exchange_view_provider`와 `resolved_timetable_provider`를 같은 커밋에서
  함께 전환. 광범위한 실사용 회귀 체크리스트 동반(OFF 모드 불변조건, 셀 단위 정확성, 되돌리기,
  계획서 날짜 수정 전파, 주 이동, 범위 밖 주, 교체불가 셀 스타일, 시간표 전환 시 캐시 정리, S3
  이전 시간표, PDF·개인 시간표 비영향).
- **S5.5.5**: 준비>기타설정에 사용자용 롤백 토글 + 최종 문서 정리.

**3단계 롤백**: ① 런타임 플래그 토글(재빌드 불필요, 즉시) ② 캐시가 `ready`가 아니면 자동으로
기존 경로로 폴백(사용자 옵션이 아니라 항상 켜진 안전장치) ③ S5.5.4 커밋 단독 되돌리기(S5.5.0~3은
비연결이라 남겨둬도 무해).

### S5.5.0 완료 기록 (2026-09-29)

- **추가**: `lib/repositories/timetable_repository.dart`에 `ProjectionStatus` 클래스
  (`projectedSeq`/`maxActiveSeq`/`lessonRowCount`/`hasTimetableRow`, `isStale` 게터 — 두 seq가
  다르면 재생이 밀린 것) + `getProjectionStatus(timetableId)`(집계 전용, `getLessonStats`와 같은
  스타일 — `COUNT(*)`/`MAX(seq)`만 쓰고 행 전체를 읽지 않음) + `getTouchedLessonsForWeek(timetableId,
  weekMonday)`(`lessons`를 `dirty_lesson_keys`와 INNER JOIN, 그 주 월~금 범위 + `is_active=1`만).
- **연결 상태**: 완전히 비연결 — 어떤 Provider·화면도 이 두 메서드를 호출하지 않는다. S5.5.1
  이후 캐시 계층에서 쓰일 예정.
- **검증**: `test/repositories/timetable_repository_test.dart`에 새 그룹 "조회 전환 준비 (S5.5.0)"
  6개 추가 — 존재하지 않는 시간표 기본값, 이벤트 없는 시간표(`isStale=false`), 재생 전/후
  `isStale` 전환, 건드린 적 없는 시간표는 빈 리스트, 같은 주만 반환(다른 주 제외 — `touchedCellsFor`가
  1:1 교체의 결강일·교체일 양쪽 모두 두 교사 자리를 건드린다고 보므로 4칸 전부 매칭됨을 확인),
  같은 DB 안 다른 시간표 간 섞이지 않음(WHERE timetable_id 절 검증). `flutter analyze` 전체 통과,
  `flutter test` 전체 313개 통과(기존 307개 전부 무수정 통과, 회귀 없음).
### S5.5.1 완료 기록 (2026-09-29)

- **추가**: `lib/utils/resolved_week.dart`에 `ResolvedWeek.fromLessons({base, touchedLessons,
  weekMonday})` 신규 static 팩토리. `of`/`dateAware`와 달리 이벤트를 재생하지 않고, 이미
  `project()`가 계산해 SQLite에 저장한 결과(`touchedLessons`, 실제로는
  `getTouchedLessonsForWeek`의 반환값을 예정)로 `base` 위의 해당 칸만 **덮어쓰기**만 한다 —
  S5.5 설계 검토의 "오버레이" 전략을 그대로 구현. 덮어쓰는 필드는 `subject`/`className`뿐이고,
  `isExchangeable`/`exchangeReason`은 `base`의 값을 유지한다(Decision B, R8 — 교체 가능 여부는
  원본 시간표 속성이지 SQLite 쪽 값을 신뢰할 대상이 아님). `weekMonday`는 결과에 실리는 값일 뿐
  필터링에 쓰이지 않는다 — 호출자가 이미 그 주 범위로 좁힌 `touchedLessons`만 건넨다고
  가정한다.
- **연결 상태**: 여전히 비연결 — 이 함수를 호출하는 Provider·화면이 없다.
- **검증**: `test/utils/resolved_week_from_lessons_test.dart` 신규 6개 — S5.3(`lesson_projection_test.dart`)와
  **정확히 같은 픽스처**를 재사용해, `project()`의 결과를 해당 주로 필터링한 값을
  `fromLessons`에 넘겼을 때 `ResolvedWeek.dateAware`와 같은 결과가 나오는지 확인(1:1 같은 주,
  보강 같은 주, 다른 주로 넘어가는 1:1의 결강일/교체일/무관 주 3곳, 순환 교체 결강일 주/무관 주).
  `project()`가 이미 S5.3에서 `dateAware`와 동등함이 증명됐으므로, 이 테스트는 "동등한 입력을
  fromLessons에 줘도 동등한 출력이 나온다"만 추가로 증명하면 되는 구조 — 전이적으로
  `fromLessons ≡ dateAware`(같은 주 한정)가 성립한다. 추가로 이벤트 없음(base 그대로), 그리고
  `isExchangeable`/`exchangeReason`이 SQLite 값이 아니라 base 값을 유지하는지 확인하는 테스트
  2개. `flutter analyze` 전체 통과, `flutter test` 전체 319개 통과(기존 313개 전부 무수정 통과,
  회귀 없음).
- **다음**: S5.5.2 — S4.0 확인 패널에 "화면 합성 N칸 · SQLite M칸 · 불일치 K칸" 읽기 전용
  섀도우 비교를 추가한다. 이 단계는 **사용자가 여러 교체 유형·여러 주에서 "불일치 0칸"을 직접
  확인해야 S5.5.3으로 진행할 수 있는 필수 게이트**다.

### S5.5.2 완료 기록 (2026-09-29) — 사용자 확인 대기 중(필수 게이트)

- **추가**: `lib/ui/screens/start_content/dated_data_inspector_section.dart`에 "화면 표시 vs
  SQLite 정합성 확인 (S5.5.2, 실험용)" 패널 + "지금 확인" 버튼. 누르면 `_runShadowComparison()`이
  실행되어:
  1. 지금 교체 화면에 열려 있는 시간표의 `TimeSlot` 원본(`exchangeScreenProvider.timetableData`)과
     JSON 활성 교체 목록(`exchangeHistoryServiceProvider.getActiveExchangeList()`)을 읽는다.
  2. 비교할 "여러 주"를 자동으로 모은다 — 지금 보고 있는 주(`selectedWeekProvider`) + 모든 활성
     교체의 결강일·교체일이 속한 주 전부(교체 유형과 무관하게 실제로 뭔가 달라질 수 있는 주만).
  3. 비교 직전 `repo.replayInto(timetableId)`를 호출해 SQLite `lessons`를 최신으로 맞춘다(파생
     뷰 갱신일 뿐, 진실 원본인 JSON·`exchange_events`는 건드리지 않는다 — 읽기 전용 원칙 유지).
  4. 각 주에 대해 "화면 합성"(날짜표시 스위치 상태에 맞춰 `ResolvedWeek.of`/`dateAware`, 즉
     `resolved_timetable_provider.dart`와 **완전히 같은 로직**)과 "SQLite 합성"
     (`repo.getTouchedLessonsForWeek` + `ResolvedWeek.fromLessons`)을 각각 계산해, 칸별로
     `subject`/`className`을 비교한다.
  5. 전체 주를 합산해 "화면 합성 N칸(비어있지 않은 칸 수) · SQLite M칸 · 불일치 K칸(비교한 주:
     W개)"을 보여준다. 불일치가 있으면 주황색으로 강조한다.
- **읽기 전용 원칙 유지**: 사용자가 "지금 확인" 버튼을 누르기 전까지는 아무 계산도 하지 않는다
  (패널을 열기만 해서는 실행되지 않음). `replayInto` 호출은 파생 뷰(`lessons`)만 갱신하므로 이
  원칙에 위배되지 않는다.
- **제약**: 비교는 **활성 시간표이면서 지금 교체 화면에 열려 있는 시간표**로 제한된다 — "화면
  합성"을 재현하려면 실제 `TimeSlot` 원본이 메모리에 있어야 하기 때문이다. 열려 있지 않으면
  "교체 화면에서 이 시간표를 먼저 연 뒤 다시 확인하세요" 안내만 표시한다.
- **검증**: `flutter analyze` 전체 통과, `flutter test` 전체 319개 통과(회귀 없음 — 이 패널은
  "사용자가 직접 눈으로 불일치 0칸을 확인"하는 것 자체가 검증 방법인 설계 게이트라, 자동화된
  단위 테스트는 추가하지 않았다. `ResolvedWeek.fromLessons`·`getTouchedLessonsForWeek`는 이미
  S5.5.0/S5.5.1에서 각각 단위 테스트로 검증됨).
- **다음(필수)**: **사용자가 실제 앱에서 여러 교체 유형(1:1·순환·2중·보강)과 여러 주(같은 주 교체,
  다른 주로 넘어가는 교체)를 실행한 뒤 "지금 확인"을 눌러 "불일치 0칸"을 직접 확인해야 한다.**
  이 확인이 끝나기 전까지 S5.5.3(실제 전환 준비)로 진행하지 않는다.

### S5.5.2 게이트 통과 — 사용자 확인 완료 (2026-09-29)

사용자가 실 앱에서 교체 4건(순환·2중 포함, 1:1/보강도 함께)을 실행한 뒤 "지금 확인" 버튼으로
확인한 결과: **"화면 합성 1726칸 · SQLite 1726칸 · 불일치 0칸 (비교한 주: 2개)"**. 순환·2중
교체가 포함됐는지 재확인 질문에 사용자가 "포함됐다"고 답변 — 순환·2중의 날짜 추정 경로(OQ-1)
까지 포함해 불일치 0칸이 확인됐다. **S5.5.2 필수 게이트 통과, S5.5.3 진행.**

### S5.5.3 완료 기록 (2026-09-29)

- **추가**:
  - `lib/services/exchange_history_service.dart`에 `flushPendingWrites()` 신규 — 기존 비공개
    `_storageQueue`(JSON 저장 → SQLite 미러 → `replayInto` 순서가 이미 보장된 큐)를 그대로
    기다리기만 하는 공개 메서드. 공개 API는 계속 동기로 유지한 채, 필요한 곳에서만 "지금까지
    쌓인 쓰기가 다 끝날 때까지 기다려" 달라고 명시적으로 요청할 수 있게 한다.
  - `lib/providers/week_lessons_cache_provider.dart`(신규) — `WeekLessonsCache` 클래스 +
    `lessonReadPathEnabledProvider`(기본 false) + `weekLessonsCacheProvider`.
    `WeekLessonsCache`는 "`ensureLoaded`(비동기 워밍) → `lessonsFor`(동기 읽기)"의 2단계
    호출 패턴으로 sync→async 오염을 피한다(S5.5 설계 검토 Decision C). `ensureLoaded`는
    (1) `flushPendingWrites()`로 읽기-쓰기 경쟁을 없애고, (2) `getProjectionStatus`로 신선도를
    확인해 밀려 있으면(`isStale`) `replayInto`를 한 번 재시도한 뒤(Decision E), (3)
    `getTouchedLessonsForWeek`로 실제 값을 캐시에 채운다. 같은 (시간표, 주) 키에 대한 동시
    호출은 진행 중인 Future를 그대로 공유해 중복 조회하지 않는다. `invalidateTimetable`로
    시간표 단위 캐시 무효화(R9)도 지원한다.
- **연결 상태**: 완전히 비연결 — `weekLessonsCacheProvider`/`lessonReadPathEnabledProvider`를
  참조하는 화면·Provider가 없다. `flushPendingWrites`도 이 캐시 외에는 아직 아무도 호출하지
  않는다.
- **검증**: `test/providers/week_lessons_cache_provider_test.dart` 신규 4개 —
  ensureLoaded 전/후 lessonsFor 구분(null vs 빈 리스트), **재생이 밀려 있는 상황을
  `replayInto`를 호출하지 않고 의도적으로 재현해 `ensureLoaded`가 자동으로 감지·복구하는지
  확인**(S5.5 설계 검토가 발견한 실제 간극에 대한 회귀 테스트), 동시 호출 중복 조회 방지(카운터로
  확인), `invalidateTimetable`의 시간표별 격리. `test/services/exchange_history_mirror_sync_test.dart`에
  `flushPendingWrites` 테스트 1개 추가 — 같은 파일의 기존 테스트가 쓰던 `Future.delayed(200ms)`
  추측성 대기를 `flushPendingWrites()`로 대체할 수 있음을 확인(신뢰성 있는 동기화 지점이
  실제로 동작함을 증명). `flutter analyze` 전체 통과, `flutter test` 전체 324개 통과(기존
  319개 전부 무수정 통과, 회귀 없음).
- **다음**: S5.5.4 — 실제 전환. `exchange_view_provider`의 `_applyResolvedWeek`와
  `resolved_timetable_provider.dart`를 같은 커밋에서 함께 `lessonReadPathEnabledProvider`
  분기로 전환한다(기본 OFF이므로 이 커밋 자체는 배포해도 동작 변화 없음). 이후 플래그를 켜고
  광범위한 실사용 회귀 체크리스트를 수행한다.

### S5.5.4 완료 기록 (2026-09-29) — 실제 조회 전환 (기본 OFF, 사용자 실 앱 확인 필요)

- **추가**:
  - `lib/providers/week_lessons_cache_provider.dart` — `WeekLessonsCache`에 `onLoaded` 콜백,
    `clearAll()`, 그리고 `WeekLessonsCacheTicker`/`weekLessonsCacheTickerProvider`(캐시가
    채워질 때마다 값을 올려 구독자에게 "다시 계산하라"는 신호를 주는 용도) 추가.
  - `lib/providers/resolved_timetable_provider.dart` — 날짜표시 ON 모드(`showWeekHeader==true`)
    분기를 새 `_resolveOnWeek()` 헬퍼로 뽑아내고, 그 안에서 `lessonReadPathEnabledProvider`가
    켜져 있으면 `weekLessonsCacheTickerProvider`를 watch한 뒤 `WeekLessonsCache.lessonsFor()`를
    동기로 조회 — 캐시가 준비돼 있으면 `ResolvedWeek.fromLessons`를, 아직이면 기존
    `ResolvedWeek.dateAware`로 폴백하면서 `ensureLoaded()`를 백그라운드로 걸어 둔다(끝나면
    ticker가 올라 Provider가 자동으로 다시 계산된다). **날짜표시 OFF 모드는 이 분기 자체에
    들어가지 않는다** — 여전히 무조건 `ResolvedWeek.of`(S5.5 설계 검토 Decision D).
  - `lib/providers/exchange_view_provider.dart` — 같은 전략을 `_applyResolvedWeek`/새
    `_resolveOnWeekForView()`에 동일하게 적용. `ExchangeViewNotifier`는 `Provider`가 아니라
    `StateNotifier`라 자동 재계산이 없으므로, 생성자에서 `ref.listen(weekLessonsCacheTickerProvider,
    ...)`로 직접 구독하고 마지막으로 그릴 때 쓴 인자(`_lastTimeSlots`/`_lastTeachers`/
    `_lastDataSource`)를 기억해 뒀다가 캐시가 준비되면 같은 인자로 다시 그린다.
  - `lib/providers/state_reset_provider.dart` — Level 3(`resetAllStates`, 시간표 전환·파일
    재선택 시 호출)에 `_clearWeekLessonsCache()` 추가, `weekLessonsCacheProvider.clearAll()`
    호출 — 캐시 키가 이미 timetableId로 격리돼 있어 정확성 문제는 없지만, 전환마다 계속
    쌓이는 것을 막는다(S5.5 설계 검토 R9).
  - `lib/ui/screens/start_content/dated_data_inspector_section.dart` — "SQLite 조회 경로
    사용 (S5.5.4, 실험적)" 스위치 추가(S5.5.5의 롤백 토글을 앞당겨 함께 구현 — 토글 없이는
    사용자가 실 앱에서 플래그를 켜볼 방법이 없어 이 단계를 검증할 수 없었다). 기본 꺼짐,
    켜면 즉시 `lessonReadPathEnabledProvider.state = true`.
- **3단계 롤백 중 2단계(캐시 미준비 시 자동 폴백)는 이 커밋 자체에 항상 내장돼 있다** — 사용자
  옵션이 아니라, `lessonsFor()`가 null을 반환하는 모든 경우(캐시 워밍 중, 로드 실패 등)에
  무조건 적용된다.
- **검증**: `test/providers/resolved_timetable_provider_lesson_read_path_test.dart` 신규
  2개 — 플래그 OFF(기본값)일 때 캐시를 전혀 건드리지 않고 기존 결과 그대로임을 확인, 플래그
  ON일 때 첫 조회는 `dateAware` 폴백(같은 주 교체라 SQLite 값과 동일한 결과), `ensureLoaded`
  완료 후 재조회하면 캐시(`fromLessons`)가 실제로 채워져 있음을 확인. `flutter analyze` 전체
  통과, `flutter test` 전체 326개 통과(기존 324개 전부 무수정 통과, 회귀 없음 — 플래그 기본값이
  false이므로 기존 회귀 스위트 결과가 그대로 유지되는 것 자체가 "커밋 배포 자체는 동작 변화
  없음"의 증거다).
- **연결 상태**: 그리드 표시(`exchange_view_provider`)와 검증(`resolved_timetable_provider`)
  둘 다 실제로 연결됐지만, **기본값이 꺼짐**이라 사용자가 새로 추가된 스위치를 직접 켜기 전까지는
  기존 동작과 동일하다.
- **다음(필수)**: **사용자가 실 앱에서 "SQLite 조회 경로 사용" 스위치를 켜고, 날짜표시 ON 모드에서
  여러 교체 유형·주 이동·되돌리기 등을 실제로 사용해 봐야 한다.** 문제가 있으면 스위치를 끄면
  즉시 기존 방식으로 돌아간다(재빌드 불필요). 이 확인이 끝나야 S5.5.5(최종 문서 정리 — 토글
  자체는 이미 이번 단계에서 구현됨)로 마무리한다.

### S5.5.4 버그 발견·수정: 교체 이력 변경 시 캐시가 무효화되지 않던 문제 (2026-09-30)

사용자가 실 앱에서 발견: 정원길 수요일 1·2·4·5교시에 1:1·2중·순환·보강 4가지 교체를 각각
실행해 정상 동작을 확인한 뒤, **"전체 초기화"로 교체 이력을 모두 지우고 같은 칸을 다시
선택**했더니 4가지 교체 모드 전부에서 교체 경로 탐색 사이드바가 뜨지 않았다(전에 한 번도
건드리지 않은 다른 칸은 정상 동작). 그리드 화면(교체 뷰 OFF라 원본 `TimeSlot`을 그대로 표시)은
정상적으로 "기술가정"을 보여주고 있어서, **표시는 정상인데 검증만 실패**하는 전형적인 표시/검증
불일치였다(S5.5 설계 검토 R11이 경고했던 위험).

**진단**: 사용자에게 그 상태 그대로 S4.0 패널의 "지금 확인"(섀도우 비교)을 다시 눌러보게
했더니 "화면 합성 863칸 · SQLite 863칸 · 불일치 0칸"으로 나왔다 — 이 버튼은
`WeekLessonsCache`를 거치지 않고 매번 `repo.replayInto` + `repo.getTouchedLessonsForWeek`를
새로 호출하므로, **SQLite `lessons` 테이블 자체는 항상 정상**이었고 문제는 그 사이에 낀
`WeekLessonsCache`에 있다는 것이 확정됐다.

**근본 원인**: `WeekLessonsCache.ensureLoaded()`는 `if (_cache.containsKey(key)) return;`로
한 번 채운 (시간표, 주) 캐시 항목을 **영원히** 그대로 들고 있었다. 무효화는 오직 시간표
전환(Level 3 리셋의 `clearAll()`) 때만 일어났고, **교체를 추가·삭제·되돌리는 것 자체는 캐시를
전혀 건드리지 않았다.** 그래서 (1) 첫 라운드 테스트 때는 매번 다른 셀을 눌러 캐시가 우연히
비어 있었거나 폴백(`dateAware`, 항상 최신)이 걸려 정상으로 보였고, (2) "전체 초기화" 후에도
캐시가 비어 있던 짧은 순간이 지나고 나면 **교체 이력이 바뀔 때마다 다시 읽어야 한다는 규칙
자체가 없어서**, 한 번 채워진 캐시 항목이 그 뒤의 어떤 교체 변경과도 동기화되지 않는 상태가
됐다.

**수정**: `lib/providers/week_lessons_cache_provider.dart`의 `weekLessonsCacheProvider`에서
`ref.listen<int>(exchangeListVersionProvider, (previous, next) { cache.clearAll(); ref.read(weekLessonsCacheTickerProvider.notifier).bump(); })`를
추가했다. `exchangeListVersionProvider`는 교체 추가·삭제·되돌리기·전체 초기화 등 교체 이력이
바뀌는 모든 경로에서 이미 증가하고 있었으므로(기존 인프라 재사용), 이 리스너 하나로 "교체
이력이 하나라도 바뀌면 캐시 전체를 비우고 다음 조회를 강제한다"는 규칙이 생긴다. 시간표
전체가 아니라 영향받은 주만 정밀하게 무효화하는 대신 통째로 비우는 쪽을 택했다 — 어떤 주가
영향받는지 이벤트별로 분석하는 비용보다, "교체 하나 바뀔 때 지금 보는 주를 다시 읽는" 비용이
훨씬 싸기 때문이다.
- **검증**: `test/providers/week_lessons_cache_provider_invalidation_test.dart`(신규) — 캐시를
  먼저 채운 뒤 `addExchange`를 호출하면 **그 즉시**(비동기 쓰기 완료를 기다리지 않고도)
  `cache.lessonsFor()`가 다시 null로 돌아오는지(무효화 확인), 그 뒤 재조회하면 새 교체가
  반영된 값이 채워지는지 확인. `flutter analyze` 전체 통과, `flutter test` 전체 327개 통과
  (기존 326개 전부 무수정 통과, 회귀 없음).
- 사용자가 이 수정 후 다시 같은 시나리오(4개 교체 유형 → 전체 초기화 → 재선택)로 재현
  테스트 — **경로 탐색은 정상 동작 확인.**

### 버그 발견·수정: 되돌린 교체가 계획서에 남는 문제 (2026-09-30, S5.5와 무관한 기존 버그)

같은 확인 과정에서 사용자가 별개의 문제를 발견: 2중교체를 실행한 뒤 삭제(되돌리기)했더니
"교체" 화면에서는 "교체 0건"으로 정상 사라졌는데, 이미 저장해 둔 "계획서"(결보강 26.10.07)
에는 그 건이 계속 남아 있었다. 사용자에게 "SQLite 조회 경로 사용" 스위치를 끈 상태에서도
재현되는지 물었으나 별도 확인은 하지 않기로 했고, 대신 "되돌리기 경우 교체에서는 사라지지만
계획서에서는 사라지지 않는 문제 같다"는 정확한 진단을 사용자가 직접 제시했다.

**원인 확인**: `lib/providers/substitution_plan_viewmodel.dart`의 `loadPlanData()`가
`historyService.getExchangeList()`(되돌린 건도 포함한 전체 목록)를 쓰고 있었다 —
`getActiveExchangeList()`(`!isReverted`만 필터링)를 썼어야 했다. `undoLastExchange()`는
항목을 리스트에서 제거하지 않고 `isReverted=true`로 표시만 하고 남겨두는데(다시 실행을
위해), `getExchangeList()`는 이 필터링을 하지 않으므로 계획서 화면이 되돌린 건까지 계속
표시했던 것 — **S5.5(SQLite 조회 경로) 작업과는 완전히 무관한 기존 버그**다. 이 메서드는
SQLite를 전혀 읽지 않고 JSON 기반 `_exchangeList`만 직접 읽는다(설계상 계획서는 S5.5
범위 밖으로 명시했던 그대로).

**수정**: `getExchangeList()` → `getActiveExchangeList()` 한 줄 교체.
- **검증**: `test/providers/substitution_plan_viewmodel_reverted_test.dart`(신규) — 교체
  실행 직후 계획서에 1건 존재 확인 → `undoLastExchange()` 호출 → 계획서가 빈 목록으로
  갱신되는지 확인(로그로 "교체 히스토리 개수: 1 → 0" 전환 확인됨). `flutter analyze` 전체
  통과, `flutter test` 전체 328개 통과(기존 327개 전부 무수정 통과, 회귀 없음).
  **사용자 실 앱 확인 완료(2026-09-30)**: "되돌리기 후 완전히 사라지는 것을 확인함".

## S5.6. 순환·2중 교체의 노드별 날짜 확정 (계획서 → 교체 화면 반영)

### S5.6 설계 검토 (2026-09-30, Opus 5)

사용자가 실 앱 테스트 중 발견: 계획서 화면에서 순환·2중 교체의 결강일/교체일을 노드별로
지정할 수 있는데(날짜 선택기 이미 존재, `ExchangeHistoryItem.absenceDate`/`substitutionDate`에
직접 반영됨 — §10.10), "교체" 화면은 여전히 이 교체 유형에 대해 항상 "?"만 보여준다. 원인은
순환(3+ 노드)·2중(4 노드)이 "결강일·교체일" 단 한 쌍만 저장하고, 노드가 3개 이상이라 각
노드의 정확한 날짜를 확정할 수 없어 `ExchangeCellDates.forItem`이 항상 `unsupported`를
반환하기 때문(1:1·보강은 노드가 2개뿐이라 이 쌍만으로 완전히 표현됨). 사용자가 "계획서에서
지정한 날짜가 실제로 교체 화면에도 반영되게 한다"(더 크고 위험한 쪽)를 선택, Opus 설계
검토 진행.

**핵심 발견**: SQLite 스키마에 `node_dates_json` 컬럼이 S5.0 때부터 이미 준비되어 있었다
(안 쓰이고 있었을 뿐) — 스키마 변경 불필요. 계획서 화면의 각 행이 이미 소스/타겟 노드의
요일·교시를 다 갖고 있어 새 UI 없이 기존 행 편집만으로 노드별 날짜 지정 가능.

**설계**: `ExchangeHistoryItem.nodeDates`(슬롯 키 `'요일|교시'` → `DateTime`) 신규 필드 +
단일 판단 함수 `resolveEventDates()`(신규 `lib/utils/event_date_resolver.dart`)가 "확정 쌍
(1:1·보강) / 확정 노드(순환·2중, 신규) / 추정(OQ-1, 기존)" 우선순위로 모든 소비자에 걸쳐
하나의 답을 낸다. 실제 코드 변경은 `lesson_projection.dart`, `resolved_week.dart`의
`dateAware`, `exchange_cell_dates.dart`의 `forWeek` 3곳뿐 — 나머지(OFF 모드 오버레이, X/○
하이라이트, SQLite 조회 경로)는 이 3곳을 거치므로 자동으로 따라온다.

**최대 위험(R7)**: 2중 교체는 "1단계가 한 자리를 비운 뒤 2단계가 성립"하는 순서 의존 구조라,
노드들이 서로 다른 주로 갈리면 `project()`(순차 재생)와 `dateAware`(주 단위 근사)가 다른
값을 낼 수 있다. S5.6.2에서 등식 테스트로 먼저 확인하고, 깨지면 등식을 완화하지 않고
"2중은 모든 노드가 같은 주일 때만 확정 인정"으로 범위를 줄인다.

**단계 분해**: S5.6.0(데이터 모델)~S5.6.4(저장 메서드)는 **플래그 없이 배포 가능**(아직
아무도 이 데이터를 안 읽어 동작 변화가 0). S5.6.5(계획서 표시)~S5.6.6(실제 저장 연결)만
`nodeDateEditEnabledProvider`(기본 OFF)로 감싼다. S5.6.7에서 기본 ON 전환 + 문서 정리.
전체 OQ-1~9와 "절대 바꾸지 말 것" 체크리스트는 검토 결과 원문 참조(대화 로그).

### S5.6.0 완료 기록 (2026-09-30)

- **추가**: `lib/utils/exchange_node_slot.dart`(신규) — `nodeSlotKey(dayName, period)` 순수
  함수(교사 미포함 — `ExchangeCellDates.forItem`의 기존 "칸의 날짜는 노드의 날짜, 누가
  앉든 상관없다" 계약을 그대로 따름). `ExchangeHistoryItem`에 `nodeDates`(기본값 `const {}`),
  `supportsNodeDates`(순환·2중만 true), `nodeDateFor()`, `copyWithNodeDate()` 추가. 기존
  6개 `copyWith*`(`Reverted`/`Notes`/`Dates`/`Tags`/`Metadata`/`ProfileId`) 전부
  `nodeDates: nodeDates` 전달하도록 수정(빠뜨리면 조용한 유실 — 특히 되돌리기). `toJson()`은
  비어 있으면 `'nodeDates'` 키 자체를 생략(구 파일과 바이트 동일), `fromJson()`은 키 없으면
  `const {}`.
- **연결 상태**: 완전히 비연결 — `nodeDates`를 실제로 채우는 UI가 없다.
- **검증**: `test/models/exchange_history_item_test.dart`에 신규 그룹 8개 — 기본값·게이팅
  (1:1에서 `copyWithNodeDate` 호출 시 `identical`로 자기 자신 반환 확인), 왕복 직렬화,
  키 생략 확인, 6개 `copyWith*` 전부 보존 확인(특히 `copyWithReverted`). `flutter analyze`
  전체 통과, `flutter test` 전체 335개 통과(회귀 없음).

### S5.6.1 완료 기록 (2026-09-30)

- **추가**: `lib/services/exchange_event_mirror.dart`의 `_toRecord`/`toExchangeHistoryItem`
  양방향에 `nodeDatesJson` 연결(스키마는 S5.0부터 이미 존재, 변경 없음). 비어 있으면 null로
  둔다(1:1·보강 및 미확정 순환·2중 모두 기존과 바이트 동일).
- **검증**: `test/services/exchange_event_mirror_test.dart` +4(1:1은 null, 순환 미확정도
  null, 순환 확정 시 정확히 직렬화, 역변환 왕복), `test/repositories/timetable_repository_test.dart`의
  기존 SQLite 왕복 테스트에 `nodeDatesJson` 검증 추가. `flutter analyze` 전체 통과,
  `flutter test` 전체 340개 통과(회귀 없음).
- **다음**: S5.6.2 — `event_date_resolver.dart` 신설 + `lesson_projection`·`resolved_week.dateAware`
  전환. **R7(2중 등식) 게이트를 여기서 먼저 확인**.

### S5.6.2 완료 기록 (2026-09-30) — R7 게이트 통과

- **추가**: `lib/utils/event_date_resolver.dart`(신규) — `resolveEventDates(item)`이
  "확정 쌍(1:1·보강, period 무시) → 확정 노드(순환·2중, `nodeDates` 조회) → 추정(OQ-1,
  결강일이 속한 주)" 우선순위로 슬롯별 날짜를 판단하는 **유일한 장소**. `lesson_projection.dart`의
  `_resolveDateByDay`를 삭제하고 `project()`/`touchedCellsFor()`가 이 함수를 쓰도록 전환.
  `resolved_week.dart`의 `dateAware`도 "순환·2중 unsupported → of() 방식 통째 폴백" 분기를
  없애고, 모든 이벤트가 같은 per-move 경로(`resolveEventDates` → `fromHere`/`toHere` 판정)를
  타도록 통일 — `nodeDates`가 비어 있으면 모든 슬롯이 estimated이고 추정값은 전부 결강일
  주 안에 있으므로 `fromHere == toHere == inViewedWeek(absenceDate)`가 항상 성립해
  기존 동작과 수학적으로 동일하다(주석으로 증명 남김).
- **R7 게이트(이 단계의 최대 위험) 결과: 통과.** 2중 교체는 "1단계가 자리를 비운 뒤 2단계가
  성립"하는 순서 의존 구조라 노드들이 서로 다른 주로 갈리면 `project()`(순차 재생)와
  `dateAware`(주 단위 근사)가 어긋날 위험이 있었다. 실제로 2단계(nodeA↔nodeB)만 결강일과
  다른 주로 확정한 픽스처로 시험한 결과 **등식이 깨지지 않았다** — 이 2중 픽스처는 두
  단계가 서로 다른 좌표(4개 노드가 전부 다른 교사·시간)를 건드려 `_applyFillOnly`의
  스냅샷 근사와 실제로 충돌하지 않기 때문이다. **결론(OQ-9 해소)**: 2중을 "모든 노드가
  같은 주일 때만 확정 인정"으로 축소할 필요 없음 — 순환·2중 모두 제한 없이 지원한다.
- **연결 상태**: 여전히 비연결 — `nodeDates`를 채우는 UI가 없으므로 이 변경 자체는 앱 동작에
  영향이 없다(모든 기존 회귀 테스트가 무수정 통과하는 것이 그 증거).
- **검증**: `test/utils/event_date_resolver_test.dart`(신규 7개) + `lesson_projection_test.dart`
  +2(순환 부분 확정, 2중 R7 게이트) + `resolved_week_from_lessons_test.dart` +2(같은 픽스처를
  SQLite 조회 경로로 재증명). 기존 회귀 스위트 — `resolved_week_date_aware_test.dart`,
  `resolved_week_test.dart`, `exchange_cell_dates_test.dart`, `exchanged_cell_overlay_dates_test.dart`
  포함 — **전부 무수정 통과**. `flutter analyze` 전체 통과, `flutter test` 전체 351개 통과
  (기존 340개 전부 무수정 통과, 회귀 없음).
- **다음**: S5.6.3 — `ExchangeCellDates.forWeek`를 이벤트 단위에서 노드(슬롯) 단위로 세분화.

### S5.6.3 완료 기록 (2026-09-30)

- **추가**: `lib/utils/exchange_cell_dates.dart`의 `forWeek`가 순환·2중(`unsupported`)
  이벤트를 더 이상 "이벤트 통째로" 처리하지 않고, 새 비공개 헬퍼 `_legacySlottedKeys(path)`
  (기존 `legacySourceKeys`/`legacyDestinationKeys`와 정확히 같은 키를 내되 각 키의 슬롯
  (요일·교시)·vacate 여부를 함께 반환 — 두 기존 함수 자체는 한 글자도 바꾸지 않음)로
  **노드(슬롯) 단위**로 순회한다. 슬롯마다 `resolveEventDates`로 확인해, 확정됐고
  (`isConfirmed`) 보고 있는 주에 속하면 그 칸만 추가(`undatedKeys`에서 제외), 확정 안 됐으면
  (추정) 기존과 똑같이 "어느 주든 항상 표시 + undatedKeys" 경로를 그대로 탄다 — 1:1·보강의
  요일 불일치 폴백도 이 경로를 타지만 `resolveEventDates`가 이 경우 항상 estimated를
  반환하므로 동작 변화가 없다.
- **자동으로 따라온 것(코드 변경 없음)**: `exchanged_cell_overlay_dates.dart`(OFF 모드
  꼬리표, `touchedCellsFor` 재사용 — S5.6.2에서 이미 확정 노드를 반영하도록 바뀜),
  `timetable_data_source.dart`의 `_resolveOverlayDate`(ON 모드 "?", `forWeek().undatedKeys`만
  봄), `exchange_executor.dart`의 X/○ 하이라이트(`forWeek` 재사용) — 전부 확정 노드가 있으면
  자동으로 정확한 주에만 나타나고 "?"에서 빠진다.
- **검증**: `test/utils/exchange_cell_dates_test.dart` +4(노드 하나 확정 시 스코프·undated
  제외, 확정 노드가 관계없는 주에는 전혀 안 나타남, 순환·2중 각각 "확정 노드 없음" 시
  `forWeek` 결과가 `legacySourceKeys`∪`legacyDestinationKeys`와 정확히 같은 집합임을 증명),
  `exchanged_cell_overlay_dates_test.dart` +1(확정 노드가 있으면 추정이 아니라 확정 날짜를
  보여줌 — 코드 무변경인데 값이 바뀜을 고정). 기존 회귀 스위트 전부 무수정 통과. `flutter
  analyze` 전체 통과, `flutter test` 전체 356개 통과(기존 351개 전부 무수정 통과, 회귀 없음).
- **다음**: S5.6.4 — `ExchangeHistoryService.updateNodeDate` 추가(가드 2개: 순환·2중 전용,
  요일 일치 검증). UI는 아직 미연결.

### S5.6.4 완료 기록 (2026-09-30)

- **추가**: `lib/services/exchange_history_service.dart`에 `updateNodeDate(itemId, {dayName,
  period, date})` 신규 — 기존 `updateDates`(1:1·보강 전용, 무변경)와 나란히 두는 형제
  메서드. 가드 2개: ① 대상이 `supportsNodeDates`가 아니면(1:1·보강) null만 반환 ② `date`의
  실제 요일이 `dayName`과 다르면 null만 반환(둘 다 상태를 바꾸지 않음). 통과하면
  `item.copyWithNodeDate()` → 리스트 교체 → 버전 증가 → `_notifyVersionChanged()` →
  `_saveToLocalStorage()`까지 **기존 배선을 그대로 재사용**한다 — 새로 연결한 훅이
  0개다(S5.4a가 `replayInto`를 기존 훅에 이어붙인 것과 같은 전략). 이 한 줄
  (`_notifyVersionChanged`)만으로 JSON 저장 → SQLite 미러 → `replayInto` → 계획서 자동
  새로고침 → `WeekLessonsCache.clearAll()`(S5.5.4에서 이미 연결됨)까지 전부 자동으로
  따라온다.
- **연결 상태**: 여전히 비연결 — 이 메서드를 호출하는 UI가 없다.
- **검증**: `test/exchange_history_service_test.dart`에 신규 그룹 `updateNodeDate` 5개 —
  순환에 정상 저장, 1:1은 게이트에 막혀 null·상태 무변경, 요일 불일치도 null·상태 무변경,
  버전 증가 확인, 존재하지 않는 id는 null. `flutter analyze` 전체 통과, `flutter test`
  전체 361개 통과(기존 356개 전부 무수정 통과, 회귀 없음).
- **S5.6.0~S5.6.4 전체 요약**: 데이터 모델(`nodeDates`)·SQLite 미러·판단 로직
  (`resolveEventDates`)·조회 세분화(`forWeek`)·저장 메서드(`updateNodeDate`)까지 전부 완성
  됐지만, **UI가 없어 실제로 이 기능을 쓸 방법이 아직 없다**(의도된 설계 — 여기까지는
  플래그 없이 배포해도 동작 변화가 0). 다음은 S5.6.5(계획서 화면 표시를 노드 기준으로
  전환) + S5.6.6(날짜 선택기가 실제로 `updateNodeDate`를 호출하도록 연결) — 여기서부터
  `nodeDateEditEnabledProvider`(기본 OFF)로 감싼다.

### S5.6.5 완료 기록 (2026-09-30)

- **추가**: `lib/providers/node_date_edit_provider.dart`(신규) — `nodeDateEditEnabledProvider`
  (기본 false, S5.5.4와 같은 3단계 롤백의 1단계). `substitution_plan_viewmodel.dart`의
  `_handleCircularExchange`/`_handleDualExchange`에 선택적 `EventDateResolution? resolution`
  파라미터 추가(null=기존과 동일). 플래그 ON이면 `loadPlanData()`가 각 순환·2중 항목에
  `resolveEventDates(item)`을 한 번 계산해 넘기고, 두 핸들러는 새 헬퍼 `_resolveRowDates()`로
  각 행의 source/target 노드 슬롯 날짜를 계산해 쓴다 — 확정된 슬롯은 확정 날짜, 미확정
  슬롯은 **그 슬롯의 실제 요일에 맞는 추정 날짜**(기존처럼 item 전체의 결강일/교체일 쌍을
  요일이 다른 행에도 그대로 복사하던 부정확한 방식 대신). `_handleOneToOneExchange`/
  `_handleSupplementExchange`는 시그니처·본문 모두 무변경.
- **연결 상태**: 화면 표시는 연결됐지만 **기본 OFF**라 배포 자체는 동작 변화 없음. 날짜
  선택기(쓰기 경로)는 아직 미연결 — S5.6.6에서 연결 예정.
- **검증**: `test/providers/substitution_plan_viewmodel_node_dates_test.dart`(신규 3개) —
  플래그 OFF면 순환교체 모든 행이 기존처럼 item의 결강일/교체일을 그대로 보여줌, 플래그
  ON이면 확정 노드는 확정 날짜·미확정 노드는 슬롯 요일에 맞는 추정 날짜로 정확히 갈라짐(4개
  노드 순환의 3개 행 전부 개별 검증), 플래그 ON이어도 1:1 교체 행은 완전히 무영향. `flutter
  analyze` 전체 통과, `flutter test` 전체 364개 통과(기존 361개 전부 무수정 통과, 회귀 없음).
- **다음**: S5.6.6 — `content_input_grid.dart`의 `_applyDateSelection`이 플래그 ON + 순환·2중
  항목일 때 `updateNodeDate`를 호출하도록 연결(실패·게이트 걸림 시 기존 `updateDates` 경로로
  폴백).

### S5.6.6 완료 기록 (2026-09-30) — 실제 쓰기 경로 연결 (기본 OFF)

- **추가**: `lib/ui/screens/plan_output/widgets/content_input_grid.dart`의
  `_applyDateSelection`이 `groupId` 대신 `SubstitutionPlanData data` 전체를 받도록 시그니처
  변경(호출부는 이미 `data`를 갖고 있어 전달만 추가). `item.supportsNodeDates &&
  nodeDateEditEnabledProvider`가 모두 참이면, 그 행이 가리키는 슬롯(결강일 열이면
  `data.absenceDay`/`data.period`, 교체일 열이면 `data.substitutionDay`/
  `data.substitutionPeriod`)으로 `updateNodeDate`를 호출한다 — 성공하면 끝, 가드에 걸려
  null이 나오면(이론상 발생하지 않아야 함 — 날짜 선택기가 이미 `selectableDayPredicate`로
  그 행의 요일만 고를 수 있게 강제하지만, 방어적으로) **"저장 안 됨"으로 끝내지 않고 기존
  `updateDates` 경로로 폴백**한다. 1:1·보강, 또는 플래그가 꺼져 있으면 이 분기 자체에
  들어가지 않고 기존 `updateDates` 한 줄 그대로다.
- `lib/ui/screens/start_content/dated_data_inspector_section.dart`에 "순환·2중 교체 노드별
  날짜 확정 (S5.6, 실험적)" 스위치 추가(S5.5.4와 같은 패턴 — 기본 꺼짐, 즉시 토글).
- **연결 상태**: 이제 S5.6.0~S5.6.6 전체가 실제로 이어졌다 — 스위치를 켜면 계획서에서
  순환·2중의 날짜를 노드 단위로 고칠 수 있고, 그 결과가 교체 화면·SQLite 조회 경로까지
  전부 자동으로 따라간다(새로 배선한 훅은 없음, S5.6.4의 `_notifyVersionChanged` 재사용
  그대로). 기본값은 여전히 꺼짐이라 배포 자체는 동작 변화가 없다.
- **검증**: 이 단계는 UI 위젯의 비공개 메서드 배선이라 전용 단위 테스트를 추가하지 않았다
  (분기 로직이 호출하는 `updateNodeDate`/`updateDates`는 이미 각각 S5.6.4/기존 테스트로
  검증됨). `flutter analyze` 전체 통과, `flutter test` 전체 364개 통과(기존과 동일 개수,
  회귀 없음).
- **다음(필수)**: **사용자가 실 앱에서 스위치를 켜고, 순환·2중 계획서 행의 날짜를 수정한
  뒤 교체 화면(날짜표시 ON)에서 그 칸의 "?"가 실제 날짜로 바뀌는지 확인해야 한다.** 확인이
  끝나면 S5.6.7(플래그 기본 ON 전환 + 문서 정리)로 마무리한다.

### S5.6.7 완료 기록 (2026-09-30) — 실행 시점 노드 날짜 자동 확정 (Opus 검토 반영)

**배경**: S5.6.6까지 확인하던 사용자가 실 앱에서 "순환·2중 교체를 실행하면 계획서에 날짜가
자동으로 보이는데, 왜 교체 화면은 여전히 '?'만 보여주냐"고 지적했다. Sonnet이 "계획서는
추정일 뿐이고 사용자가 직접 확인해야 확정된다"고 설명했으나 사용자가 이 설명을 거부("네가
잘못 알고 있다")했고, 여러 차례 스크린샷 교환으로도 좁혀지지 않아 Opus에게 재검토를
요청했다.

**Opus 진단**: 사용자가 맞았다. `ExchangeExecutor._dateForNode`(교체 실행부)는 `selectedWeek`
로부터 각 노드의 실제 날짜를 **이미 정확히 계산해서** `absenceDate`/`substitutionDate`를
만든다. 그런데 이 값을 `nodeDates`에 기록하지 않고 버려서, 나중에 `resolveEventDates`가
"결강일이 속한 주"라는 **같은 식으로 다시 유도**한 뒤 "추정"이라는 라벨을 붙여 "?"를
띄우고 있었다 — 실은 몰라서 추정하는 게 아니라 **이미 아는 값을 기록만 안 한 것**이었다.
2026-09-29의 "억지로 추정하지 않는다" 결정은 "모르는 값을 지어내지 말라"는 것이었지 "아는
값을 기록하지 말라"는 뜻이 아니었으므로, 이 결정과 충돌하지 않는다.

Sonnet이 처음 제안한 수정안("모델 팩토리에서 absenceDate로부터 무조건 역산해 시드")은
Opus가 반려했다 — 플래그 OFF 상태에서 계획서의 `updateDates`(항목 전체 쌍 갱신) 경로와
충돌해 계획서와 교체 화면이 서로 다른 날짜를 주장하게 되고, 기존 테스트 7개가 깨진다.

**채택한 설계**: 값의 출처를 실행기(`selectedWeek`를 아는 유일한 계층)로 못박는다.
- `lib/utils/node_date_seed.dart`(신규) — `seedNodeDatesForWeek(path, weekMonday)` 순수
  함수. 순환·2중이 아니면 빈 맵. `path.nodes`를 순회해 각 노드의 슬롯에 `weekMonday +
  (요일오프셋)`을 채운다 — `resolveEventDates`의 OQ-1 추정식과 완전히 같은 수식이지만,
  나중에 다시 추측하는 게 아니라 **실행 시점에 사실로 기록**한다는 점이 다르다.
- `ExchangeHistoryItem.fromExchangePath`에 옵셔널 `nodeDates` 인자 추가 — **미지정(null)이면
  기존과 완전히 동일한 빈 맵**(기본값). 1:1·보강에는 절대 저장하지 않는다(`copyWithNodeDate`
  와 같은 오염 방지 가드).
- `ExchangeHistoryService.executeExchange`/`addExchange`에 같은 이름의 옵셔널 인자를
  추가해 그대로 통과시킨다(서비스는 판단하지 않는다).
- `ExchangeExecutor._computeExchangeDates`의 반환에 `weekMonday`를 추가하고,
  `executeExchange`에서 `ref.read(nodeDateEditEnabledProvider)`가 true일 때만
  `seedNodeDatesForWeek(exchangePath, dates.weekMonday)`를 계산해 넘긴다. **플래그
  OFF(기본값)면 null을 넘겨 S5.6.6 이전과 완전히 동일하게 동작한다** — 이것이 이 단계도
  플래그로 게이팅해야 하는 이유(읽기 쪽은 이미 무조건 켜져 있지만, 쓰기 쪽인 이 단계는
  `updateDates`와의 충돌을 피하려면 반드시 게이팅해야 한다).
- `content_input_grid.dart`의 `_applyDateSelection` 폴백 분기(이론상 발생하지 않아야 함)에
  진단용 `AppLogger.warning` 한 줄 추가.
- **관측 가능한 변화는 정확히 2가지뿐**(플래그 ON일 때): ① 참여 칸의 "?"가 사라짐(사용자가
  원한 것) ② X/○ 하이라이트가 실제 주에만 스코프됨(예전엔 순환·2중이 어느 주를 봐도 항상
  표시됐음 — 유령 하이라이트가 사라지는 방향이지만 눈에 띄는 변화라 수동 확인 항목에 포함).
  SQLite `lessons` 출력·`project() ≡ dateAware` 등식·날짜표시 OFF 모드·계획서 표시값은
  전부 **값 자체가 시드 전과 완전히 동일**함을 테스트로 증명했다(라벨만 추정→확정으로
  바뀔 뿐).
- **기존 항목 백필은 하지 않는다** — 오늘 테스트로 이미 만든 순환·2중 건은 `nodeDates`가
  영구히 빈 채로 남아 계속 "?"가 뜬다. 삭제 후 새로 실행하면 새 로직으로 시드된다.
- **알려진 한계(OQ-11)**: `nodeSlotKey`가 교사를 포함하지 않으므로(S5.6.0의 의도된 설계),
  (요일,교시)가 같고 교사만 다른 두 노드는 같은 슬롯 키를 공유한다 — 2중 교체에서 실제로
  발생 가능(테스트로 재현·고정함). 무해하지만 나중에 계획서에서 한쪽을 고치면 다른 쪽도
  같이 바뀐다.
- **덤으로 발견한 별개의 명명 오류(수정하지 않음, 별도 단계로 분리)**: `substitution_plan_
  viewmodel.dart`의 `_handleDualExchange`에서 `absentNode`/`substituteNode`/
  `intermediateNode1`/`intermediateNode2` 지역 변수명이 `DualExchangePath.nodes =>
  [node1, node2, nodeA, nodeB]`의 실제 의미와 거꾸로 붙어 있다. 행 짝짓기·비고란은 우연히
  올바르게 나오므로 동작 버그는 아니다 — 이번 단계와 무관해 손대지 않음(향후 S5.6.9 후보).
- **검증**: `test/utils/node_date_seed_test.dart`(신규 5개 — 순환 시드, 슬롯 충돌 재현,
  1:1·보강 빈 맵, 월요일 정규화, `resolveEventDates`와 값 동일성), `exchange_history_item_test.dart`
  +4, `exchange_history_service_test.dart` +2, `exchange_cell_dates_test.dart` +1(전부
  시드된 순환의 "?" 소멸 + 다른 주 완전 소거), `lesson_projection_test.dart` +1(시드된
  2중의 SQLite 출력 불변 + R7 재확인). **기존 테스트는 단 1건도 수정하지 않았다** — Opus
  설계의 핵심 목표였고 실제로 달성됐다. `flutter analyze` 전체 통과, `flutter test` 전체
  377개 통과(기존 364개 전부 무수정 통과, 회귀 없음).
- **사용자 실 앱 확인 완료(2026-09-30)**: 처음 재현 테스트에서 여전히 "?"가 떠 원인 조사를
  진행했다. `executeExchange`/`_resolveOverlayDate`에 임시 진단 로그를 추가해 확인한 결과,
  실행 순간 `nodeDateEditEnabled=false`로 찍혔다 — 코드 버그가 아니라 **Flutter의 hot
  restart가 세션 메모리 전용 상태(이 스위치 포함)를 전부 초기화**하기 때문이었다. 사용자가
  코드 수정마다 hot restart로 재확인하던 와중에, 재시작 후 스위치를 다시 켜지 않은 채
  테스트해 계속 OFF로 실행된 것. 재시작 없이 스위치를 켠 직후 바로 실행하니 **참여 칸에
  "?" 없이 정상적으로 날짜가 표시됨을 확인**("정상 동작하는 것 같습니다. 핫리로드후,
  준비>기타 부분이 초기화되어서 생기는 문제였던 것으로 보입니다"). 진단 로그 3곳
  (`exchange_executor.dart`, `exchange_history_service.dart`, `timetable_data_source.dart`)은
  모두 제거했다 — `flutter analyze`/`flutter test`(377개) 재확인, 회귀 없음.
- **교훈**: 세션 전용(비영속) 플래그는 hot restart마다 초기화된다는 것을 앞으로도 사용자
  안내에 명시할 것 — 코드 수정 후 재시작한 뒤에는 실험용 스위치를 매번 다시 켜야 한다.
- **다음**: S5.6.8(플래그 기본 ON 전환 + 문서 정리) 여부를 사용자와 논의.

### S5.6.8 완료 기록 (2026-09-30) — 플래그 기본 ON 전환, S5.6 전체 완료

- **변경**: `lib/providers/node_date_edit_provider.dart`의 `nodeDateEditEnabledProvider` 기본값을
  `false` → `true`로 전환. Dartdoc을 "S5.6.5~S5.6.6, 실험적"에서 "S5.6.8부터 기본값"으로
  갱신하고, S5.6.7(실행 시점 자동 확정) 동작도 함께 문서화. S4.0 패널의 토글
  (`_buildNodeDateEditToggle`)도 라벨에서 "실험적" 문구를 빼고, 강조 색상 로직을 뒤집었다 —
  기본값(켜짐)은 평범한 상태로 두고, **꺼서 예전 방식(항상 "?")으로 되돌린 경우에만** 주황색
  으로 강조한다(S5.5.4의 "SQLite 조회 경로" 토글과 반대 방향 — 그쪽은 아직 기본 꺼짐이라
  "켜졌을 때" 강조).
- **영향**: 이제부터 순환·2중 교체를 실행하면 **기본적으로** 참여 칸 날짜가 즉시 확정되고
  "?" 없이 표시된다. 문제가 있으면 언제든 S4.0 패널에서 스위치를 꺼서 재빌드 없이 즉시
  예전 방식(순환·2중은 항상 "?")으로 되돌릴 수 있다 — 이미 확정된 날짜가 지워지지는 않지만
  새로 실행하는 교체부터는 확정하지 않는다.
- **회귀**: 기본값이 바뀌므로 `nodeDateEditEnabledProvider`의 기본값(꺼짐)에 의존하던 테스트
  1건(`substitution_plan_viewmodel_node_dates_test.dart`의 "플래그 OFF" 테스트)이 명시적으로
  `container.read(nodeDateEditEnabledProvider.notifier).state = false`를 설정하도록 수정
  됐다 — 이 테스트가 검증하는 내용(플래그 OFF 시 예전 동작) 자체는 그대로다. 그 외 테스트는
  전부 무수정 통과. `flutter analyze` 전체 통과, `flutter test` 전체 377개 통과.
- **S5.6 전체(S5.6.0~S5.6.8) 완료.** 순환·2중 교체의 노드별 날짜 확정 기능이 기본으로
  켜져 있고, 실행 시점 자동 확정 + 계획서 화면 수동 보정 두 경로 모두 실 앱에서 확인
  완료됐다.

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
| D2 | 다른 주 교체 UI 방식 | **확정(2026-09-30)**: 별도 UI 없음. 원하는 주로 이동해(기존 주 이동 UI) 교체를 실행하면 "?"(미확정) 상태로 기록되고, 계획서 화면에서 날짜를 지정/보정한다 — S5.6(`nodeDateEditEnabledProvider`, `updateNodeDate`)이 이미 이 흐름 그대로 구현·검증됨. S6 설계 검토(2026-09-30)에서 코드 레벨로 이미 전 구간이 연결돼 있음을 확인, 신규 UI 없음 |
| D3 | 다른 주 교체에서 순환·2중 지원 범위 | **확정(2026-09-29)**: 제한 없이 순환·2중 모두 지원. S5.6.2의 R7 게이트에서 2중 교체가 서로 다른 주로 갈려도 `project() ≡ dateAware`가 깨지지 않음을 실제 다주 픽스처로 확인 |
| D4 | 학기 중 새 엑셀 적용 방식 | **확정(2026-09-29)**: 별도 새 시간표로 등록. 기존 등록 흐름과 이미 일치, 추가 구현 없음 |
| D5 | 같은 학기 재등록 시 동작 | **확정(2026-09-29)**: 새 시간표로 등록해 기존 데이터 보존. 기존 등록 흐름과 이미 일치, 추가 구현 없음 |
| D6 | 후속 교체가 있는 되돌리기 정책 | **확정·구현 완료(2026-09-30 종결 기록)**: OQ-2로 승인된 비차단 경고(`exchange_dependency_checker.dart` + `exchange_executor.dart`)로 구현 완료. 게다가 "이미 교체된 칸은 재선택 불가"라는 기존 보호장치 때문에 후속 의존 상황 자체가 현재 UI로는 만들어지지 않음 — S6/S7/S8에 영향 없음 |
| D7 | 기본 화면(교체 반영본 vs 원본 비교) | 여전히 미결정, 기본값은 "원본"(`exchange_view_provider.dart`의 `isEnabled = false`). S6 설계 검토(2026-09-30)에서 조회 경로 ON/OFF 분기와 완전히 독립이고 계획서·PDF는 `ResolvedWeek`를 아예 안 쓰므로 **S6·S7 설계엔 영향 없음**을 확인. S8에서 레거시 정리 시 "교체뷰 OFF 경로는 삭제 대상 아님"만 유의 |
| D8 | 계획서 날짜 수정의 의미 | **확정(2026-09-30)**: 계획서에서 날짜를 직접 수정하면 해당 교체건의 실제 날짜가 바뀐다. S5.6.6(`content_input_grid.dart`의 `_applyDateSelection` → `updateNodeDate`/`updateDates`)이 이미 이 의미 그대로 구현·검증됨 — S7에서 별도 구현 불필요, S7.1 회귀 테스트(`pdf_field_mapping_test.dart`)로 PDF 출력까지 고정 |

"교체" 페이지의 날짜표시 ON/OFF 두 모드 표시 방식 자체는 2026-09-29 확정되었다(S1.5, 계획서
§5 참조). 그 기본값(OFF)을 ON으로 뒤집을지는 S6 설계 검토에서 다시 물었으나 **사용자가
"현행 유지(OFF)"로 확정(2026-09-30)** — 날짜 기반 표시·검증·SQLite 조회 경로 자체는 다
구현·검증돼 있지만, 앱을 켠 기본 화면에서는 계속 잠들어 있는 상태로 유지된다.

## S6 알려진 제한 (날짜표시 OFF 모드, 2026-09-30 기록)

`showWeekHeaderProvider`가 기본값(OFF)으로 유지되기로 확정됨에 따라, 아래는 OFF 모드에서
계속 남아 있는(고칠 계획 없는) 구조적 한계다 — 전부 ON으로 전환하면 사라지는 한계이므로
"버그"가 아니라 "OFF 모드의 설계상 트레이드오프"로 취급한다.

- **모든 주에 표시됨**: OFF 모드는 날짜 개념이 없으므로(요일만 기준), 교체가 어느 캘린더 주에
  실행됐는지와 무관하게 매주 반복 표시된다.
- **검증이 과잉 차단함**: 같은 이유로, 다른 주에 실행된 교체가 이번 주의 새 교체 탐색을 실제로
  막을 이유가 없는데도 막을 수 있다.
- **꼬리표 좌표 키 충돌**: `ExchangedCellOverlayDates.build`가 `교사_요일_교시`만으로 키를
  만들기 때문에, 서로 다른 주에서 같은 좌표(교사·요일·교시)를 건드린 교체가 2건 이상 있으면
  나중 항목이 앞 항목의 날짜 꼬리표를 덮어쓴다(마지막 승). OFF 모드가 날짜를 좌표에 담지 않는
  이상 근본적으로 고칠 수 없다 — 유일한 해법은 ON 전환(S6.4)이며, 사용자가 이를 보류했으므로
  현재는 알려진 제한으로만 남긴다.

## 변경 기록

| 날짜 | 내용 |
|---|---|
| 2026-09-29 | `c4867cf` 실패 이후 재작성. S0·S1만 상세화, SQLite 유지·데이터 모델 우선 착수로 확정 |
| 2026-09-29 | S5(S5.0~S5.4b) 완료 — SQLite `lessons`가 실제 진실 원본이 됨. S5.5 Opus 설계 검토 승인, S5.5.0(조회 헬퍼 2개, 비연결) 완료 |
| 2026-09-29 | S5.5.1(`ResolvedWeek.fromLessons` 오버레이 어댑터, 비연결) 완료 — S5.3 픽스처로 dateAware와 동등성 증명 |
| 2026-09-29 | S5.5.2(S4.0 패널에 섀도우 비교 패널 추가) 완료, 사용자가 순환·2중 포함 4건으로 "불일치 0칸" 확인 — 게이트 통과. S5.5.3(프리페치 캐시 `WeekLessonsCache`, `flushPendingWrites`, 비연결) 완료 |
| 2026-09-29 | S5.5.4(실제 조회 전환, 기본 OFF) 완료 — `resolved_timetable_provider`·`exchange_view_provider` 둘 다 SQLite 오버레이 경로로 연결, S4.0 패널에 롤백 스위치 추가(S5.5.5 토글 선반영). 사용자 실 앱 확인 대기 중 |
| 2026-09-30 | 사용자가 S5.5.4 실 앱 테스트 중 표시/검증 불일치 버그 발견(교체 이력 변경 시 `WeekLessonsCache` 미무효화) — `exchangeListVersionProvider` 구독 추가로 수정, 회귀 테스트 추가 |
| 2026-09-30 | 같은 테스트 중 별개의 기존 버그 발견(되돌린 교체가 계획서에 계속 남음, S5.5와 무관) — `loadPlanData()`가 `getActiveExchangeList()`를 쓰도록 수정, 회귀 테스트 추가 |
| 2026-09-30 | S5.6(순환·2중 노드별 날짜) Opus 설계 검토 완료, 사용자 승인. S5.6.0~S5.6.4(데이터 모델·SQLite 미러·판단 로직·조회 세분화·저장 메서드) 전부 완료, 전부 비연결(동작 변화 0). R7(2중 등식) 게이트 통과 |
| 2026-09-30 | S5.6.5(계획서 화면 표시를 노드 기준으로 전환) 완료 — `nodeDateEditEnabledProvider` 신설(기본 OFF) |
| 2026-09-30 | S5.6.6(계획서 날짜 선택기 → `updateNodeDate` 실제 연결) 완료, S4.0 패널에 토글 추가. 사용자 실 앱 확인 대기 중 |
| 2026-09-30 | 사용자가 "순환·2중 실행 시 날짜가 이미 자동 배정되는데 왜 ?로 뜨냐" 지적 → Opus 재검토 → S5.6.7(실행 시점 노드 날짜 자동 확정, 플래그 게이팅) 완료. 기존 테스트 0건 수정, 신규 13개 |
| 2026-09-30 | S5.6.7 재현 테스트에서 "?"가 계속 떠 진단 로그로 조사 — 원인은 hot restart가 세션 전용 플래그를 초기화하는 것(코드 버그 아님). 재시작 없이 재확인해 정상 동작 확인, 진단 로그 제거 |
| 2026-09-30 | S5.6.8(플래그 기본 ON 전환) 완료 — S5.6(순환·2중 교체 노드별 날짜 확정) 전체 완료 |
| 2026-09-30 | "준비 > 기타 설정 > 날짜 기반 데이터 확인" 패널 정리 — 검증이 끝나 더 이상 필요 없는 "교체 이력 드리프트 알림"(S4.4/S5.2)과 "화면 표시 vs SQLite 정합성 확인" 섀도우 비교 패널(S5.5.2)을 삭제. 시간표 정보/통계 블록과 두 롤백 토글(S5.5.4 조회 경로, S5.6 노드별 날짜)은 유지. `flutter analyze` 통과, `flutter test` 377개 전체 통과(수정된 테스트 없음) |
| 2026-09-30 | S5.5.4 회귀 체크리스트 코드 레벨 점검 진행. **OFF 모드 불변조건**: `resolved_timetable_provider`·`exchange_view_provider` 둘 다 `showWeekHeader` OFF면 무조건 `ResolvedWeek.of`, ON이어도 `lessonReadPathEnabledProvider` OFF면 무조건 `dateAware` — SQLite 경로 자체를 코드 구조상 못 탐(기존 테스트로 확인됨). **시간표 전환 시 캐시 정리**: `state_reset_provider.dart`의 Level 3 리셋이 `weekLessonsCacheProvider.clearAll()`을 이미 호출하고 있음을 코드로 확인(별도 전용 테스트는 없음). **PDF·개인 시간표 비영향**: `lib/` 전체에서 PDF·개인시간표 관련 코드가 `resolvedTimetableProvider`/`lessonReadPathEnabledProvider`/`weekLessonsCacheProvider`/`ResolvedWeek.fromLessons`/`dateAware`를 전혀 참조하지 않음을 grep으로 확인 — 구조적으로 영향 불가. **교체불가 셀 스타일**: `applyDatedNonExchangeable`가 조회 경로(ON/OFF) 분기 이후 공통으로 적용되므로 이 토글과 독립적임을 코드로 확인. **주 이동**: 캐시 키가 `timetableId\|weekMonday`이고 R7(2중 등식) 게이트에서 이미 다주 픽스처로 검증된 것과 동일 메커니즘이라 별도 테스트 추가 없이 코드 레벨로 충분하다고 판단 |
| 2026-09-30 | **S3 이전 시간표 항목에서 실제 회귀(알려진 한계) 발견** — SQLite `timetables`/`lesson_snapshots` 행이 없는 시간표(S3 이전 등록분)에서 `lessonReadPathEnabledProvider`를 켜고 교체를 실행하면, `replayInto`가 스냅샷 템플릿을 못 찾아 그 칸의 `lessons.subject`/`className`이 `null`로 채워짐 → 화면에서 원래 과목명이 사라짐. 재현·고정한 회귀 테스트: `test/providers/resolved_timetable_provider_pre_s3_test.dart`(2개) |
| 2026-09-30 | **S3 이전 시간표 회귀 즉시 수정** — `TimetableRepository.ensureDatedBackfill(timetableId, base, registeredAt, ...)` 신규: `timetables` 행이 없으면 S3 등록 흐름(`timetable_file_screen.dart` 4.5단계)과 동일한 절차(시간표 메타데이터 + 학기 전체 lessons + 원본 스냅샷)를 트랜잭션 안에서 딱 한 번 수행, 이미 있으면 즉시 반환(idempotent, 동시 호출 안전). `WeekLessonsCache`에 `ensureBackfill` 콜백을 추가해 `_load()`가 재생 여부 확인 전에 먼저 호출하도록 연결(`week_lessons_cache_provider.dart`의 `_ensureDatedBackfill`이 현재 화면에 열린 `TimeSlot` 목록 + `timetableRegistryProvider`의 이름·교사·학교명·등록시각을 채워 넣음, 둘 다 못 찾으면 조용히 건너뛰어 기존 동작 유지). 회귀 테스트를 "알려진 한계"에서 "수정 확인"으로 갱신(과목명이 정확히 복원됨을 확인), 리포지터리 레벨 단위 테스트 2개 추가(`timetable_repository_test.dart` — 신규 생성 시 채움, 이미 있으면 아무것도 안 함). `flutter analyze` 통과, `flutter test` 381개 전체 통과 |
| 2026-09-30 | **S5.5.4 회귀 체크리스트 8개 항목 전부 정리 완료 — S5.5(S5.5.0~S5.5.5) 전체 완료.** 나머지 문서 정리: handoff.md 최상단 상태 요약을 "S1~S5.6까지 전부 완료"로 갱신(기존엔 S5.5·S5.6 완료 사실이 요약에 누락돼 있었음), 상태 표에 S5.5.5 행 신설(토글은 S5.5.4에서 이미 선반영, 회귀 체크리스트 완료로 S5.5 전체 종결), "다음에 할 정확한 작업" 절의 "남은 것은 회귀 체크리스트뿐" 문구를 전부 정리 완료로 갱신하고 다음 선택지(S5.5.5 토글 기본 ON 전환 또는 계획 문서의 S6 착수)를 명시. 토글 자체는 여전히 기본 OFF로 유지(사용자가 별도 지시할 때만 기본 ON 전환) |
| 2026-09-30 | **S5.5.5(토글 기본 ON 전환) 완료 — S5.5(S5.5.0~S5.5.5) 실제 종결.** `lessonReadPathEnabledProvider` 기본값 false→true(S5.6.8과 동일한 패턴). S4.0 패널의 토글 문구·강조 색상도 함께 갱신(UI 변경은 사용자 사전 확인 후 진행) — 라벨에서 "실험적" 제거, 기본값(켜짐)은 강조하지 않고 꺼서 예전 방식으로 되돌린 경우에만 주황색으로 강조(S5.6.8의 노드별 날짜 토글과 동일 규칙). 기본값에 의존하던 테스트 2개(`resolved_timetable_provider_lesson_read_path_test.dart`, `resolved_timetable_provider_pre_s3_test.dart`의 "OFF" 시나리오)를 명시적 `.state = false` 설정으로 수정, 나머지 무수정. `flutter analyze` 통과, `flutter test` 381개 전체 통과 |
| 2026-09-30 | **S6·S7 설계 검토 완료(Opus) — 둘 다 "이미 구현돼 있음"으로 확인.** 사용자가 D2("다른 주 교체 UI 방식")·D8("계획서 날짜 수정 의미")을 확정한 뒤 코드를 실제로 추적한 결과, S6·S7이 요구하는 동작 전부가 S5.6에서 이미 구현·검증돼 있음을 확인 — 신규 UI·기능 추가 없이 회귀 테스트로 고정하는 것으로 범위 확정. `showWeekHeaderProvider` 기본 ON 전환·PDF 날짜 연도 표시는 사용자가 둘 다 "현행 유지"로 결정 |
| 2026-09-30 | **S6.1 결함 후보(G4) 검증 — 재현 안 됨.** "학기 기간 축소로 비활성화된 주에서 교체하면 SQLite 조회 경로에서 누락되는가"를 리포지터리 레벨로 재현 시도했으나, `project()`가 스왑 결과 `Lesson`을 `isActive` 미지정(기본값 true)으로 만들고 `replayInto`가 내용 변경 시 행 전체를 갱신해 is_active가 자동으로 되살아나므로 실제로는 문제없음을 확인. 회귀 감지용 테스트 1개 추가(`timetable_repository_test.dart`) |
| 2026-09-30 | **S6.0(다른 주 교체 회귀 커버리지) 확인, S6.2(OFF 모드 알려진 제한) 문서화, S6.4(날짜표시 기본값) 현행 유지로 확정 — S6 종결.** 신규 테스트 스위트를 만들지 않고 기존 `exchange_cell_dates_test.dart`/`resolved_week_date_aware_test.dart`/`resolved_week_from_lessons_test.dart`/`lesson_projection_test.dart`의 기존 "다른 주" 커버리지로 충분함을 확인. OFF 모드의 3가지 구조적 한계(모든 주 표시, 검증 과잉 차단, 꼬리표 좌표 키 충돌)를 "S6 알려진 제한" 절에 기록 |
| 2026-09-30 | **S7.1(계획서→PDF 날짜 회귀 테스트) 완료, S7.2(PDF 연도 표시)·S7.3(계획서 주차 그룹 캡션) 현행 유지로 확정, D2·D3·D6·D8 미결정 표 갱신 — S7 종결.** `test/utils/pdf_field_mapping_test.dart` 신규 — 노드 날짜를 다른 주로 수정한 순환 교체가 PDF가 실제로 찍을 날짜 문자열(`SubstitutionPlanFieldAccessor.getValue` + `DateFormatUtils.toMonthDay`)까지 정확히 반영됨을 고정 |
| 2026-09-30 | **S8-A(확실한 죽은 코드 제거) 완료 — S8 부분 종결.** `lib/utils/personal_exchange_view_manager.dart`(276줄) 삭제 — `lib`·`test` 전체에서 자기 자신 외 참조 0건임을 grep으로 확인 후 삭제. S8-B(실험용 플래그·OFF 분기)·S8-C(`showWeekHeaderProvider` OFF 경로 전체)는 각각 "아직 유일한 롤백 수단"·"S6.4 결정으로 계속 주 경로"라 의도적으로 보류. `flutter analyze` 통과, `flutter test` 383개 전체 통과. **이 계획 문서의 S0~S8 로드맵 전 단계가 처리 완료됐다**(S8은 안전한 부분만 실행) |
