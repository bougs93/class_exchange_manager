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

## S2 이후 (방향만 기록, 착수 전 재확정)

아래는 이번 계획의 큰 흐름이다. 각 단계 착수 직전에 사용자와 함께 세부 항목·완료 조건·회귀 체크포인트를 다시 정한다.

| 단계(가안) | 방향 | 기존 기능 영향 |
|---|---|---|
| S2 | SQLite 스키마·Repository 추가 (기존 JSON 저장과 병행, 아직 미사용) | 없음 — 신규 저장소만 추가 |
| S3 | 엑셀 등록 시 날짜별 데이터도 함께 생성·저장 (기존 주단위 저장 경로는 그대로 유지) | 낮음 — 부가 기록만 추가 |
| S4 | 전체/개인 시간표 "조회"만 날짜 기반으로 전환 (쓰기는 기존 경로 유지) | 중간 — 여기서부터 실제 화면 검증 필요 |
| S5 | 교체 실행·되돌리기를 날짜 기반 저장으로 전환 (날짜 데이터가 진실 원본이 됨) | 높음 — 핵심 회귀 위험 구간 |
| S6 | 다른 주 교체 UI·표시 | 중간 |
| S7 | 계획서·PDF 출력 날짜 기반 전환 | 중간 |
| S8 | 기존 주단위 전용 코드 제거, 최종 통합 검증 | 정리 단계 — 전체 회귀 테스트 |

S4~S5는 이전 시도(`c4867cf`)가 실패한 구간과 겹친다. 이 구간에 진입할 때는 특히 더 잘게 쪼개고,
한 번에 여러 화면·서비스를 동시에 바꾸지 않는다.

## 미결정 제품 정책

아래 항목은 해당 단계 진입 전 사용자 확인이 필요하다. 임의로 확정하지 않는다.

| ID | 항목 | 관련 단계 |
|---|---|---|
| D1 | 방학·공휴일 처리 방식 | S3, S5 |
| D2 | 다른 주 교체 UI 방식 | S6 |
| D3 | 다른 주 교체에서 순환·2중 지원 범위 | S5 |
| D4 | 학기 중 새 엑셀 적용 방식 | S3 |
| D5 | 같은 학기 재등록 시 동작 | S3 |
| D6 | 후속 교체가 있는 되돌리기 정책 | S5 |
| D7 | 기본 화면(교체 반영본 vs 원본 비교) | S4 |
| D8 | 계획서 날짜 수정의 의미 | S7 |

D2·D7과 별개로, "교체" 페이지의 날짜표시 ON/OFF 두 모드 표시 방식 자체는 2026-09-29 확정되었다 (S1.5, 계획서 §5 참조).
D2(다른 주 교체 시 상대 날짜를 어떻게 선택하는가)와 D7(기본 화면이 교체 반영본인지 원본 비교인지)은 이 확정과 별개로 여전히 미결정이다.

## 변경 기록

| 날짜 | 내용 |
|---|---|
| 2026-09-29 | `c4867cf` 실패 이후 재작성. S0·S1만 상세화, SQLite 유지·데이터 모델 우선 착수로 확정 |
