import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// 한글 폰트 파일 상수
///
/// Windows 시스템 폰트(C:\Windows\Fonts\)에서 사용 가능한 한글 폰트 목록을 관리합니다.
/// PDF 출력 및 UI에서 공통으로 사용됩니다.
class KoreanFontConstants {
  /// 사용 가능한 한글 폰트 파일명 목록 (확장자 포함)
  ///
  /// 우선순위 순서로 정렬되어 있습니다:
  /// - 맑은 고딕 (가장 일반적, 권장)
  /// - 굴림, 바탕, 돋움, 궁서 (Windows 기본 폰트)
  /// - 한바탕, 한돋움, 한산뜻돋움 (추가 폰트)
  static const List<String> fontFiles = [
    'malgun.ttf', // 맑은 고딕
    'malgunbd.ttf', // 맑은 고딕 Bold
    'gulim.ttc', // 굴림
    'batang.ttc', // 바탕
    'dotum.ttc', // 돋움
    'gungsuh.ttc', // 궁서
    'hanbatang.ttf', // 한바탕
    'handotum.ttf', // 한돋움
    'hansantteutdotum-regular.ttf', // 한산뜻돋움
  ];

  /// UI 표시용 폰트 정보 (파일명 + 한글명)
  ///
  /// substitution_output_widget에서 드롭다운 표시용으로 사용됩니다.
  static const List<Map<String, String>> fontListWithNames = [
    {'file': 'malgun.ttf', 'name': '맑은 고딕'},
    {'file': 'malgunbd.ttf', 'name': '맑은 고딕 Bold'},
    {'file': 'gulim.ttc', 'name': '굴림'},
    {'file': 'batang.ttc', 'name': '바탕'},
    {'file': 'dotum.ttc', 'name': '돋움'},
    {'file': 'gungsuh.ttc', 'name': '궁서'},
    {'file': 'hanbatang.ttf', 'name': '한바탕'},
    {'file': 'handotum.ttf', 'name': '한돋움'},
    {'file': 'hansantteutdotum-regular.ttf', 'name': '한산뜻돋움'},
  ];

  /// Windows Fonts 폴더의 전체 경로 생성
  ///
  /// Returns: 폰트 파일의 절대 경로 목록
  ///
  /// 예: ['C:\\Windows\\Fonts\\malgun.ttf', ...]
  static List<String> getWindowsFontPaths() {
    return fontFiles.map((file) => 'C:\\Windows\\Fonts\\$file').toList();
  }

  /// 특정 폰트 파일의 Windows 경로 생성
  ///
  /// [fileName] 폰트 파일명 (예: 'malgun.ttf')
  ///
  /// Returns: 전체 경로 (예: 'C:\\Windows\\Fonts\\malgun.ttf')
  static String getWindowsFontPath(String fileName) {
    return 'C:\\Windows\\Fonts\\$fileName';
  }

  /// 기본 폰트 파일명 (한바탕)
  static const String defaultFont = 'hanbatang.ttf';

  /// 기본 폰트 한글명
  static const String defaultFontName = '한바탕';

  // ==================== 번들 폰트 목록 (웹 + 모바일) ====================
  //
  // 위 [fontFiles] 목록(맑은 고딕·굴림·바탕·돋움·궁서·한바탕 등)은 전부
  // Windows 시스템에 설치된 상용 폰트 파일이다. 저작권사(Microsoft·한양정보통신
  // 등)의 라이선스가 OS 안에서의 사용만 허용하므로, 이 파일들을 앱에 번들로
  // 넣어 배포하는 것은 허용되지 않는다.
  //
  // 이 제약은 웹만의 문제가 아니다 — **Android/iOS에도 `C:\Windows\Fonts`가
  // 없다.** 예전에는 `kIsWeb` 하나로만 분기해서, 모바일이 PC와 같은 9개
  // Windows 파일명 목록을 그대로 보여줬다. 모바일에서 뭘 골라도 그 파일이
  // 기기에 없으니 매번 조용히 기본 폰트로 떨어졌고, 사용자 눈에는 "선택이
  // 안 먹힌다"로 보였다(2026-10-02 웹에서 먼저 발견, 모바일도 같은 구조적
  // 결함).
  //
  // 그래서 **웹과 모바일은 같은 번들 폰트 세트를 공유**한다 — OFL
  // 라이선스로 재배포가 허용된 Noto Sans/Serif KR을 "고딕체/명조체"라는
  // 보편적 이름으로 제공한다. 실제 맑은 고딕 등과 글자 모양이 같지는
  // 않지만, 비슷한 용도를 고를 수 있게 한다. 데스크톱(Windows)만 실제
  // 시스템 폰트 9종을 선택할 수 있다.

