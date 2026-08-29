import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/teacher_row_highlight_colors.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/services_provider.dart';
import '../../../providers/substitution_plan_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../theme/app_theme_type.dart';
import '../../../theme/design_tokens.dart';
import '../../widgets/timetable_grid/exchange_arrow_direction_icon.dart';
import '../../widgets/timetable_grid/exchange_arrow_style.dart';
import '../../../services/app_settings_storage_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/simplified_timetable_theme.dart';
import '../../widgets/timetable_grid/timetable_grid_constants.dart';
import '../../widgets/data_storage_location_section.dart';
import 'highlight_color_picker.dart';
import 'setting_save_mixin.dart';

/// 시작 화면 설정 카드 (언어 · 2중 교체 · 하이라이트 색상 · 저장 위치 · 데이터 초기화)
///
/// 설정 관련 상태(언어·색상·초기화)를 스스로 로드/저장한다.
///
/// 교사명·학교명은 활성 시간표의 속성이므로 이 카드가 관여하지 않는다(문서 §2).
/// 데이터 초기화 성공 시 [onDataReset]으로 부모에 알린다(선택).
class StartSettingsCard extends ConsumerStatefulWidget {
  /// 전체 데이터 초기화 완료 알림 (필요 없으면 생략)
  final VoidCallback? onDataReset;

  const StartSettingsCard({super.key, this.onDataReset});

  @override
  ConsumerState<StartSettingsCard> createState() => _StartSettingsCardState();
}

