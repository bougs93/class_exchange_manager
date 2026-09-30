# 날짜 기반 시간표 전환 진행 기록·인수인계

최종 갱신: 2026-09-30
현재 상태: IN_PROGRESS. **S1~S5(S5.0~S5.4b)까지 전부 완료, 사용자 최종 확인 완료** — SQLite가
실제 진실 원본 역할을 하고 있음이 검증됨. 상세 이력은 steps.md의 각 단계 절 참조.

**S5.5(조회를 SQLite로 전환)**: 6단계 중 S5.5.0~S5.5.4 코드 구현 전부 완료, S5.5.2 필수
게이트("불일치 0칸")도 사용자 확인 완료. S5.5.4 실 앱 테스트 중 발견된 버그(`WeekLessonsCache`가
교체 이력 변경 시 무효화 안 되던 문제)는 수정 완료·재현 테스트로 확인됨. 같은 테스트 중 발견된
별개의 기존 버그(계획서 화면이 되돌린 교체를 계속 표시 — S5.5와 무관, `SubstitutionPlanViewModel`의
필터 누락)도 수정·확인 완료. **남은 것은 S5.5.4의 나머지 회귀 체크리스트**(OFF 모드 불변조건,
주 이동, 시간표 전환 시 캐시 정리, S3 이전 시간표, PDF·개인 시간표 비영향)뿐 — 문제 있으면
스위치를 꺼서 즉시 기존 방식으로 되돌릴 수 있다.

**S5.6(순환·2중 교체의 노드별 날짜 확정) — 전체 완료.** S5.5.4 테스트 중 사용자가 "계획서에서
지정한 날짜가 교체 화면에 반영되지 않는다"를 발견 → Opus 설계 검토 → 사용자가 "실제로
반영되게 한다"(큰 변경)를 선택해 착수. **S5.6.0~S5.6.8 전부 완료 — 실 앱 확인까지 끝났고,
플래그도 기본 ON으로 전환됐다.** 데이터 모델·SQLite 미러·판단 로직·조회 세분화·저장 메서드·
계획서 화면 표시·실제 쓰기 연결·실행 시점 자동 확정까지 전부 이어졌다. 이 단계의 최대
위험이던 R7(2중 교체가 서로 다른 주로 갈릴 때 `project()`↔`dateAware` 등식이 깨질 위험)은
실제 다주 픽스처로 시험한 결과 **깨지지 않음을 확인** — 순환·2중 모두 제한 없이 지원.
S5.6.7 도중 "?"가 재현되는 문제가 있었으나 원인은 코드가 아니라 hot restart가 세션 전용
플래그를 초기화하는 것이었음을 진단 로그로 확인·해결. 이제 순환·2중 교체를 실행하면
**기본적으로** 참여 칸 날짜가 즉시 확정되고 "?" 없이 표시된다 — 문제가 있으면 S4.0 패널
에서 스위치를 꺼서 재빌드 없이 즉시 예전 방식으로 되돌릴 수 있다.
S5.6.5~S5.6.6는 `nodeDateEditEnabledProvider`(기본 OFF, S4.0 패널에 토글 추가)로 감쌌다.

