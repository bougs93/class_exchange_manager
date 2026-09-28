# 날짜 기반 시간표 전환 진행 기록·인수인계

최종 갱신: 2026-09-29
현재 상태: IN_PROGRESS — S1·S1.5 구현 완료, S2 이후 미착수
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
| S2 이후 | TODO | 착수 직전 사용자와 세부 확정 |

## 5. 다음에 할 정확한 작업

S1·S1.5는 완료했다. 다음은 사용자가 실제 앱(Windows)에서 날짜표시 스위치를 켜고 끄며 수동 확인한 뒤,
S2(SQLite 스키마·Repository, 기존 JSON과 병행)부터 이어간다. 착수 전 세부 항목을 사용자와 다시 확정한다.

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

```text
갱신 시각:
현재 단계와 상태:
현재 Git HEAD / 브랜치:
이번에 완료한 작은 작업:
변경한 파일:
핵심 설계 결정과 근거:
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오):
미실행 검증과 이유:
남은 실패 또는 컴파일 오류:
사용자 답변이 필요한 항목:
다음 작업 1개 (파일/함수/기대 결과):
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