class _StartSettingsCardState extends ConsumerState<StartSettingsCard>
    with SettingSaveMixin {
  // 언어 설정
  String _selectedLanguage = 'ko';
  bool _isLoadingLanguage = true;

  // 하이라이트 색상
  Color _highlightedTeacherColor = TeacherRowHighlightColors.defaultColor;
  bool _isLoadingHighlightColor = true;
  bool _isSavingHighlightColor = false;

  // 데이터 초기화
  bool _isResetting = false;

  // 기타 설정 기본값 복원
  bool _isRestoringDefaults = false;

  // 데이터 저장 위치 표시
  final GlobalKey<DataStorageLocationSectionState> _dataStorageLocationKey =
      GlobalKey<DataStorageLocationSectionState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 언어·하이라이트 색상 설정 로드
  Future<void> _loadSettings() async {
    try {
      final appSettings = AppSettingsStorageService();
      final results = await Future.wait([
        appSettings.getLanguageCode(),
        appSettings.getHighlightedTeacherColor(),
      ]);

      if (!mounted) return;
      setState(() {
        _selectedLanguage = results[0] as String;
        _isLoadingLanguage = false;

        // 구 프리셋은 교체 범례와 유사하여 자동 교체
        final colorValue = results[1] as int?;
        final resolvedColor = TeacherRowHighlightColors.resolveSavedColor(
          colorValue,
        );
        _highlightedTeacherColor = resolvedColor;
        if (colorValue != null && resolvedColor.toARGB32() != colorValue) {
          SimplifiedTimetableTheme.setHighlightedTeacherColor(resolvedColor);
        }
        _isLoadingHighlightColor = false;
      });
    } catch (e) {
      AppLogger.error('설정 로드 중 오류: $e', e);
      if (mounted) {
        setState(() {
          _isLoadingLanguage = false;
          _isLoadingHighlightColor = false;
        });
      }
    }
  }

  /// 언어 설정 저장
  Future<void> _saveLanguage(String languageCode) async {
    final appSettings = AppSettingsStorageService();
    await saveSetting(
      saver: () => appSettings.saveAppSettings(languageCode: languageCode),
      successMessage: '언어 설정이 저장되었습니다. 앱을 재시작하면 적용됩니다.',
      onSuccess: () => setState(() => _selectedLanguage = languageCode),
    );
  }

  /// 2중 교체 설정 저장
  Future<void> _saveDualExchangeEnabled(bool enabled) async {
    await saveSetting(
      saver:
          () => ref
              .read(dualExchangeEnabledProvider.notifier)
              .setEnabled(enabled),
      successMessage: enabled ? '2중 교체 기능이 활성화되었습니다.' : '2중 교체 기능이 비활성화되었습니다.',
    );
  }

  /// 순환 교체 설정 저장
  Future<void> _saveCircularExchangeEnabled(bool enabled) async {
    await saveSetting(
      saver:
          () => ref
              .read(circularExchangeEnabledProvider.notifier)
              .setEnabled(enabled),
      successMessage: enabled ? '순환 교체 기능이 활성화되었습니다.' : '순환 교체 기능이 비활성화되었습니다.',
    );
  }

  /// 1:1 교체 화살표 방향 저장
  Future<void> _saveOneToOneArrowDirection(ArrowDirection direction) async {
    await saveSetting(
      saver:
          () => ref
              .read(oneToOneArrowDirectionProvider.notifier)
              .setDirection(direction),
      successMessage: '화살표 표시 설정이 저장되었습니다.',
    );
  }

  /// 2중 교체 화살표 방향 저장
  Future<void> _saveDualArrowDirection(ArrowDirection direction) async {
    await saveSetting(
      saver:
          () => ref
              .read(dualArrowDirectionProvider.notifier)
              .setDirection(direction),
      successMessage: '화살표 표시 설정이 저장되었습니다.',
    );
  }

  /// 하이라이트 색상 저장
  Future<void> _saveHighlightColor(Color color) async {
    final appSettings = AppSettingsStorageService();
    await saveSetting(
      saver: () => appSettings.saveHighlightedTeacherColor(color.toARGB32()),
      successMessage: '하이라이트 색상이 저장되었습니다.',
      setSavingState: (value) => _isSavingHighlightColor = value,
      onSuccess: () {
        setState(() => _highlightedTeacherColor = color);
        SimplifiedTimetableTheme.setHighlightedTeacherColor(color);
      },
    );
  }

  /// 기타 설정을 앱 기본값으로 복원 (언어·교사명·학교명은 유지)
  Future<void> _restoreMiscSettingsToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('기본값 복원'),
            content: const Text(
              '기타 설정을 기본값으로 되돌리시겠습니까?\n\n'
              '복원되는 항목:\n'
              '• 하이라이트 색상: 기본 청록\n'
              '• 2중 교체: 활성화\n'
              '• 순환 교체: 비활성화\n'
              '• 1:1 화살표: 양방향(1개)\n'
              '• 2중 화살표: 양방향(1개)\n\n'
              '언어·교사명·학교명은 변경되지 않습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('복원'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoringDefaults = true);

    try {
      final success =
          await AppSettingsStorageService().restoreMiscSettingsToDefaults();

      if (!mounted) return;

      if (success) {
        ref.invalidate(dualExchangeEnabledProvider);
        ref.invalidate(circularExchangeEnabledProvider);
        ref.invalidate(oneToOneArrowDirectionProvider);
        ref.invalidate(dualArrowDirectionProvider);
        await _loadSettings();
        showSnackBar('기타 설정이 기본값으로 복원되었습니다.');
      } else {
        showSnackBar('기본값 복원에 실패했습니다.', isError: true);
      }
    } catch (e) {
      AppLogger.error('기본값 복원 중 오류: $e', e);
      if (mounted) {
        showSnackBar('오류가 발생했습니다: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoringDefaults = false);
      }
    }
  }

  /// 모든 데이터 초기화
  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('데이터 초기화', style: TextStyle(color: Colors.red)),
            content: const Text(
              '모든 저장된 데이터를 삭제하시겠습니까?\n\n'
              '다음 데이터가 삭제됩니다:\n'
              '• 시간표 데이터\n'
              '• 교체 리스트\n'
              '• 교체불가 셀 데이터\n'
              '• 결보강 계획서 데이터\n'
              '• PDF 출력 설정\n'
              '• 시간표 테마 설정\n'
              '• 앱 설정\n\n'
              '이 작업은 되돌릴 수 없습니다!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('모두 삭제'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isResetting = true);

    try {
      final results = await StorageService().deleteAllJsonFiles();
      final successCount = results.values.where((v) => v).length;
      final totalCount = results.length;
      final failedFiles =
          results.entries.where((e) => !e.value).map((e) => e.key).toList();

      if (mounted) {
        if (failedFiles.isEmpty && totalCount > 0) {
          // timetable_registry.json도 함께 지워졌으므로 메모리 상태를 비운다.
          // 그러지 않으면 삭제된 시간표가 홈 카드에 계속 남는다(문서 §7-4).
          _resetInMemoryTimetableState();
          showSnackBar('모든 데이터가 삭제되었습니다. ($totalCount개 파일)');
          widget.onDataReset?.call();
        } else if (totalCount == 0) {
          showSnackBar('삭제할 데이터가 없습니다.');
        } else {
          showSnackBar(
            '일부 데이터 삭제에 실패했습니다.\n성공: $successCount개 / 전체: $totalCount개',
            isError: true,
          );
        }
      }
    } catch (e) {
      AppLogger.error('데이터 초기화 중 오류: $e', e);
      if (mounted) {
        showSnackBar('오류가 발생했습니다: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
        await _dataStorageLocationKey.currentState?.reload();
      }
    }
  }

  /// 데이터 초기화 후 시간표 관련 메모리 상태 비우기
  ///
  /// 디스크 파일만 지우면 Provider와 서비스에 남은 값이 다시 화면에 나타난다.
  void _resetInMemoryTimetableState() {
    ref.read(exchangeHistoryServiceProvider).resetInMemoryState();
    ref.read(substitutionPlanProvider.notifier).clearInMemory();
    ref.invalidate(timetableRegistryProvider);
    ref.read(timetableSwitchVersionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        // ExpansionTile 내부 ListTile이 배경색 있는 Container에 가려지지 않도록
        // 잉크를 그릴 자체 Material 제공 (Flutter 디버그 assertion 요구)
        color: Colors.transparent,
        child: ExpansionTile(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings,
                  color: theme.primaryColor,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '기타 설정',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLanguageSection(),
                  const SizedBox(height: 8),
                  _buildThemeSection(),
                  const SizedBox(height: 8),
                  _buildHighlightColorSection(),
                  const SizedBox(height: 8),
                  _buildResponsiveExchangeSettingsSections(),
                  const SizedBox(height: 8),
                  DataStorageLocationSection(
                    key: _dataStorageLocationKey,
                    compact: true,
                  ),
                  const SizedBox(height: 8),
                  _buildResponsiveActionCardsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 디자인 테마 선택 섹션 (클래식 / 머티리얼 3)
  Widget _buildThemeSection() {
    final selectedTheme = ref.watch(appThemeTypeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '디자인 테마',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < AppThemeType.displayOrder.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _buildThemeOptionCard(
                  AppThemeType.displayOrder[i],
                  isSelected: selectedTheme == AppThemeType.displayOrder[i],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 개별 디자인 테마 옵션 카드
  Widget _buildThemeOptionCard(AppThemeType type, {required bool isSelected}) {
    final tokens = context.tokens;
    final previewTokens = DesignTokens.of(type);

    return InkWell(
      onTap: () => _selectTheme(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.sectionBackground,
          border: Border.all(
            color: isSelected ? previewTokens.primary : tokens.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildThemePreviewSwatch(previewTokens),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color:
                            isSelected
                                ? previewTokens.primary
                                : tokens.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          type.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.description,
                    style: TextStyle(fontSize: 10, color: tokens.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 테마 미리보기 스와치 (미니 화면 목업)
  Widget _buildThemePreviewSwatch(DesignTokens t) {
    return Container(
      width: 36,
      height: 30,
      decoration: BoxDecoration(
        color: t.scaffoldBackground,
        border: Border.all(color: t.cardBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 7, color: t.appBarBackground),
          Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.8,
                  child: Container(
                    height: 3,
                    color: t.textPrimary.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 14,
                  height: 7,
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 디자인 테마 선택 저장
  Future<void> _selectTheme(AppThemeType type) async {
    await saveSetting(
      saver: () => ref.read(appThemeTypeProvider.notifier).select(type),
      successMessage: '디자인 테마가 ${type.displayName}(으)로 변경되었습니다.',
    );
  }

  /// 언어 설정 섹션
  Widget _buildLanguageSection() {
    if (_isLoadingLanguage) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(4.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '언어 설정',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        DropdownButton<String>(
          value: _selectedLanguage,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(
              value: 'ko',
              child: Text('한국어', style: TextStyle(fontSize: 12)),
            ),
          ],
          onChanged:
              (newValue) =>
                  newValue != null && newValue != _selectedLanguage
                      ? _saveLanguage(newValue)
                      : null,
        ),
      ],
    );
  }

  /// 2개 카드 섹션 배치 (넓으면 1행·높이 연동, 좁으면 2행)
  ///
  /// ExpansionTile 자식은 세로 max가 무한이므로 Row+stretch 단독 사용은 위험하다.
  /// [IntrinsicHeight]로 행 높이를 먼저 확정한 뒤 stretch 한다.
  Widget _buildResponsivePairedSections({
    required Widget Function(bool stretchHeight) buildFirst,
    required Widget Function(bool stretchHeight) buildSecond,
    double minSectionWidth = 280,
    double spacing = 12,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= minSectionWidth * 2 + spacing;
        final first = buildFirst(twoColumns);
        final second = buildSecond(twoColumns);

        if (twoColumns) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: first),
                SizedBox(width: spacing),
                Expanded(child: second),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, SizedBox(height: spacing), second],
        );
      },
    );
  }

  /// 간접교체 · 화살표 표시 섹션 (동일 너비·높이, 넓으면 1행·좁으면 2행)
  Widget _buildResponsiveExchangeSettingsSections() {
    return _buildResponsivePairedSections(
      buildFirst:
          (stretchHeight) =>
              _buildIndirectExchangeGroupSection(stretchHeight: stretchHeight),
      buildSecond:
          (stretchHeight) =>
              _buildArrowDirectionSection(stretchHeight: stretchHeight),
    );
  }

  /// 설정 그룹 공통 외곽 카드 (화살표 표시 · 간접교체)
  Widget _buildSettingsGroupCard({
    required Widget child,
    bool stretchHeight = false,
  }) {
    final tokens = context.tokens;

    return Container(
      width: double.infinity,
      height: stretchHeight ? double.infinity : null,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  /// 화살표 표시 설정 섹션 (1:1·2중·연쇄 교체 화살표 방향)
  Widget _buildArrowDirectionSection({bool stretchHeight = false}) {
    final tokens = context.tokens;
    final oneToOneDir = ref.watch(oneToOneArrowDirectionProvider);
    final dualDir = ref.watch(dualArrowDirectionProvider);
    final isDualExchangeEnabled = ref.watch(dualExchangeEnabledProvider);
    final isCircularExchangeEnabled = ref.watch(
      circularExchangeEnabledProvider,
    );

    return _buildSettingsGroupCard(
      stretchHeight: stretchHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Text(
            '화살표 표시',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '교체 화면 시간표에 표시되는 화살표 방향을 설정합니다.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildArrowDirectionCard(
                label: '1:1 교체',
                value: oneToOneDir,
                arrowColor: ExchangeArrowStyle.oneToOne.color,
                onChanged: _saveOneToOneArrowDirection,
              ),
              _buildArrowDirectionCard(
                label: '2중 교체',
                value: dualDir,
                arrowColor: ExchangeArrowStyle.dual.color,
                enabled: isDualExchangeEnabled,
                onChanged: _saveDualArrowDirection,
              ),
              _buildArrowDirectionStaticCard(
                label: '연쇄교체',
                arrowColor: ExchangeArrowStyle.circular.color,
                enabled: isCircularExchangeEnabled,
              ),
            ],
          ),
          if (stretchHeight) const Spacer(),
        ],
      ),
    );
  }

  /// 연쇄교체 화살표 표시 카드 (단방향 1개 고정, 선택 불가)
  Widget _buildArrowDirectionStaticCard({
    required String label,
    required Color arrowColor,
    bool enabled = true,
  }) {
    final tokens = context.tokens;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? tokens.surface : tokens.sectionBackground,
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.black87 : tokens.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            ExchangeArrowDirectionIcon(
              direction: ArrowDirection.forward,
              color: enabled ? arrowColor : tokens.textMuted,
              singleLine: true,
            ),
          ],
        ),
      ),
    );
  }

  /// 화살표 방향 선택 카드 (1:1·2중 각각 그룹)
  Widget _buildArrowDirectionCard({
    required String label,
    required ArrowDirection value,
    required Color arrowColor,
    required ValueChanged<ArrowDirection> onChanged,
    bool enabled = true,
  }) {
    final tokens = context.tokens;
    final effectiveColor = enabled ? arrowColor : tokens.textMuted;

    Widget arrowIcon(ArrowDirection direction) {
      return ExchangeArrowDirectionIcon(
        direction: direction,
        color: effectiveColor,
      );
    }

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? tokens.surface : tokens.sectionBackground,
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.black87 : tokens.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            DropdownButton<ArrowDirection>(
              value: value,
              underline: const SizedBox.shrink(),
              isDense: true,
              iconSize: 18,
              selectedItemBuilder:
                  (context) => [
                    arrowIcon(ArrowDirection.forward),
                    arrowIcon(ArrowDirection.bidirectional),
                  ],
              items: [
                DropdownMenuItem(
                  value: ArrowDirection.forward,
                  child: arrowIcon(ArrowDirection.forward),
                ),
                DropdownMenuItem(
                  value: ArrowDirection.bidirectional,
                  child: arrowIcon(ArrowDirection.bidirectional),
                ),
              ],
              onChanged:
                  !enabled
                      ? null
                      : (newValue) =>
                          newValue != null && newValue != value
                              ? onChanged(newValue)
                              : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 간접교체 그룹 (2중 교체 · 순환 교체 메뉴 표시 설정)
  Widget _buildIndirectExchangeGroupSection({bool stretchHeight = false}) {
    final tokens = context.tokens;

    return _buildSettingsGroupCard(
      stretchHeight: stretchHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Text(
            '간접교체',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '1:1 교체가 어려울 때 교체 화면에 표시할 메뉴를 설정합니다.',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildIndirectExchangeCard(
                label: '2중교체',
                description: '2회 간접 교체',
                showRecommended: true,
                isEnabled: ref.watch(dualExchangeEnabledProvider),
                onChanged: _saveDualExchangeEnabled,
              ),
              _buildIndirectExchangeCard(
                label: '순환교체',
                description: '3~4회 간접 교체',
                isEnabled: ref.watch(circularExchangeEnabledProvider),
                onChanged: _saveCircularExchangeEnabled,
              ),
            ],
          ),
          if (stretchHeight) const Spacer(),
        ],
      ),
    );
  }

  /// 간접교체 토글 카드 (화살표 설정 카드와 동일한 컴팩트 스타일)
  Widget _buildIndirectExchangeCard({
    required String label,
    required String description,
    bool showRecommended = false,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showRecommended) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '추천',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                description,
                style: TextStyle(fontSize: 10, color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.72,
            alignment: Alignment.center,
            child: Switch(
              value: isEnabled,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  /// 하이라이트 색상 설정 섹션
  Widget _buildHighlightColorSection() {
    if (_isLoadingHighlightColor) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return HighlightColorPicker(
      currentColor: _highlightedTeacherColor,
      isSaving: _isSavingHighlightColor,
      onColorSelected: _saveHighlightColor,
    );
  }

  /// 기본값 복원 · 데이터 초기화 카드 (넓으면 1행·높이 연동, 좁으면 2행)
  Widget _buildResponsiveActionCardsSection() {
    return _buildResponsivePairedSections(
      buildFirst:
          (stretchHeight) => _buildSettingsGroupCard(
            stretchHeight: stretchHeight,
            child: _buildRestoreDefaultsCardContent(
              stretchHeight: stretchHeight,
            ),
          ),
      buildSecond:
          (stretchHeight) => _buildSettingsGroupCard(
            stretchHeight: stretchHeight,
            child: _buildDataResetCardContent(stretchHeight: stretchHeight),
          ),
    );
  }

  /// 기본값 복원 카드 내용
  Widget _buildRestoreDefaultsCardContent({bool stretchHeight = false}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const Text(
          '기본값 복원',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        if (stretchHeight) const Spacer() else const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                _isRestoringDefaults ? null : _restoreMiscSettingsToDefaults,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryColor,
              side: BorderSide(
                color: theme.primaryColor.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon:
                _isRestoringDefaults
                    ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                    )
                    : Icon(Icons.restore, size: 18, color: theme.primaryColor),
            label: const Text('기본값 복원', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }

  /// 데이터 초기화 카드 내용
  Widget _buildDataResetCardContent({bool stretchHeight = false}) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: stretchHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const Text(
          '데이터 초기화',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '모든 저장된 데이터를 삭제합니다.',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        if (stretchHeight) const Spacer() else const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isResetting ? null : _resetAllData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child:
                _isResetting
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text('모든 데이터 삭제', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
