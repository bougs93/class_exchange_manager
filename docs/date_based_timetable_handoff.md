# 날짜 기반 시간표 전환 진행 기록·인수인계

최종 갱신: 2026-09-29
현재 상태: IN_PROGRESS — S1·S1.5·S1.6~S1.10·S2·S3·S3a·S4(S4.0~S4.4) 구현 완료. S4.3(개인 시간표
적용)은 사용자 결정으로 보류. S5(교체 실행·되돌리기 날짜 기반 저장 전환) Opus 설계 검토 완료,
OQ-1~8 전부 사용자 승인("전체적으로 진행해줘") — steps.md "S5 설계 검토" 절 참조. S5.0(저널
스키마+Repository, 완전 비연결) 구현 완료. 다음은 S5.1(부가 기록 미러 쓰기).
S3a를 실제 Windows 빌드로 확인하던 중 "기타 설정" 펼치면 앱이 멈추는 버그를 발견·수정했다
(`sqlite3_flutter_libs` 누락 — steps.md "긴급 수정" 절 참조). 사용자가 재빌드해 **정상 동작 확인 완료**.
S4.0에서도 별도 버그(SemesterPeriodSection SegmentedButton assertion)를 추가로 발견·수정, 확인 완료.
작업 디렉터리: `D:/Project/flutter_Teacher_Swap_Manager/class_exchange_manager`

## 1. 먼저 읽을 문서

1. 이 문서
2. [계획서](date_based_timetable_plan.md) — 배경·목표·비파괴 원칙
3. [단계별 실행 계획](date_based_timetable_steps.md) — S0·S1 상세, S2 이후 방향
4. 작업 디렉터리의 CLAUDE.md 지시와 최신 사용자 메시지

## 2. 왜 다시 계획을 세우는가

`c4867cf`("astra: musk구현, astra 점검중.")에서 58개 파일·12,343줄을 한 번에 변경하며
학기 전체 날짜 기반 시간표(SQLite)를 구현하려 했으나, **의도한 동작이 완성되지 않고 기존 기능도 손상**되어
`ad3ca9b` 시점으로 되돌렸다. 구체적으로 무엇이 손상됐는지는 기록되지 않았다.

재작업 원칙: 작은 단위로 쪼개고, 매 단계 기존 기능 회귀를 검증한다. 자세한 내용은 계획서 §4 참조.

## 3. 확정 사항 (요약)

