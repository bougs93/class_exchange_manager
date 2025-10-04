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
- `exchangeLogicProvider` - 교체 모드 상태 관리 (oneToOne, circular, chain)
- `navigationProvider` - 홈 화면 네비게이션 상태

**서비스** (`lib/services/`):
- `ExcelService` - Excel 파일 파싱, 다양한 파일 레이아웃용 `ExcelParsingConfig` 처리
- `ExchangeService` - 핵심 1:1 교체 로직
- `CircularExchangeService` - 2-5명 교사 순환 교체 처리
- `ChainExchangeService` - 연쇄 교체 처리

**핵심 알고리즘** (`lib/utils/`):
- `ExchangeAlgorithm` - 메인 교체 경로 탐색 및 검증
- `ExchangeVisualizer` - 교체 가능성에 대한 실시간 색상 코딩
- `ExchangePathConverter` - 다양한 교체 표현 간 변환

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
- **순환 교체**: BFS 경로 탐색을 사용하는 2-5명 교사 연쇄 교체
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

## 현재 구현 상태

**Phase 1 - 핵심 기능 (완료)**:
- ✅ Riverpod 전체 프로젝트 전환 완료
- ✅ `ExcelService`를 사용한 Excel 파일 파싱
- ✅ 핵심 데이터 모델 및 교체 경로 추상화
- ✅ 메인 UI 화면 및 네비게이션
- ✅ 1:1 교체 알고리즘 구현
- ✅ 순환 교체 알고리즘 구현
- ✅ 연쇄 교체 알고리즘 구현
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
- ✅ **최종 결과**: exchange_screen.dart 1133 → 877 lines (22.6% 감소)

**향후 단계**:
- `pdf: ^3.10.7`을 사용한 문서 생성 (PDF)
- 교체 정보용 QR 코드 시스템
- Windows 시스템 트레이 위젯 (선택사항)

## 시스템 이해를 위한 주요 파일

**상태 관리**:
- `lib/main.dart` - ProviderScope 래퍼로 Riverpod 활성화
- `lib/providers/exchange_screen_provider.dart` - 교체 화면 상태 관리
- `lib/providers/services_provider.dart` - 서비스 인스턴스 제공
- `lib/ui/screens/exchange_screen/exchange_screen_state_proxy.dart` - Provider 상태 중앙 집중화

**UI 컴포넌트** (리팩토링 완료):
- `lib/ui/screens/exchange_screen.dart` - 메인 교체 화면 (877 lines, 8 Mixin)
- `lib/ui/screens/exchange_screen/widgets/exchange_app_bar.dart` - AppBar 위젯
- `lib/ui/screens/exchange_screen/widgets/timetable_tab_content.dart` - 시간표 탭 컨텐츠
- `lib/ui/screens/home_screen.dart` - ConsumerWidget 기반 홈 화면

**ViewModel & Manager** (Composition 패턴):
- `lib/ui/screens/exchange_screen/exchange_screen_viewmodel.dart` - 비즈니스 로직 분리
- `lib/ui/screens/exchange_screen/managers/exchange_operation_manager.dart` - 파일/모드 관리
- `lib/ui/screens/exchange_screen/helpers/grid_helper.dart` - DataGrid 헬퍼
- `lib/ui/screens/exchange_screen/helpers/cell_tap_helper.dart` - 셀 탭 헬퍼

**비즈니스 로직**:
- `lib/services/excel_service.dart` - Excel 파싱 (한글 텍스트 처리, ExcelServiceConstants)
- `lib/services/exchange_service.dart` - 1:1 교체 로직
- `lib/services/circular_exchange_service.dart` - 순환 교체 (LRU 캐시)
- `lib/services/chain_exchange_service.dart` - 연쇄 교체
- `lib/utils/exchange_algorithm.dart` - 핵심 경로 탐색 알고리즘
- `lib/models/exchange_path.dart` - 교체 유형 추상화

**유틸리티**:
- `lib/utils/cell_style_config.dart` - 셀 스타일 데이터 클래스 (12-parameter 문제 해결)
- `lib/utils/cell_cache_manager.dart` - 통합 캐시 관리 (enum 패턴)
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

### 성과
- **코드 라인 감소**: 1133 → 877 lines (22.6%)
- **Mixin 감소**: 11개 → 8개 + 1 Manager
- **flutter analyze**: No issues found
- **유지보수성**: 매우 향상 (테스트 용이, 의존성 명확)