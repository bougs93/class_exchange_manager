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
Excel 파일 (읽기 전용) → ExcelService → Models → Services → UI
                                           ↓
                                   SQLite Database ← Memory Cache
```

### 상태 관리 및 의존성
- **Riverpod** (`flutter_riverpod: ^2.4.9`) 반응형 상태 관리
- **SQLite** 로컬 데이터 저장 (개인 시간표, 교체 이력)
- **Excel 파싱** (`excel: ^4.0.6`) 기존 .xlsx 시간표 파일 읽기

### 주요 컴포넌트

**모델** (`lib/models/`):
- `TimeSlot` - 교사, 과목, 학급명, 요일, 교시가 포함된 개별 시간표 칸
- `Teacher` - 교사 정보 및 메타데이터
- `ExchangePath` 계층 - `OneToOneExchangePath`와 `CircularExchangePath` 구현체를 가진 추상 베이스
- `ExchangeNode` - 경로 탐색 알고리즘용 그래프 노드

**서비스** (`lib/services/`):
- `ExcelService` - Excel 파일 파싱, 다양한 파일 레이아웃용 `ExcelParsingConfig` 처리
- `ExchangeService` - 핵심 1:1 교체 로직
- `CircularExchangeService` - 2-5명 교사 순환 교체 처리

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

### 한국어 현지화
- 사용자 대면 텍스트와 주석은 한국어
- 기술 용어와 라이브러리 이름은 원문 유지
- AWS 리소스 설명은 영문

### 코드 품질
- 개발/프로덕션 환경에서 모의 데이터 사용 금지 (테스트 제외)
- `logger: ^2.0.2+1`을 통한 구조화된 로깅 사용
- 성능을 위해 상세 디버그 로그 제거

## 현재 구현 상태

**Phase 1 (진행 중)**:
- ✅ Riverpod을 사용한 기본 프로젝트 구조
- ✅ `ExcelService`를 사용한 Excel 파일 파싱
- ✅ 핵심 데이터 모델 및 교체 경로 추상화
- ✅ 메인 UI 화면 및 네비게이션
- 🚧 교체 알고리즘 구현
- 🚧 실시간 시각화 시스템

**향후 단계**:
- `pdf: ^3.10.7`을 사용한 문서 생성 (PDF)
- 교체 정보용 QR 코드 시스템
- Windows 시스템 트레이 위젯 (선택사항)

## 시스템 이해를 위한 주요 파일

- `lib/services/excel_service.dart` - 한글 텍스트 처리를 포함한 복잡한 Excel 파싱 로직
- `lib/utils/exchange_algorithm.dart` - 핵심 경로 탐색 알고리즘
- `lib/models/exchange_path.dart` - 교체 유형 추상화
- `lib/ui/screens/exchange_screen.dart` - 메인 교체 인터페이스
- `docs/requirements.md` & `docs/design.md` - 상세 사양