# PDF 한글 폰트 설정 가이드

## 문제
dart_pdf 패키지는 기본적으로 Helvetica 폰트를 사용하는데, 이 폰트는 한글을 지원하지 않습니다.

## 해결 방법

### 1. 한글 폰트 파일 다운로드
다음 중 하나를 다운로드하세요:
- Noto Sans KR: https://fonts.google.com/noto/specimen/Noto+Sans+KR
- 나눔고딕: https://hangeul.naver.com/font

### 2. 폰트 파일 배치
다운로드한 TTF 파일을 다음 위치에 배치하세요:
```
lib/assets/fonts/NotoSansKR-Regular.ttf
```

### 3. pubspec.yaml 설정
```yaml
flutter:
  uses-material-design: true
  
  fonts:
    - family: NotoSansKR
      fonts:
        - asset: lib/assets/fonts/NotoSansKR-Regular.ttf

  assets:
    - lib/assets/fonts/
```

### 4. PDF 서비스 업데이트
lib/services/pdf_export_service.dart의 폰트 로드 부분 주석 해제:

```dart
static Future<pw.Font?> _loadKoreanFont() async {
  try {
    final fontData = await rootBundle.load('lib/assets/fonts/NotoSansKR-Regular.ttf');
    return pw.Font.ttf(fontData.buffer.asByteData());
  } catch (_) {
    return null;
  }
}
```

## 참고
현재는 폰트 없이도 PDF가 생성되지만, 한글 텍스트가 깨질 수 있습니다.
폰트를 추가하면 한글이 정상적으로 표시됩니다.