**S5.6.7(추가, 2026-09-30)**: 사용자가 실 앱 확인 중 "순환·2중을 실행하면 계획서에 날짜가
자동으로 뜨는데 왜 교체 화면은 '?'냐"고 지적, Sonnet의 설명("계획서는 추정일 뿐")을
거부하고 Opus 재검토를 요청. **Opus 진단: 사용자가 맞았다** — 교체 실행기는 각 노드의
실제 날짜를 이미 정확히 계산하는데, 그 값을 기록하지 않고 나중에 같은 식으로 재추정해
"?"를 띄우고 있었다. **수정**: 실행기(`ExchangeExecutor.executeExchange`)가 실행 시점에
`seedNodeDatesForWeek()`로 참여 노드 전부의 날짜를 `nodeDates`에 즉시 기록하도록 연결
(플래그 게이팅, 기존 테스트 0건 수정). **재현 테스트에서 처음엔 여전히 "?"가 떠 진단
로그로 조사 — 원인은 코드가 아니라 Flutter hot restart가 세션 전용 플래그(이 스위치
포함)를 매번 초기화하는 것이었다.** 재시작 없이 스위치를 켠 직후 실행하니 정상 동작
확인 완료("정상 동작하는 것 같습니다"), 진단 로그 제거. **S5.6.0~S5.6.7 전 단계 실 앱
확인까지 완료.**

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
| S5.1 부가 기록 미러 쓰기 | DONE (2026-09-29) | `ExchangeHistoryService.mirrorSink`/`mirrorClearSink` 훅. 동기 API 무변경, JSON이 여전히 진실 원본. 사용자 실 앱 확인 완료 |
| S5.2 드리프트 실제 비교 | DONE (2026-09-29) | 확인 패널에 "JSON N건 · SQLite M건 · 일치/불일치" 표시 + 새로고침 |
| S5.1 보완: 로드 시 미러 동기화 | DONE (2026-09-29) | 사용자가 S5.2에서 "불일치" 발견 → loadFromLocalStorage() 직후 1회 미러 추가로 수정. 재확인이 S5.3 게이트 |
| S5.3 투영 순수 함수 검증 | DONE (2026-09-29) | `lesson_projection.dart`의 `project()`가 `ResolvedWeek.dateAware`와 등식으로 일치함을 증명(6개 시나리오). DB 미기록, 화면 무변화 |
| S5.4 되돌리기 의존성 경고 | DONE (2026-09-29) | `exchange_dependency_checker.dart` 신규, `undoLastExchange`에 비차단 스낵바 안내만 추가(D6/OQ-2). 되돌리기 로직 자체 무변경 |
| S5.4a lessons 투영 실제 기록 | DONE (2026-09-29) | `TimetableRepository.replayInto` 신규, S5.1 훅 2곳(mirrorSink/mirrorClearSink)에 이어붙임. OQ-7(기간 축소 충돌 차단) 구현 |
| S5.4a 성능 수정 (1차) | DONE (2026-09-29) | 스냅샷 템플릿 캐싱 + 500건마다 양보. 사용자 재확인 결과 체감 개선 부족 |
| S5.4a 성능 수정 (2차) | DONE (2026-09-29) | `dirty_lesson_keys`(스키마 v5)로 "건드린 좌표만" 재계산하도록 재설계. 부수적으로 삭제된 교체의 흔적이 안 지워지던 실제 정합성 버그도 발견·수정. 사용자 확인 완료 — 지연 증상 사라짐 |
| S5.4b 저널을 SQLite에서 읽기 | **DONE — 최종 확인 완료 (2026-09-29)** | `loadSink` 추가 — SQLite에 저널 있으면 그걸로, 없으면 JSON 폴백+자동 1회 이관. "여기서부터 신규가 진실 원본". 재시작 후에도 교체 이력 유지됨을 사용자가 확인 |
| S5.5 설계 검토 | DONE (2026-09-29) | Opus 5 검토, "오버레이" 전략 채택, 6단계(S5.5.0~S5.5.5) 분해. 사용자 승인("이 설계대로 진행 (권장)") |
| S5.5.0 조회 헬퍼(비연결) | DONE (2026-09-29) | `getProjectionStatus`/`getTouchedLessonsForWeek` 추가. 완전 비연결, 신규 테스트 6개 |
| S5.5.1 `ResolvedWeek.fromLessons`(비연결) | DONE (2026-09-29) | 오버레이 어댑터 신규. S5.3 픽스처로 `dateAware`와 동등성 증명, 신규 테스트 6개 |
| S5.5.2 섀도우 비교 패널 | **DONE — 사용자 게이트 통과 (2026-09-29)** | S4.0 패널에 "지금 확인" 버튼. 화면 합성(`resolved_timetable_provider`와 동일 로직) vs SQLite(`fromLessons`) 칸별 비교. 사용자가 순환·2중 포함 4건으로 "불일치 0칸" 확인 |
| S5.5.3 프리페치 캐시(비연결) | DONE (2026-09-29) | `WeekLessonsCache`(`ensureLoaded`/`lessonsFor` 2단계 패턴) + `ExchangeHistoryService.flushPendingWrites()` + `lessonReadPathEnabledProvider`(기본 OFF). 신규 테스트 5개(재생 밀림 자동 복구 포함) |
| S5.5.4 실제 조회 전환(기본 OFF) | **코드 완료, 버그 1건 발견·수정·재현 테스트로 확인 완료** | `resolved_timetable_provider`·`exchange_view_provider` 둘 다 ON 모드에서만 SQLite 오버레이 경로 연결(캐시 미준비 시 자동 `dateAware` 폴백). OFF 모드는 무조건 기존 `of()`. S4.0 패널에 롤백 스위치 추가. 2026-09-30: 캐시가 교체 이력 변경 시 무효화되지 않던 버그를 사용자가 발견 → `exchangeListVersionProvider` 구독 추가로 수정, 사용자가 재현 테스트로 정상 동작 확인. 신규 테스트 3개 |
| (별개) 계획서 화면이 되돌린 교체를 계속 표시 | **DONE — 사용자 확인 완료 (2026-09-30)** | S5.5와 무관한 기존 버그, 같은 테스트 중 발견. `SubstitutionPlanViewModel.loadPlanData()`가 `getActiveExchangeList()`를 쓰도록 수정. 신규 테스트 1개 |
| S5.6 설계 검토 | DONE (2026-09-30) | Opus 5 검토. `nodeDates` 데이터 모델 + 단일 판단 함수(`resolveEventDates`) + 6단계 분해. 사용자가 "실제 반영" 큰 옵션 선택 |
| S5.6.0 `nodeDates` 데이터 모델(비연결) | DONE (2026-09-30) | `ExchangeHistoryItem.nodeDates`/`supportsNodeDates`/`copyWithNodeDate`, `exchange_node_slot.dart`. 6개 `copyWith*` 전부 보존 처리. 신규 테스트 8개 |
| S5.6.1 SQLite `nodeDatesJson` 미러(비연결) | DONE (2026-09-30) | 스키마는 S5.0부터 이미 존재 — 미러 양방향 변환만 연결. 신규 테스트 4개 |
| S5.6.2 판단 로직 통합 + R7 게이트 | **DONE — R7 통과 (2026-09-30)** | `event_date_resolver.dart` 신설, `lesson_projection`·`resolved_week.dateAware` 전환. 2중 교체가 다른 주로 갈려도 `project ≡ dateAware` 등식이 깨지지 않음을 실제 픽스처로 확인 — 순환·2중 제한 없이 지원 확정. 신규 테스트 11개 |
| S5.6.3 `forWeek` 노드 단위 세분화 | DONE (2026-09-30) | 확정 노드는 실제 주에만 스코프, "?"에서 제외. `legacySourceKeys`/`legacyDestinationKeys` 무변경 유지(등식 테스트로 고정). 신규 테스트 5개 |
| S5.6.4 `updateNodeDate` 저장 메서드(비연결) | DONE (2026-09-30) | 가드 2개(순환·2중 전용, 요일 일치). 기존 배선(`_notifyVersionChanged` 등) 재사용, 새 훅 0개. 신규 테스트 5개 |
| S5.6.5 계획서 화면 표시 전환 | DONE (2026-09-30) | `nodeDateEditEnabledProvider` 신설(기본 OFF). `_handleCircularExchange`/`_handleDualExchange`가 확정 노드는 확정값, 미확정은 슬롯 요일에 맞는 추정값을 보여줌. 신규 테스트 3개 |
| S5.6.6 실제 쓰기 경로 연결 | DONE (2026-09-30) | `content_input_grid.dart`의 날짜 선택기가 순환·2중+플래그 ON일 때 `updateNodeDate` 호출(가드 걸리면 기존 `updateDates`로 폴백). S4.0 패널에 토글 추가 |
| S5.6.7 실행 시점 노드 날짜 자동 확정 | **DONE — 사용자 실 앱 확인 완료 (2026-09-30)** | 사용자가 "실행하면 이미 자동 배정되는데 왜 ?냐" 지적 → Opus 진단(사용자가 맞음, 아는 값을 기록 안 하고 있었음) → `ExchangeExecutor`가 실행 시점에 `seedNodeDatesForWeek()`로 즉시 기록하도록 연결(플래그 게이팅). 기존 테스트 0건 수정, 신규 13개. 재현 테스트 중 "?" 재발 → 진단 로그로 원인이 hot restart의 세션 플래그 초기화임을 확인(코드 버그 아님) → 재확인 완료, 로그 제거 |
| S5.6.8 플래그 기본 ON 전환 | **DONE (2026-09-30) — S5.6 전체 완료** | `nodeDateEditEnabledProvider` 기본값 false→true. S4.0 패널 토글 라벨·강조 색상 갱신(꺼짐이 이제 "예전 방식으로 되돌림"이라 강조 대상). 기본값 의존 테스트 1건 명시적 설정으로 수정, 나머지 무수정. `flutter test` 377개 전체 통과 |

