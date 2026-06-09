import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/teacher_row_highlight_colors.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../services/app_settings_storage_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/simplified_timetable_theme.dart';
import '../../widgets/data_storage_location_section.dart';
import 'highlight_color_picker.dart';
import 'setting_save_mixin.dart';

/// 시작 화면 설정 카드 (언어 · 2중 교체 · 하이라이트 색상 · 저장 위치 · 데이터 초기화)
///
/// 설정 관련 상태(언어·색상·초기화)를 스스로 로드/저장하여 시작 화면 본체의
/// 기본 정보(교사명·학교명) 관리와 책임을 분리한다.
///
/// 펼침 상태는 부모가 제어한다([expanded]/[onExpansionChanged]) — 교사명이
/// 비어 있을 때 자동으로 펼치는 등의 판단을 부모(기본 정보 로더)가 담당하기 때문이다.
/// 데이터 초기화 성공 시 [onDataReset]으로 부모에 알려 교사명/학교명을 비우게 한다.
class StartSettingsCard extends ConsumerStatefulWidget {
  final VoidCallback onDataReset;

  const StartSettingsCard({super.key, required this.onDataReset});

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
          showSnackBar('모든 데이터가 삭제되었습니다. ($totalCount개 파일)');
          widget.onDataReset(); // 부모의 교사명/학교명 비우기
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.settings, color: theme.primaryColor, size: 14),
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
                _buildHighlightColorSection(),
                const SizedBox(height: 8),
                _buildIndirectExchangeGroupSection(),
                const SizedBox(height: 8),
                DataStorageLocationSection(
                  key: _dataStorageLocationKey,
                  compact: true,
                ),
                const SizedBox(height: 8),
                _buildDataResetSection(),
              ],
            ),
          ),
        ],
      ),
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

  /// 간접교체 그룹 (2중 교체 · 순환 교체 메뉴 표시 설정)
  Widget _buildIndirectExchangeGroupSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '간접교체',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '1:1 교체가 어려울 때 교체 화면에 표시할 메뉴를 설정합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          _buildExchangeModeTogglesSection(),
        ],
      ),
    );
  }

  /// 2중교체 · 순환교체 토글을 한 줄에 가로 배치
  Widget _buildExchangeModeTogglesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildIndirectExchangeToggle(
            label: '2중교체',
            description: '2회의 간접 교체',
            showRecommended: true,
            isEnabled: ref.watch(dualExchangeEnabledProvider),
            onChanged: _saveDualExchangeEnabled,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildIndirectExchangeToggle(
            label: '순환교체',
            description: '3~4회의 간접 교체',
            isEnabled: ref.watch(circularExchangeEnabledProvider),
            onChanged: _saveCircularExchangeEnabled,
          ),
        ),
      ],
    );
  }

  /// 간접교체 하위 메뉴 토글
  Widget _buildIndirectExchangeToggle({
    required String label,
    required String description,
    bool showRecommended = false,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 0.72,
          alignment: Alignment.topLeft,
          child: Switch(
            value: isEnabled,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (showRecommended) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
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
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
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

  /// 데이터 초기화 섹션
  Widget _buildDataResetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '데이터 초기화',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '모든 저장된 데이터를 삭제합니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
