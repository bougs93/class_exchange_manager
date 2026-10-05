# CLAUDE.md

이 파일은 Claude Code (claude.ai/code)가 이 저장소에서 작업할 때 참고할 가이드를 제공합니다.

## 프로젝트 개요

교사용 시간표 교체 프로그램입니다. 병가, 출장, 연수 등으로 인한 수업 교체를 자동화하여 처리하는 Flutter 애플리케이션입니다. Excel 파일에서 교사 시간표를 읽어와 1:1 교체와 순환 교체 기능을 실시간 시각화와 함께 제공합니다.

## 개발 명령어

### 실행 및 빌드
```bash
# 앱 실행
flutter run

# 플랫폼별 빌드
flutter build apk                # Android
flutter build windows           # Windows 데스크톱
flutter build ios              # iOS

# 의존성 설치
flutter pub get
```

### 코드 품질 및 테스트
```bash
# 코드 분석 (analysis_options.yaml의 flutter_lints 사용)
flutter analyze

# 코드 포맷팅
dart format .

# 테스트 실행
flutter test
flutter test test/widget_test.dart     # 특정 테스트 파일 실행
```

## 아키텍처 개요

**Clean Architecture** 원칙을 따르는 Flutter 앱입니다:

### 핵심 데이터 흐름
```
Excel 파일 (읽기 전용) → ExcelService → Models → Providers → UI
                                           ↓
                                   SQLite Database ← Memory Cache
```

### 상태 관리 및 의존성
- **Riverpod** (`flutter_riverpod: ^2.4.9`) 반응형 상태 관리
  - **전체 애플리케이션 상태는 Riverpod Provider로 관리**
  - `ConsumerWidget` 또는 `ConsumerStatefulWidget` 사용
  - 로컬 UI 상태(애니메이션, 스크롤)만 StatefulWidget 허용
- **SQLite** 로컬 데이터 저장 (개인 시간표, 교체 이력)
- **Excel 파싱** (`excel: ^4.0.6`) 기존 .xlsx 시간표 파일 읽기

### 주요 컴포넌트

**모델** (`lib/models/`):
- `TimeSlot` - 교사, 과목, 학급명, 요일, 교시가 포함된 개별 시간표 칸
- `Teacher` - 교사 정보 및 메타데이터
- `ExchangePath` 계층 - `OneToOneExchangePath`와 `CircularExchangePath` 구현체를 가진 추상 베이스
- `ExchangeNode` - 경로 탐색 알고리즘용 그래프 노드

**Providers** (`lib/providers/`):
- `exchangeScreenProvider` - 교체 화면의 모든 상태 관리 (30+ 상태 변수)
- `servicesProvider` - 서비스 인스턴스 제공 (ExcelService, ExchangeService 등)
- `exchangeLogicProvider` - 교체 모드 상태 관리 (oneToOne, circular, dual)
- `navigationProvider` - 홈 화면 네비게이션 상태

**서비스** (`lib/services/`):
- `ExcelService` - Excel 파일 파싱, 다양한 파일 레이아웃용 `ExcelParsingConfig` 처리
- `ExchangeService` - 핵심 1:1 교체 로직
- `CircularExchangeService` - 2-5명 교사 순환 교체 처리
- `DualExchangeService` - 2중 교체 처리

**핵심 알고리즘**:
- 경로 탐색·검증은 **서비스 계층**이 담당한다 (`ExchangeService`,
  `CircularExchangeService`, `DualExchangeService`). 예전에 있던
  `ExchangeAlgorithm` 클래스는 어디서도 쓰이지 않아 제거했다(2026-10-03).
  `lib/utils/exchange_algorithm.dart`에는 이제 두 서비스가 공유하는
  `ExchangeOption`·`ExchangeType` 타입만 남아 있다.
- `ExchangePathConverter` (`lib/utils/`) - 다양한 교체 표현 간 변환
- 셀 색상 결정은 `lib/utils/simplified_timetable_theme.dart`가 한다
  (`ExchangeVisualizer`는 미사용이라 제거됨, 2026-10-03).

### UI 아키텍처

**메인 네비게이션**: 5개 화면이 있는 Drawer 기반 네비게이션:
- 홈, 교체 관리, 개인 시간표, 문서 출력, 설정