## 5. 다음에 할 정확한 작업

**S1~S5(S5.0~S5.4b) 전체가 완료됐다** — 기존 JSON 교체 이력이 그대로 보이는 것과, 앱을
재시작해도 교체 이력이 유지되는 것(SQLite가 실제 진실 원본이 됐다는 핵심 증거)을 사용자가 확인
완료했다.

**S5.5(조회를 SQLite `lessons`로 실제 전환)** — Opus 설계 검토·사용자 승인 완료, 6단계 중
S5.5.0~S5.5.4 코드 구현 전부 완료, S5.5.2 필수 게이트("불일치 0칸")도 사용자 확인 완료.
S5.5.4 실 앱 테스트 중 캐시 무효화 버그를 발견·수정, 사용자 재현 테스트로 정상 동작 확인
완료. 같은 테스트 중 발견된 별개 버그(계획서가 되돌린 교체를 계속 표시)도 수정·확인 완료.
**남은 것은 S5.5.4의 나머지 회귀 체크리스트뿐**(OFF 모드 불변조건, 셀 단위 정확성, 주 이동,
범위 밖 주, 교체불가 셀 스타일, 시간표 전환 시 캐시 정리, S3 이전 시간표, PDF·개인 시간표
비영향) — S5.5.5(롤백 토글)는 S5.5.4에서 이미 선반영 완료.

**완료: S5.6(순환·2중 교체의 노드별 날짜 확정)** — S5.5.4 확인 중 사용자가 "계획서에서
지정한 날짜가 교체 화면에 반영 안 됨"을 발견 → Opus 설계 검토 → 사용자가 "실제로 반영되게
한다"(큰 변경)를 선택. 상세 설계는 steps.md의 "S5.6 설계 검토" 절 참조.

- S5.6.0 (`ExchangeHistoryItem.nodeDates` 데이터 모델, 비연결) — **완료**
- S5.6.1 (SQLite `nodeDatesJson` 양방향 미러, 스키마 변경 없음) — **완료**
- S5.6.2 (`event_date_resolver.dart` 신설 + `lesson_projection`·`resolved_week.dateAware`
  전환) — **완료. R7(2중 등식) 게이트 통과** — 2중 교체가 서로 다른 주로 갈려도
  `project() ≡ dateAware`가 깨지지 않음을 실제 다주 픽스처로 확인, 순환·2중 모두 제한 없이
  지원하기로 확정(OQ-9 해소)
- S5.6.3 (`ExchangeCellDates.forWeek`를 노드 단위로 세분화) — **완료**. 확정 노드는 실제
  주에만 스코프되고 "?"에서 빠짐, 미확정 노드는 기존과 동일하게 항상 표시+"?"
- S5.6.4 (`ExchangeHistoryService.updateNodeDate` 저장 메서드, 가드 2개) — **완료**
- S5.6.5 (계획서 화면 표시를 노드 기준으로 전환) — **완료**. `nodeDateEditEnabledProvider`
  (기본 OFF) 신설, 확정 노드는 확정값·미확정은 슬롯 요일에 맞는 추정값 표시
- S5.6.6 (날짜 선택기가 실제로 `updateNodeDate`를 호출하도록 연결) — **완료.**
  `content_input_grid.dart`의 `_applyDateSelection`이 순환·2중+플래그 ON일 때 그 행의
  노드에만 저장(가드 걸리면 기존 `updateDates`로 폴백). S4.0 패널에 토글 추가
- S5.6.7 (실행 시점 노드 날짜 자동 확정, Opus 재검토 반영) — **완료, 사용자 실 앱 확인
  완료.** `ExchangeExecutor.executeExchange`가 실행 시점에 `seedNodeDatesForWeek()`로
  참여 노드 전부를 즉시 `nodeDates`에 기록(플래그 게이팅, 기존 테스트 0건 수정). 재현
  테스트에서 "?"가 재발했으나 진단 로그로 **hot restart가 세션 전용 플래그를 초기화하는
  것**(코드 버그 아님)임을 확인 — 재시작 없이 재확인해 정상 동작 확인 완료
