# HWPX 문서 수정 방법

## 📋 개요

본 문서는 **수업 교체 도우미** 앱에서 HWPX(한글 Open XML) 문서를 자동으로 채워 출력하는 방법을 정리합니다.

현재 앱은 PDF 양식(`Syncfusion`) + AcroForm 필드 방식으로 결보강 계획서를 출력합니다. HWPX 출력을 검토할 때, **Flutter만으로 구현 가능한 가장 단순한 방법**은 **플레이스홀더(`{{필드명}}`) + ZIP/XML 문자열 치환**입니다.

**핵심 개념:**

- HWPX 파일은 내부적으로 **ZIP + XML(OWPML)** 구조입니다.
- 한컴 **누름틀(필드) API**를 Dart에서 직접 호출하는 공식 패키지는 **없습니다**.
- 대신 템플릿에 `{{date.0}}` 같은 **고정 문자열**을 넣고, Flutter에서 XML 안의 해당 문자열만 바꿉니다.
- 기존 PDF 필드명 규칙(`date.0`, `teacher.0` 등)을 **그대로 재사용**할 수 있습니다.

**관련 코드 (현재 PDF 방식):**

| 구분 | 파일 |
|------|------|
| PDF 필드/컬럼 정의 | `lib/utils/pdf_field_config.dart` |
| PDF 내보내기 서비스 | `lib/services/pdf_export_service.dart` |
| PDF 양식 제작 가이드 | `lib/assets/docs/pdf_form_guide.md` |

---

## 1. 방식 비교 (결론)

| 방식 | Flutter만으로 가능? | 난이도 | 비고 |
|------|---------------------|--------|------|
| 한컴 **누름틀(필드)** — `PutFieldText` 등 | ❌ 불가 | 높음 | Dart/HWPX 전용 라이브러리 없음 |
| **플레이스홀더** `{{date.0}}` + ZIP/XML 치환 | ✅ 가능 | **낮음** | **본 문서의 추천 방식** |
| Node + `@rhwp/editor` | ✅ 가능 | 중 | rhwp hwpctl API 사용 |
| Python + `python-hwpx` | ✅ 가능 | 중 | CLI/스크립트 연동 |

**가장 간단한 Flutter 방식 = 필드 API가 아니라 문자열 치환입니다.**

---

## 2. 왜 Flutter가 “누름틀”을 직접 못 바꾸나?

HWPX 안의 **누름틀(필드)** 은 화면에 보이는 plain text가 아니라 **OWPML XML 요소**로 저장됩니다.

```
example.hwpx  (실제로는 ZIP 파일)
├── Contents/
│   ├── content.hpf
│   ├── section0.xml      ← 본문
│   ├── header.xml        ← 머리글 (있을 경우)
│   └── footer.xml        ← 바닥글 (있을 경우)
├── styles.xml
├── META-INF/
│   └── manifest.xml
└── (이미지 등 BinData/)
```

PDF의 AcroForm처럼 `field.name = 'date.0'` 한 줄로 값을 넣으려면 **HWPX 파서/편집 라이브러리**가 필요합니다. pub.dev에는 HWPX 생성·필드 편집용 **Dart 패ackage가 없습니다.**

| 포맷 | Flutter 처리 |
|------|--------------|
| PDF + AcroForm | ✅ `syncfusion_flutter_pdf` |
| HWPX + 누름틀 | ❌ 전용 Dart 라이브러리 없음 |
| HWPX + `{{placeholder}}` | ✅ `archive` 패키지로 ZIP/XML 치환 |

---

## 3. 추천 방식: 플레이스홀더 치환

### 3.1 아이디어

1. 한/글에서 결보강 계획서 **HWPX 템플릿**을 만듭니다.
2. 데이터를 넣을 칸에 **일반 텍스트**로 플레이스홀더를 입력합니다.
3. Flutter 앱이 `.hwpx`(ZIP)를 열어 XML 파일에서 `{{키}}` 문자열만 실제 값으로 바꿉니다.
4. 수정된 내용을 다시 ZIP으로 묶어 `.hwpx`로 저장합니다.