**그리드 시스템**: `flutter_layout_grid: ^2.0.6`과 `syncfusion_flutter_datagrid: ^30.1.41`를 사용하여 한글 텍스트 처리가 가능한 Excel 호환 시간표 표시.

**교체 시각화**:
- 초록색: 1:1 직접 교체 가능
- 노란색: 순환 교체 필요
- 빨간색: 교체 불가능
- 실시간 피드백을 제공하는 대화형 선택

**아키텍처 패턴** (2025년 리팩토링 완료):
- **MVVM 패턴**: ViewModel을 통한 비즈니스 로직 분리
- **Composition over Inheritance**: Manager 클래스로 Mixin 의존성 감소
- **Provider Proxy 패턴**: 중앙 집중식 상태 접근
- **Widget 분리**: 재사용 가능한 작은 위젯 컴포넌트

## 주요 기술적 제약사항

### Excel 호환성
기존 한국 학교 Excel 파일과의 완전한 호환성 유지 필요:
- A열에 "교사명(번호)" 형식의 교사명
- 설정 가능한 행에 요일 헤더 (기본 2행)
- 설정 가능한 행에 교시 번호 (기본 3행)
- 셀 형식: "학급번호\n과목명" (예: "1-1\n수학")

### 교체 알고리즘 요구사항
- **1:1 교체**: 과목 호환성 검사를 포함한 교사 간 직접 교환
- **순환 교체**: BFS 경로 탐색을 사용하는 2~5명 교사 순환 교체
- **제약사항**: 과목 매칭 (설정 가능), 특별교실 제한, 블록타임 보존
- **성능**: 1초 미만의 실시간 시뮬레이션

### 오프라인 우선 설계
모든 핵심 기능이 인터넷 없이 작동해야 합니다. Excel 파일은 읽기 전용 데이터 소스로 사용하며, 개인 데이터는 SQLite에, 실시간 작업은 메모리 캐시에 저장합니다.

## 개발 가이드라인 (docs/global_rules.md 기준)

### 구현 원칙
- 비즈니스 로직 구현 전 테스트 작성
- SOLID 원칙과 Clean Architecture 준수
- 복잡한 솔루션보다 단순성 우선
- 코드 중복 방지 (DRY 원칙)

### Riverpod 상태 관리 규칙 (필수)
- **모든 애플리케이션 상태는 Riverpod Provider로 관리**
- **새로운 화면 작성 시**:
  - 상태가 있으면 `ConsumerWidget` 또는 `ConsumerStatefulWidget` 사용
  - 상태가 없으면 `StatelessWidget` 사용
  - `setState()` 사용 금지 (로컬 UI 상태 제외)
- **Provider 패턴**:
  - `StateNotifierProvider` - 복잡한 상태 관리
  - `StateProvider` - 간단한 상태 관리
  - `Provider` - 서비스 인스턴스 제공
- **상태 접근**:
  - `ref.watch()` - 반응형 UI 업데이트
  - `ref.read()` - 일회성 상태 접근
  - `ref.listen()` - 상태 변경 리스너
- **허용되는 StatefulWidget 사용**:
  - 애니메이션 컨트롤러 관리
  - 스크롤 컨트롤러 관리
  - 기타 순수 UI 로컬 상태

### 한국어 현지화
- 사용자 대면 텍스트와 주석은 한국어
- 기술 용어와 라이브러리 이름은 원문 유지
- AWS 리소스 설명은 영문

### 코드 품질
- 개발/프로덕션 환경에서 모의 데이터 사용 금지 (테스트 제외)
- `logger: ^2.0.2+1`을 통한 구조화된 로깅 사용
- 성능을 위해 상세 디버그 로그 제거
- **스낵바(SnackBar)는 항상 `lib/utils/snackbar_helper.dart`의 `SnackBarHelper`를 통해 표시** (`showSuccess`/`showError`/`showInfo`/`showWarning`/`showWithAction`). `ScaffoldMessenger.of(context).showSnackBar(...)`를 직접 호출하지 말 것 — 스낵바를 띄운 위젯이 표시 중 unmount되면 Flutter 내부 자동 닫힘 타이머가 시작되지 않아 스낵바가 영구히 남는 문제가 있었고, `SnackBarHelper`만 이를 해결하는 강제 닫힘 안전장치를 갖고 있음 (2026-09-29 수정)

## 현재 구현 상태

