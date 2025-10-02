# 프로젝트 개요: 수업 교환 관리자

이 프로젝트는 교사들의 수업 교환 업무를 간소화하고 자동화하기 위해 설계된 Flutter 애플리케이션입니다. 기존 Excel 시간표 파일을 읽고, 1:1 또는 순환 수업 교환을 용이하게 하며, 교환 가능한 시간을 시각화하고, PDF 보고서를 생성하며, 교환 정보를 공유하기 위한 QR 코드를 생성하는 기능을 제공합니다. 이 애플리케이션은 오프라인 우선 접근 방식으로 구축되었으며 모바일(Android, iOS) 및 데스크톱(Windows)을 포함한 여러 플랫폼을 대상으로 하며, 향후 Windows 시스템 트레이 위젯에 대한 계획도 있습니다.

## 주요 기능

*   **Excel 파일 호환**: 기존 xlsx 형태 시간표 파일 완전 지원
*   **1:1 교체**: 두 교사 간 직접 시간 교체
*   **순환 교체**: 2-5명까지 연쇄 교체 지원
*   **실시간 시각화**: 교체 가능한 시간을 색상으로 표시
*   **문서 생성**: PDF 결보강 계획서 자동 생성
*   **QR코드**: 교체 정보 전달을 위한 QR코드 생성
*   **오프라인 우선**: 인터넷 없이 모든 기능 사용 가능

## 주요 기술

*   **프레임워크**: Flutter
*   **상태 관리**: Riverpod (`flutter_riverpod`)
*   **파일 처리**: Excel 읽기 (`excel`), 파일 선택 (`file_picker`), 경로 관리 (`path_provider`)
*   **UI 컴포넌트**: 그리드 레이아웃 (`flutter_layout_grid`), 캘린더 (`table_calendar`), 데이터 그리드 (`syncfusion_flutter_datagrid`), 위젯 화살표 (`widget_arrows`)
*   **문서 생성**: PDF 생성 (`pdf`)
*   **로깅**: `logger`

## 빌드 및 실행

프로젝트를 설정하고 실행하려면 다음 단계를 따르세요:

1.  **저장소 복제**:
    ```bash
    git clone [repository-url]
    cd class_exchange_manager
    ```
    (참고: `[repository-url]`을 실제 저장소 URL로 대체하세요.)

2.  **의존성 설치**:
    ```bash
    flutter pub get
    ```

3.  **애플리케이션 실행**:
    ```bash
    flutter run
    ```

## 개발 규칙 및 프로젝트 구조

*   **코딩 스타일**: 이 프로젝트는 `analysis_options.yaml`을 통해 `package:flutter_lints/flutter.yaml`에 정의된 권장 Flutter 린팅 규칙을 준수합니다.
*   **프로젝트 구조**: 코드베이스는 다음과 같이 논리적인 디렉토리로 구성됩니다:
    *   `lib/models/`: `Teacher`, `TimeSlot`, `ExchangePath` 등 애플리케이션의 핵심 데이터 구조를 정의합니다.
    *   `lib/providers/`: Riverpod을 사용하여 애플리케이션의 상태 관리를 담당합니다.
    *   `lib/services/`: `ExcelService`, `ExchangeService` 등 비즈니스 로직과 외부 시스템(예: Excel 파일)과의 상호작용을 처리합니다.
    *   `lib/repositories/`: 데이터 접근 및 저장을 위한 로직을 포함합니다.
    *   `lib/ui/`: 사용자 인터페이스 컴포넌트를 포함하며, `screens/` (예: `HomeScreen`) 및 `widgets/` (예: `TimetableGridSection`)로 세분화됩니다.
    *   `lib/utils/`: 다양한 유틸리티 함수 및 헬퍼 클래스를 포함합니다.

## 핵심 컴포넌트

*   **`main.dart`**: 애플리케이션의 진입점이며, 초기 라우팅 및 테마 설정을 담당합니다.
*   **`lib/models/`**: `Teacher` (교사 정보), `TimeSlot` (시간표의 개별 시간), `ExchangePath` (교환 경로)와 같은 핵심 모델들이 정의되어 있습니다.
*   **`lib/services/excel_service.dart`**: Excel 파일을 읽고 파싱하여 애플리케이션에서 사용할 수 있는 데이터 구조로 변환하는 역할을 합니다.
*   **`lib/services/exchange_service.dart`**: 1:1 교환 및 순환 교환과 같은 교환 로직을 처리합니다.
*   **`lib/ui/screens/home_screen.dart`**: 애플리케이션의 메인 화면으로, 시간표 표시 및 교환 기능을 제공합니다.
*   **`lib/ui/widgets/timetable_grid_section.dart`**: 시간표 데이터를 시각적으로 표시하는 그리드 위젯입니다.

## 테스트

단위 및 위젯 테스트는 `test/` 디렉토리에 있습니다. 테스트를 실행하려면 다음 명령을 사용하세요:

```bash
flutter test
```