  /// 번들 폰트 파일명 목록 (lib/assets/fonts/ 기준 상대 경로, 웹 + 모바일 공용)
  ///
  /// 굵게(Bold) 변형은 제외한다(2026-10-02 요청) — 각 가족당 Regular
  /// 하나씩만 둔다.
  static const List<String> bundledFontFiles = [
    'NotoSansKR-Subset.ttf',
    'NotoSerifKR-Subset.ttf',
  ];

  /// 번들 폰트 UI 표시 목록 (파일명 + 한글명, 웹 + 모바일 공용)
  static const List<Map<String, String>> bundledFontListWithNames = [
    {'file': 'NotoSansKR-Subset.ttf', 'name': '고딕체'},
    {'file': 'NotoSerifKR-Subset.ttf', 'name': '명조체'},
  ];

  /// 모바일(Android/iOS) 기본 폰트 파일명 — 고딕체
  static const String mobileDefaultFont = 'NotoSansKR-Subset.ttf';

  /// 모바일 기본 폰트 한글명
  static const String mobileDefaultFontName = '고딕체';

  /// 웹 기본 폰트 파일명 — 명조체 (2026-10-02 요청: 웹만 모바일과 다른 기본값)
  static const String webDefaultFont = 'NotoSerifKR-Subset.ttf';

  /// 웹 기본 폰트 한글명
  static const String webDefaultFontName = '명조체';

  // ==================== 플랫폼 공통 접근자 ====================
  //
  // UI(폰트 드롭다운)와 설정 유효성 검사는 플랫폼을 가리지 않고 이 3개만
  // 쓰면 된다 — 매 호출부마다 플랫폼 분기를 반복하지 않기 위함이다.
  //
  // 선택 "목록"은 웹과 모바일이 같은 번들 세트([bundledFontFiles])를
  // 공유하지만, "기본값"은 셋 다 다르다 — 데스크톱은 한바탕, 모바일은
  // 고딕체, 웹은 명조체. `kIsWeb`이 참이면 `Platform.*`은 평가되지
  // 않으므로(단락 평가) 웹 빌드에서 `dart:io`의 `Platform`을 참조해도
  // 안전하다.

  /// 웹인지, 모바일(Android/iOS)인지, 데스크톱인지 — 폰트 선택 목적의 분류.
  static bool get _isBundledFontPlatform =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;

  /// 현재 플랫폼에서 고를 수 있는 폰트 목록 (파일명 + 한글명)
  static List<Map<String, String>> get platformFontListWithNames =>
      _isBundledFontPlatform ? bundledFontListWithNames : fontListWithNames;

  /// 현재 플랫폼에서 고를 수 있는 폰트 파일명 목록
  static List<String> get platformFontFiles =>
      _isBundledFontPlatform ? bundledFontFiles : fontFiles;

  /// 현재 플랫폼의 기본 폰트 파일명
  static String get platformDefaultFont {
    if (kIsWeb) return webDefaultFont;
    if (Platform.isAndroid || Platform.isIOS) return mobileDefaultFont;
    return defaultFont;
  }
}