**Phase 1 - 핵심 기능 (완료)**:
- ✅ Riverpod 전체 프로젝트 전환 완료
- ✅ `ExcelService`를 사용한 Excel 파일 파싱
- ✅ 핵심 데이터 모델 및 교체 경로 추상화
- ✅ 메인 UI 화면 및 네비게이션
- ✅ 1:1 교체 알고리즘 구현
- ✅ 순환 교체 알고리즘 구현
- ✅ 2중 교체 알고리즘 구현
- ✅ 실시간 시각화 시스템

**Phase 2 - 코드 품질 개선 (2025년 1월 완료)**:
- ✅ 중복 코드 제거 및 복잡도 감소
- ✅ Magic number 상수화
- ✅ LRU 캐시 구현 (메모리 누수 방지)
- ✅ Deprecated API 마이그레이션

**Phase 3 - 아키텍처 리팩토링 (2025년 1월 완료)**:
- ✅ MVVM 패턴 적용 (ViewModel 분리)
- ✅ Widget 컴포넌트 분리 (AppBar, TabContent)
- ✅ Helper 클래스 생성 (Grid, CellTap)
- ✅ Provider Proxy 패턴 (상태 중앙 집중화)
- ✅ Composition over Inheritance (11 Mixin → 8 Mixin + 1 Manager)
- ⚠️ 당시 exchange_screen.dart는 877줄까지 줄었으나, 이후 기능 추가로 **다시
  크게 늘었다**(아래 "대형 파일 다루기" 참고). 이 절의 수치는 2025년 1월 시점의
  기록이며 현재 상태가 아니다.

**Phase 4 - 코드 정리 및 최적화 (2025년 10월 완료)**:
- ✅ Provider 편의 메서드 제거 (select 패턴으로 전환)
- ✅ 사용하지 않는 코드 제거 (ExchangeViewManager 356줄)
- ✅ 중복 메서드 통합 (DayUtils로 _getDayString 통합)
- ✅ StateProxy 중복 setter 제거
- ✅ 문서 정리 (중복 문서 2개 삭제)
- ✅ **누적 결과**: 총 472줄 감소

**향후 단계**:
- 🚧 `pdf: ^3.10.7`을 사용한 문서 생성 (PDF) - 진행 중
- 교체 정보용 QR 코드 시스템
- Windows 시스템 트레이 위젯 (선택사항)

## 시스템 이해를 위한 주요 파일

**상태 관리**:
- `lib/main.dart` - ProviderScope 래퍼로 Riverpod 활성화
- `lib/providers/exchange_screen_provider.dart` - 교체 화면 상태 관리
- `lib/providers/services_provider.dart` - 서비스 인스턴스 제공
- `lib/ui/screens/exchange_screen/exchange_screen_state_proxy.dart` - Provider 상태 중앙 집중화

**UI 컴포넌트**:
- `lib/ui/screens/exchange_screen.dart` - 메인 교체 화면 (Mixin 7개 + 상태는
  전부 Riverpod. `setState` 없음)
- `lib/ui/screens/exchange_screen/widgets/exchange_app_bar.dart` - AppBar 위젯
- `lib/ui/screens/exchange_screen/widgets/timetable_tab_content.dart` - 시간표 탭 컨텐츠
- `lib/ui/screens/start_screen.dart` - 앱 셸. 상단 `UnifiedNavigationBar` +
  `IndexedStack`으로 6개 탭(준비·교체·계획서·안내·시간표·도움말)을 전환한다.
  각 탭 화면은 자체 AppBar 없이 이 셸 아래에 그려진다.
  (예전 `home_screen.dart`는 더 이상 없다.)

**ViewModel & Manager** (Composition 패턴):
- `lib/ui/screens/exchange_screen/exchange_screen_viewmodel.dart` - 비즈니스 로직 분리
- `lib/ui/screens/exchange_screen/managers/exchange_operation_manager.dart` - 파일/모드 관리
- `lib/ui/screens/exchange_screen/helpers/grid_helper.dart` - DataGrid 헬퍼
- `lib/ui/screens/exchange_screen/helpers/cell_tap_helper.dart` - 셀 탭 헬퍼

**비즈니스 로직**:
- `lib/services/excel_service.dart` - Excel 파싱 (한글 텍스트 처리, ExcelServiceConstants)
- `lib/services/exchange_service.dart` - 1:1 교체 로직
- `lib/services/circular_exchange_service.dart` - 순환 교체 (LRU 캐시)
- `lib/services/dual_exchange_service.dart` - 2중 교체
- `lib/utils/exchange_algorithm.dart` - 핵심 경로 탐색 알고리즘
- `lib/models/exchange_path.dart` - 교체 유형 추상화