- 주 단위 → 날짜 단위 전환. 전환 중에도 기존 기능(1:1/순환/2중 교체, 주 이동, 개인 시간표, 계획서·PDF 출력 등) 유지.
- 저장소는 SQLite 유지 (2026-09-29 확정).
- 1단계 작업은 **데이터 모델만** 먼저 만든다 (UI·저장소 미연결, 2026-09-29 확정).
- 나머지 확정 사항은 [계획서 §3](date_based_timetable_plan.md#3-확정된-요구사항) 참조.

## 4. 현재 작업 상태

| 단계 | 상태 | 비고 |
|---|---|---|
| 계획 문서 재작성 | DONE | `date_based_timetable_plan.md`, `_steps.md`, 이 문서 신규 작성. 과거 5개 문서는 삭제(2026-09-29, 사용자 요청) |
| S0 현황 조사 | 부분 | 별도 커밋 없이 S1.5 구현 중 헤더·주차 바 관련 코드를 직접 조사함(steps.md S1.5 "코드 조사 결과" 참조) |
| S1 날짜 전용 데이터 모델 | DONE (2026-09-29) | `SchoolSemester`, `SemesterDateGenerator` 추가. UI·저장소 미연결, 신규 파일만 추가. 유닛테스트 16개 |
| S1.5 날짜표시 스위치 | DONE (2026-09-29) | `showWeekHeaderProvider` 추가(기본 false). 헤더·주차 바·교체된 칸 오버레이 태그까지 조건부 처리 완료 |
| S1.6~S1.10 다른 주 교체 반영 | DONE (2026-09-29) | Opus 5 설계 검토 후 Sonnet 5로 구현. `ExchangeCellDates`(참여 칸별 실제 날짜), `ResolvedWeek.dateAware`(다른 주 독립 반영), 검증(`resolvedTimetableProvider`)·X/○ 하이라이트(`exchange_executor.dart`)까지 스위치 ON일 때만 연결. 순환·2중은 "?" 표시로 폴백 |
| S2 SQLite 스키마·Repository | DONE (2026-09-29) | `sqflite`+`sqflite_common_ffi`. 기존 JSON 저장과 완전 병행, 어떤 화면도 아직 미참조 |
| S3 엑셀 등록 시 날짜별 생성 | DONE (2026-09-29) | D1·D4·D5 확정 후 진행. `timetable_file_screen.dart` 등록 흐름에 부가 저장 훅 추가, 실패해도 기존 등록에 영향 없음 |
| S3a 준비>기타설정 학기 기간 반영 | DONE (2026-09-29) | 설계 리뷰 후 진행. `semester_period_section.dart` 신규 UI, `is_active` 컬럼으로 축소분 보관 |
| S4.0 읽기 전용 SQLite 확인 패널 | DONE (2026-09-29) | `dated_data_inspector_section.dart` 신규 UI, `getLessonStats` 집계 쿼리. 사용자 실 앱 확인 완료 |
| S4.1 학기 범위 판정 유틸 | DONE (2026-09-29) | `WeekSemesterStatusChecker` + `datedSemesterProvider`, 순수 로직만(연결 없음) |
| S4.2 교체 화면 범위 밖 주 안내 | DONE (2026-09-29) | `exchange_week_bar.dart`에 주황색 아이콘+강조 텍스트. 사용자 실 앱 확인 완료(가시성 피드백 반영) |
| S4.3 개인 시간표 동일 안내 | 보류 (2026-09-29) | 사용자가 "지금은 적용 안 함"으로 결정. 코드 변경 없음 |
| S4.4 드리프트 자가 점검 안내 | DONE (2026-09-29) | S4.0 패널에 "교체 이력 N건, SQLite 미반영" 한 줄 추가(최소 범위) |
| S5 설계 검토 | DONE (2026-09-29) | Opus 5 검토, OQ-1~8 전부 사용자 승인. 8단계(S5.0~S5.4b) 분해 확정 |
| S5.0 교체 이벤트 저널 스키마 | DONE (2026-09-29) | `exchange_events` 테이블(스키마 v2→v3) + Repository CRUD. 완전 비연결 |
| S5.1 이후 | TODO | 부가 기록 미러 쓰기부터 순서대로 진행. 지난 실패 구간과 겹침 — 특히 신중히 |

## 5. 다음에 할 정확한 작업

S1~S4(S4.0~S4.4), S5 설계 검토, S5.0까지 완료했다. 사용자가 실제 앱(Windows)에서 아래를 수동
확인한 뒤, S5.1(교체 실행·삭제·되돌리기 시 `exchange_events`에도 부가 기록 — JSON이 여전히 진실
원본)로 이어간다.

- 날짜표시 스위치 ON/OFF 전환
- 계획서에서 다른 주로 넘어가는 교체(결강일·교체일이 다른 주)를 만들고, 교체 화면에서 각 주로 이동해 반영 확인
- 원본/교체 스위치가 여전히 정상 동작하는지
- 순환·2중 교체의 "?" 표시
- "준비 > 기타 설정" 화면의 "학기 기간"·"날짜 기반 데이터 확인" 두 섹션이 정상 표시되는지
- 교체를 실제로 몇 건 실행한 뒤 "날짜 기반 데이터 확인" 패널의 "현재 교체 이력: N건" 문구가
  정확한 건수로 갱신되는지 (S4.4, 아직 미확인)
- 교체 화면에서 학기 범위 밖 주로 이동 시 주황색 안내가 뜨는지(S4.2, 확인 완료)

## 6. 기존 작업 트리 보호

`lib/assets/templates/substitution_plan_template.pdf`가 사용자에 의해 수정된 상태였을 수 있다.
사용자의 기존 변경으로 취급하고 무관한 커밋에 포함하지 않는다. 재개 시 실제 git status로 다시 확인한다.

## 7. 매 작업 단위 종료 시 갱신할 기록

### 7.1 최근 기록 (2026-09-29, S1·S1.5)

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S1 DONE, S1.5 DONE
현재 Git HEAD / 브랜치: main (커밋 미실행 — 사용자 확인 대기)
사용 모델: Claude Sonnet 5 (모델 전환 없음 — 두 단계 모두 전환 불필요 범위)
이번에 완료한 작은 작업:
  1) SchoolSemester/SemesterDateGenerator 순수 모델 추가 (S1)
  2) showWeekHeaderProvider 추가, 기본값 false로 헤더·주차 바 날짜 표시를 조건부화 (S1.5)
  3) OFF 모드 교체된 칸 날짜 꼬리표 오버레이 추가 (S1.5)