**치환 예시:**

| 템플릿 (입력) | 출력 (치환 후) |
|---------------|----------------|
| `{{date.0}}` | `2026-05-27` |
| `{{teacher.0}}` | `홍길동` |
| `{{subject.0}}` | `수학` |

### 3.2 PDF 방식과의 대응

| | PDF (현재) | HWPX (플레이스홀더) |
|--|-----------|---------------------|
| 템플릿 | `.pdf` + AcroForm 필드 | `.hwpx` + `{{placeholder}}` |
| 필드명 예 | `date.0`, `teacher.0` | `{{date.0}}`, `{{teacher.0}}` |
| Flutter 처리 | `PdfExportService` | `SimpleHwpxExportService` (구현 예정) |
| 외부 런타임 | 없음 | **없음** |
| 서식 유지 | ✅ | ✅ (치환만 하면 대부분 유지) |

### 3.3 프로젝트 필드명 (`kPdfTableColumns`)

HWPX 템플릿에도 아래 키를 그대로 사용할 수 있습니다. (`lib/utils/pdf_field_config.dart` 기준)

| 컬럼 키 | 플레이스홀더 예 (0행) |
|---------|----------------------|
| `date` | `{{date.0}}` |
| `day` | `{{day.0}}` |
| `period` | `{{period.0}}` |
| `grade` | `{{grade.0}}` |
| `class` | `{{class.0}}` |
| `subject` | `{{subject.0}}` |
| `teacher` | `{{teacher.0}}` |
| `2subject` | `{{2subject.0}}` |
| `2teacher` | `{{2teacher.0}}` |
| `3date` | `{{3date.0}}` |
| `3day` | `{{3day.0}}` |
| `3period` | `{{3period.0}}` |
| `3subject` | `{{3subject.0}}` |
| `3teacher` | `{{3teacher.0}}` |
| `remarks` | `{{remarks.0}}` |

여러 행이 있으면 행 인덱스를 `.0`, `.1`, `.2` … 로 붙입니다. (PDF AcroForm 필드명 규칙과 동일)

---

## 4. HWPX 템플릿 제작 방법 (한/글)

### 4.1 기본 절차

1. 한/글에서 결보강 계획서 양식을 작성합니다.
2. 자동으로 채울 칸에 **누름틀 대신** 아래처럼 **일반 텍스트**를 입력합니다.
   - 예: `{{date.0}}`, `{{teacher.0}}`
3. **`.hwpx` 형식**으로 저장합니다.
4. 한/글에서 템플릿을 다시 열어 레이아웃·글자 크기를 확인합니다.
5. Flutter로 샘플 데이터 치환 후, 한/글에서 **결과 파일**을 열어 최종 검증합니다.

### 4.2 작성 시 권장 사항

- 플레이스홀더는 **한 덩어리로** 입력합니다. (나중에 XML 분할 이슈 방지)
- 칸 너비는 **실제 출력값보다 넉넉히** 잡습니다.
- 표 셀·머리글·바닥글에도 같은 규칙의 `{{키}}`를 사용할 수 있습니다.
- 암호가 걸린 HWPX는 이 방식으로 **처리할 수 없습니다.**

### 4.3 누름틀 vs 플레이스홀더

| | 한컴 누름틀(필드) | `{{placeholder}}` |
|--|------------------|-------------------|
| Flutter에서 직접 수정 | ❌ | ✅ |
| 한/글 필드 기능(탭 이동 등) | ✅ | ❌ |
| 자동화 구현 난이도 | 높음 (외부 라이브러리) | **낮음** |
| 결보강 계획서 출력용 | 가능 | **충분한 경우 많음** |

---

## 5. Flutter 구현 가이드

### 5.1 의존성

`pubspec.yaml`에 ZIP 처리 패키지를 추가합니다.

```yaml
dependencies:
  archive: ^4.0.0
```

### 5.2 서비스 예시 (`SimpleHwpxExportService`)

