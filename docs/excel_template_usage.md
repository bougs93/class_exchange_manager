# 엑셀 템플릿 서비스 사용 가이드

## 개요

`ExcelTemplateService`는 기존 엑셀 파일을 읽어서 **템플릿 정보를 추출**하고, 나중에 이 템플릿을 사용해서 데이터를 채운 엑셀 파일을 생성할 수 있는 서비스입니다.

### 주요 기능

- ✅ 엑셀 파일 읽기 (`.xlsx` 형식)
- ✅ 템플릿 구조 분석 (셀, 병합 정보 등)
- ✅ 테이블 테그 위치 자동 감지 (예: `date`, `day`, `date(day)` 등)
- ✅ 템플릿 정보 저장/불러오기 (JSON 형식)
- ✅ 프로바이더를 통한 상태 관리

---

## 사용 흐름

### 1단계: 템플릿 파일 읽기

#### 방법 1: 파일 선택 다이얼로그로 선택 (권장)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lib/services/excel_template_service.dart';

// 파일 선택 후 템플릿 정보 추출
ExcelTemplateInfo? info = await ExcelTemplateService().pickAndExtractTemplate();

if (info != null) {
  // 템플릿 정보 추출 성공
  print('워크시트: ${info.sheetName}');
} else {
  // 사용자가 파일 선택을 취소하거나 오류 발생
  print('템플릿 로드 실패');
}
```

#### 방법 2: 특정 파일 직접 지정

```dart
import 'dart:io';
import 'lib/services/excel_template_service.dart';

File templateFile = File('path/to/template.xlsx');
ExcelTemplateInfo? info = await ExcelTemplateService().extractTemplateInfo(templateFile);

if (info != null) {
  print('템플릿 로드 성공!');
}
```

---

### 2단계: 템플릿 정보 확인

```dart
if (info != null) {
  // 워크시트 이름
  print('워크시트: ${info.sheetName}');
  
  // 테그 위치 확인
  // 예: {date: CellLocation(row: 0, col: 0), day: CellLocation(row: 0, col: 1), ...}
  print('테그 위치: ${info.tagLocations}');
  
  // 셀 개수 확인
  print('총 셀 개수: ${info.cells.length}');
  
  // 최대 행/열 확인
  print('최대 행: ${info.maxRows}, 최대 열: ${info.maxCols}');
  
  // 개별 셀 정보 확인
  for (final cell in info.cells) {
    print('셀 (${cell.row}, ${cell.col}): ${cell.value}');
  }
}
```

---

### 3단계: 프로바이더를 통한 상태 관리 (추천)

#### 위젯에서 사용

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lib/providers/substitution_plan_viewmodel.dart';
import 'lib/services/excel_template_service.dart';

class TemplateSelectionWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(excelTemplateProvider);
    
    return Column(
      children: [
        if (template == null)
          ElevatedButton(
            onPressed: () async {
              // 템플릿 파일 선택
              final info = await ExcelTemplateService().pickAndExtractTemplate();
              if (info != null) {
                // 프로바이더에 설정
                ref.read(excelTemplateProvider.notifier).setTemplate(info);
              }
            },
            child: const Text('템플릿 파일 선택'),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('선택된 워크시트: ${template.sheetName}'),
              Text('테그 개수: ${template.tagLocations.length}'),
              ElevatedButton(
                onPressed: () {
                  // 템플릿 초기화
                  ref.read(excelTemplateProvider.notifier).clearTemplate();
                },
                child: const Text('템플릿 변경'),
              ),
            ],
          ),
      ],
    );
  }
}
```

#### 상태 업데이트

```dart
// 템플릿 설정
ref.read(excelTemplateProvider.notifier).setTemplate(templateInfo);

// 템플릿 초기화
ref.read(excelTemplateProvider.notifier).clearTemplate();

// 파일 경로로 직접 로드
bool success = await ref.read(excelTemplateProvider.notifier)
    .loadTemplateFromFile('path/to/template.xlsx');
```

---

## 템플릿 파일 요구사항

### 지원 형식

- **파일 형식**: `.xlsx` (Excel 2007 이상)
- **구조**: 첫 번째 워크시트가 사용됨

### 테그 정의

템플릿 파일의 **첫 번째 행에 테그를 포함**해야 합니다:

#### 단순 형식 (권장)

```
date      day   period   grade  class   subject   teacher   remarks
결강일    요일   교시    학년   반     과목     교사      비고
```

#### 복합 형식 (괄호 포함)

```
date(day)        date3(day3)          period3
결강일(요일)     교체일(교체요일)     교체교시
```

### 지원하는 테그 목록

#### 결강 관련
- `date` - 결강일
- `day` - 결강 요일
- `period` - 교시
- `grade` - 학년
- `class` - 반
- `subject` - 과목
- `teacher` - 교사

#### 보강/수업변경 관련
- `subject2` - 보강/수업변경 과목
- `teacher2` - 보강/수업변경 교사 성명

#### 수업 교체 관련
- `date3` - 교체일
- `day3` - 교체 요일
- `period3` - 교체 교시
- `subject3` - 교체 과목
- `teacher3` - 교체 교사

