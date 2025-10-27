# 엑셀 템플릿 서비스 - 구현 요약

## 📋 개요

**엑셀 파일의 서식을 읽어서 관리하는 시스템**을 구현했습니다. 이를 통해:

1. ✅ **기존 엑셀 파일을 템플릿으로 읽기** - 셀, 병합, 스타일 정보 추출
2. ✅ **테이블 테그 자동 감지** - `date`, `day`, `date(day)` 등 테그 위치 파악
3. ✅ **상태 관리** - 프로바이더로 앱 전역에서 접근 가능
4. ✅ **향후 출력 작업 준비** - 추출된 템플릿 정보로 데이터 채우기 가능

---

## 🗂️ 생성된 파일

### 1. 서비스 파일: `lib/services/excel_template_service.dart`

**역할**: 엑셀 파일 읽기 및 템플릿 정보 추출

**핵심 클래스**:
- `ExcelTemplateService` - 싱글톤 서비스
- `ExcelTemplateInfo` - 템플릿 정보 (워크시트, 셀, 테그 위치)
- `CellInfo` - 셀 정보 (행, 열, 값, 스타일)
- `CellStyleInfo` - 셀 스타일 (폰트, 색상, 정렬)
- `CellLocation` - 셀 위치

**주요 메서드**:
```dart
// 파일 선택 및 템플릿 추출
Future<ExcelTemplateInfo?> pickAndExtractTemplate()

// 특정 파일 템플릿 추출
Future<ExcelTemplateInfo?> extractTemplateInfo(File templateFile)

// 템플릿 정보 저장
Future<bool> saveTemplateInfo(ExcelTemplateInfo info, String filePath)
```

**특징**:
- 자동 테그 감지 (`date`, `day`, `date(day)` 등)
- 모든 셀 정보 추출
- 에러 처리 및 로깅
- 없는 API 호출 제거 (maxCols, mergedCells 등)

---

### 2. 상태 관리: `lib/providers/substitution_plan_viewmodel.dart` (수정)

**추가된 클래스**:
- `ExcelTemplateNotifier` - 템플릿 상태 관리
- `excelTemplateProvider` - 앱 전역 프로바이더

**상태 관리 메서드**:
```dart
// 템플릿 설정
void setTemplate(ExcelTemplateInfo template)

// 템플릿 초기화
void clearTemplate()

// 파일에서 템플릿 로드
Future<bool> loadTemplateFromFile(String filePath)
```

**사용 예시**:
```dart
// 조회
final template = ref.watch(excelTemplateProvider);

// 설정
ref.read(excelTemplateProvider.notifier).setTemplate(info);

// 초기화
ref.read(excelTemplateProvider.notifier).clearTemplate();
```

---

### 3. 문서: `docs/excel_template_usage.md`

**내용**:
- 📖 상세 사용 가이드
- 🎯 실제 사용 예시
- 📊 데이터 구조 설명
- 🔧 API 참조
- ❓ 문제 해결

---

## 🚀 사용 방법

### 단계 1: 템플릿 파일 로드

```dart
// 파일 선택 다이얼로그
ExcelTemplateInfo? info = await ExcelTemplateService().pickAndExtractTemplate();

// 또는 특정 파일 지정
File file = File('path/to/template.xlsx');
ExcelTemplateInfo? info = await ExcelTemplateService().extractTemplateInfo(file);
```

### 단계 2: 프로바이더에 저장

```dart
if (info != null) {
  ref.read(excelTemplateProvider.notifier).setTemplate(info);
}
```

### 단계 3: 어디서든 접근

```dart
// 어느 위젯에서든
final template = ref.watch(excelTemplateProvider);

// 테그 위치 확인
print(template?.tagLocations);
// {date: CellLocation(row: 0, col: 0), day: CellLocation(row: 0, col: 1), ...}
```

---

## 📊 데이터 흐름

```
엑셀 파일 (.xlsx)
    ↓
ExcelTemplateService.pickAndExtractTemplate()
    ↓
ExcelTemplateInfo 추출
  ├─ 워크시트 이름
  ├─ 모든 셀 정보
  ├─ 테그 위치 → {date: (0,0), day: (0,1), ...}
  └─ 메타데이터
    ↓
excelTemplateProvider로 상태 관리
    ↓
앱 전역에서 접근 가능
    ↓
향후 데이터 출력 시 사용
```