변경한 파일:
  신규 — lib/models/school_semester.dart, lib/utils/semester_date_generator.dart,
        lib/providers/show_week_header_provider.dart,
        test/models/school_semester_test.dart, test/utils/semester_date_generator_test.dart
  수정 — lib/ui/screens/exchange_screen/managers/grid_header_manager.dart,
        lib/ui/screens/exchange_screen/widgets/exchange_week_bar.dart,
        lib/ui/screens/exchange_screen/widgets/timetable_tab_content.dart,
        lib/ui/screens/exchange_screen.dart,
        lib/utils/timetable_data_source.dart,
        lib/ui/widgets/simplified_timetable_cell.dart
핵심 설계 결정과 근거:
  - 날짜표시는 기존 X/O 오버레이(cellStatusSymbolVisibilityProvider)와 별개 스위치로 분리 — 기존 기능 미변경
  - 날짜 꼬리표는 교체 이력을 다시 조회하지 않고 "선택 주 월요일 + 요일 오프셋"으로 계산
    (표시 중인 열이 곧 그 주의 실제 날짜이므로, S6 다른 주 지원 전까지는 정확함)
  - 툴바 폭 계산 로직(exchange_control_panel.dart)은 건드리지 않고 스위치를 exchange_week_bar.dart에 배치