**유틸리티**:
- `lib/utils/cell_style_config.dart` - 셀 스타일 데이터 클래스 (12-parameter 문제 해결)
- `lib/utils/simplified_timetable_theme.dart` - 셀 스타일 결정 + 캐시
- `lib/utils/syncfusion_timetable_helper.dart` - Syncfusion 헬퍼 (중복 제거)

**문서**:
- `docs/requirements.md` & `docs/design.md` - 상세 사양
- `CLAUDE.md` - 프로젝트 개요 및 개발 가이드 (본 파일)

## 최근 리팩토링 이력 (2025년 1월)

### 코드 품질 개선
1. **LRU 캐시 구현** - circular_exchange_service.dart에 최대 100개 항목 제한
2. **중복 코드 제거** - syncfusion_timetable_helper.dart의 4개 중복 함수 → 1개로 통합
3. **복잡도 감소** - excel_service.dart의 5단계 중첩 루프 → 4개 함수로 분리
4. **Magic number 제거** - ExcelServiceConstants 클래스 생성
5. **Parameter 최적화** - 12-parameter 함수 → CellStyleConfig 데이터 클래스
6. **캐시 통합** - cell_cache_manager.dart의 6개 중복 메서드 → enum 패턴

### 아키텍처 개선
1. **MVVM 패턴** - ExchangeScreenViewModel (260+ lines) 분리
2. **Widget 분리** - ExchangeAppBar (69 lines), TimetableTabContent (101 lines)
3. **Helper 클래스** - GridHelper, CellTapHelper 생성
4. **Provider Proxy** - ExchangeScreenStateProxy로 84개 getter/setter 중앙 집중화
5. **Composition** - ExchangeOperationManager (263 lines)로 3개 Mixin 대체

### 성과 (2025년 1월 당시 기록)
- **코드 라인 감소**: 1133 → 877 lines (22.6%)
- **Mixin 감소**: 11개 → 8개 + 1 Manager
- **flutter analyze**: No issues found

> ⚠️ 위 수치는 **2025년 1월 시점의 기록**이다. 이후 웹 전환·결보강·계획서
> 기능이 더해지며 파일이 다시 커졌다. 현재 상태는 아래 절을 볼 것.

## 대형 파일 다루기

큰 파일은 **통째로 읽지 말고 필요한 부분만 찾아 읽을 것.** 구조부터 보려면
`grep -nE "^class |Widget _build[A-Za-z]*\(" <파일>`로 윤곽만 뜨는 게 싸다.
현재 크기가 궁금하면 문서를 믿지 말고 직접 재라:

```bash
find lib -name "*.dart" -exec wc -l {} + | sort -rn | head -10
```

### 더 쪼개지 않기로 한 파일

아래 셋은 **안전하게 뺄 수 있는 것을 이미 다 뺐다.** 더 줄이려면 동작이
바뀔 위험이 커서 중단했으니, 크기만 보고 다시 시도하지 말 것.

- `lib/ui/screens/exchange_screen.dart` — UI는 이미 Mixin(`ExchangeUIBuilder`,
  `SidebarBuilder`)에 있고, 남은 로직은 State의 private 멤버 15개 이상과 얽혀
  있다. 위임 getter 묶음은 Mixin 계약을 구현하는 `@override`라 지울 수 없다.
- `lib/ui/widgets/timetable_grid_section.dart` — Syncfusion 헤더 갱신 버그
  이력이 있다(아래 "주요 이슈" 참고). `build`·`didUpdateWidget`·`ValueKey`·
  `_getScaled*`는 건드리지 말 것.
- `.../substitution_output/substitution_output_widget.dart` — 남은 부분이
  `setState`/`mounted`/run-ID 가드/`await`가 뒤섞인 오케스트레이션이다.

## 파일 분할 구조 (2026-10-03~04)

대형 파일을 기능 단위로 쪼갰다. **파사드는 그대로 두고 `export`로 기존 import
경로를 유지**했으므로 호출부는 한 곳도 수정하지 않았다. 새 코드를 넣을 때도
이 구조를 따를 것.

