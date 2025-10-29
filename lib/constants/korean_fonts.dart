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
    'malgun.ttf',                      // 맑은 고딕
    'malgunbd.ttf',                    // 맑은 고딕 Bold
    'gulim.ttc',                       // 굴림
    'batang.ttc',                      // 바탕
    'dotum.ttc',                       // 돋움
    'gungsuh.ttc',                     // 궁서
    'hanbatang.ttf',                   // 한바탕
    'handotum.ttf',                    // 한돋움
    'hansantteutdotum-regular.ttf',    // 한산뜻돋움
  ];

  /// UI 표시용 폰트 정보 (파일명 + 한글명)
  ///
  /// file_export_widget에서 드롭다운 표시용으로 사용됩니다.
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
}