실행한 검증 / 결과: flutter analyze(전체) 문제 없음, flutter test(전체 212개, 신규 16개 포함) 전부 통과
미실행 검증과 이유: 실제 Windows 데스크톱 앱 실행 후 스위치 수동 조작 확인 — 이 환경에서 GUI 조작 불가
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음 (전달된 요구사항은 모두 반영)
다음 작업 1개: 사용자의 수동 확인 후 S2(SQLite 스키마·Repository) 세부 항목 논의
```

### 7.2 최근 기록 (2026-09-29, S1.6~S1.10)

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S1.6 DONE, S1.7 DONE, S1.8 DONE, S1.9 DONE, S1.10 DONE
현재 Git HEAD / 브랜치: main (커밋 미실행 — 사용자 확인 대기)
사용 모델: 설계는 Claude Opus 5(서브에이전트), 구현은 Claude Sonnet 5. 계획대로 위험 구간(다른 주 교체
  반영 로직)만 Opus 5 설계 검토를 받고 구현은 Sonnet 5로 진행 — 모델 전환 판단 기준을 그대로 적용
이번에 완료한 작은 작업:
  1) 사용자 보고: 계획서에서 결강일과 교체일이 다른 주로 갈리는 교체가 "다른 주" 화면에 전혀 반영되지 않음
     + X/○ 하이라이트가 모든 주에 항상 표시됨(둘 다 같은 근본 원인)
  2) Opus 5 설계 검토(서브에이전트) 완료, 사용자와 5개 공개 질문(OQ-1~5) 확인 후 확정
  3) S1.6: ExchangeCellDates 순수 유틸 신설(참여 칸별 실제 날짜 매핑, 요일 불일치 가드),
     ExchangedCellOverlayDates·exchange_executor.dart 키 생성 로직이 여기 위임하도록 리팩터링
  4) S1.7: ResolvedWeek.dateAware 추가 (of/exchangePathMoves/_applyMove는 무변경)
  5) S1.8: exchange_view_provider(표시) + resolved_timetable_provider(검증) 둘 다 스위치 ON이면
     dateAware 사용하도록 연결 (사용자 확정: 이중배정 방지 위해 검증도 함께 고침)
  6) S1.9: X/○ 하이라이트도 같은 방식으로 주별 스코프, 주 이동·스위치 토글 시 재계산 트리거 추가
  7) S1.10: 순환·2중 교체는 "?" 표시로 폴백 (날짜 억지 추정 안 함), 툴팁에 설명 추가
변경한 파일:
  신규 — lib/utils/exchange_cell_dates.dart,
        test/utils/exchange_cell_dates_test.dart, test/utils/resolved_week_date_aware_test.dart
  수정 — lib/utils/exchanged_cell_overlay_dates.dart(위임으로 축소),
        lib/utils/resolved_week.dart(dateAware 추가),
        lib/ui/widgets/timetable_grid/exchange_executor.dart(키 생성 위임 + 주별 스코프 분기),
        lib/providers/exchange_view_provider.dart, lib/providers/resolved_timetable_provider.dart,
        lib/ui/screens/exchange_screen/widgets/timetable_tab_content.dart(재계산 트리거),
        lib/utils/timetable_data_source.dart("?" 마커),
        lib/ui/widgets/simplified_timetable_cell.dart(툴팁 설명)
핵심 설계 결정과 근거:
  - OFF 경로는 호출부에서만 분기하고 기존 함수(of/legacySourceKeys 등) 내부는 한 글자도 안 바꿈 — 이게
    회귀 안전성의 핵심(Opus 설계서 §4 "unchanged when OFF" 체크리스트를 그대로 따름)
  - 순환·2중 교체는 노드 3개 이상인데 저장된 날짜가 2개뿐이라 정확한 매핑 불가 → "?"로 명시,
    억지 추정하지 않음(2026-09-29 사용자 확정)
  - ON/OFF 전환 시 X/○ 표시 칸이 달라지는 것은 허용(2026-09-29 사용자 확정) — 서로 다른 관점이므로 정상
  - 검증(resolvedTimetableProvider)도 표시와 함께 이번에 고침(2026-09-29 사용자 확정) — 이중배정 위험 방지
  - 교체 화면에서 다른 주를 직접 선택해 새로 교체를 만드는 기능(D2)은 이번 범위 밖 — 계획서에서 날짜를
    수정해 다른 주로 보내는 기존 방법만 지원
실행한 검증 / 결과: flutter analyze(전체) 문제 없음, flutter test(전체 231개, 신규 15개 포함: S1.6 8개 +
  S1.7 7개) 전부 통과. 기존 resolved_week_test.dart·exchanged_cell_overlay_dates_test.dart 무수정 통과
미실행 검증과 이유: 실제 Windows 데스크톱 앱에서 다른 주 교체 시나리오·"?" 표시·원본/교체 스위치 수동 확인
  — 이 환경에서 GUI 조작 불가
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음 (OQ-1~5 모두 확인 완료)
다음 작업 1개: 사용자의 수동 확인 후 S2(SQLite 스키마·Repository) 세부 항목 논의, 또는 D2(교체 화면에서
  다른 주 직접 선택) 필요 여부 재확인
```

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S4.0·S4.1·S4.2 완료. Opus 검토로 S4를 S4.0~S4.4 + S5.5로 재설계(steps.md "S4
  재설계" 절 참조) — 문자 그대로의 "조회를 SQLite로 전환"은 S5.5로 미루고, 그 전에 검증 전용
  단계들을 먼저 진행하기로 사용자 승인받음.
현재 Git HEAD / 브랜치: main, S3a 이후 커밋 위(정확한 해시는 git log로 확인)
이번에 완료한 작은 작업:
  1) S4.0: TimetableRepository.getLessonStats() 추가(COUNT/MIN/MAX 집계 쿼리만 사용), 읽기 전용
     확인 패널 dated_data_inspector_section.dart 신규 작성 → 사용자가 실제 Windows 앱에서 확인 완료
  2) S4.0 버그 수정: "기타 설정" 펼칠 때 SegmentedButton assertion 예외 발생 — 원인은 S3a
     SemesterPeriodSection의 기존 버그(_isLoadingApplied 기본값 false로, 로드 전 첫 프레임에 draft가
     null인 채 편집기를 그림). _isLoadingApplied 기본값을 true로 수정, 사용자 재빌드로 확인 완료
  3) S4.1: WeekSemesterStatus 순수 유틸(week_semester_status.dart) + datedSemesterProvider
     (dated_semester_provider.dart) 신규 작성. 아직 어떤 위젯도 참조하지 않음.
  4) S4.2: exchange_week_bar.dart에 학기 범위 밖 주 안내 아이콘 1개 연결 — 날짜표시 ON이면서
     선택된 주가 beforeRange/afterRange일 때만 표시, 클릭 동작 없는 툴팁 아이콘(OQ-2/3/5 반영)