- S5.6.8 (플래그 기본 ON 전환 + 문서 정리) — **완료.** `nodeDateEditEnabledProvider` 기본값
  true로 전환, S4.0 패널 토글 문구·강조 색상 갱신(이제 "꺼짐"이 예외 상태). 기본값에 의존
  하던 테스트 1건만 명시적 설정으로 수정, 나머지 무수정.
- **S5.6(S5.6.0~S5.6.8) 전 단계 완료.** 순환·2중 교체는 이제 실행하는 순간부터 날짜가
  자동 확정되며, 계획서 화면에서 개별 노드 날짜를 수동으로 다시 지정할 수도 있다. 문제가
  생기면 S4.0 패널의 스위치를 꺼서 재빌드 없이 즉시 예전 방식(순환·2중은 항상 "?")으로
  되돌릴 수 있다.
- **참고(세션 전용 플래그 공통 주의사항)**: 이 프로젝트의 실험용 스위치(`nodeDateEditEnabledProvider`,
  `lessonReadPathEnabledProvider` 등)는 전부 세션 메모리에만 저장된다. **코드 수정 후 hot
  restart를 하면 매번 기본값으로 돌아가므로, 재시작 직후에는 원하는 스위치 상태를 다시
  맞춰야 한다** — S5.6.7 확인 중 이것 때문에 상당한 시간 동안 "버그"로 오인해 조사했다.

S5.5.0 구현 중 발견한 실제 버그(SQLite에서 곧바로 이력을 불러오는 시간표는 로드 시 `replayInto`를
타지 않아 `lessons`가 재생 안 된 채로 남을 수 있음)는 **S5.5.3의 `WeekLessonsCache.ensureLoaded`가
`getProjectionStatus`로 감지해 `replayInto`를 자동 재시도하는 것으로 해소됐다**(회귀 테스트로
검증 완료). S5.5.4에서 이 캐시를 통해서만 읽도록 연결하면 이 간극이 실제로 막힌다.

**우선순위 낮음(선택, 아직 안 함)**:
- 교체를 여러 건 실행한 뒤 "날짜 기반 데이터 확인" 패널(S4.0)에서 lessons 내용이 실제로
  바뀌었는지 (S5.4a) — 패널이 개별 셀 내용까지는 안 보여주므로 DB 파일을 직접 열어봐야 할 수 있음

**완료·종결된 항목** (더 이상 확인 불필요):
- OQ-7(학기 기간 축소 충돌 차단) — 확인 완료
- 성능 수정(건드린 좌표만 재계산) — 확인 완료, 지연 증상 사라짐
- 되돌리기 의존성 경고(D6/OQ-2) — UI 구조상 검증 불가로 판정, 로직은 유닛 테스트로 검증됨. 이미
  교체된(X 표시) 칸은 재선택이 안 되는 기존 보호장치 때문에 의존 상황 자체가 안 만들어짐
- 원본/교체 토글 — 재현 실패, 사용자가 "정상"으로 확인
- 날짜표시 스위치, 순환·2중 교체 "?" 표시, 학기 범위 밖 주 안내(S4.2) 등 — 기존 확인 완료

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

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S5.0에 이어 S5.1(부가 기록 미러 쓰기) 완료. JSON이 여전히 진실 원본.
현재 Git HEAD / 브랜치: main, S5.0 완료 커밋 위(정확한 해시는 git log로 확인)
이번에 완료한 작은 작업:
  1) lib/services/exchange_event_mirror.dart 신규: toExchangeEventRecords() 순수 변환 함수
     (ExchangeHistoryItem 목록 → ExchangeEventRecord 목록, seq는 목록 순서 그대로)
  2) TimetableRepository.replaceExchangeEventsFor() 추가 — 삭제 후 삽입을 한 트랜잭션으로 묶어
     JSON의 "리스트 전체 다시 쓰기"와 같은 멱등 의미론 재현(삭제된 교체 건이 저널에 안 남게)
  3) ExchangeHistoryService에 mirrorSink/mirrorClearSink 필드 추가(기본 null), 기존 저장 큐
     (_enqueueStorageOperation) 뒤쪽에만 훅 추가 — 동기 public API 시그니처 무변경
  4) services_provider.dart의 exchangeHistoryServiceProvider에서 두 싱크를 TimetableRepository에
     연결. resetForTesting()에도 두 싱크 초기화 추가(싱글톤 테스트 오염 방지)
변경한 파일:
  신규 — lib/services/exchange_event_mirror.dart, test/services/exchange_event_mirror_test.dart
  수정 — lib/repositories/timetable_repository.dart(replaceExchangeEventsFor),
        lib/services/exchange_history_service.dart(mirrorSink/mirrorClearSink 필드+훅,
        resetForTesting 확장),
        lib/providers/services_provider.dart(싱크 주입),
        test/repositories/timetable_repository_test.dart(replaceExchangeEventsFor 테스트 3개)
