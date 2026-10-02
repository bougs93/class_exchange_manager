import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/pdf_field_config.dart';
import '../utils/substitution_plan_field_accessor.dart';
import '../utils/date_format_utils.dart';
import '../constants/korean_fonts.dart';
import 'pdf_font_cache_manager.dart';

/// PDF 내보내기 서비스
/// - 선택된 PDF 템플릿에 교체 데이터를 채워서 출력합니다.
class PdfExportService {
  /// PDF 필드의 기본 폰트 크기 (pt 단위)
  /// 템플릿의 폰트 크기를 읽는 것이 지원되지 않으므로 이 상수를 사용합니다.
  static const double defaultFontSize = 10.0;

  /// 비고(remarks) 필드의 폰트 크기 (pt 단위)
  /// 비고 필드는 텍스트가 길 수 있으므로 더 작은 폰트 사이즈를 사용합니다.
  static const double remarksFontSize = 7.0;

  /// 윈도우 Fonts 폴더에서 사용 가능한 모든 폰트 파일 목록 가져오기
  /// Returns: 폰트 파일명 리스트 (확장자 포함)
  static Future<List<String>> getAvailableFonts() async {
    try {
      final fontsDir = Directory('C:\\Windows\\Fonts');

      if (!await fontsDir.exists()) {
        developer.log('Windows Fonts 폴더를 찾을 수 없습니다.');
        return _getDefaultFonts();
      }

      final fontFiles =
          fontsDir
              .listSync()
              .whereType<File>()
              .map((entity) => entity.path.split(Platform.pathSeparator).last)
              .where(
                (filename) =>
                    filename.toLowerCase().endsWith('.ttf') ||
                    filename.toLowerCase().endsWith('.ttc'),
              )
              .toList();

      developer.log('사용 가능한 폰트 파일: ${fontFiles.length}개');

      if (fontFiles.isEmpty) {
        return _getDefaultFonts();
      }

      // 파일명 순서로 정렬
      fontFiles.sort();

      return fontFiles;
    } catch (e) {
      developer.log('폰트 목록 가져오기 오류: $e');
      return _getDefaultFonts();
    }
  }

  /// 기본 폰트 목록 (오류 시 사용)
  static List<String> _getDefaultFonts() {
    return KoreanFontConstants.fontFiles;
  }