변경한 파일:
  신규 — lib/ui/screens/start_content/dated_data_inspector_section.dart,
        lib/utils/week_semester_status.dart, lib/providers/dated_semester_provider.dart,
        test/utils/week_semester_status_test.dart
  수정 — lib/repositories/timetable_repository.dart(LessonStats + getLessonStats),
        lib/data/timetable_database.dart(defaultDatabasePath 공개),
        lib/ui/screens/start_content/start_settings_card.dart(패널 배치),
        lib/ui/screens/start_content/semester_period_section.dart(_isLoadingApplied 기본값 버그 수정),
        lib/ui/screens/exchange_screen/widgets/exchange_week_bar.dart(안내 아이콘 추가),
        test/repositories/timetable_repository_test.dart(getLessonStats 테스트 3개 추가)
핵심 설계 결정과 근거:
  - 집계는 반드시 COUNT(*)/MIN/MAX 쿼리로만 — 수천 행을 Dart 메모리로 올리지 않는다(Opus 설계 그대로)
  - S4.0 패널은 철저히 읽기 전용 — 값 수정은 여전히 SemesterPeriodSection의 역할
  - WeekSemesterStatusChecker는 semester가 null이면 항상 unknown — "범위를 모른다"와 "범위 밖이다"를
    구분해, 날짜 데이터 없는 시간표를 실수로 "범위 밖"으로 표시하지 않는다
  - S4.2 아이콘은 날짜표시 OFF일 때 항상 숨김(OQ-5) — 클릭 동작·다이얼로그 없는 툴팁 아이콘뿐(OQ-2) —
    학기 범위는 SQLite DatedTimetable.semester 기준(OQ-3), 승인된 Opus 권장안 그대로
  - 어떤 기존 조회 경로(교체 화면 그리드·개인 시간표)도 아직 SQLite를 읽지 않음 — 전환은 S5.5까지 없음
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 269개 통과(S4.0 신규 3개 + S4.1 신규 7개, S4.2는 순수 로직 기존 테스트로 커버).
  사용자가 실제 Windows 앱에서 S4.0 패널 표시값이 DB 실제 내용과 일치함을 확인, "기타 설정" 예외도
  수정 후 재빌드로 해소 확인.
미실행 검증과 이유: S4.4 안내 문구가 실제 앱에서 정확한 건수로 뜨는지(교체 실행 후 재확인)만
  아직 수동 확인 전 — 사용자 확인 필요. 나머지는 모두 확인 완료.
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음. S4.3(개인 시간표에도 동일 안내 적용, OQ-4)은 사용자가 "지금은 적용
  안 함"으로 확정, 코드 변경 없이 보류.
다음 작업 1개 (파일/함수/기대 결과): S4(S4.0~S4.4) 전체 완료. 다음은 S5(교체 실행·되돌리기를 날짜
  기반 저장으로 전환) 착수 여부를 사용자와 확인 — 이 구간은 이전 실패(c4867cf)와 겹치므로 S1.6~S1.10·
  S3a처럼 Opus 설계 리뷰를 먼저 거친 뒤 사용자 승인을 받고 세부 단계로 쪼개 진행한다.