핵심 설계 결정과 근거:
  - JSON 저장이 먼저 큐에 들어가고 그 "직후 같은 큐"에 미러 쓰기를 추가 — 순서는 보장되지만
    미러가 실패해도(sink==null 포함) JSON 저장에는 전혀 영향 없음(S5 설계 검토 R3 대응)
  - replaceExchangeEventsFor(삭제 후 삽입)를 새로 만든 이유: S5.0의 upsertExchangeEvents는 갱신만
    하고 삭제된 항목을 못 지우므로, removeFromExchangeList로 삭제된 건이 저널에 유령으로 남는
    문제가 있었음 — 완전 교체 방식으로 해결
  - ExchangeHistoryService가 싱글톤이라, 위젯 테스트가 Provider 트리를 먼저 빌드하면 mirrorSink가
    전역으로 남아 이후 순수 유닛 테스트를 오염시킬 수 있음을 미리 인지하고 resetForTesting()에서
    방어(실제로는 현재 어떤 테스트도 exchangeHistoryServiceProvider를 빌드하지 않아 당장 문제는 없음)
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 283개 통과(신규 8개: exchange_event_mirror_test 5개 + replaceExchangeEventsFor
  3개). 기존 exchange_history_service_test.dart·모든 위젯 테스트 무수정 통과(mirrorSink 주입이
  위젯 테스트를 깨지 않음을 확인)
미실행 검증과 이유: 실제 앱에서 교체를 실행한 뒤 SQLite exchange_events에 실제로 행이 쌓이는지
  수동 확인 — 이 환경에서 GUI 조작 불가, 사용자 확인 필요. (S4.0/S4.4 패널에는 아직 저널 건수를
  보여주는 UI가 없음 — 이는 S5.2에서 추가 예정)
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음
다음 작업 1개 (파일/함수/기대 결과): S5.2 — dated_data_inspector_section.dart(S4.0/S4.4 패널)의
  드리프트 안내를 "교체 이력: JSON N건 / SQLite 저널 M건 / 불일치 K건"으로 확장. TimetableRepository
  .getExchangeEvents(timetableId).length를 새로 노출해 JSON 쪽 건수(exchangeHistoryServiceProvider
  .getActiveExchangeList().length)와 비교, 불일치 시 S4.2와 같은 주황색 강조. 완료 조건: 사용자가
  실제 앱에서 교체 여러 건 실행·되돌리기 후 N==M, K==0을 눈으로 확인 — 이 확인이 S5.3 진입 게이트.
```

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S5.1에 이어 S5.2(드리프트 실제 비교) 완료. 사용자가 S5.1 수동 회귀 확인도
  완료("테스트 했습니다"). S5.2 자체의 화면 확인(일치 표시)은 아직 사용자 확인 전 — S5.3 게이트.
현재 Git HEAD / 브랜치: main, S5.1 완료 커밋 위(정확한 해시는 git log로 확인)
이번에 완료한 작은 작업:
  1) dated_data_inspector_section.dart의 드리프트 안내를 실제 비교로 확장 — "교체 이력: JSON N건
     · SQLite 저널 M건 · 일치/불일치 K건". 불일치 시 S4.2와 같은 주황색 강조(테두리+굵은 글씨)
  2) _load()에서 TimetableRepository.getExchangeEvents(timetableId) 함께 조회, is_reverted=0인
     건수만 카운트(JSON의 getActiveExchangeList()와 기준 통일)
  3) 새로고침 아이콘 추가 — SQLite 쪽 값은 실시간 반응하지 않고(미러 쓰기가 비동기 큐라 순간적
     불일치가 정상일 수 있음) 사용자가 명시적으로 다시 셀 수 있게 함
변경한 파일:
  수정 — lib/ui/screens/start_content/dated_data_inspector_section.dart(_sqliteEventCount 필드,
        _buildDriftNotice 재작성)
핵심 설계 결정과 근거:
  - JSON은 실시간(exchangeListVersionProvider watch), SQLite는 스냅샷 — 두 값이 잠깐 다르게 보이는
    것과 "진짜 드리프트"를 구분하기 위해 새로고침을 명시적으로 뒀다(자동 폴링 등 복잡한 로직 안 씀)
  - 이 단계는 새 Repository 로직을 추가하지 않았다 — S5.0/S5.1에서 이미 검증된
    getExchangeEvents/getActiveExchangeList를 화면에서 조합해 보여줄 뿐이라 신규 테스트 없음
  - 여전히 읽기 전용, 쓰기 버튼 없음
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 283개 통과(회귀 없음, 신규 로직 없어 신규 테스트도 없음)
미실행 검증과 이유: 실제 앱에서 교체를 여러 건 실행·되돌리기한 뒤 "일치"로 표시되는지, 새로고침이
  잘 동작하는지 수동 확인 — 이 환경에서 GUI 조작 불가, 사용자 확인 필요. **이 확인이 S5.3 진입
  게이트**(불일치가 계속 보이면 S5.1 미러 쓰기 버그를 먼저 고쳐야 함)
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음
다음 작업 1개 (파일/함수/기대 결과): 사용자가 위 확인을 마친 뒤 S5.3 — lib/utils/lesson_projection.dart
  신규 작성. project({snapshot, semester, activeEvents}) 순수 함수로 exchangePathMoves/
  ExchangeCellDates.forItem을 재사용해 lessons 목록에 이벤트를 적용한 결과를 계산(DB에는 쓰지 않음).
  핵심 회귀 테스트: 임의의 주 W에 대해 project(...)를 W로 필터한 결과 == ResolvedWeek.dateAware(...)
  .toTimeSlots(...)가 성립함을 증명(1:1·보강·같은 주·다른 주·요일 불일치 폴백 전 케이스, 기존
  10.14/10.26 픽스처 재사용). 완료 조건: 이 등식 테스트 전부 통과, 화면 동작은 여전히 무변화.
```

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S5.2 실제 앱 확인 중 사용자가 "불일치" 발견 → 원인 조사·수정 완료(S5.1 보완).
  재빌드 후 재확인 대기 중 — 이것이 S5.3 진입 게이트.