  /// Fallback 한글 폰트 찾기
  /// 지정된 폰트를 찾지 못했을 때 실제 Windows Fonts 폴더에서
  /// 사용 가능한 한글 폰트를 자동으로 찾아서 반환합니다.
  /// [fontSize] 폰트 크기
  static Future<PdfFont?> _findFallbackKoreanFont(double fontSize) async {
    try {
      final fontsDir = Directory('C:\\Windows\\Fonts');
      if (!await fontsDir.exists()) {
        developer.log('Windows Fonts 폴더를 찾을 수 없습니다.');
        return null;
      }

      // 한글 폰트로 알려진 일반적인 폰트 파일명 패턴들
      // 우선순위 순으로 정렬 (자주 사용되는 폰트 먼저)
      // 참고: Windows에서는 파일명이 대소문자를 구분하지 않지만, 실제 파일명은 다양할 수 있습니다.
      final List<String> koreanFontPatterns = [
        'malgun', // 맑은 고딕 (가장 일반적) - 정확한 파일명: malgun.ttf
        'gulim', // 굴림 - 정확한 파일명: gulim.ttc (TrueType Collection)
        'batang', // 바탕 - 정확한 파일명: batang.ttc, batangche.ttc (바탕체)
        'dotum', // 돋움 - 정확한 파일명: dotum.ttc, dotumche.ttc (돋움체)
        'gungsuh', // 궁서 - 정확한 파일명: gungsuh.ttc, gungsuhche.ttc (궁서체)
      ];

      // 실제 폰트 파일 목록 가져오기 (한 번만 호출하여 성능 최적화)
      final allFontFiles = fontsDir.listSync().whereType<File>().toList();

      // 파일명을 소문자로 변환한 매핑 생성 (대소문자 무시 검색용)
      final fontFileMap = <String, File>{};
      for (File fontFile in allFontFiles) {
        final fileName =
            fontFile.path.split(Platform.pathSeparator).last.toLowerCase();
        if ((fileName.endsWith('.ttf') || fileName.endsWith('.ttc')) &&
            !fontFileMap.containsKey(fileName)) {
          fontFileMap[fileName] = fontFile;
        }
      }

      developer.log('Fallback 검색: 총 ${fontFileMap.length}개의 폰트 파일 발견');

      // 디버깅: 한글 폰트로 추정되는 파일 목록 출력 (처음 20개만)
      final koreanFontCandidates =
          fontFileMap.keys
              .where(
                (name) => koreanFontPatterns.any(
                  (pattern) => name.contains(pattern.toLowerCase()),
                ),
              )
              .take(20)
              .toList();
      if (koreanFontCandidates.isNotEmpty) {
        developer.log('한글 폰트 후보 (처음 20개): ${koreanFontCandidates.join(", ")}');
      }

      // 우선순위에 따라 폰트 검색
      // 정확한 파일명 매칭을 우선 시도하고, 실패하면 패턴 매칭 시도
      for (String pattern in koreanFontPatterns) {
        final patternLower = pattern.toLowerCase();

        // 1단계: 정확한 파일명 매칭 (예: malgun.ttf, gulim.ttc)
        // 확장자 변형도 시도 (.ttf와 .ttc 모두)
        final exactMatches = ['$patternLower.ttf', '$patternLower.ttc'];

        for (String exactMatch in exactMatches) {
          if (fontFileMap.containsKey(exactMatch)) {
            try {
              final fontFile = fontFileMap[exactMatch]!;
              final fontBytes = await fontFile.readAsBytes();
              final actualFileName =
                  fontFile.path.split(Platform.pathSeparator).last;
              developer.log(
                '✓ Fallback 폰트 발견 (정확한 매칭): $actualFileName (패턴: $pattern)',
              );
              return PdfTrueTypeFont(fontBytes, fontSize);
            } catch (e) {
              developer.log('✗ Fallback 폰트 로드 실패 ($exactMatch): $e');
            }
          }
        }

        // 2단계: 파일명이 패턴으로 시작하는 경우 (예: malgunbd.ttf -> malgun으로 시작)
        for (String fileName in fontFileMap.keys) {
          if (fileName.startsWith(patternLower) &&
              (fileName.endsWith('.ttf') || fileName.endsWith('.ttc'))) {
            try {
              final fontFile = fontFileMap[fileName]!;
              final fontBytes = await fontFile.readAsBytes();
              final actualFileName =
                  fontFile.path.split(Platform.pathSeparator).last;
              developer.log(
                '✓ Fallback 폰트 발견 (시작 매칭): $actualFileName (패턴: $pattern)',
              );
              return PdfTrueTypeFont(fontBytes, fontSize);
            } catch (e) {
              developer.log('✗ Fallback 폰트 로드 실패 ($fileName): $e');
              continue;
            }
          }
        }

        // 3단계: 파일명에 패턴이 포함되어 있는지 확인 (가장 넓은 범위)
        for (String fileName in fontFileMap.keys) {
          if (fileName.contains(patternLower)) {
            try {
              final fontFile = fontFileMap[fileName]!;
              final fontBytes = await fontFile.readAsBytes();
              final actualFileName =
                  fontFile.path.split(Platform.pathSeparator).last;
              developer.log(
                '✓ Fallback 폰트 발견 (포함 매칭): $actualFileName (패턴: $pattern)',
              );
              return PdfTrueTypeFont(fontBytes, fontSize);
            } catch (e) {
              developer.log('✗ Fallback 폰트 로드 실패 ($fileName): $e');
              continue;
            }
          }
        }
      }

      // 패턴 매칭으로 찾지 못한 경우, 첫 번째 사용 가능한 폰트 시도
      developer.log('패턴 매칭 실패, 첫 번째 사용 가능한 폰트 시도 중...');
      for (String fileName in fontFileMap.keys.take(10)) {
        try {
          final fontFile = fontFileMap[fileName]!;
          final fontBytes = await fontFile.readAsBytes();
          final actualFileName =
              fontFile.path.split(Platform.pathSeparator).last;
          developer.log('✓ Fallback 폰트 발견 (임의): $actualFileName');
          return PdfTrueTypeFont(fontBytes, fontSize);
        } catch (e) {
          continue;
        }
      }

      developer.log('✗ Fallback 한글 폰트를 찾지 못했습니다.');
      return null;
    } catch (e) {
      developer.log('Fallback 한글 폰트 검색 중 오류: $e');
      return null;
    }
  }