| 원래 파일 | 분리된 곳 |
|---|---|
| `notice_message_generator.dart` | `lib/utils/notice/` |
| `exchange_service.dart` | `lib/services/exchange/` |
| `excel_service.dart` | `lib/services/excel_parsing/` |
| `exchange_history_service.dart` | `lib/services/exchange_history/` |
| `timetable_repository.dart` | `lib/repositories/timetable/` |
| `timetable_data_source.dart` | `lib/utils/timetable_grid_source/` |
| `exchange_arrow_painter.dart` | `timetable_grid/arrow_geometry.dart` |
| `start_settings_card.dart` | `lib/ui/screens/start_content/settings/` |
| `timetable_file_screen.dart` | `lib/ui/screens/timetable_file/` |
| `web_admin_settings_screen.dart` | `lib/ui/screens/web_admin/` |
| `content_input_grid.dart` | `.../plan_output/widgets/content_input/` |
| `plan_backup_screen.dart` | `.../plan_output/widgets/plan_backup/` |
| `unified_exchange_sidebar.dart` | `lib/ui/widgets/exchange_sidebar/` |

또 `TimetableData`·`ExcelParsingConfig`는 `lib/models/timetable_data.dart`로,
`ExchangeResult`는 `lib/models/exchange_result.dart`로 옮겼다 — 전에는 이 타입
하나를 쓰려고 24개 파일이 `excel_service.dart`(그리고 `dart:io`·`package:excel`)를
통째로 import했다.

## 죽은 코드 제거 (2026-10-03~04)

참조가 전혀 없던 **약 2,400줄**을 삭제했다. 아래 이름이 옛 문서·주석에 남아
있을 수 있으나 **더 이상 존재하지 않는다**:
`SettingsScreen`, `ExcelExportService`, `CellStateManager`, `CellCacheManager`,
`ExchangePathManager`, `PersonalScheduleDebugHelper`, `ExchangeVisualizer`,
`SelectedTimetableFileBanner`, `CommonAppBar`, `ExchangeAlgorithm`,
`ExchangeViewCheckbox`, `TeacherNoticeStatsWidget`, `ClassNoticeStatsWidget`.

## 웹 실행 전 탐색 Worker 생성 (필수)

순환·2중 교체 경로 탐색은 브라우저 Web Worker에서 돈다
(`tool/exchange_search_worker.dart` → `web/exchange_search_worker.js`).
이 파일은 **`flutter build web`이 만들어 주지 않는다** — 별도로 컴파일해야 한다.

```bash
# 웹 실행 전 한 번 (생성물은 .gitignore 처리됨)
dart run tool/build_web.dart --worker-only
flutter run -d chrome --web-port=5000

# 배포용 전체 빌드 (Worker + 앱을 함께 만든다)
dart run tool/build_web.dart --dart-define=...
```

`web/` 아래 파일은 Flutter가 `build/web/`으로 그대로 복사하므로, Worker를
**먼저** 만들면 로컬 실행과 배포 빌드가 같은 산출물을 쓴다. CI 워크플로도
같은 순서다.

> 없으면 순환·2중 교체에서 "교체 탐색 Worker를 불러오지 못했습니다"가 떴었다
> (2026-10-04). 지금은 Worker가 없으면 본 isolate에서 대신 돌아가도록
> 폴백이 들어가 있어 **기능은 동작하지만 느리다** — 로그에
> "본 isolate로 폴백" 경고가 보이면 Worker를 만들지 않은 것이다.

## 위젯 테스트 작성법 (이 프로젝트 고유)

새 위젯 테스트를 쓸 때는 아래를 따를 것. 선례:
`test/widgets/timetable_file_screen_test.dart`,
`test/widgets/unified_exchange_sidebar_test.dart`.

- **`pumpAndSettle()`을 쓰지 말 것** — 이 프로젝트에서는 무한 대기에 빠진다.
  경계가 있는 `pump()` 루프를 쓴다.
- `initState`에서 디스크를 읽는 위젯은 `tester.runAsync()`로 감싸야 실제 I/O가
  진행된다.
- 디스크 없는 가짜는 `test/helpers/in_memory_json_storage.dart`.
- 오버플로 검사: `tester.view.physicalSize`로 폭을 바꾸고
  `expect(tester.takeException(), isNull)`.

### ⚠️ 서비스를 State 필드에서 직접 생성하지 말 것