현재 Git HEAD / 브랜치: main, S5.2 완료 커밋 위(정확한 해시는 git log로 확인)
이번에 완료한 작은 작업:
  1) 사용자 보고: S5.2 패널이 "JSON 2건 · SQLite 저널 0건 · 불일치 2건"으로 표시됨
  2) 원인 조사: ProviderContainer + 인메모리 DB로 실제 서비스 배선(exchangeHistoryServiceProvider
     + timetableRepositoryProvider)을 그대로 재현하는 디버그 테스트 작성·실행 — mirrorSink는
     "새로 저장할 때"만 호출되므로, mirrorSink가 붙기 전부터 JSON에 있던 이력은 loadFromLocalStorage()
     로만 메모리에 올라올 뿐 SQLite에 한 번도 안 쓰였음을 확인. 같은 테스트에서 "새 교체를 1건 더
     실행"하면 그 순간 메모리 전체 리스트가 다시 저장되며 기존 것까지 SQLite에 나타남도 확인(자연
     치유되는 구조였음 — 버그라기보다 "즉시 동기화가 안 된 것"에 가까움)
  3) 수정: loadFromLocalStorage()가 JSON 로드를 마친 직후 한 번 mirrorSink를 호출해 방금 불러온
     전체 목록을 SQLite에도 즉시 밀어 넣도록 보완. 같은 저장 큐 뒤쪽에만 붙여 JSON은 계속 진실
     원본, 동기 API도 무변경 유지
  4) 디버그용으로 썼던 임시 테스트 파일은 삭제하고, 정식 회귀 테스트로 재작성해 남김
변경한 파일:
  신규 — test/services/exchange_history_mirror_sync_test.dart
  수정 — lib/services/exchange_history_service.dart(loadFromLocalStorage에 1회 미러 동기화 추가)
핵심 설계 결정과 근거:
  - "쓰기 시에만 미러"라는 S5.1의 기본 설계는 그대로 유지 — 다만 로드 시점에도 "지금 메모리에 있는
    전체 목록"을 한 번 미러하는 것을 추가했을 뿐, 새로운 쓰기 경로를 만들지 않았다(기존
    replaceExchangeEventsFor/toExchangeEventRecords를 그대로 재사용)
  - 이것은 S5.4b(JSON→SQLite 읽기 전환)를 앞당긴 것이 아니다 — 여전히 읽기는 JSON에서만 하고,
    단지 "SQLite로도 밀어 넣는 시점"을 쓰기 시점 외에 로드 시점까지 넓혔을 뿐이다
  - 근본 원인이 "버그"가 아니라 "S5.4b에서 계획된 1회 백필(OQ-4)이 아직 없어서 생긴 예상된 틈"임을
    먼저 재현 테스트로 증명한 뒤에 수정했다 — 추측으로 고치지 않고 재현부터 함
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 284개 통과(신규 1개: 기존 이력이 loadFromLocalStorage 한 번으로 SQLite에
  반영됨을 확인)
미실행 검증과 이유: 사용자가 실제 앱을 재빌드해 S5.2 패널을 다시 열어 "일치"로 바뀌는지 확인 —
  이 환경에서 GUI 조작 불가, 사용자 확인 필요. **이 확인이 S5.3 진입 게이트**
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음
다음 작업 1개 (파일/함수/기대 결과): 사용자가 재빌드 후 "일치" 확인을 마치면 S5.3 —
  lib/utils/lesson_projection.dart 신규 작성(project() 순수 함수, exchangePathMoves/
  ExchangeCellDates.forItem 재사용, DB 미기록). 핵심 회귀 테스트: project(...) 결과가
  ResolvedWeek.dateAware(...).toTimeSlots(...)와 일치함을 증명. 완료 조건: 이 등식 테스트 전부
  통과, 화면 동작은 여전히 무변화.