아래 코드는 **개념·PoC용**입니다. 실제 프로젝트에 넣을 때는 `lib/services/` 아래 별도 파일로 분리하는 것을 권장합니다.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

/// HWPX 템플릿의 {{키}} 플레이스홀더만 치환 (Flutter 단독)
class SimpleHwpxExportService {
  /// [templatePath] 원본 .hwpx 경로
  /// [fields] 치환할 값 (키: date.0, 값: 2026-05-27)
  /// [outputPath] 저장할 .hwpx 경로
  static Future<void> fillTemplate({
    required String templatePath,
    required Map<String, String> fields,
    required String outputPath,
  }) async {
    // 1) hwpx = zip 파일
    final bytes = await File(templatePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 2) XML/HPF 항목만 치환, 나머지(이미지 등)는 그대로 유지
    final updatedFiles = <ArchiveFile>[];

    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }

      final name = file.name;
      final isTextPart = name.endsWith('.xml') || name.endsWith('.hpf');

      if (!isTextPart) {
        updatedFiles.add(file);
        continue;
      }

      var content = utf8.decode(file.content as List<int>);

      fields.forEach((key, value) {
        content = content.replaceAll('{{$key}}', _escapeXml(value));
      });

      updatedFiles.add(
        ArchiveFile(name, content.length, content.codeUnits),
      );
    }

    // 3) 다시 hwpx(zip)로 저장
    final encoder = ZipEncoder();
    final outBytes = encoder.encode(Archive(updatedFiles));
    if (outBytes == null) {
      throw StateError('HWPX 인코딩 실패');
    }
    await File(outputPath).writeAsBytes(outBytes);
  }

  /// XML 특수문자 이스케이프
  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
```

### 5.3 호출 예시

```dart
await SimpleHwpxExportService.fillTemplate(
  templatePath: r'C:\templates\substitution_plan.hwpx',
  fields: {
    'date.0': '2026-05-27',
    'day.0': '화',
    'teacher.0': '홍길동',
    'subject.0': '수학',
  },
  outputPath: r'C:\output\substitution_plan_filled.hwpx',
);
```

### 5.4 PDF 서비스와의 연동 아이디어

`PdfExportService`가 `planData`와 `kPdfTableColumns`로 필드 맵을 만드는 것처럼, HWPX용 서비스도 **동일한 필드명 규칙**을 재사용하면 UI·데이터 계층 변경을 최소화할 수 있습니다.

```
교체 데이터 (SubstitutionPlan)
        ↓
공통 필드 맵 생성  { 'date.0': '...', 'teacher.0': '...' }
        ↓
    ┌───────────────┬────────────────────┐
    │ PdfExport     │ SimpleHwpxExport   │
    │ Service       │ Service            │
    └───────────────┴────────────────────┘
         ↓                    ↓
      .pdf                 .hwpx
```

---

## 6. 처리 흐름 (다이어그램)

```
[한/글] 템플릿 제작 ({{date.0}} 등)
        ↓
[Flutter] template.hwpx 로드 (ZIP 디코드)
        ↓