  /// 번들 한글 폰트 로드 (Noto Sans/Serif KR 서브셋, OFL 라이선스 —
  /// `OFL.txt` 동봉).
  ///
  /// 웹과 모바일(Android/iOS)에서는 유일한 폰트 소스이고(시스템 폰트가
  /// 없음), 데스크톱(Windows)에서는 시스템 폰트를 하나도 찾지 못했을 때의
  /// 최종 폴백이다(아래 [loadKoreanFont] 참고). [fontType]은
  /// [KoreanFontConstants.bundledFontFiles]에 속한 파일명이어야 하고,
  /// 아니면(데스크톱용 "malgun.ttf" 등) 기본값으로 대체한다. 폰트별 바이트는
  /// 1회만 읽어 각각 캐시한다.
  ///
  /// ## 왜 원본 Noto Sans KR(10.4MB)을 그대로 쓰지 않는가
  ///
  /// 원본은 **가변 폰트**(Variable Font)라 굵기 100~900을 하나의 파일에서
  /// 보간하도록 설계돼 있는데, `syncfusion_flutter_pdf`의 `PdfTrueTypeFont`는
  /// 가변 폰트 보간을 지원하지 않아 축(axis) 보정 없이 그대로 읽는다. 그
  /// 결과 기본값(`wght=100`, 즉 **Thin**)으로 글자가 그려져, 의도한 굵기가
  /// 아니었을 가능성이 높다. 또한 이 학교 시간표 앱에서 쓰이지 않는 한자
  /// 8천여 자, 키릴·그리스 문자, 레이아웃(GSUB/GPOS) 테이블도 전부 들어
  /// 있어 매우 크다.
  ///
  /// `fonttools`로 **① 원하는 굵기를 고정한 정적 인스턴스로 변환**(보간
  /// 데이터 제거 — 글자 모양은 그대로) **② 실제 쓰이는 문자만 남기는
  /// 서브셋**(현대 한글 완성형 11,172자 전부 + 영문 + 일반 구두점 — 한자·타
  /// 문자권·레이아웃 테이블 제외)을 적용했다(2026-10-02). 현대 한글 음절을
  /// 전부 남겼으므로 교사명·과목명 등 실사용 텍스트에서 글자가 빠질 일은
  /// 없다.
  ///
  /// | 파일 | 원본 | 가공 후 |
  /// |---|---|---|
  /// | NotoSansKR-Subset.ttf (고딕체, 모바일 기본값) | 10.4MB | 2.4MB |
  /// | NotoSerifKR-Subset.ttf (명조체, 웹 기본값) | 23.8MB | 8.4MB |
  ///
  /// 굵게(Bold) 변형은 넣지 않았다(2026-10-02 요청) — 가족마다 Regular
  /// 하나씩만 제공한다. 기본값은 웹과 모바일이 서로 다르다(2026-10-02
  /// 요청) — [KoreanFontConstants.platformDefaultFont] 참고.
  ///
  /// 명조체는 획에 삐침이 있는 구조라 외곽선 데이터 자체가 더 커서, 같은
  /// 작업을 거쳐도 고딕체보다 크다. 세 파일 모두 `pubspec.yaml`의
  /// `assets:`(폰트 전용 `fonts:`가 아님)로 등록돼 있어 **쓰이는 것만, 실제로
  /// 쓰일 때만** 내려받는다 — 첫 화면 로딩에는 영향이 없고, 그 서체를 처음
  /// 선택해 내보낼 때만 받는다.
  static final Map<String, Uint8List> _bundledFontBytesByFile = {};

  static Future<PdfFont?> _loadBundledKoreanFont(
    double fontSize, {
    String? fontType,
  }) async {
    // fontType이 없거나 유효하지 않으면 현재 플랫폼의 기본값(웹: 명조체,
    // 모바일: 고딕체)으로 떨어진다.
    final fileName =
        (fontType != null &&
                KoreanFontConstants.bundledFontFiles.contains(fontType))
            ? fontType
            : KoreanFontConstants.platformDefaultFont;
    try {
      var bytes = _bundledFontBytesByFile[fileName];
      if (bytes == null) {
        bytes =
            (await rootBundle.load(
              'lib/assets/fonts/$fileName',
            )).buffer.asUint8List();
        _bundledFontBytesByFile[fileName] = bytes;
      }
      developer.log('번들 한글 폰트 로드 성공: $fileName (${bytes.length} bytes)');
      return PdfTrueTypeFont(bytes, fontSize);
    } catch (e) {
      developer.log('번들 한글 폰트 로드 실패 ($fileName): $e');
      return null;
    }
  }