---

## 🎯 향후 사용 시나리오

### 시나리오 1: 결보강 계획서 내보내기

```dart
// 템플릿 로드
final template = ref.watch(excelTemplateProvider);

if (template != null) {
  // 1. 테그 위치 파악
  final dateLocation = template.tagLocations['date'];
  final dayLocation = template.tagLocations['day'];
  // ...
  
  // 2. 각 위치에 데이터 채우기
  // sheet.cell(CellIndex.indexByColumnRow(
  //   columnIndex: dateLocation.col,
  //   rowIndex: dateLocation.row
  // )).value = '2024-01-15';
  
  // 3. 파일 저장
}
```

### 시나리오 2: 동적 UI 생성

```dart
// 템플릿의 테그를 기반으로 입력 필드 자동 생성
if (template != null) {
  for (final tagName in template.tagLocations.keys) {
    print('$tagName 입력 필드 생성');
    // TextField(label: tagName)
  }
}
```

---

## 📝 템플릿 파일 요구사항

### 파일 구조

엑셀 파일의 **첫 번째 행**에 다음 테그 중 하나 이상 포함:

```
| date     | day  | period | grade | class | subject | teacher | remarks |
|----------|------|--------|-------|-------|---------|---------|---------|
| 결강일   | 요일 | 교시   | 학년  | 반    | 과목    | 교사    | 비고    |
```

### 지원하는 테그

```
단순 형식:
  date, day, period, grade, class, subject, teacher
  subject2, teacher2
  date3, day3, period3, subject3, teacher3
  remarks

복합 형식 (괄호 포함):
  date(day), date3(day3)
  period(기간) 등
```

---

## 🔍 핵심 기능

### 1. 테그 인식

```dart
// 단순 테그
bool _isTagName('date')           // ✅ true
bool _isTagName('day')            // ✅ true

// 복합 테그
bool _isTagName('date(day)')      // ✅ true
bool _isTagName('date3(day3)')    // ✅ true
```

### 2. 위치 매핑

```dart
// 테그 → 셀 위치
template.tagLocations['date']
// → CellLocation(row: 0, col: 0)

template.tagLocations['day']
// → CellLocation(row: 0, col: 1)
```

### 3. 상태 관리

```dart
// 앱 시작
template = null

// 템플릿 로드
setTemplate(info)
template = info

// 템플릿 변경
clearTemplate()
template = null
```

---

## 🛠️ 기술 사항

### 사용 라이브러리

- `excel: ^4.0.6` - 엑셀 파일 읽기/쓰기
- `file_picker: ^6.1.1` - 파일 선택 다이얼로그
- `flutter_riverpod: ^2.4.9` - 상태 관리

### API 설계

- **싱글톤 패턴**: `ExcelTemplateService` (메모리 효율)
- **StateNotifier**: 상태 관리 (반응형)
- **팩토리 생성자**: 제네릭 변환 (`toMap()`, `fromMap()`)

### 에러 처리

- 파일 존재 여부 확인
- 워크시트 존재 확인
- 셀 읽기 예외 처리
- 로깅으로 디버깅 지원

---

## ✅ 체크리스트

- ✅ 엑셀 템플릿 서비스 구현
- ✅ 상태 관리 (Provider) 구현
- ✅ 테그 감지 (단순 & 복합 형식)
- ✅ linter 에러 제거
- ✅ 상세 문서 작성
- ⏳ 다음: 데이터 출력 기능 구현

---

## 📞 다음 단계

1. **데이터 출력 로직**: `ExcelTemplateInfo`를 사용하여 실제 데이터 채우기
2. **UI 통합**: `file_export_widget.dart`에서 템플릿 선택 및 출력 연결
3. **테스트**: 다양한 템플릿 파일로 테스트

---

## 💡 참고

- 템플릿 정보는 **프로바이더를 통해 글로벌 상태**로 관리됩니다.
- 각 셀의 **정확한 위치** (행, 열)를 추출하므로 정확한 데이터 배치 가능합니다.
- **확장 가능한 구조**로 향후 더 많은 기능 추가 가능합니다.