```

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S5.3(투영 순수 함수 검증) 완료. 사용자 확인 불필요(화면 무변화). 다음은 S5.4.
현재 Git HEAD / 브랜치: main, S5.1 보완 커밋 위(정확한 해시는 git log로 확인)
이번에 완료한 작은 작업:
  1) lib/utils/lesson_projection.dart 신규: project({snapshot, activeEvents, timetableId}) 순수
     함수. List<Lesson>에 활성 교체 이벤트를 재생(replay)한 결과를 List<Lesson>으로 반환, SQLite에
     아무것도 쓰지 않음
  2) resolved_week.dart의 exchangePathMoves/CellMove와 exchange_cell_dates.dart의
     ExchangeCellDates.forItem을 그대로 재사용 — 새 규칙을 만들지 않아 화면 합성 로직과 어긋날
     수 없게 설계
  3) 순환·2중(노드별 날짜 없음)은 OQ-1 채택안대로 "결강일이 속한 주의 월~금"으로 폴백
  4) test/utils/lesson_projection_test.dart 신규 6개 — resolved_week_date_aware_test.dart의
     기존 픽스처를 그대로 재사용해, project(...)를 특정 주로 필터한 결과가
     ResolvedWeek.dateAware(...).toTimeSlots(...)와 완전히 일치함을 등식으로 증명(1:1 같은 주,
     보강 같은 주, 1:1 다른 주 3개 시나리오, 순환 교체 폴백, 요일 불일치 폴백, 이벤트 없음)
변경한 파일:
  신규 — lib/utils/lesson_projection.dart, test/utils/lesson_projection_test.dart
핵심 설계 결정과 근거:
  - 화면 합성(ResolvedWeek.dateAware)과 투영(project)이 같은 두 유틸(exchangePathMoves,
    ExchangeCellDates.forItem)을 공유하게 만들어, "화면에 보이는 것"과 "SQLite에 쓰일 것"이
    구조적으로 같은 판단 기준을 쓰도록 보장 — S5 설계 검토서가 요구한 핵심 성질
  - S5.3은 등식을 증명하는 단계일 뿐 실제로 SQLite lessons에 쓰지 않는다 — 그 실행은 S5.4a
  - 순환·2중 폴백(결강일 주의 월~금)은 ResolvedWeek.dateAware의 기존 폴백과 정확히 같은 전제를
    쓰므로, 등식이 이 케이스에서도 자동으로 성립함을 테스트로 확인
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 290개 통과(신규 6개, 전부 첫 시도에 통과 — 재사용한 로직이 정확했음을 시사)
미실행 검증과 이유: 없음 — 이 단계는 순수 계산 함수 추가만이라 화면 동작이 전혀 바뀌지 않으므로
  사용자 수동 확인이 필요 없음
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음
다음 작업 1개 (파일/함수/기대 결과): S5.4 — lib/utils/exchange_dependency_checker.dart 신규 작성.
  이벤트 E를 되돌릴 때 E가 만든 칸(destination)을 나중 이벤트가 source/destination으로 쓰고
  있으면 의존으로 판정하는 순수 함수. exchange_executor.dart의 undoLastExchange에서 의존 건이
  있으면 스낵바에 "이후 교체 N건이 이 교체를 전제로 합니다" 경고만 추가(차단 없음, OQ-2 채택안).
  완료 조건: 유닛 테스트(의존 있음/없음/다른 주/되돌린 건 제외), 실제 앱에서 의존 없는 되돌리기는
  문구가 전혀 안 바뀜을 확인(회귀 없음 증명).
```

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S5.4(되돌리기 의존성 경고) 완료. 다음은 S5.4a — lessons에 투영을 실제로 기록.
현재 Git HEAD / 브랜치: main, S5.3 완료 커밋 위(정확한 해시는 git log로 확인)
이번에 완료한 작은 작업:
  1) lib/utils/exchange_dependency_checker.dart 신규: findDependentExchanges({target,
     allEventsInOrder}) 순수 함수. target이 만든 칸(목적지)을 target 이후 실행된 활성 이벤트가
     source/destination으로 쓰면 의존으로 판정. ExchangeCellDates.legacySourceKeys/
     legacyDestinationKeys(요일·교시 기준) 재사용 — 기존 isCellExchanged와 같은 판정 기준
  2) exchange_executor.dart의 undoLastExchange에 연결 — 되돌리기는 그대로 수행하고, 의존 건이
     있으면 기존 스낵바 메시지 뒤에 "(참고: 이후 교체 N건이 이 교체를 전제로 합니다)"만 덧붙임
     (D6/OQ-2 채택안 — 비차단)
변경한 파일:
  신규 — lib/utils/exchange_dependency_checker.dart, test/utils/exchange_dependency_checker_test.dart
  수정 — lib/ui/widgets/timetable_grid/exchange_executor.dart(undoLastExchange에 안내 문구 추가)
핵심 설계 결정과 근거:
  - 되돌리기 로직 자체(historyService.undoLastExchange() 호출과 그 결과 처리)는 한 글자도
    바꾸지 않았다 — 메시지 조합 단계에만 분기를 추가해 회귀 위험을 최소화
  - 요일·교시 기준(날짜 무관) 판정이라 다른 주의 같은 요일·교시를 과대 감지할 수 있지만, 이
    함수는 차단이 아니라 안내일 뿐이므로 과대 감지가 놓치는 것보다 안전하다고 판단
  - 투영(project)은 활성 이벤트를 순서대로 재생하므로 되돌린 뒤 최종 상태는 항상 결정적 —
    이 경고는 로직 분기가 아니라 순수하게 사용자 인지용
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 296개 통과(신규 6개, 회귀 없음)
미실행 검증과 이유: 실제 앱에서 (a) 의존 없는 보통의 되돌리기가 기존과 똑같은 문구로 뜨는지,
  (b) 의존 있는 시나리오(A 교체로 빈 칸을 B가 보강)를 만들어 안내 문구가 실제로 붙는지 — 이
  환경에서 GUI 조작 불가, 사용자 확인 필요
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음
다음 작업 1개 (파일/함수/기대 결과): 사용자 확인 후 S5.4a — TimetableRepository.replayInto
  (timetableId) 신규 작성. 한 트랜잭션에서 ① lesson_snapshots로 lessons 재생성(is_active 유지)
  → ② lesson_projection.project()로 활성 이벤트를 seq 순 재생 → ③ timetables.projected_seq
  갱신(신규 컬럼, 스키마 v3→v4). 호출 시점: 교체 실행·되돌리기·다시실행·삭제·전체삭제·날짜수정
  직후(미러 쓰기 큐 뒤), applyPeriodChange 직후. applyPeriodChange에 충돌 차단 규칙 추가(R5,
  OQ-7 — 기간 축소가 활성 교체와 겹치면 차단). 완료 조건: S5.2 패널에서 projected_seq 불일치 0,
  투영 후 lessons를 되읽어 ResolvedWeek.dateAware와 일치(테스트), 교체 다건 실행 후 UI 지연 없음.
  이 단계부터는 실제로 SQLite lessons가 갱신되므로 착수 전 간단한 설계 확인을 다시 거칠 것.