  /// 한글 폰트 로드 (Public API)
  ///
  /// 플랫폼을 세 갈래로 나눠 처리한다 — 웹/모바일/데스크톱이 폰트를 구할 수
  /// 있는 방법이 서로 다르기 때문이다.
  ///
  /// 1. **웹·모바일(Android/iOS)**: 번들 폰트 사용 — [fontType]으로
  ///    고딕체/명조체 중 선택. 시스템에 깔린 한글 폰트를 앱이 알 수 없으니
  ///    (웹은 OS 접근 자체가 없고, 모바일은 `C:\Windows\Fonts`가 존재하지
  ///    않는다), Windows 전용 9종은 애초에 쓸 수 없다. 저작권 때문에 맑은
  ///    고딕 등을 그대로 번들에 넣을 수도 없어 OFL 라이선스의 Noto
  ///    Sans/Serif KR로 대신한다 —
  ///    [KoreanFontConstants.bundledFontListWithNames] 참고.
  ///    (예전에는 `kIsWeb` 하나로만 갈라서 모바일이 데스크톱과 같은 9종
  ///    목록을 보고 있었다 — 그 목록을 골라도 기기에 파일이 없어 매번
  ///    조용히 기본값으로 떨어졌다. 2026-10-02 발견)
  /// 2. **데스크톱(Windows)**: 시스템 폰트 우선 — 사용자가 선택한 폰트
  ///    ([fontType])를 존중해 기존 인쇄물과 같은 글꼴로 출력할 수 있게 한다.
  /// 3. 데스크톱에서 시스템 폰트를 하나도 못 찾으면 번들 폰트로 최종
  ///    폴백한다 (예전에는 여기서 null을 반환해 한글이 통째로 비어 있었다).
  ///
  /// [fontSize] 폰트 크기 (기본값: defaultFontSize 상수 사용)
  /// [fontType] 폰트 종류. 웹·모바일에서는
  /// [KoreanFontConstants.bundledFontFiles] 중 하나, 데스크톱에서는 Windows
  /// 폰트 파일명("malgun.ttf" 등)이어야 한다 — 어느 쪽이든
  /// [KoreanFontConstants.platformFontListWithNames]로 고른 값을 그대로
  /// 넘기면 된다.
  static Future<PdfFont?> loadKoreanFont({
    double fontSize = defaultFontSize,
    String? fontType,
  }) async {
    // 웹과 모바일은 시스템 폰트에 접근할 방법이 없다 — Windows 전용 탐색을
    // 아예 건너뛰고 바로 번들 폰트로 간다 (불필요한 디렉터리 접근 시도·로그
    // 소음도 함께 없앤다).
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      return _loadBundledKoreanFont(fontSize, fontType: fontType);
    }
    try {
      developer.log(
        '한글 폰트 검색 시작 (폰트 크기: ${fontSize}pt, 폰트 종류: ${fontType ?? "자동"})',
      );
      developer.log('Windows 시스템 폰트 사용 (C:\\Windows\\Fonts\\)');

      // Windows 시스템 폰트 사용
      List<String> commonFontPaths;

      if (fontType != null) {
        // 폰트 파일명이 직접 지정된 경우 (예: "malgun.ttf", "HCRBatang.ttf")
        if (fontType.endsWith('.ttf') || fontType.endsWith('.ttc')) {
          // 파일명의 다양한 변형 시도 (대소문자, 확장자 등)
          final baseName = fontType.substring(0, fontType.lastIndexOf('.'));
          final ext = fontType.substring(fontType.lastIndexOf('.'));

          commonFontPaths = [
            // 원본 파일명 (정확한 대소문자)
            'C:\\Windows\\Fonts\\$fontType',
            // 소문자 변형
            'C:\\Windows\\Fonts\\${baseName.toLowerCase()}$ext',
            // 대문자 변형
            'C:\\Windows\\Fonts\\${baseName.toUpperCase()}$ext',
            // 첫 글자만 대문자
            'C:\\Windows\\Fonts\\${baseName[0].toUpperCase()}${baseName.substring(1).toLowerCase()}$ext',
          ];

          // 확장자 변형도 시도 (.ttf <-> .ttc)
          if (ext == '.ttf') {
            commonFontPaths.addAll([
              'C:\\Windows\\Fonts\\$baseName.ttc',
              'C:\\Windows\\Fonts\\${baseName.toLowerCase()}.ttc',
              'C:\\Windows\\Fonts\\${baseName.toUpperCase()}.ttc',
            ]);
          } else if (ext == '.ttc') {
            commonFontPaths.addAll([
              'C:\\Windows\\Fonts\\$baseName.ttf',
              'C:\\Windows\\Fonts\\${baseName.toLowerCase()}.ttf',
              'C:\\Windows\\Fonts\\${baseName.toUpperCase()}.ttf',
            ]);
          }

          // 실제 Fonts 폴더에서 파일 검색 시도
          try {
            final fontsDir = Directory('C:\\Windows\\Fonts');
            if (await fontsDir.exists()) {
              final files =
                  fontsDir
                      .listSync()
                      .whereType<File>()
                      .map((entity) => entity.path)
                      .where((path) {
                        final fileName =
                            path
                                .split(Platform.pathSeparator)
                                .last
                                .toLowerCase();
                        final searchName = baseName.toLowerCase();
                        return fileName.startsWith(searchName) &&
                            (fileName.endsWith('.ttf') ||
                                fileName.endsWith('.ttc'));
                      })
                      .take(5) // 최대 5개만
                      .toList();

              if (files.isNotEmpty) {
                // 실제로 찾은 파일들을 맨 앞에 추가
                commonFontPaths = [...files, ...commonFontPaths];
                developer.log('실제 폰트 파일 발견: ${files.length}개');
              }
            }
          } catch (e) {
            developer.log('폰트 폴더 검색 실패: $e');
          }
        } else {
          // 폰트 종류가 지정되었지만 정확한 파일명이 아닌 경우
          // Windows 시스템 기본 폰트 검색
          commonFontPaths = KoreanFontConstants.getWindowsFontPaths();
        }
      } else {
        // 폰트 종류가 지정되지 않으면 모든 폰트 검색
        commonFontPaths = KoreanFontConstants.getWindowsFontPaths();
      }

      for (String fontPath in commonFontPaths) {
        try {
          final fontFile = File(fontPath);
          if (await fontFile.exists()) {
            final fontBytes = await fontFile.readAsBytes();
            developer.log(
              '✓ 로컬 한글 폰트 로드 성공: $fontPath (${fontBytes.length} bytes, 크기: ${fontSize}pt)',
            );
            return PdfTrueTypeFont(fontBytes, fontSize);
          } else {
            developer.log('→ 폰트 파일 없음: $fontPath');
          }
        } catch (e) {
          developer.log('✗ 폰트 확인 실패 ($fontPath): $e');
          continue;
        }
      }

      // 지정된 폰트를 찾지 못한 경우, 실제 존재하는 한글 폰트 자동 탐색
      developer.log('지정된 폰트를 찾지 못했습니다. 사용 가능한 한글 폰트 자동 탐색 중...');
      final fallbackFont = await _findFallbackKoreanFont(fontSize);
      if (fallbackFont != null) {
        developer.log('✓ Fallback 한글 폰트 로드 성공 (크기: ${fontSize}pt)');
        return fallbackFont;
      }

      // 시스템 폰트를 전혀 찾지 못했다 — Android 등 `C:\Windows\Fonts`가
      // 없는 플랫폼이 여기로 떨어진다. 번들 폰트로 최종 폴백한다.
      developer.log('시스템 한글 폰트 없음 — 번들 폰트로 폴백');
      return _loadBundledKoreanFont(fontSize);
    } catch (e) {
      developer.log('한글 폰트 로드 중 오류: $e — 번들 폰트로 폴백');
      return _loadBundledKoreanFont(fontSize);
    }
  }

  /// 결보강 계획서 PDF 내보내기
  ///
  /// [planData] 교체 데이터 목록
  /// [templatePath] 사용자 선택 PDF 템플릿 경로(파일 시스템 경로 또는 에셋 경로)
  /// [outputPath] 생성될 PDF 파일의 저장 경로 (웹에서는 null — 파일 저장 생략)
  /// [fontSize] 폰트 크기 (기본값: defaultFontSize)
  /// [remarksFontSize] 비고 필드 폰트 크기 (기본값: remarksFontSize)
  /// [fontType] 폰트 종류 (Windows 시스템 폰트 파일명: malgun.ttf, malgunbd.ttf, gulim.ttc, batang.ttc, dotum.ttc, gungsuh.ttc)
  /// [includeRemarks] 비고 필드 출력 여부 (기본값: true)
  /// [additionalFields] 추가 필드 데이터 (teacherName, absencePeriod, workStatus, reasonForAbsence, notes, schoolName)
  ///
  /// Returns: PDF 바이트 (성공 시, 웹 저장·공유용). [outputPath]가 있으면
  /// 파일로도 저장한다. 실패 시 null.
  static Future<Uint8List?> exportSubstitutionPlan({
    required List<SubstitutionPlanData> planData,
    String? outputPath,
    required String templatePath,
    double? fontSize,
    double? remarksFontSize,
    String? fontType,
    bool includeRemarks = true,
    Map<String, String>? additionalFields,
  }) async {
    try {
      // 폰트 캐시 매니저 생성
      final fontCacheManager = PdfFontCacheManager();

      // 1) 템플릿 PDF 파일 로드
      // 에셋 경로인지 파일 시스템 경로인지 구분하여 처리
      List<int> templateBytes;

      // 에셋 경로 판단: 'assets/' 또는 'lib/assets/'로 시작하는 경우
      if (templatePath.startsWith('assets/') ||
          templatePath.startsWith('lib/assets/')) {
        // 에셋 경로인 경우: rootBundle을 사용하여 로드
        // 참고: Flutter에서 에셋 파일은 pubspec.yaml에 등록되어 있어야 합니다.
        try {
          developer.log('템플릿 에셋 로드 시작: $templatePath');
          final assetData = await rootBundle.load(templatePath);
          templateBytes = assetData.buffer.asUint8List();
          developer.log('템플릿 에셋 로드 성공: ${templateBytes.length} bytes');
        } catch (e) {
          throw FileSystemException('에셋 템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
      } else {
        // 파일 시스템 경로인 경우: File을 사용하여 로드
        final templateFile = File(templatePath);
        if (!await templateFile.exists()) {
          throw FileSystemException('템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
        developer.log('템플릿 파일 로드 시작: $templatePath');
        templateBytes = await templateFile.readAsBytes();
        developer.log('템플릿 파일 로드 성공: ${templateBytes.length} bytes');
      }

      // 2) 템플릿 PDF 로드
      final PdfDocument document = PdfDocument(inputBytes: templateBytes);

      // 3) 폼 필드 접근
      final PdfForm form = document.form;
      developer.log('폼 필드 개수: ${form.fields.count}');

      // 4) 데이터를 폼 필드에 채우기
      int successCount = 0;
      int failCount = 0;

      // 내용 수정 표와 동일한 순서(결강일 → 결강교시)로 정렬
      final sortedPlanData = List<SubstitutionPlanData>.from(planData)
        ..sort((a, b) {
          final aDate = DateFormatUtils.parseYearMonthDay(a.absenceDate);
          final bDate = DateFormatUtils.parseYearMonthDay(b.absenceDate);
          if (aDate != null && bDate != null) {
            final dateCompare = aDate.compareTo(bDate);
            if (dateCompare != 0) return dateCompare;
          } else if (aDate != null) {
            return -1;
          } else if (bDate != null) {
            return 1;
          }

          final aPeriod = int.tryParse(a.period) ?? 9999;
          final bPeriod = int.tryParse(b.period) ?? 9999;
          final periodCompare = aPeriod.compareTo(bPeriod);
          if (periodCompare != 0) return periodCompare;

          return a.absenceDate.compareTo(b.absenceDate);
        });

      // 각 데이터 행에 대해 필드 이름 생성 및 채우기
      for (int rowIndex = 0; rowIndex < sortedPlanData.length; rowIndex++) {
        final data = sortedPlanData[rowIndex];

        // 각 컬럼 키에 대해 필드 이름 생성 (예: date.0, date.1, ...)
        for (String columnKey in kPdfTableColumns) {
          // 비고 필드 출력 여부 확인
          if (columnKey == 'remarks' && !includeRemarks) {
            // 비고 출력이 비활성화된 경우 건너뛰기
            continue;
          }

          // 필드 이름 생성: {컬럼키}.{행인덱스}
          final String fieldName = '$columnKey.$rowIndex';

          // 데이터 매핑
          String? value = _getFieldValue(data, columnKey);

          if (value != null && value.isNotEmpty) {
            // 해당 이름의 폼 필드 찾기 (인덱스로 접근)
            bool found = false;
            for (int i = 0; i < form.fields.count; i++) {
              final field = form.fields[i];
              if (field is PdfTextBoxField && field.name == fieldName) {
                // 필드의 기존 폰트 크기 정보 추출 시도
                // 참고: 템플릿의 폰트 크기를 읽는 것이 지원되지 않으므로 기본값 사용
                // 실제 폰트 크기는 템플릿 PDF 파일에 정의된 대로 유지됩니다
                // 비고(remarks) 필드는 더 작은 폰트 사이즈 사용
                double fieldFontSize =
                    columnKey == 'remarks'
                        ? (remarksFontSize ?? PdfExportService.remarksFontSize)
                        : (fontSize ?? PdfExportService.defaultFontSize);

                // 폰트 캐시 매니저를 통해 폰트 가져오기 (캐싱 자동 처리)
                PdfFont? fontForField = await fontCacheManager.getOrLoad(
                  fontSize: fieldFontSize,
                  fontType: fontType,
                );

                // 필드에 값 채우기 전에 한글 폰트 먼저 설정
                if (fontForField != null) {
                  try {
                    // 폰트 설정 후 텍스트 설정
                    field.font = fontForField;
                    field.text = value;
                    developer.log('필드 채웠음 (한글폰트 적용): $fieldName = $value');
                  } catch (e) {
                    developer.log('폰트 설정 실패, 기본 폰트로 시도: $fieldName - $e');
                    field.text = value; // 폰트 설정 실패해도 텍스트는 입력
                  }
                } else {
                  // 한글 폰트를 찾지 못한 경우
                  developer.log('한글 폰트를 찾지 못함, 기본 폰트로 진행: $fieldName');
                  field.text = value;
                }
                successCount++;
                found = true;
                break;
              }
            }

            if (!found) {
              developer.log('필드를 찾지 못함: $fieldName');
              failCount++;
            }
          }
        }

        // 복합 필드 처리 (예: date(day), 3date(3day))
        for (String compositeField in kPdfCompositeFieldBases) {
          final String fieldName = '$compositeField.$rowIndex';
          final List<String> componentFields =
              kPdfCompositeFieldMapping[compositeField] ?? [];

          if (componentFields.isEmpty) {
            developer.log('복합 필드 분석 실패: $compositeField');
            continue;
          }

          // 개별 필드 값들을 수집
          List<String> values = [];
          for (String component in componentFields) {
            String? value = _getFieldValue(data, component);
            if (value != null && value.isNotEmpty) {
              values.add(value);
            }
          }

          if (values.isNotEmpty) {
            // 복합 필드가 존재하는지 확인
            bool found = false;
            for (int i = 0; i < form.fields.count; i++) {
              final field = form.fields[i];
              if (field is PdfTextBoxField && field.name == fieldName) {
                // 필드의 기존 폰트 크기 정보 추출 시도
                // 참고: 템플릿의 폰트 크기를 읽는 것이 지원되지 않으므로 기본값 사용
                // 실제 폰트 크기는 템플릿 PDF 파일에 정의된 대로 유지됩니다
                double fieldFontSize =
                    fontSize ?? PdfExportService.defaultFontSize;

                // 폰트 캐시 매니저를 통해 폰트 가져오기 (캐싱 자동 처리)
                final fontForField = await fontCacheManager.getOrLoad(
                  fontSize: fieldFontSize,
                  fontType: fontType,
                );

                // 복합 필드 포맷팅: date(day) 형식으로 입력
                final formattedValue = formatCompositeFieldValue(
                  compositeField,
                  values,
                );

                // 한글 폰트 먼저 설정 (텍스트 설정 전에)
                if (fontForField != null) {
                  try {
                    // 폰트 설정 후 텍스트 설정
                    field.font = fontForField;
                    field.text = formattedValue;
                    developer.log(
                      '복합 필드 채웠음 (한글폰트 적용): $fieldName = $formattedValue',
                    );
                  } catch (e) {
                    developer.log('복합 필드 폰트 설정 실패, 기본 폰트로 시도: $fieldName - $e');
                    field.text = formattedValue; // 폰트 설정 실패해도 텍스트는 입력
                  }
                } else {
                  // 한글 폰트를 찾지 못한 경우
                  developer.log('한글 폰트를 찾지 못함, 기본 폰트로 진행: $fieldName');
                  field.text = formattedValue;
                }
                successCount++;
                found = true;
                break;
              }
            }

            if (!found) {
              developer.log('복합 필드를 찾지 못함: $fieldName');
              failCount++;
            }
          }
        }
      }

      developer.log('필드 채우기 완료: 성공 $successCount, 실패 $failCount');

      // 4-1) 추가 필드 채우기
      if (additionalFields != null && additionalFields.isNotEmpty) {
        developer.log('추가 필드 채우기 시작: ${additionalFields.length}개');

        for (final entry in additionalFields.entries) {
          final fieldName = entry.key;
          final fieldValue = entry.value;

          // 빈 값은 건너뛰기
          if (fieldValue.isEmpty) continue;

          try {
            // 필드 찾기
            PdfField? targetField;
            for (int i = 0; i < form.fields.count; i++) {
              final field = form.fields[i];
              if (field.name == fieldName) {
                targetField = field;
                break;
              }
            }

            if (targetField == null) {
              developer.log('추가 필드를 찾을 수 없음: $fieldName');
              failCount++;
              continue;
            }

            if (targetField is PdfTextBoxField) {
              // 학교명 필드는 20pt, 나머지는 기본 폰트 크기 사용
              final fieldFontSize =
                  fieldName == 'schoolName'
                      ? 20.0
                      : (fontSize ?? defaultFontSize);

              // 폰트 캐시 매니저를 통해 폰트 가져오기 (캐싱 자동 처리)
              final koreanFont = await fontCacheManager.getOrLoad(
                fontSize: fieldFontSize,
                fontType: fontType,
              );

              if (koreanFont != null) {
                targetField.font = koreanFont;
              }

              // 필드 값 설정
              targetField.text = fieldValue;
              developer.log(
                '추가 필드 채웠음: $fieldName = $fieldValue (폰트 크기: ${fieldFontSize}pt)',
              );
              successCount++;
            }
          } catch (e) {
            developer.log('추가 필드 채우기 실패 ($fieldName): $e');
            failCount++;
          }
        }

        developer.log('추가 필드 채우기 완료');
      }

      // 5) 폼 필드 플래튼 (편집 불가능하게 만듦)
      try {
        form.flattenAllFields();
        developer.log('폼 필드 평탄화 완료');
      } catch (e) {
        developer.log('폼 필드 평탄화 중 오류: $e');
      }

      // 6) PDF 바이트 생성 (항상) + 파일 저장 (경로가 있을 때만)
      final Uint8List bytes = Uint8List.fromList(await document.save());
      if (outputPath != null && outputPath.isNotEmpty) {
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        developer.log('PDF 저장 완료: $outputPath (${bytes.length} bytes)');
      }

      // 7) 문서 닫기
      document.dispose();

      return bytes;
    } catch (e) {
      developer.log('PDF 내보내기 오류: $e');
      return null;
    }
  }

  /// 컬럼 키에 해당하는 값을 데이터에서 가져오기
  /// [data] 교체 데이터
  /// [columnKey] 컬럼 키 (kPdfTableColumns에 정의된 키, 축약형)
  /// Returns: 필드 값 또는 null
  ///
  /// SubstitutionPlanFieldAccessor를 사용하여 축약형 키를 자동으로 처리합니다.
  static String? _getFieldValue(SubstitutionPlanData data, String columnKey) {
    final value = SubstitutionPlanFieldAccessor.getValue(data, columnKey);
    if (value.isEmpty) return null;

    // 날짜 필드인 경우 월.일 형식으로 변환
    // PDF 템플릿의 축약형 키: 'date' (결강일), '3date' (교체일)
    if (columnKey == 'date' || columnKey == '3date') {
      return DateFormatUtils.toMonthDay(value);
    }

    return value;
  }

  /// 템플릿의 모든 폼 필드 정보 출력 (디버깅용)
  /// 선택한 PDF 템플릿의 폼 필드 이름과 상세 정보를 확인할 때 사용합니다.
  static Future<Map<String, dynamic>> getTemplateFieldInfo(
    String templatePath,
  ) async {
    try {
      // 에셋 경로인지 파일 시스템 경로인지 구분하여 처리
      List<int> templateBytes;

      // 에셋 경로 판단: 'assets/' 또는 'lib/assets/'로 시작하는 경우
      if (templatePath.startsWith('assets/') ||
          templatePath.startsWith('lib/assets/')) {
        // 에셋 경로인 경우: rootBundle을 사용하여 로드
        try {
          developer.log('템플릿 에셋 로드 시작 (필드 정보 읽기): $templatePath');
          final assetData = await rootBundle.load(templatePath);
          templateBytes = assetData.buffer.asUint8List();
          developer.log(
            '템플릿 에셋 로드 성공 (필드 정보 읽기): ${templateBytes.length} bytes',
          );
        } catch (e) {
          throw FileSystemException('에셋 템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
      } else {
        // 파일 시스템 경로인 경우: File을 사용하여 로드
        final templateFile = File(templatePath);
        if (!await templateFile.exists()) {
          throw FileSystemException('템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
        developer.log('템플릿 파일 로드 시작 (필드 정보 읽기): $templatePath');
        templateBytes = await templateFile.readAsBytes();
        developer.log('템플릿 파일 로드 성공 (필드 정보 읽기): ${templateBytes.length} bytes');
      }

      final PdfDocument document = PdfDocument(inputBytes: templateBytes);

      final Map<String, dynamic> info = {
        'totalFields': document.form.fields.count,
        'fields': <Map<String, String>>[],
      };

      for (int i = 0; i < document.form.fields.count; i++) {
        final field = document.form.fields[i];

        final fieldInfo = {
          'index': '$i',
          'name': field.name ?? '(unnamed)',
          'type': field.runtimeType.toString(),
          'value': (field is PdfTextBoxField) ? field.text : '(N/A)',
        };

        (info['fields'] as List).add(fieldInfo);
        developer.log(
          '필드 $i: ${fieldInfo['name']} (${fieldInfo['type']}) = ${fieldInfo['value']}',
        );
      }

      document.dispose();
      return info;
    } catch (e) {
      developer.log('템플릿 필드 정보 읽기 오류: $e');
      return {'error': e.toString()};
    }
  }
}
