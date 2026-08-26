import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/personal_schedule_provider.dart';
import '../../services/app_settings_storage_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/logger.dart';
import '../widgets/app_branding_header.dart';
import '../widgets/app_content_card.dart';
import '../widgets/selected_timetable_file_banner.dart';
import 'start_content/start_settings_card.dart';
import 'start_content/setting_save_mixin.dart';
import 'handlers/exchange_ui_builder.dart';
import 'timetable_file_screen.dart';
import '../../providers/timetable_registry_provider.dart';

/// 시작 화면 콘텐츠
///
/// 엑셀 불러오기·기본 정보·설정을 표시합니다.
/// - 시간표 파일 선택 카드 / 기본 정보 카드
/// - 설정 (언어, 하이라이트 색상, 저장 위치 등) — 기본 정보는 별도 카드에서 편집
class StartContentScreen extends ConsumerStatefulWidget {
  const StartContentScreen({super.key});

  @override
  ConsumerState<StartContentScreen> createState() => _StartContentScreenState();
}

class _StartContentScreenState extends ConsumerState<StartContentScreen>
    with SettingSaveMixin, ExchangeUIBuilder {
  // 교사명, 학교명 입력 필드
  final TextEditingController _teacherNameController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();
  bool _isLoadingNames = true;
  bool _isSavingNames = false;

  @override
  void initState() {
    super.initState();

    // 설정에서 입력·저장 시 홈 카드 하단 기본 정보도 함께 갱신
    _teacherNameController.addListener(_onBasicInfoControllersChanged);
    _schoolNameController.addListener(_onBasicInfoControllersChanged);

    _loadSettings();
  }

  @override
  void dispose() {
    _teacherNameController.removeListener(_onBasicInfoControllersChanged);
    _schoolNameController.removeListener(_onBasicInfoControllersChanged);
    _teacherNameController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  /// 교사명·학교명 변경 시 홈 카드 요약 영역 갱신
  void _onBasicInfoControllersChanged() {
    if (mounted) setState(() {});
  }

  /// 교사명·학교명 로드 (언어·색상 등 설정은 StartSettingsCard가 자체 로드)
  Future<void> _loadSettings() async {
    try {
      final appSettings = AppSettingsStorageService();
      final nameData = await appSettings.loadTeacherAndSchoolName();

      if (mounted) {
        final teacherName = (nameData['defaultTeacherName'] ?? '').trim();
        final schoolName = (nameData['defaultSchoolName'] ?? '').trim();

        setState(() {
          _teacherNameController.text = teacherName;
          _schoolNameController.text = schoolName;
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      AppLogger.error('기본 정보 로드 중 오류: $e', e);
      if (mounted) {
        setState(() => _isLoadingNames = false);
      }
    }
  }

  /// 교사명과 학교명 저장
  Future<void> _saveTeacherAndSchoolName() async {
    final appSettings = AppSettingsStorageService();
    await saveSetting(
      saver:
          () => appSettings.saveTeacherAndSchoolName(
            teacherName: _teacherNameController.text.trim(),
            schoolName: _schoolNameController.text.trim(),
          ),
      successMessage: '기본 정보가 저장되었습니다.',
      setSavingState: (value) => _isSavingNames = value,
      onSuccess: _onTeacherNameSaved,
    );
  }

  /// 교사명 저장 성공 시 다른 화면에 즉시 반영
  ///
  /// 메인 화면들은 IndexedStack으로 살아있어 탭 전환만으로는 갱신되지 않으므로,
  /// 저장한 교사명을 교체 화면·개인 시간표에 직접 반영한다.
  void _onTeacherNameSaved() {
    _refreshExchangeScreenHighlightedTeacher();
    ref
        .read(personalScheduleProvider.notifier)
        .setTeacherName(_teacherNameController.text.trim());
  }

  /// 교체 화면의 교사 행 하이라이트를 저장된 교사명으로 즉시 갱신
  void _refreshExchangeScreenHighlightedTeacher() {
    try {
      final dataSource = ref.read(exchangeScreenProvider).dataSource;
      dataSource?.refreshHighlightedTeacherName();
    } catch (e) {
      // 시간표 미로드 등으로 DataSource가 없을 수 있음
      AppLogger.debug('교체 화면 DataSource가 아직 없습니다: $e');
    }
  }

  /// 파일 로드 오류 메시지 닫기
  void _clearFileError() {
    ref.read(exchangeScreenProvider.notifier).setErrorMessage(null);
  }

  /// 엑셀 파일 선택 → 시간표 관리 화면으로 연결
  ///
  /// 시간표 추가/전환은 레지스트리 스코프가 적용된 관리 화면에서만 수행합니다.
  /// (홈에서 직접 로드하면 활성 시간표 스코프와 불일치가 발생하므로 우회를 막음)
  Future<void> _selectExcelFile() async {
    await _openTimetableManager();
    if (mounted) {
      setState(() {}); // 복귀 시 배너·파일 정보 갱신
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final screenState = ref.watch(exchangeScreenProvider);
    final selectedFile = screenState.selectedFile;
    final timetableFileName = screenState.timetableFileName;
    final hasLoadedTimetable = screenState.hasLoadedTimetable;
    final isLoading = screenState.isLoading;
    final errorMessage = screenState.errorMessage;

    return Container(
      color: tokens.sectionBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 앱 아이콘 + 프로그램명 + 버전·이용 기간 (도움말 > 프로그램 정보와 동일)
            const AppContentCard(
              child: AppBrandingHeader(showVersionAndPeriod: true),
            ),
            const SizedBox(height: 16),

            // 시간표 파일 선택 카드
            _buildFileSelectionCard(
              theme,
              selectedFile,
              timetableFileName,
              hasLoadedTimetable,
              isLoading,
              errorMessage,
            ),
            const SizedBox(height: 16),

            // 기본 정보 카드 (교사명·학교명)
            _buildBasicInfoCard(theme),

            const SizedBox(height: 24),

            // 설정 카드 (접을 수 있음) — 언어·색상·초기화 등은 카드가 자체 관리
            StartSettingsCard(
              onDataReset: () {
                _teacherNameController.clear();
                _schoolNameController.clear();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 활성 시간표(학기) 배너 + 시간표 관리 화면 진입 버튼
  Widget _buildActiveTimetableBanner() {
    final tokens = context.tokens;
    final activeEntry = ref.watch(activeTimetableEntryProvider);
    final name = activeEntry?.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.table_chart_outlined,
            size: 18,
            color: name != null ? tokens.primary : tokens.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name != null ? '현재 시간표: $name' : '등록된 시간표가 없습니다',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: name != null ? tokens.primary : tokens.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _openTimetableManager,
            child: const Text('변경 >'),
          ),
        ],
      ),
    );
  }

  /// 시간표 관리 화면 열기
  Future<void> _openTimetableManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TimetableFileScreen()),
    );
  }

  /// 시간표 파일 선택 카드
  Widget _buildFileSelectionCard(
    ThemeData theme,
    File? selectedFile,
    String? timetableFileName,
    bool hasLoadedTimetable,
    bool isLoading,
    String? errorMessage,
  ) {
    // 로드 성공 시에만 파일명 배너 표시 (실패·오류 시에는 미표시)
    final showFileBanner =
        hasLoadedTimetable && errorMessage == null && !isLoading;

    return AppContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 활성 시간표(학기) 배너 + 시간표 관리 진입
          _buildActiveTimetableBanner(),

          // 교체 화면과 동일한 파란색 파일 배너 (엑셀 파일명 표시)
          SelectedTimetableFileBanner(
            selectedFile: showFileBanner ? selectedFile : null,
            displayFileName: showFileBanner ? timetableFileName : null,
          ),

          // 하단: 파일 관리 버튼들
          const SizedBox(height: 16),
          Row(
            children: [
              // 시간표 관리(추가·전환) 버튼 — 레지스트리 스코프가 적용된 관리 화면으로 연결
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _selectExcelFile,
                  icon:
                      isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Icon(
                            hasLoadedTimetable
                                ? Icons.swap_horiz
                                : Icons.upload_file,
                          ),
                  label: Text(
                    hasLoadedTimetable ? '시간표 변경/추가' : '시간표 파일 선택',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 교체 화면과 동일: 하단 빨간 오류 배너
          buildPaddedErrorMessageSection(errorMessage, _clearFileError),
        ],
      ),
    );
  }

  /// 기본 정보 카드 (교사명·학교명 입력 및 저장)
  Widget _buildBasicInfoCard(ThemeData theme) {
    return AppContentCard(child: _buildBasicInfoForm(theme));
  }

  /// 기본 정보 입력 폼 (제목·교사명·학교명·저장 한 줄)
  Widget _buildBasicInfoForm(ThemeData theme) {
    final tokens = context.tokens;
    const titleStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

    if (_isLoadingNames) {
      return Row(
        children: [
          Text(
            '기본 정보',
            style: titleStyle.copyWith(color: tokens.textSecondary),
          ),
          const Spacer(),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('기본 정보', style: titleStyle.copyWith(color: tokens.textSecondary)),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _buildBasicInfoInputField(
            label: '교사명',
            controller: _teacherNameController,
            icon: Icons.person,
            hintText: '교사명',
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _buildBasicInfoInputField(
            label: '학교명',
            controller: _schoolNameController,
            icon: Icons.school,
            hintText: '학교명',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveTeacherAndSchoolName(),
          ),
        ),
        const SizedBox(width: 8),
        _buildCompactSaveButton(theme),
      ],
    );
  }

  /// 최소 크기 저장 버튼 (한 줄 레이아웃용)
  Widget _buildCompactSaveButton(ThemeData theme) {
    return SizedBox(
      height: 28,
      child: TextButton(
        onPressed: _isSavingNames ? null : _saveTeacherAndSchoolName,
        style: TextButton.styleFrom(
          foregroundColor: theme.primaryColor,
          backgroundColor: theme.primaryColor.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(44, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child:
            _isSavingNames
                ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.primaryColor,
                  ),
                )
                : const Text('저장', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  /// 기본 정보 입력 필드 한 칸 (라벨 + 아이콘 + TextField)
  Widget _buildBasicInfoInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required TextInputAction textInputAction,
    void Function(String)? onSubmitted,
  }) {
    final tokens = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            '$label :',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 28,
            // 아이콘을 TextField 밖에 두어 prefix 여백 문제를 방지
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: tokens.cardBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(icon, size: 14, color: tokens.textSecondary),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 13, height: 1.2),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: tokens.textMuted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      textInputAction: textInputAction,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