#### 기타
- `remarks` - 비고

---

## 데이터 구조

### ExcelTemplateInfo

```dart
class ExcelTemplateInfo {
  /// 워크시트 이름
  final String sheetName;
  
  /// 모든 셀 정보 리스트
  final List<CellInfo> cells;
  
  /// 병합된 셀 정보 리스트
  final List<MergedCellInfo> mergedCells;
  
  /// 최대 행 수
  final int maxRows;
  
  /// 최대 열 수
  final int maxCols;
  
  /// 테이블 테그 위치 정보
  /// 예: {date: CellLocation(row: 0, col: 0), ...}
  final Map<String, CellLocation> tagLocations;
}
```

### CellInfo

```dart
class CellInfo {
  /// 행 번호 (0부터 시작)
  final int row;
  
  /// 열 번호 (0부터 시작)
  final int col;
  
  /// 셀 값
  final dynamic value;
  
  /// 셀 스타일 정보
  final CellStyleInfo? style;
}
```

### CellLocation

```dart
class CellLocation {
  final int row;  // 행 번호 (0부터 시작)
  final int col;  // 열 번호 (0부터 시작)
}
```

---

## 실제 사용 예시

### 예시 1: 템플릿 로드 및 테그 위치 확인

```dart
Future<void> loadAndPrintTemplate() async {
  final service = ExcelTemplateService();
  
  // 1. 파일 선택
  final info = await service.pickAndExtractTemplate();
  
  if (info != null) {
    // 2. 테그 위치 확인
    for (final entry in info.tagLocations.entries) {
      final tagName = entry.key;
      final location = entry.value;
      print('$tagName: (행 ${location.row}, 열 ${location.col})');
    }
    
    // 출력 예:
    // date: (행 0, 열 0)
    // day: (행 0, 열 1)
    // period: (행 0, 열 2)
    // ...
  }
}
```

### 예시 2: 프로바이더를 통한 자동 상태 관리

```dart
class FileExportWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(excelTemplateProvider);
    
    return Column(
      children: [
        // 템플릿 선택 버튼
        ElevatedButton(
          onPressed: () async {
            final info = await ExcelTemplateService().pickAndExtractTemplate();
            if (info != null) {
              ref.read(excelTemplateProvider.notifier).setTemplate(info);
            }
          },
          child: const Text('템플릿 선택'),
        ),
        
        // 템플릿 정보 표시
        if (template != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('워크시트: ${template.sheetName}'),
              Text('인식된 테그: ${template.tagLocations.keys.join(", ")}'),
              
              // 내보내기 버튼 (템플릿이 선택된 경우에만)
              ElevatedButton(
                onPressed: () => _exportWithTemplate(context, template),
                child: const Text('데이터 내보내기'),
              ),
            ],
          ),
      ],
    );
  }
  
  void _exportWithTemplate(BuildContext context, ExcelTemplateInfo template) {
    // 템플릿 정보를 사용하여 데이터 내보내기
    // (다음 단계에서 구현)
  }
}
```

---

## 다음 단계

이 템플릿 서비스로 추출한 **ExcelTemplateInfo**는 다음 용도로 사용됩니다:

1. **출력 작업**: 템플릿 구조에 맞춰 실제 데이터를 채우기
2. **검증**: 데이터의 올바른 위치 확인
3. **UI 생성**: 테그 위치를 기반으로 동적 UI 생성

---

## 문제 해결

### 템플릿이 인식되지 않음

- ✅ 파일이 `.xlsx` 형식인지 확인
- ✅ 첫 번째 행에 테그가 있는지 확인
- ✅ 테그 이름이 정확한지 확인 (대소문자 구분 안 함)

### 특정 테그가 발견되지 않음

- ✅ 테그가 첫 번째 행에 있는지 확인
- ✅ 테그 이름이 정확한지 확인 (`date`, `day`, `date(day)` 등)
- ✅ 추가 테그가 필요한 경우 `_isTagName` 메서드 수정

---

## API 참조

### ExcelTemplateService

```dart
// 싱글톤 인스턴스 생성
final service = ExcelTemplateService();

// 메서드들
Future<ExcelTemplateInfo?> extractTemplateInfo(File templateFile)
Future<ExcelTemplateInfo?> pickAndExtractTemplate()
Future<bool> saveTemplateInfo(ExcelTemplateInfo info, String filePath)
```

### ExcelTemplateNotifier (Provider)

```dart
// 프로바이더 접근
ref.read(excelTemplateProvider)  // 현재 템플릿 정보 조회
ref.watch(excelTemplateProvider) // 템플릿 변경 감시

// 메서드들
void setTemplate(ExcelTemplateInfo template)
void clearTemplate()
Future<bool> loadTemplateFromFile(String filePath)
```

---

## 참고 사항

- 템플릿 정보는 **프로바이더를 통해 앱 전역에서 공유**됩니다.
- 대용량 엑셀 파일의 경우 로딩 시간이 소요될 수 있습니다.
- 추출된 템플릿 정보는 메모리에만 저장되므로, 필요시 JSON으로 저장해야 합니다.