`final _svc = SomeService();`처럼 State **필드 초기화자**에서 외부 서비스를
만들면, 그 생성자가 `FirebaseFirestore.instance` 같은 걸 평가하는 순간
**`initState`보다 먼저, try/catch 밖에서** 터진다. 실제로 접속 설정 화면이
이것 때문에 테스트를 하나도 쓸 수 없었다(2026-10-03). Provider를 거칠 것:

```dart
// 나쁨
final _brandingService = WebBrandingService();
// 좋음 — 실제 사용 시점까지 생성이 미뤄지고, 테스트가 override할 수 있다
WebBrandingService get _brandingService => ref.read(webBrandingServiceProvider);
```

### ⚠️ `dispose()`에서 `ref.read`를 쓰지 말 것

Flutter는 `dispose()` 호출 **전에** element의 context를 비우므로
`dispose()` 안의 `ref.read`는 **반드시** `StateError`를 던진다(조용히 삼켜진다).
필요한 notifier는 `initState`에서 미리 캐시해 둘 것.

### ⚠️ Windows에서 한글 파일을 PowerShell로 자르지 말 것

PowerShell `Get-Content`/`Set-Content`로 줄을 잘라 다시 쓰면 **한글 UTF-8이
조용히 깨진다**(실제 발생). `sed -i 'N,Md'`나 편집 도구를 쓰고, 대량 삭제 후엔
`grep -c '[가-힣]'`로 전후를 대조할 것.

## 주요 이슈 및 해결 방법

### 교체 칸의 날짜를 요일만으로 찾지 말 것 (2026-10-05)

결강일과 교체일은 **다른 주의 같은 요일**일 수 있다(예: 10.07(수) 4교시 ↔
10.14(수) 6교시). 예전 `dateByDayNumber`(요일 → 날짜 맵)는 한쪽 날짜가 다른
쪽을 덮어써서, 날짜·교체 반영 화면에서 결강일 주의 교체가 사라졌다.
- 셀 이동(`CellMove`)에 날짜를 붙일 때는 **반드시**
  `resolveEventDates(item).forMove(move)`를 쓴다 (칸 좌표 = 쪽·교사·요일·교시로 조회).
- `forSlot(요일, 교시)`는 순환·2중 노드 날짜용이다. 1:1·보강에서 구분할 수
  없으면 null을 돌려준다.
- 회귀 테스트: `test/utils/same_weekday_cross_week_test.dart`
- SQLite `lessons`에 이미 잘못 투영된 값은 DB 스키마 v6 마이그레이션이
  `projected_seq`를 무효화해 다음 조회 때 다시 계산한다.

### Syncfusion DataGrid 동적 헤더 업데이트 이슈 (2025년 1월)

**문제**: 교체 모드에서 셀 선택 시 테이블 헤더 UI가 업데이트되지 않음

**근본 원인**:
1. **GlobalKey 사용 문제**: `SfDataGrid`에 GlobalKey를 사용하면 Flutter가 동일한 State 객체를 재사용
2. **컬럼 변경 미감지**: 컬럼 개수가 동일하면 Syncfusion DataGrid가 헤더 변경을 감지하지 못함
3. **참조**: [Syncfusion 공식 포럼 이슈](https://www.syncfusion.com/forums/181891)

**해결 방법**:
```dart
// lib/ui/widgets/timetable_grid_section.dart
SfDataGrid(
  // GlobalKey 대신 ValueKey 사용으로 columns 변경 시 강제 재생성
  key: ValueKey(widget.columns.hashCode),
  columns: _getScaledColumns(),
  stackedHeaderRows: _getScaledStackedHeaders(),
  ...
)
```

**추가 조치**:
1. **캐싱 제거**: `_getScaledColumns()`, `_getScaledStackedHeaders()`의 캐싱 로직 제거
2. **didUpdateWidget 감지**: TimetableGridSection에서 columns 변경 시 `setState()` 호출
3. **타이밍 조정**: 모드 변경 시 `addPostFrameCallback` 사용으로 Provider 업데이트 후 헤더 갱신

**영향받은 파일**:
- `lib/ui/widgets/timetable_grid_section.dart` - ValueKey 적용, 캐싱 제거
- `lib/ui/screens/exchange_screen.dart` - addPostFrameCallback 타이밍 조정

**결과**: 모든 상황(셀 선택, 경로 선택, 모드 변경)에서 헤더 UI 정상 업데이트