```

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S4 전체(S4.0~S4.4) 완료 뒤 S5 착수. S5 Opus 설계 검토 완료, OQ-1~8 전부
  사용자 승인("전체적으로 진행해줘"). S5.0(저널 스키마+Repository, 완전 비연결) 구현 완료.
현재 Git HEAD / 브랜치: main, S4 완료 커밋 위(정확한 해시는 git log로 확인)
사용 모델: 설계는 Claude Opus 5(서브에이전트), 구현은 Claude Sonnet 5 — 위험 구간 진입 시
  선례(S1.6~S1.10, S3a, S4 재설계)와 동일한 모델 전환 판단 기준 적용
이번에 완료한 작은 작업:
  1) S5 설계 검토: Opus 서브에이전트가 "이벤트 저널 + 파생 투영" 방식을 권장(직접 행 뒤집기 방식은
     c4867cf와 같은 실패 패턴이라 기각). ExchangeHistoryService 소비자 30여 곳 전수 조사, 죽은 코드
     PersonalExchangeViewManager 발견(재연결 금지 결정), 개인 시간표는 loadPlanData() 경로로 보호됨을 확인.
     S5.0~S5.4b 8단계 분해 + OQ-1~8 제시, 사용자가 전부 권장안대로 승인
  2) S5.0: exchange_events 저널 테이블 신설(스키마 v2→v3), TimetableRepository에 CRUD 추가.
     ExchangeEventRecord.pathJson은 ExchangePath.toJson()과 같은 포맷 재사용(직렬화기 이원화 금지)
변경한 파일:
  신규 — lib/models/exchange_event_record.dart
  수정 — lib/data/timetable_database.dart(스키마 v3, exchange_events 테이블),
        lib/repositories/timetable_repository.dart(upsertExchangeEvents/getExchangeEvents/
        deleteExchangeEventsFor, deleteTimetable에 저널 삭제 포함),
        test/repositories/timetable_repository_test.dart(교체 이벤트 저널 테스트 6개 추가)
핵심 설계 결정과 근거:
  - 진실 원본은 항상 하나: exchange_events(저널). lessons는 그 저널을 재생해 만드는 파생 뷰일 뿐,
    직접 UPDATE하는 코드 경로를 두지 않는다(S5 전체 기간 동안 지킬 불변 조건)
  - ExchangeHistoryService의 동기 public API 시그니처를 동결한다 — 이미 있는 비동기 저장 큐
    뒤쪽에만 SQLite 미러 쓰기를 추가해 30여 곳의 동기 소비자를 무변경으로 지킨다(S5.1에서 실행)
  - upsertExchangeEvents는 ConflictAlgorithm.replace로 멱등 — 기존 JSON "전체 다시 쓰기"와 같은 성질
  - S5.0 시점에는 어떤 화면·서비스도 이 테이블을 참조하지 않음 — 순수 추가라 회귀 위험 없음
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 275개 통과(신규 6개: seq 순서 조회, upsert 멱등성, 시간표 간 격리,
  deleteExchangeEventsFor, deleteTimetable 연쇄 삭제, 저장·조회 왕복 보존)
미실행 검증과 이유: 스키마 마이그레이션(v2→v3) 자체는 별도 테스트하지 않음 — 기존 v1→v2도 같은
  방식으로 테스트 없이 진행된 전례를 따름. 이 단계는 화면 동작이 전혀 바뀌지 않아 사용자 수동
  확인은 필요 없음.
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음 (OQ-1~8 모두 확인 완료)
다음 작업 1개 (파일/함수/기대 결과): S5.1 — ExchangeHistoryService에 선택적 보조 싱크(mirrorSink)를
  주입해, 교체 실행·삭제·되돌리기·다시실행·날짜 수정 시 exchange_events에도 부가 기록되도록 연결.
  JSON이 여전히 진실 원본이며 loadFromLocalStorage()는 그대로 JSON에서만 읽는다. 완료 조건: 교체
  실행/되돌리기/삭제/날짜 수정 후 exchange_events 행이 메모리 리스트와 1:1 일치(테스트), 기존 JSON
  파일 내용이 S5.1 이전과 바이트 동일함을 확인, 실제 앱에서 기존 기능 전부 정상.
```

## 8. 새 AI에게 전달할 재개 문구

```text
docs/date_based_timetable_handoff.md와 docs/date_based_timetable_steps.md를 읽고
날짜 기반 시간표 전환 작업의 현재 상태를 확인해주세요.
이전 시도(c4867cf)가 기존 기능을 손상시켜 되돌려졌으므로, 이번에는 작은 단위로 쪼개
매 단계 기존 기능 회귀를 검증하며 진행합니다. 1단계는 UI·저장소와 연결하지 않는
순수 날짜 데이터 모델부터 시작합니다.
사용자가 구현을 지시한 경우에만 다음 미완료 단계부터 이어가세요.
```
