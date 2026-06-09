import 'package:flutter/material.dart';
import '../../../constants/app_info.dart';
import '../../../utils/url_launcher_helper.dart';
import '../../widgets/app_branding_header.dart';
import '../../widgets/app_content_card.dart';

/// 도움말 > 프로그램 정보 탭 콘텐츠
///
/// 앱 버전, 제작자, 소개, 라이선스 등 메타 정보를 표시합니다.
class ProgramInfoContent extends StatelessWidget {
  const ProgramInfoContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildBasicInfoCard(),
            const SizedBox(height: 16),
            _buildDetailInfoCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return const AppContentCard(
      child: AppBrandingHeader(showVersionAndPeriod: true),
    );
  }

  Widget _buildBasicInfoCard() {
    return AppContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Developer :',
            value: AppInfo.developer,
          ),
          const SizedBox(height: 12),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.business_outlined,
            label: 'Company :',
            value: AppInfo.affiliation,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailInfoCard(ThemeData theme) {
    return AppContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(theme, Icons.description_outlined, '프로그램 소개'),
              const SizedBox(height: 6),
              _buildSectionContentAsList(AppInfo.description.trim()),
            ],
          ),
          _buildSectionSpacer(),
          _buildUsageRestrictionSection(theme),
          _buildSectionSpacer(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                theme,
                Icons.contact_support_outlined,
                'Noah Lab 정보',
              ),
              const SizedBox(height: 6),
              _buildSectionContentAsList(AppInfo.contact.trim()),
            ],
          ),
          _buildSectionSpacer(),
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
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
          child: Icon(icon, color: headerColor, size: 15),
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

  Widget _buildSectionContentAsList(String content) {
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

  Widget _buildUsageRestrictionSection(ThemeData theme) {
    final daysUntilExpiry = AppInfo.getDaysUntilExpiry();
    final isExpired = AppInfo.isExpired();
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
          '베타 버전 이용 안내',
          color: color,
        ),
        const SizedBox(height: 6),
        _buildSectionContentAsList(AppInfo.usageRestriction.trim()),
      ],
    );
  }

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
                  onTap: () => UrlLauncherHelper.launchURL(url),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 4,
                    ),
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

  Widget _buildSectionSpacer() {
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildDivider(),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade300);
  }
}
