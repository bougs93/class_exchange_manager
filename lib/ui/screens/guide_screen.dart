import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'guide/program_info_content.dart';
import '../widgets/app_content_card.dart';
import '../widgets/exchange_control_panel.dart';
import '../widgets/timetable_grid/grid_header_widgets.dart';
import '../../utils/url_launcher_helper.dart';

/// 도움말 화면
///
/// 프로그램 정보, 사용법, PDF 양식 제작을 서브 메뉴로 제공합니다.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  /// 선택된 서브 메뉴 (0: 프로그램 정보, 1: 기본 사용법, 2: PDF 양식 제작)
  int _selectedIndex = 0;

  // 마크다운 파일 내용을 저장할 변수
  String _basicUsageMarkdown = '';
  String _pdfFormGuideMarkdown = '';
  bool _isLoading = true;

  /// 서브 메뉴 정의 (아이콘·라벨·선택 색상)
  static const _menuItems = [
    (
      icon: Icons.info_outline,
      label: '프로그램 정보',
      color: Colors.teal,
    ),
    (
      icon: Icons.help_outline,
      label: '기본 사용법',
      color: Colors.blue,
    ),
    (
      icon: Icons.description_outlined,
      label: 'PDF 양식 제작',
      color: Colors.purple,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMarkdownFiles();
  }
  
  /// 마크다운 파일 로드
  Future<void> _loadMarkdownFiles() async {
    try {
      // 두 파일을 동시에 로드
      final results = await Future.wait([
        rootBundle.loadString('lib/assets/docs/basic_usage.md'),
        rootBundle.loadString('lib/assets/docs/pdf_form_guide.md'),
      ]);
      
      if (mounted) {
        setState(() {
          _basicUsageMarkdown = results[0];
          _pdfFormGuideMarkdown = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('마크다운 파일 로드 오류: $e');
      if (mounted) {
        setState(() {
          _basicUsageMarkdown = '# 오류\n\n마크다운 파일을 불러오는 중 오류가 발생했습니다.\n\n오류 내용: $e';
          _pdfFormGuideMarkdown = '# 오류\n\n마크다운 파일을 불러오는 중 오류가 발생했습니다.\n\n오류 내용: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================================
  // Main Build Method
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // AppBar 없음 — HomeScreen 상단 UnifiedNavigationBar 사용
    // 서브 메뉴는 1차 메뉴 바로 아래 2번째 줄(가로 툴바)
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubMenuBar(),
          Expanded(
            child: ColoredBox(
              color: Colors.grey.shade50,
              child: _buildContent(theme),
            ),
          ),
        ],
      ),
    );
  }

  /// 메인 메뉴 하단 가로 서브 메뉴 — 교체/시간표 2차 툴바와 동일 패턴
  Widget _buildSubMenuBar() {
    return Container(
      height: kExchangeUnifiedToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(_menuItems.length, (index) {
          final item = _menuItems[index];
          final isSelected = _selectedIndex == index;

          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CompactToolbarLabelButton(
              onPressed: () {
                if (_selectedIndex != index) {
                  setState(() => _selectedIndex = index);
                }
              },
              icon: item.icon,
              label: item.label,
              tooltip: item.label,
              backgroundColor: isSelected
                  ? item.color.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              foregroundColor:
                  isSelected ? item.color : Colors.grey.shade700,
              borderColor: isSelected ? item.color : Colors.grey.shade300,
              height: kExchangeUnifiedToolbarHeight - 8,
              fontSize: kModeButtonFontSize,
              iconSize: kModeButtonIconSize,
            ),
          );
        }),
      ),
    );
  }

  /// 선택된 서브 메뉴에 따른 콘텐츠
  Widget _buildContent(ThemeData theme) {
    switch (_selectedIndex) {
      case 0:
        return const ProgramInfoContent();
      case 1:
        return _buildBasicUsageTab(theme);
      case 2:
        return _buildFormGuideTab(theme);
      default:
        return const ProgramInfoContent();
    }
  }

  // ============================================================================
  // Tab Contents
  // ============================================================================

  /// 마크다운 탭 빌드 (공통 메서드)
  ///
  /// [markdownContent]: 표시할 마크다운 내용
  Widget _buildMarkdownTab(ThemeData theme, String markdownContent) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // selectable: true 는 문단마다 SelectableText를 분리해 1블록씩만 선택됩니다.
    // SelectionArea + 일반 Text 렌더링으로 여러 문단을 한 번에 드래그 선택할 수 있습니다.
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppContentCard(
              child: MarkdownBody(
                  data: _processMarkdownWithYoutubeThumbnails(markdownContent),
                  selectable: false,
                  styleSheet: _buildMarkdownStyleSheet(theme),
                  imageBuilder: (uri, title, alt) {
                  // URI에서 경로 추출
                  // flutter_markdown이 마크다운의 이미지 경로를 파싱할 때
                  // 공백이 있는 파일명의 경우 path에서 일부만 추출될 수 있음
                  // 따라서 전체 URI 문자열에서 직접 추출하는 것이 더 안전함
                  
                  String imagePath = '';
                  final uriString = uri.toString();
                  
                  // 디버그 로그
                  debugPrint('🖼️ 이미지 URI 전체: $uriString');
                  debugPrint('🖼️ URI scheme: ${uri.scheme}');
                  debugPrint('🖼️ URI path: ${uri.path}');
                  debugPrint('🖼️ URI fragment: ${uri.fragment}');
                  
                  // URI가 상대 경로인 경우 (scheme이 없음)
                  if (uri.scheme.isEmpty) {
                    // 상대 경로는 전체 URI 문자열을 사용
                    imagePath = uriString;
                  } else if (uri.scheme == 'file') {
                    // file:// 프로토콜인 경우 path 사용
                    imagePath = uri.path;
                  } else {
                    // 그 외의 경우 path 사용
                    imagePath = uri.path;
                  }
                  
                  // URL 디코딩 (공백이 %20으로 인코딩된 경우 처리)
                  imagePath = Uri.decodeComponent(imagePath);
                  
                  debugPrint('🖼️ 디코딩된 이미지 경로: $imagePath');
                  
                  // 유튜브 썸네일 이미지인 경우 특별 처리
                  if (uriString.contains('img.youtube.com')) {
                    final videoId = _extractVideoIdFromThumbnailUrl(uriString);
                    if (videoId != null) {
                      return _buildYouTubeThumbnail(videoId, alt ?? '');
                    }
                  }
                  
                  // 네트워크 이미지 처리 (http:// 또는 https://로 시작)
                  if (uriString.startsWith('http://') || uriString.startsWith('https://')) {
                    return Image.network(
                      uriString,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('❌ 네트워크 이미지 로드 실패: $uriString, 오류: $error');
                        return Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.grey.shade200,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey.shade400),
                              const SizedBox(height: 4),
                              Text(
                                '이미지를 불러올 수 없습니다',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  
                  // 로컬 이미지 (assets) 처리
                  // file:// 프로토콜 제거 (있는 경우)
                  if (imagePath.startsWith('file://')) {
                    imagePath = imagePath.substring(7);
                  }
                  
                  // ./ 또는 ../ 제거
                  if (imagePath.startsWith('./')) {
                    imagePath = imagePath.substring(2);
                  } else if (imagePath.startsWith('../')) {
                    imagePath = imagePath.substring(3);
                  }
                  
                  // 앞뒤 공백 제거
                  imagePath = imagePath.trim();
                  
                  // lib/assets/docs/ 경로로 변환 (이미 해당 경로에 있으면 그대로 사용)
                  if (!imagePath.startsWith('lib/assets/docs/')) {
                    imagePath = 'lib/assets/docs/$imagePath';
                  }
                  
                  debugPrint('🖼️ 최종 assets 경로: $imagePath');
                  
                  // Image.asset을 사용하여 이미지 로드
                  // pubspec.yaml에 lib/assets/docs/가 등록되어 있으므로
                  // lib/assets/docs/파일명 형식으로 경로를 지정해야 함
                  return Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('❌ 이미지 로드 실패');
                      debugPrint('   경로: $imagePath');
                      debugPrint('   오류: $error');
                      debugPrint('   스택 트레이스: $stackTrace');
                      
                      // 오류 상세 정보 표시
                      String errorMessage = '이미지를 불러올 수 없습니다';
                      if (error.toString().contains('Asset not found')) {
                        errorMessage = '파일을 찾을 수 없습니다\n경로: $imagePath\n\n앱을 재시작해주세요';
                      } else {
                        errorMessage = '이미지 로드 오류\n$error';
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey.shade200,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey.shade400),
                            const SizedBox(height: 4),
                            Text(
                              errorMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      UrlLauncherHelper.launchURL(href, context: context);
                    }
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }

  /// "기본 사용법" 탭 컨텐츠
  Widget _buildBasicUsageTab(ThemeData theme) {
    return _buildMarkdownTab(theme, _basicUsageMarkdown);
  }

  /// "PDF 양식 제작" 탭 콘텐츠
  Widget _buildFormGuideTab(ThemeData theme) {
    return _buildMarkdownTab(theme, _pdfFormGuideMarkdown);
  }

  // ============================================================================
  // Markdown Style Sheet
  // ============================================================================

  /// 마크다운 스타일 시트 생성
  MarkdownStyleSheet _buildMarkdownStyleSheet(ThemeData theme) {
    return MarkdownStyleSheet(
      // 제목 스타일
      h1: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: theme.primaryColor,
        height: 1.5,
      ),
      h2: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: theme.primaryColor.withValues(alpha: 0.9),
        height: 1.5,
      ),
      h3: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.primaryColor.withValues(alpha: 0.8),
        height: 1.4,
      ),
      // 본문 스타일
      p: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Colors.grey.shade700,
      ),
      // 리스트 스타일
      listBullet: TextStyle(
        fontSize: 14,
        color: theme.primaryColor,
        fontWeight: FontWeight.bold,
      ),
      // 코드 블록 스타일
      code: TextStyle(
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: Colors.grey.shade200,
        color: Colors.grey.shade900,
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      // 링크 스타일
      a: TextStyle(
        fontSize: 14,
        color: theme.primaryColor,
        decoration: TextDecoration.underline,
      ),
      // 강조 스타일
      strong: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade900,
      ),
      em: TextStyle(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: Colors.grey.shade700,
      ),
      // 블록 인용 스타일
      blockquote: TextStyle(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: Colors.grey.shade600,
      ),
      blockquoteDecoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          left: BorderSide(
            color: theme.primaryColor,
            width: 4,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // YouTube Processing
  // ============================================================================

  /// 마크다운 텍스트 전처리
  /// 
  /// 1. HTML <img> 태그를 마크다운 이미지 문법으로 변환
  /// 2. 유튜브 링크를 썸네일 이미지로 변환
  String _processMarkdownWithYoutubeThumbnails(String markdown) {
    String processed = markdown;
    
    // 1. HTML <img> 태그를 마크다운 이미지 문법으로 변환
    // <img src="image.png" style="width: 100%; max-width: 600px;" /> 형식 처리
    // src 속성에서 이미지 경로 추출
    // 따옴표가 작은따옴표 또는 큰따옴표일 수 있으므로 두 가지 패턴으로 처리
    final htmlImgPattern1 = RegExp(
      r'<img\s+src="([^"]+)"[^>]*/?>',
      caseSensitive: false,
      multiLine: true,
    );
    final htmlImgPattern2 = RegExp(
      r"<img\s+src='([^']+)'[^>]*/?>",
      caseSensitive: false,
      multiLine: true,
    );
    
    processed = processed.replaceAllMapped(htmlImgPattern1, (match) {
      final imageSrc = match.group(1) ?? '';
      // HTML 태그를 마크다운 이미지 문법으로 변환
      return '![]($imageSrc)';
    });
    
    processed = processed.replaceAllMapped(htmlImgPattern2, (match) {
      final imageSrc = match.group(1) ?? '';
      // HTML 태그를 마크다운 이미지 문법으로 변환
      return '![]($imageSrc)';
    });
    
    // 2. 유튜브 링크 패턴
    final youtubePattern = RegExp(
      r'\[([^\]]+)\]\(https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]+)\)',
      multiLine: true,
    );

    processed = processed.replaceAllMapped(youtubePattern, (match) {
      final linkText = match.group(1) ?? '';
      final videoId = match.group(2) ?? '';
      
      // 유튜브 썸네일 이미지 URL
      final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
      
      // 이미지와 링크를 결합한 마크다운 형식으로 변환
      return '[![$linkText]($thumbnailUrl "$linkText")]($videoUrl)';
    });
    
    return processed;
  }

  /// 썸네일 URL에서 비디오 ID 추출
  String? _extractVideoIdFromThumbnailUrl(String url) {
    final pattern = RegExp(r'img\.youtube\.com/vi/([a-zA-Z0-9_-]+)/');
    final match = pattern.firstMatch(url);
    return match?.group(1);
  }

  /// 유튜브 썸네일 위젯 생성
  Widget _buildYouTubeThumbnail(String videoId, String alt) {
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
    
    return GestureDetector(
      onTap: () => UrlLauncherHelper.launchURL(videoUrl, context: context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  // 썸네일 로드 실패 시 대체 이미지
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            // 재생 버튼 오버레이
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Utilities
  // ============================================================================
  // (URL 실행 유틸리티는 UrlLauncherHelper로 이동)
}