```

```text
갱신 시각: 2026-09-29
현재 단계와 상태: S5.4a(lessons 투영 실제 기록) 완료. 다음은 사용자 확인 후 S5.4b.
현재 Git HEAD / 브랜치: main, S5.4 완료 커밋 위(정확한 해시는 git log로 확인)
이번에 완료한 작은 작업:
  1) S5.3 보완(착수 전 발견): lesson_projection.dart의 project()가 새 칸에 Lesson.generateId()
     (매번 랜덤)를 쓰고 있어, replayInto를 반복 호출하면 같은 칸에 행이 계속 쌓이는 실제 버그였다.
     좌표 기반 결정적 ID(_deterministicId)로 교체 — OQ-6 요구사항을 이제 충족
  2) 스키마 v3→v4: timetables.projected_seq 컬럼 추가(기본 -1). UI에는 아직 노출 안 함(범위 최소화)
  3) TimetableRepository.replayInto(timetableId) 신규 — 트랜잭션 안에서 ①템플릿으로 lessons 내용
     리셋(id/date/period/teacher/is_active 유지) ②활성 이벤트를 seq 순 project()에 재생
     ③달라진 행만 갱신+새 칸만 삽입, projected_seq 갱신
  4) exchange_event_mirror.dart에 toExchangeHistoryItem() 추가 — ExchangeEventRecord를
     ExchangeHistoryItem으로 역직렬화(ExchangeHistoryItem.fromJson 재사용)
  5) applyPeriodChange에 OQ-7 구현 — 활성 교체가 새 범위 밖으로 나가면 트랜잭션 시작 전에
     PeriodChangeConflictException을 던지고 아무것도 바꾸지 않음(유일한 차단 예외)
  6) replayInto를 새 호출부 없이 S5.1의 기존 훅(services_provider.dart의 mirrorSink/
     mirrorClearSink)에 이어붙임 — 교체 실행/삭제/되돌리기/다시실행/날짜수정/전체삭제/로드
     동기화가 전부 이미 이 훅을 거치므로 추가 배선 불필요. semester_period_section.dart의
     _apply()에는 applyPeriodChange 직후 replayInto 호출을 별도로 추가
변경한 파일:
  수정 — lib/utils/lesson_projection.dart(결정적 ID),
        lib/data/timetable_database.dart(스키마 v4, projected_seq),
        lib/repositories/timetable_repository.dart(replayInto, PeriodChangeConflictException,
        applyPeriodChange OQ-7 검사),
        lib/services/exchange_event_mirror.dart(toExchangeHistoryItem),
        lib/providers/services_provider.dart(mirrorSink/mirrorClearSink에 replayInto 연결),
        lib/ui/screens/start_content/semester_period_section.dart(_apply()에 replayInto 호출),
        test/repositories/timetable_repository_test.dart(투영 재생 (S5.4a) 그룹 5개 추가)
핵심 설계 결정과 근거:
  - lessons는 저널의 파생 뷰일 뿐 — replayInto 밖에서 lessons의 교사·과목을 직접 고치는 코드
    경로를 두지 않는다(S5 설계 검토 R1 불변 조건 유지)
  - 새 호출부를 늘리지 않고 기존 S5.1 훅에 이어붙인 것이 핵심 — 교체 실행·삭제·되돌리기 등 모든
    변경 지점을 한 곳(mirrorSink)에서 이미 가로채고 있었으므로, replayInto 호출 위치를 새로
    찾을 필요가 없었다(회귀 위험 최소화)
  - OQ-7만 유일하게 차단 — 다른 모든 S5 안내(OQ-2 되돌리기 의존성 등)는 비차단인데, 기간 축소는
    되돌릴 방법이 없는 유일한 데이터 유실 지점이기 때문
  - S5.3에서 발견하지 못했던 랜덤 ID 문제를 S5.4a 착수 전에 먼저 고친 것 — "실제로 반복 호출되는
    상황"이 되어서야 드러난 문제로, 순수 함수 등식 테스트만으로는 이런 멱등성 문제를 못 잡는다는
    교훈(내용은 같아도 ID가 다르면 SQL 관점에서는 "새 행"이 된다)
실행한 검증 / 결과 (flutter analyze, flutter test, 수동 시나리오): flutter analyze 전체 통과,
  flutter test 전체 301개 통과(신규 5개: 1:1 교체 재생 시 두 교사 자기 행이 정확히 스왑,
  되돌린 이벤트 미재생, 재생 멱등성, projected_seq 갱신, applyPeriodChange 충돌 차단+무변경)
미실행 검증과 이유: 실제 앱에서 (a) 교체 여러 건 실행 후 SQLite lessons 내용이 실제로 바뀌는지,
  (b) 학기 기간을 활성 교체와 겹치게 줄였을 때 차단 메시지가 뜨는지 — 이 환경에서 GUI 조작 불가,
  사용자 확인 필요. S5.4의 "의존성 경고 실제 확인"도 원본/교체 토글 조사로 보류된 채 아직 미확인
남은 실패 또는 컴파일 오류: 없음
사용자 답변이 필요한 항목: 없음
다음 작업 1개 (파일/함수/기대 결과): 사용자 확인 후 S5.4b — ExchangeHistoryService
.loadFromLocalStorage()가 SQLite exchange_events에서 읽도록 전환("여기서부터 신규가 진실
원본"). 최초 1회: JSON에 있고 SQLite에 없으면 임포트 후 JSON을 *.v2.bak으로 보관(OQ-4), 임포트
실패 시 JSON 경로로 자동 폴백. 한 릴리스 동안 JSON 쓰기는 유지(이중 쓰기, 문제 생기면 로드
소스만 되돌리면 즉시 복구). 완료 조건: 기존 JSON 데이터가 있는 상태로 앱을 열어 교체 목록이
전부 그대로 보임, 재시작 후에도 동일, 1:1/순환/2중/보강+되돌리기 전 시나리오 재확인, 계획서·PDF
출력 결과가 S5 이전과 동일. 이 단계가 끝나면 S5 전체 완료 — S5.5(조회 전환)는 별도 설계 검토.
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