[Flutter] Contents/*.xml, *.hpf 순회
        ↓
[Flutter] {{키}} → 실제 값 치환 (+ XML 이스케이프)
        ↓
[Flutter] ZIP 재압축 → output.hwpx 저장
        ↓
[한/글 / HOP] 결과 파일 열어 검증
```

---

## 7. 주의사항 및 제한

### 7.1 XML에서 텍스트가 쪼개질 수 있음

한/글이 `{{date.0}}`을 XML **여러 `<hp:t>` 노드**로 나누면, 단순 `replaceAll`이 **실패**할 수 있습니다.

**대응:**

- 템플릿 작성 후 반드시 **치환 테스트**를 수행합니다.
- 실패 시 플레이스홀더 문자열을 짧게 하거나, 한/글에서 해당 구간을 다시 입력합니다.
- 고급 대안: Python `python-hwpx`, Node `rhwp` 등 **전용 라이브러리** 검토.

### 7.2 표·머리글·바닥글

`.xml` 및 `.hpf` 확장자 파일을 순회하면 본문 외 영역도 치환됩니다. 템플릿마다 경로가 다를 수 있으므로, **실제 파일 구조**를 한 번 확인하는 것이 좋습니다.

### 7.3 암호화·손상 파일

- 암호가 설정된 HWPX: **불가**
- 비표준/손상 ZIP: `ZipDecoder` 단계에서 오류 가능

### 7.4 미리보기

Flutter용 **HWPX 네이티브 뷰어 패키지는 없습니다.** 미리보기 옵션은 별도 검토가 필요합니다.

| 방법 | 앱 내 미리보기 | 비고 |
|------|----------------|------|
| PDF 변환 후 `PdfPreviewScreen` | ✅ | 기존 UI 재사용 |
| HOP/한/글로 외부 실행 | △ | 구현 간단 |
| HTML + WebView | ✅ | 레이아웃 fidelity 제한 |

---

## 8. 대안 (Flutter-only가 아닌 경우)

플레이스홀더 방식으로 해결되지 않거나, **진짜 누름틀**을 유지해야 할 때 참고합니다.

| 도구 | 용도 | 링크 |
|------|------|------|
| `python-hwpx` | HWPX 읽기/쓰기, 필드·표 편집 | [GitHub](https://github.com/airmang/python-hwpx) |
| `@rhwp/editor` | hwpctl `PutFieldText`, `exportHwpx()` | [npm](https://www.npmjs.com/package/@rhwp/editor) |
| HOP | HWP/HWPX 데스크톱 뷰어/편집기 (앱 임베드 아님) | [GitHub](https://github.com/golbin/hop) |
| 한컴 한글 SDK | 상용, 공식 HWP/HWPX API | [한컴 SDK](https://hancom.com/product/sdk/hwpSdk) |

---

## 9. PoC 체크리스트

- [ ] 한/글에서 `.hwpx` 템플릿 제작 (`{{date.0}}` 등)
- [ ] `archive` 패키지 추가
- [ ] `SimpleHwpxExportService` 구현 및 단위 테스트
- [ ] 필드 1~2개만 치환 후 한/글에서 열기
- [ ] `kPdfTableColumns` 전체 행 치환 테스트
- [ ] 표·머리글 영역 치환 확인
- [ ] (선택) PDF 출력과 HWPX 출력 병행 여부 결정

---

## 10. FAQ

### Q. PDF 대신 HWPX만 쓰면 되나요?

학교·교육청 환경에 따라 **제출 포맷이 HWP/HWPX**인 경우가 있습니다. 앱에서는 PDF(미리보기·인쇄)와 HWPX(제출용)를 **병행**하는 구성도 가능합니다.

### Q. `{{date.0}}` 대신 `{date.0}` 한 중괄호를 써도 되나요?

가능합니다. 다만 **템플릿과 코드의 규칙을 하나로 통일**해야 합니다. 본 문서는 `{{키}}` 형식을 기준으로 합니다.

### Q. Node/rhwp PoC와 이 방식 중 무엇을 먼저 할까요?

**Flutter + placeholder + archive** 를 먼저 시험하는 것을 권장합니다. 의존성이 없고, 현재 PDF 필드명과도 잘 맞습니다.

---

## 11. 참고 자료

- [HWPX 포맷 구조 (한컴)](https://tech.hancom.com/hwpxformat/)
- [rhwp — Rust + WASM HWP/HWPX 엔진](https://github.com/edwardkim/rhwp)
- [HOP — Open HWP 데스크톱 앱](https://github.com/golbin/hop)
- [python-hwpx](https://github.com/airmang/python-hwpx)
- 프로젝트 PDF 양식 가이드: `lib/assets/docs/pdf_form_guide.md`

---

**문서 버전:** 1.0  
**작성 목적:** HWPX 출력 PoC — Flutter 단독 플레이스홀더 치환 방식 정리  
**최종 업데이트:** 2026-05-27
