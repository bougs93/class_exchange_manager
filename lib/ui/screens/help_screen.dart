import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../utils/url_launcher_helper.dart';

/// 도움말 화면
/// 
/// 프로그램 사용법과 양식 파일 정보를 제공합니다.
/// - 기본 사용법: 프로그램의 주요 기능 사용 방법
/// - 양식DF 파일: PDF 양식 파일 안내
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 마크다운 파일 내용을 저장할 변수
  String _basicUsageMarkdown = '';
  String _pdfFormGuideMarkdown = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 2개의 탭: "기본 사용법", "양식PDF 제작방법"
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: Duration.zero,
    );
    
    // 마크다운 파일 로드
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================================
  // Main Build Method
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('도움말'),
        elevation: 0,
        backgroundColor: Colors.blue.shade50,
      ),
      body: Column(
        children: [
          // 탭 메뉴 (document_screen.dart와 동일한 스타일)
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(
                    text: '기본 사용법',
                    icon: Icon(Icons.help_outline, size: 18),
                  ),
                  Tab(
                    text: '양식PDF 제작 방법',
                    icon: Icon(Icons.description, size: 18),
                  ),
                ],
              ),
            ),
          ),
          
          // 탭 컨텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // "기본 사용법" 탭
                _buildBasicUsageTab(theme),
                // "양식DF 파일" 탭
                _buildFormFileTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: MarkdownBody(
                data: _processMarkdownWithYoutubeThumbnails(markdownContent),
                styleSheet: _buildMarkdownStyleSheet(theme),
                imageBuilder: (uri, title, alt) {
                  // 유튜브 썸네일 이미지인 경우 특별 처리
                  if (uri.toString().contains('img.youtube.com')) {
                    final videoId = _extractVideoIdFromThumbnailUrl(uri.toString());
                    if (videoId != null) {
                      return _buildYouTubeThumbnail(videoId, alt ?? '');
                    }
                  }
                  // 일반 이미지는 기본 처리
                  return Image.network(uri.toString());
                },
                onTapLink: (text, href, title) {
                  if (href != null) {
                    UrlLauncherHelper.launchURL(href, context: context);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "기본 사용법" 탭 컨텐츠
  Widget _buildBasicUsageTab(ThemeData theme) {
    return _buildMarkdownTab(theme, _basicUsageMarkdown);
  }

  /// "양식PDF 제작 방법" 탭 컨텐츠
  Widget _buildFormFileTab(ThemeData theme) {
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

  /// 마크다운 텍스트에서 유튜브 링크를 찾아 썸네일 이미지로 변환
  /// 
  /// 유튜브 링크를 감지하고 이미지 태그로 변환하여 썸네일을 표시합니다.
  String _processMarkdownWithYoutubeThumbnails(String markdown) {
    // 유튜브 링크 패턴
    final youtubePattern = RegExp(
      r'\[([^\]]+)\]\(https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]+)\)',
      multiLine: true,
    );

    return markdown.replaceAllMapped(youtubePattern, (match) {
      final linkText = match.group(1) ?? '';
      final videoId = match.group(2) ?? '';
      
      // 유튜브 썸네일 이미지 URL
      final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      final videoUrl = 'https://www.youtube.com/watch?v=$videoId';
      
      // 이미지와 링크를 결합한 마크다운 형식으로 변환
      return '[![$linkText]($thumbnailUrl "$linkText")]($videoUrl)';
    });
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

