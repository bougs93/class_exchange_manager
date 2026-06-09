# 교사용 시간표 교체 프로그램 설계 문서 (핵심 요약)

## 📋 목차
1. [시스템 아키텍처](#1-시스템-아키텍처)
2. [핵심 기능 설계](#2-핵심-기능-설계)
3. [데이터베이스 설계](#3-데이터베이스-설계)
4. [UI/UX 설계](#4-uiux-설계)
5. [구현 계획](#5-구현-계획)

---

## 1. 시스템 아키텍처

### 1.1 전체 구조 (Riverpod 기반)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Presentation  │    │  State Mgmt     │    │  Business Logic │    │   Data Layer    │
│                 │    │   (Riverpod)    │    │                 │    │                 │
│ • ConsumerWidget│───▶│ • Providers     │───▶│ • Services      │───▶│ • SQLite DB     │
│ • Mobile UI     │    │ • Notifiers     │    │ • Exchange Mgr  │    │ • Memory Cache  │
│ • Desktop UI    │    │ • State         │    │ • Document Gen  │    │ • Excel Parser  │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 1.2 핵심 컴포넌트
- **Providers (Riverpod)**: 상태 관리 및 의존성 주입
  - `exchangeScreenProvider` - 교체 화면 상태
  - `servicesProvider` - 서비스 인스턴스
  - `exchangeLogicProvider` - 교체 모드 로직
  - `navigationProvider` - 네비게이션 상태
- **Services**: 비즈니스 로직 처리
  - `ExcelService` - Excel 파일 파싱
  - `ExchangeService` - 1:1 교체 로직
  - `CircularExchangeService` - 순환 교체 로직
  - `DualExchangeService` - 2중 교체 로직
- **DocumentGenerator**: PDF/QR코드 생성 (예정)
- **DatabaseManager**: SQLite 데이터 관리 (예정)

---

## 2. 데이터 구조 설계

### 2.1 TimeSlot (각 칸의 정보)
| 필드명 | 타입 | 설명 | 예시 |
|--------|------|------|------|
| teacher | String? | 교사명 | "김영희", null |
| subject | String? | 과목명 | "수학", null |
| className | String? | 학급명 | "1-1", null |

**표시 방식**: Excel과 UI에서 `className`과 `subject`를 분리하여 표시
- Excel: `1-1` (위쪽 셀), `수학` (아래쪽 셀)
- UI: `[1-1]` (위쪽), `[수학]` (아래쪽)

### 2.2 TimeTable (2차원 배열 관리)
| 필드명 | 타입 | 설명 | 예시 |
|--------|------|------|------|
| scheduleList | List<List<TimeSlot?>> | [요일][교시] 2차원 배열 | schedule[0][2] = 월요일 3교시 |
| days | int | 요일 수 (기본 5일) | 5 |
| periods | int | 교시 수 (기본 7교시) | 7 |

### 2.3 구현 코드 예시
```dart
// TimeSlot 클래스
class TimeSlot {
  String? teacher;    // 교사명: "김영희", null
  String? subject;    // 과목명: "수학", null  
  String? className;  // 학급명: "1-1", null
  
  TimeSlot({this.teacher, this.subject, this.className});
  
  bool get isEmpty => teacher == null && subject == null && className == null;
  bool get isNotEmpty => !isEmpty;
  
  // 표시용 문자열 생성 (UI에서 사용)
  String get displayText {
    if (isEmpty) return '';
    return '${className ?? ''}\n${subject ?? ''}';
  }
}

// TimeTable 클래스
class TimeTable {
  List<List<TimeSlot?>> scheduleList;  // [요일][교시] 2차원 배열
  int days;    // 요일 수 (기본 5일)
  int periods; // 교시 수 (기본 7교시)
  
  TimeTable({this.days = 5, this.periods = 7}) 
      : scheduleList = List.generate(
          days, 
          (day) => List.generate(periods, (period) => null)
        );
  
  // 특정 시간대 접근: schedule[0][2] = 월요일 3교시
  TimeSlot? getTimeSlot(int day, int period) {
    if (day < 0 || day >= days || period < 0 || period >= periods) {
      return null;
    }
    return scheduleList[day][period];
  }
  
  // 특정 시간대 설정
  void setTimeSlot(int day, int period, TimeSlot? timeSlot) {
    if (day >= 0 && day < days && period >= 0 && period < periods) {
      scheduleList[day][period] = timeSlot;
    }
  }
}
```

### 2.4 핵심 기능 설계

#### 2.3 SOLID 원칙 적용
- **단일 책임 원칙(SRP)**: 각 컴포넌트와 함수는 하나의 책임만 가집니다.
- **개방-폐쇄 원칙(OCP)**: 새로운 기능을 추가할 때 기존 코드를 수정하지 않고 확장할 수 있도록 설계합니다.
- **리스코프 치환 원칙(LSP)**: 상위 타입의 객체를 하위 타입의 객체로 대체해도 프로그램의 정확성이 유지되도록 합니다.
- **인터페이스 분리 원칙(ISP)**: 클라이언트가 사용하지 않는 인터페이스에 의존하지 않도록 합니다.
- **의존성 역전 원칙(DIP)**: 고수준 모듈이 저수준 모듈에 의존하지 않도록 추상화에 의존합니다.

#### 2.4.1 교체 알고리즘 (계획)

**1:1 직접 교체**
- 같은 요일, 같은 교시, 다른 교사, 호환 과목 찾기
- 가장 간단하고 직관적인 교체 방식

**순환 교체 (2-5명)**
- A → B → C → A 형태의 순환 교체
- BFS 알고리즘으로 경로 탐색 (구현 시 결정)

**제약 조건 (설정 가능)**
- 과목 제약: 같은 과목끼리만 vs 모든 과목 허용
- 특별실 제약: 같은 타입의 특별실끼리만
- 연강 제약: 블록타임 수업의 연속성 유지

#### 2.4.2 데이터 모델 확장

```dart
// 교체 요청 정보
class ExchangeRequest {
  int requesterId;      // 교체 요청자
  int targetId;         // 교체 대상자  
  int scheduleId;       // 교체할 수업
  int targetScheduleId; // 교체받을 수업
  String reason;        // 교체 사유
  String status;        // pending, completed, cancelled
}

// 교체 옵션
class ExchangeOption {
  int targetScheduleId;
  int targetTeacherId;
  String type;          // direct, circular
  int steps;            // 순환 교체 시 단계 수
}
```

---

## 3. 데이터베이스 설계

### 3.1 핵심 테이블 (계획)

```sql
-- 교사 정보
CREATE TABLE teacher (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    subject TEXT NOT NULL,
    department TEXT,
    phone TEXT,
    qr_code TEXT UNIQUE,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 교실 정보 (필요시)
CREATE TABLE classroom (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT DEFAULT 'general',  -- general, special
    location TEXT
);

-- 시간표
CREATE TABLE schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    teacher_id INTEGER NOT NULL,
    classroom_id INTEGER,
    subject TEXT NOT NULL,
    class_name TEXT,
    day_of_week INTEGER NOT NULL,
    period INTEGER NOT NULL,
    schedule_date DATE NOT NULL,
    is_exchanged BOOLEAN DEFAULT 0,
    original_teacher_id INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (teacher_id) REFERENCES teacher(id)
);

-- 교체 이력
CREATE TABLE exchange (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    requester_id INTEGER NOT NULL,
    target_id INTEGER NOT NULL,
    schedule_id INTEGER NOT NULL,
    target_schedule_id INTEGER NOT NULL,
    exchange_type TEXT NOT NULL,  -- direct, circular
    reason TEXT,
    status TEXT DEFAULT 'pending',
    exchange_code TEXT UNIQUE,
    requested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    FOREIGN KEY (requester_id) REFERENCES teacher(id),
    FOREIGN KEY (target_id) REFERENCES teacher(id)
);
```

### 3.2 인덱스 (성능 최적화)
```sql
-- 자주 사용하는 쿼리를 위한 인덱스
CREATE INDEX idx_schedule_teacher_date ON schedule(teacher_id, schedule_date);
CREATE INDEX idx_schedule_day_period ON schedule(day_of_week, period);
CREATE INDEX idx_exchange_requester ON exchange(requester_id);
CREATE INDEX idx_exchange_status ON exchange(status);
```

### 3.3 데이터 흐름
```
Excel 파일 (교사별 시간표) → Excel Parser → SQLite DB ← Memory Cache → UI
```

### 3.4 Excel 파일 구조 예시
```
     A      B      C      D      E      F
1  교사명    월     화     수     목     금
2  김교사   1-1    1-2    2-1    2-2    3-1
            수학    수학    수학    수학    수학
3  이교사   1-1    1-2    2-1    2-2    3-1
            국어    국어    국어    국어    국어
4  박교사   1-1    1-2    2-1    2-2    3-1
            영어    영어    영어    영어    영어
```

---

## 4. UI/UX 설계

### 4.1 메인 화면 구성

**전체 레이아웃**
```
┌─────────────────────────────────────────┐
│ Header: 로고, 설정, 도움말              │
├─────────────────────────────────────────┤
│ Navigation: 홈, 교체, 개인시간표, 출력   │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ Calendar Widget                     │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ Schedule Grid (flutter_layout_grid) │ │
│ │ 교사명    월    화    수    목    금 │ │
│ │ 김교사  [1-1]  [1-2]  [2-1]  [2-2]  │ │
│ │         [수학] [수학] [수학] [수학]  │ │
│ │ 이교사  [1-1]  [1-2]  [2-1]  [2-2]  │ │
│ │         [국어] [국어] [국어] [국어]  │ │
│ │ 박교사  [1-1]  [1-2]  [2-1]  [2-2]  │ │
│ │         [영어] [영어] [영어] [영어]  │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**시간표 그리드 구현 (flutter_layout_grid)**
- **그리드 시스템**: Excel과 동일한 행/열 구조
- **반응형 레이아웃**: 화면 크기에 따라 자동 조정
- **셀 크기**: 고정 크기 또는 유연한 크기 설정 가능
- **스크롤**: 수평/수직 스크롤 지원

### 4.2 교체 시각화 (계획)

**색상 코딩**
- 초록색: 1:1 직접 교체 가능
- 노란색: 순환 교체 필요  
- 빨간색: 교체 불가능
- 파란색: 선택된 셀

**인터랙션 플로우**
1. 시간표 셀 클릭 → 교체 가능성 표시
2. 교체 옵션 선택 → 확인 다이얼로그
3. 교체 실행 → 결과 알림

### 4.3 플랫폼별 최적화 (계획)

**모바일 (Android/iOS)**
- 터치 제스처: 핀치 줌, 스와이프 스크롤
- 반응형 레이아웃: 화면 크기별 최적화
- 네이티브 UI: Material Design 3 / Cupertino

**데스크톱 (Windows)**
- 키보드 단축키: Ctrl+Z (실행취소), Ctrl+S (저장)
- 마우스 상호작용: 우클릭 컨텍스트 메뉴
- 다중 창: 여러 시간표 동시 표시

**Windows 위젯 (선택사항)**
- 시스템 트레이: 백그라운드 실행
- 알림: 교체 요청, 완료 알림
- 빠른 접근: 더블클릭으로 메인 앱 실행

---

## 5. 구현 계획

### 5.1 개발 단계 (12주) - 계획

#### Phase 1: 핵심 기능 (4-6주)
**1-2주차: 기본 구조**
- [ ] Flutter 프로젝트 설정
- [ ] SQLite 데이터베이스 구현
- [ ] Excel 파일 파싱 기능
- [ ] 기본 UI 레이아웃

**3-4주차: 시간표 표시**
- [ ] 시간표 그리드 UI 구현
- [ ] 교사별 시간표 로드
- [ ] 기본 데이터 관리

**5-6주차: 1:1 교체**
- [ ] 1:1 직접 교체 알고리즘
- [ ] 교체 시각화 기능
- [ ] 교체 이력 저장

#### Phase 2: 고급 기능 (4-6주)
**7-8주차: 순환 교체**
- [ ] 순환 교체 알고리즘 (BFS)
- [ ] 제약 조건 검사
- [ ] 교체 옵션 최적화

**9-10주차: 문서 생성**
- [ ] PDF 문서 생성
- [ ] 결보강 계획서 템플릿
- [ ] QR코드 생성

**11-12주차: 개인 시간표**
- [ ] 개인 시간표 추출
- [ ] 교체 코드 시스템
- [ ] 실시간 업데이트

#### Phase 3: 최적화 (2-4주) - 선택사항
- [ ] Windows 위젯 (시스템 트레이)
- [ ] 성능 최적화
- [ ] 사용자 테스트 및 피드백

### 5.2 기술 스택 (계획)

**핵심 라이브러리**
```yaml
dependencies:
  flutter: sdk
  # 상태 관리
  flutter_riverpod: ^2.4.9    # 상태 관리 (Riverpod)
  # 데이터베이스
  sqflite: ^2.3.0             # SQLite 데이터베이스
  # 파일 처리
  excel: ^4.0.6               # Excel 파일 처리
  path_provider: ^2.1.1       # 파일 경로 관리
  file_picker: ^6.1.1         # 파일 선택
  # UI 컴포넌트
  flutter_layout_grid: ^2.0.6 # 시간표 그리드 레이아웃
  table_calendar: ^3.0.9      # 캘린더 위젯
  # 문서 생성
  pdf: ^3.10.7                # PDF 생성
  qr_flutter: ^4.1.0          # QR코드 생성
```

**개발 도구**
```yaml
dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^5.0.0
  mockito: ^5.4.2      # 테스트용 Mock 객체
```

### 5.3 폴더 구조 (실제 구현됨)
```
lib/
├── main.dart                              # ProviderScope 래퍼
├── models/                                # 데이터 모델
│   ├── time_slot.dart
│   ├── teacher.dart
│   ├── timetable_data.dart
│   ├── exchange_path.dart                # 추상 클래스
│   ├── one_to_one_exchange_path.dart
│   ├── circular_exchange_path.dart
│   ├── chain_exchange_path.dart
│   └── exchange_node.dart
├── providers/                             # Riverpod 상태 관리 ✅
│   ├── exchange_screen_provider.dart     # 교체 화면 상태
│   ├── services_provider.dart            # 서비스 인스턴스
│   ├── exchange_logic_provider.dart      # 교체 모드 로직
│   └── navigation_provider.dart          # 네비게이션 상태
├── services/                              # 비즈니스 로직
│   ├── excel_service.dart                # Excel 파싱
│   ├── exchange_service.dart             # 1:1 교체
│   ├── circular_exchange_service.dart    # 순환 교체
│   └── dual_exchange_service.dart       # 2중 교체
├── ui/                                    # UI 컴포넌트
│   ├── screens/                          # 화면 (ConsumerWidget)
│   │   ├── home_screen.dart             # ConsumerWidget
│   │   ├── exchange_screen.dart         # ConsumerStatefulWidget
│   │   ├── personal_schedule_screen.dart # StatelessWidget
│   │   ├── document_screen.dart         # StatelessWidget
│   │   └── settings_screen.dart         # StatelessWidget
│   ├── widgets/
│   │   ├── unified_exchange_sidebar.dart # StatefulWidget (애니메이션)
│   │   ├── timetable_grid_section.dart  # StatefulWidget (스크롤)
│   │   └── exchange_filter_widget.dart
│   └── mixins/                           # Mixin (Provider 기반)
│       ├── exchange_mode_handler.dart
│       ├── exchange_logic_mixin.dart
│       └── ...
└── utils/                                 # 유틸리티
    ├── constants.dart
    ├── logger.dart
    ├── exchange_algorithm.dart
    ├── exchange_visualizer.dart
    └── timetable_data_source.dart
```

---

## 6. 핵심 설계 원칙 (계획)

### 6.1 기본 원칙
- **단순함 우선**: 복잡한 추상화보다 실용적 접근
- **점진적 개선**: 기본 기능부터 단계별 확장
- **유연성**: 요구사항 변경에 쉽게 대응

### 6.2 상태 관리 (Riverpod) - 필수 규칙
- **전체 애플리케이션 상태는 Riverpod로 관리**
- **Provider 패턴**:
  - `StateNotifierProvider` - 복잡한 상태 (30+ 변수)
  - `StateProvider` - 간단한 상태 (단일 값)
  - `Provider` - 서비스 인스턴스
- **UI 컴포넌트**:
  - 상태가 있으면 `ConsumerWidget` 또는 `ConsumerStatefulWidget`
  - 상태가 없으면 `StatelessWidget`
  - `setState()` 사용 금지 (로컬 UI 상태 제외)
- **상태 접근**:
  - `ref.watch()` - 반응형 UI 업데이트
  - `ref.read()` - 일회성 상태 접근
  - `ref.listen()` - 상태 변경 리스너
- **의존성 주입**: 서비스와 저장소의 자동 주입
- **캐싱**: 자동 캐싱으로 성능 최적화
- **테스트**: Provider 오버라이드로 쉬운 테스트
- **허용되는 StatefulWidget**:
  - 애니메이션 컨트롤러 관리
  - 스크롤 컨트롤러 관리
  - 기타 순수 UI 로컬 상태

### 6.3 성능 고려사항
- **메모리 관리**: 불필요한 데이터 로딩 방지
- **데이터베이스**: 인덱스 활용으로 쿼리 최적화
- **UI 반응성**: 교체 시뮬레이션은 실시간 처리

### 6.4 보안 및 안정성
- **데이터 무결성**: 트랜잭션 기반 교체 처리
- **오류 처리**: 사용자 친화적 오류 메시지
- **오프라인 우선**: 인터넷 없이 모든 기능 사용

### 6.5 개발 가이드라인
- **코드 가독성**: 명확한 변수명과 주석
- **모듈화**: 기능별로 독립적인 클래스 구성
- **테스트**: 핵심 로직에 대한 단위 테스트

---

## 📝 핵심 요약

이 설계는 **교사용 시간표 교체 프로그램**의 실용적인 구현 방향을 제시합니다.

**주요 특징:**
- ✅ Excel 파일 완전 호환
- ✅ 1:1 및 순환 교체 지원
- ✅ 실시간 시각화
- ✅ PDF/QR코드 자동 생성
- ✅ 오프라인 우선 설계
- ✅ 플랫폼 통합 (모바일/데스크톱/위젯)

**개발 우선순위:**
1. **Phase 1**: Excel 파싱 + 1:1 교체 (핵심 기능)
2. **Phase 2**: 순환 교체 + 문서 생성 (고급 기능)
3. **Phase 3**: Windows 위젯 + 최적화 (선택사항)

**계획 단계 특성:**
- 🔄 **유연한 설계**: 개발 과정에서 요구사항 변경에 대응
- 📝 **실용적 접근**: 과도한 추상화보다는 바로 구현 가능한 수준
- 🚀 **점진적 개발**: 기본 기능부터 단계별로 확장

이 설계를 바탕으로 **실제 개발하면서 필요한 부분을 상세화**해나가면 요구사항을 만족하는 고품질 애플리케이션을 구현할 수 있습니다.
