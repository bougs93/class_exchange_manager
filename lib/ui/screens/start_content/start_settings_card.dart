import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/teacher_row_highlight_colors.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../theme/app_theme_type.dart';
import '../../../theme/design_tokens.dart';
import '../../../services/stored_data_reset.dart';
import '../../../services/app_settings_storage_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/simplified_timetable_theme.dart';
import '../../widgets/timetable_grid/timetable_grid_constants.dart';
import '../../widgets/data_storage_location_section.dart';
import 'dated_data_inspector_section.dart';
import 'highlight_color_picker.dart';
import 'semester_period_section.dart';
import 'setting_save_mixin.dart';
import 'settings/arrow_direction_section.dart';
import 'settings/data_reset_card_content.dart';
import 'settings/design_theme_section.dart';
import 'settings/indirect_exchange_section.dart';
import 'settings/language_section.dart';
import 'settings/responsive_paired_sections.dart';
import 'settings/restore_defaults_card_content.dart';
import 'settings/settings_group_card.dart';

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
              '• 날짜별 수업 데이터\n'
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
      final result = await StoredDataReset.deleteAll(ref);

      if (mounted) {
        final message = _resetResultMessage(result);
        showSnackBar(message.text, isError: message.isError);
        if (!message.isError && result.hadAnything) {
          await _loadSettings();
          widget.onDataReset?.call();
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

  ({String text, bool isError}) _resetResultMessage(
    StoredDataResetResult result,
  ) {
    if (result.databaseDeleteFailed || !result.jsonOk) {
      return (
        text: '일부 데이터를 지우지 못했습니다. 앱을 다시 시작한 뒤 한 번 더 시도해 주세요.',
        isError: true,
      );
    }
    if (!result.hadAnything) {
      return (text: '삭제할 데이터가 없습니다.', isError: false);
    }
    return (text: '모든 데이터가 삭제되었습니다.', isError: false);
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
                  LanguageSection(
                    isLoading: _isLoadingLanguage,
                    selectedLanguage: _selectedLanguage,
                    onChanged: _saveLanguage,
                  ),
                  const SizedBox(height: 8),
                  DesignThemeSection(onSelect: _selectTheme),
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
                  const SemesterPeriodSection(),
                  const SizedBox(height: 8),
                  _buildResponsiveActionCardsSection(),
                  const SizedBox(height: 8),
                  const DatedDataInspectorSection(),
                ],
              ),
            ),
          ],
        ),
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

  /// 간접교체 · 화살표 표시 섹션 (동일 너비·높이, 넓으면 1행·좁으면 2행)
  Widget _buildResponsiveExchangeSettingsSections() {
    return ResponsivePairedSections(
      buildFirst:
          (stretchHeight) => IndirectExchangeGroupSection(
            stretchHeight: stretchHeight,
            onDualChanged: _saveDualExchangeEnabled,
            onCircularChanged: _saveCircularExchangeEnabled,
          ),
      buildSecond:
          (stretchHeight) => ArrowDirectionSection(
            stretchHeight: stretchHeight,
            onOneToOneChanged: _saveOneToOneArrowDirection,
            onDualChanged: _saveDualArrowDirection,
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
    return ResponsivePairedSections(
      buildFirst:
          (stretchHeight) => SettingsGroupCard(
            stretchHeight: stretchHeight,
            child: RestoreDefaultsCardContent(
              stretchHeight: stretchHeight,
              isRestoring: _isRestoringDefaults,
              onPressed: _restoreMiscSettingsToDefaults,
            ),
          ),
      buildSecond:
          (stretchHeight) => SettingsGroupCard(
            stretchHeight: stretchHeight,
            child: DataResetCardContent(
              stretchHeight: stretchHeight,
              isResetting: _isResetting,
              onPressed: _resetAllData,
            ),
          ),
    );
  }
}
