import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_info.dart';

/// 정보 화면
/// 
/// 앱의 기본 정보를 표시합니다.
/// - 프로그램명, 버전
/// - 개발자, 회사 정보
/// - 프로그램 소개, 실행 제한, 홈페이지, 업데이트, 연락처, 라이센스
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  // ============================================================================
  // Main Build Method
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('정보'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withValues(alpha: 0.05),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 섹션 (프로그램명, 버전)
              _buildHeaderCard(theme),
              const SizedBox(height: 16),
              
              // 기본 정보 카드 (제작자, 소속)
              _buildBasicInfoCard(theme),
              const SizedBox(height: 16),
              
              // 모든 정보를 하나의 카드로 통합
              _buildAllInfoCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // Main Cards
  // ============================================================================

  /// 헤더 카드 (프로그램명, 버전, 만료일 정보)
  Widget _buildHeaderCard(ThemeData theme) {
    final daysUntilExpiry = AppInfo.getDaysUntilExpiry();
    final isExpired = AppInfo.isExpired();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로그램명과 버전
            _buildProgramTitleSection(),
            
            // 만료일 정보 (있는 경우만 표시)
            if (daysUntilExpiry != null) ...[
              const SizedBox(height: 16),
              _buildExpiryInfoBanner(daysUntilExpiry, isExpired),
            ],
          ],
        ),
      ),
    );
  }

  /// 기본 정보 카드 (제작자, 회사)
  Widget _buildBasicInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Developer
            _buildDeveloperRow(),
            const SizedBox(height: 12),
            _buildDivider(),
            const SizedBox(height: 16),
            // Company
            _buildAffiliationRow(),
          ],
        ),
      ),
    );
  }

  /// 모든 정보를 하나의 카드로 통합
  Widget _buildAllInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로그램 소개 (불릿 리스트 형태)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(theme, Icons.description_outlined, '프로그램 소개'),
                const SizedBox(height: 6),
                _buildSectionContentAsList(AppInfo.description.trim()),
              ],
            ),
            _buildSectionSpacer(),
            
            // 프로그램 실행 제한 (불릿 리스트 형태)
            _buildUsageRestrictionSubSectionWithList(theme),
            _buildSectionSpacer(),
            
            // 홈페이지 링크 (불릿 리스트 형태)
            if (AppInfo.homepageLinks.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(theme, Icons.link, '홈페이지'),
                  const SizedBox(height: 6),
                  _buildHomepageLinksAsList(theme),
                ],
              ),
              _buildSectionSpacer(),
            ],
            
            // 업데이트 정보 (불릿 리스트 형태)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(theme, Icons.update_outlined, '업데이트 정보'),
                const SizedBox(height: 6),
                _buildSectionContentAsList(AppInfo.updateInfo.trim()),
              ],
            ),
            _buildSectionSpacer(),
            
            // 연락처 (불릿 리스트 형태)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(theme, Icons.contact_support_outlined, ' 정보'),
                const SizedBox(height: 6),
                _buildSectionContentAsList(AppInfo.contact.trim()),
              ],
            ),
            _buildSectionSpacer(),
            
            // 라이센스 (불릿 리스트 형태)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(theme, Icons.copyright_outlined, '라이센스'),
                const SizedBox(height: 6),
                _buildSectionContentAsList(AppInfo.license.trim()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Header Card Components
  // ============================================================================

  /// 프로그램명과 버전 섹션
  Widget _buildProgramTitleSection() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.school,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppInfo.programName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppInfo.version,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 만료일 정보 배너
  Widget _buildExpiryInfoBanner(int daysUntilExpiry, bool isExpired) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired 
          ? Colors.red.withValues(alpha: 0.2)
          : daysUntilExpiry <= 30
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.error_outline : Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getExpiryMessage(daysUntilExpiry, isExpired),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 만료일 메시지 생성
  String _getExpiryMessage(int daysUntilExpiry, bool isExpired) {
    if (isExpired) {
      return '프로그램 사용 기간이 만료되었습니다.';
    } else if (daysUntilExpiry == 0) {
      return '오늘이 사용 가능 마지막 날입니다.';
    } else {
      return '남은 사용 기간: $daysUntilExpiry일';
    }
  }

  // ============================================================================
  // Basic Info Card Components
  // ============================================================================

  /// 제작자 정보 Row 위젯
  Widget _buildDeveloperRow() {
    return _buildInfoRow(
      icon: Icons.person_outline,
      label: 'Developer :',
      value: AppInfo.developer,
    );
  }

  /// 소속 정보 Row 위젯
  Widget _buildAffiliationRow() {
    return _buildInfoRow(
      icon: Icons.business_outlined,
      label: 'Company :',
      value: AppInfo.affiliation,
    );
  }

  /// 정보 행 위젯 (공통)
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // All Info Card Sections
  // ============================================================================

  /// 섹션 헤더 (아이콘 + 제목)
  /// 
  /// [color]가 제공되면 해당 색상을 사용하고, 없으면 [theme.primaryColor]를 사용합니다.
  Widget _buildSectionHeader(
    ThemeData theme,
    IconData icon,
    String title, {
    Color? color,
  }) {
    final headerColor = color ?? theme.primaryColor;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: headerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: headerColor,
            size: 15,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: headerColor,
          ),
        ),
      ],
    );
  }

  /// 섹션 내용을 불릿 리스트 형태로 표시
  Widget _buildSectionContentAsList(String content) {
    // 빈 줄 제거 및 각 줄을 리스트로 변환
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 라이선스 및 정식 버전 안내  하위 섹션 (불릿 리스트 형태)
  Widget _buildUsageRestrictionSubSectionWithList(ThemeData theme) {
    final daysUntilExpiry = AppInfo.getDaysUntilExpiry();
    final isExpired = AppInfo.isExpired();
    
    // 만료 상태에 따른 색상 결정
    final color = isExpired 
      ? Colors.red 
      : daysUntilExpiry != null && daysUntilExpiry <= 30
        ? Colors.orange
        : theme.primaryColor;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          Icons.warning_amber_rounded,
          '라이선스 및 정식 버전 안내',
          color: color,
        ),
        const SizedBox(height: 6),
        _buildSectionContentAsList(AppInfo.usageRestriction.trim()),
      ],
    );
  }

  /// 홈페이지 링크를 불릿 리스트 형태로 표시
  Widget _buildHomepageLinksAsList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: AppInfo.homepageLinks.map((link) {
        final name = link['name'] ?? '';
        final url = link['url'] ?? '';
        final displayName = name.isNotEmpty ? name : url;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _launchURL(url),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: theme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================================
  // Helper Widgets
  // ============================================================================

  /// 섹션 간 간격과 구분선
  Widget _buildSectionSpacer() {
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildDivider(),
        const SizedBox(height: 6),
      ],
    );
  }

  /// 구분선
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade300,
    );
  }

  // ============================================================================
  // Utilities
  // ============================================================================

  /// URL 실행
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('URL 실행 불가: $url');
      }
    } catch (e) {
      debugPrint('URL 실행 오류: $e');
    }
  }
}
