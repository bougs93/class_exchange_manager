import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../models/exchange_mode.dart';
import '../../constants/app_info.dart';
import '../../constants/app_assets.dart';
import '../../constants/teacher_row_highlight_colors.dart';
import '../../services/app_settings_storage_service.dart';
import '../../services/storage_service.dart';
import '../../utils/logger.dart';
import '../../utils/simplified_timetable_theme.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';
import '../widgets/data_storage_location_section.dart';
import '../widgets/selected_timetable_file_banner.dart';

/// 홈 콘텐츠 화면
///
/// 메인 홈 화면의 내용을 표시합니다.
/// - 시간표 파일 선택 카드 / 기본 정보 카드
/// - 설정 (언어, 하이라이트 색상, 저장 위치 등) — 기본 정보는 별도 카드에서 편집
class HomeContentScreen extends ConsumerStatefulWidget {
  const HomeContentScreen({super.key});

  @override
  ConsumerState<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends ConsumerState<HomeContentScreen> {
  // 엑셀 파일 선택 관련 상태 관리
  ExchangeScreenStateProxy? _stateProxy;
  ExchangeOperationManager? _operationManager;

  // 설정 관련 상태
  bool _isSettingsExpanded = false;

  // 언어 설정 관련
  String _selectedLanguage = 'ko';
  bool _isLoadingLanguage = true;

  // 교사명, 학교명 입력 필드
  final TextEditingController _teacherNameController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();
  bool _isLoadingNames = true;
  bool _isSavingNames = false;

  // 하이라이트 색상 관련
  Color _highlightedTeacherColor = TeacherRowHighlightColors.defaultColor;
  bool _isLoadingHighlightColor = true;
  bool _isSavingHighlightColor = false;

  // 데이터 초기화 관련
  bool _isResetting = false;

  // 데이터 저장 위치 표시 (설정 카드 내)
  final GlobalKey<DataStorageLocationSectionState> _dataStorageLocationKey =
      GlobalKey<DataStorageLocationSectionState>();

  @override
  void initState() {
    super.initState();

    // 설정에서 입력·저장 시 홈 카드 하단 기본 정보도 함께 갱신
    _teacherNameController.addListener(_onBasicInfoControllersChanged);
    _schoolNameController.addListener(_onBasicInfoControllersChanged);

    // StateProxy 초기화는 build에서 ref를 사용할 수 있으므로 나중에 수행
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

  /// 설정 로드 (통합 버전 - setState 1회만 호출)
  Future<void> _loadSettings() async {
    try {
      final appSettings = AppSettingsStorageService();

      // 병렬로 모든 설정 로드
      final results = await Future.wait([
        appSettings.getLanguageCode(),
        appSettings.loadTeacherAndSchoolName(),
        appSettings.getHighlightedTeacherColor(),
      ]);

      if (mounted) {
        // 교사명/학교명 확인 및 trim 처리 (setState 전에)
        final nameData = results[1] as Map<String, dynamic>;
        final teacherName = (nameData['defaultTeacherName'] ?? '').trim();
        final schoolName = (nameData['defaultSchoolName'] ?? '').trim();

        setState(() {
          // 언어 설정
          _selectedLanguage = results[0] as String;
          _isLoadingLanguage = false;

          // 교사명/학교명 (trim된 값 저장)
          _teacherNameController.text = teacherName;
          _schoolNameController.text = schoolName;
          _isLoadingNames = false;

          // 교사명이 비어있으면 설정 메뉴를 자동으로 펼침
          if (teacherName.isEmpty) {
            _isSettingsExpanded = true;
          }

          // 하이라이트 색상 (구 프리셋은 교체 범례와 유사하여 자동 교체)
          final colorValue = results[2] as int?;
          final resolvedColor = TeacherRowHighlightColors.resolveSavedColor(
            colorValue,
          );
          _highlightedTeacherColor = resolvedColor;
          if (colorValue != null && resolvedColor.toARGB32() != colorValue) {
            SimplifiedTimetableTheme.setHighlightedTeacherColor(resolvedColor);
          }
          _isLoadingHighlightColor = false;
        });
      }
    } catch (e) {
      AppLogger.error('설정 로드 중 오류: $e', e);
      if (mounted) {
        setState(() {
          _isLoadingLanguage = false;
          _isLoadingNames = false;
          _isLoadingHighlightColor = false;
          // 오류 발생 시에도 교사명이 비어있으면 설정 메뉴 펼침
          // (Controller에 이미 trim된 값이 저장되어 있음)
          if (_teacherNameController.text.isEmpty) {
            _isSettingsExpanded = true;
          }
        });
      }
    }
  }

  /// 공통 설정 저장 헬퍼 메서드
  Future<void> _saveSetting({
    required Future<bool> Function() saver,
    required String successMessage,
    String? errorMessage,
    VoidCallback? onSuccess,
    void Function(bool)? setSavingState,
  }) async {
    if (setSavingState != null) {
      setState(() => setSavingState(true));
    }

    try {
      final success = await saver();

      if (mounted) {
        if (success) {
          onSuccess?.call();
          _showSnackBar(successMessage);
        } else {
          _showSnackBar(errorMessage ?? '저장에 실패했습니다.', isError: true);
        }
      }
    } catch (e) {
      AppLogger.error('설정 저장 중 오류: $e', e);
      if (mounted) {
        _showSnackBar('오류가 발생했습니다: $e', isError: true);
      }
    } finally {
      if (mounted && setSavingState != null) {
        setState(() => setSavingState(false));
      }
    }
  }

  /// SnackBar 표시 헬퍼 메서드
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 언어 설정 저장
  Future<void> _saveLanguage(String languageCode) async {
    final appSettings = AppSettingsStorageService();
    await _saveSetting(
      saver: () => appSettings.saveAppSettings(languageCode: languageCode),
      successMessage: '언어 설정이 저장되었습니다. 앱을 재시작하면 적용됩니다.',
      onSuccess: () => setState(() => _selectedLanguage = languageCode),
    );
  }

  /// 교사명과 학교명 저장
  Future<void> _saveTeacherAndSchoolName() async {
    final appSettings = AppSettingsStorageService();
    await _saveSetting(
      saver:
          () => appSettings.saveTeacherAndSchoolName(
            teacherName: _teacherNameController.text.trim(),
            schoolName: _schoolNameController.text.trim(),
          ),
      successMessage: '기본 정보가 저장되었습니다.',
      setSavingState: (value) => _isSavingNames = value,
      onSuccess: _refreshExchangeScreenHighlightedTeacher,
    );
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

  /// 하이라이트 색상 저장
  Future<void> _saveHighlightColor(Color color) async {
    final appSettings = AppSettingsStorageService();
    await _saveSetting(
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

    setState(() {
      _isResetting = true;
    });

    try {
      final storageService = StorageService();
      final results = await storageService.deleteAllJsonFiles();

      final successCount = results.values.where((v) => v).length;
      final totalCount = results.length;
      final failedFiles =
          results.entries.where((e) => !e.value).map((e) => e.key).toList();

      if (mounted) {
        if (failedFiles.isEmpty && totalCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('모든 데이터가 삭제되었습니다. ($totalCount개 파일)'),
              duration: const Duration(seconds: 3),
            ),
          );

          setState(() {
            _teacherNameController.clear();
            _schoolNameController.clear();
          });
        } else if (totalCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('삭제할 데이터가 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '일부 데이터 삭제에 실패했습니다.\n'
                '성공: $successCount개 / 전체: $totalCount개',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('데이터 초기화 중 오류: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
        await _dataStorageLocationKey.currentState?.reload();
      }
    }
  }

  /// StateProxy와 OperationManager 초기화
  void _initializeManagers() {
    if (_stateProxy == null) {
      _stateProxy = ExchangeScreenStateProxy(ref);

      _operationManager = ExchangeOperationManager(
        context: context,
        ref: ref,
        stateProxy: _stateProxy!,
        onCreateSyncfusionGridData: () {
          if (mounted) setState(() {});
        },
        onClearAllExchangeStates: () {
          if (mounted) setState(() {});
        },
        onRefreshHeaderTheme: () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  /// 엑셀 파일 선택 메서드
  Future<void> _selectExcelFile() async {
    _initializeManagers();

    if (_operationManager != null) {
      // 파일 선택 시도
      bool fileSelected = await _operationManager!.selectExcelFile();

      // 파일 선택이 성공한 경우에만 초기화 수행
      if (fileSelected) {
        // 파일 선택 후 보기 모드로 전환
        final globalNotifier = ref.read(exchangeScreenProvider.notifier);
        globalNotifier.setCurrentMode(ExchangeMode.view);

        // 파일 선택 후 Level 3 초기화
        ref
            .read(stateResetProvider.notifier)
            .resetAllStates(reason: '파일 선택 후 전체 상태 초기화');

        if (mounted) {
          setState(() {});
        }
      }
      // 파일 선택이 취소된 경우 아무 동작하지 않음
    }
  }

  /// 엑셀 파일 선택 해제 메서드 (확인 다이얼로그 포함)
  Future<void> _clearSelectedFile() async {
    // 확인 다이얼로그 표시
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('파일 선택 해제')),
            ],
          ),
          content: const Text(
            '선택된 시간표 파일을 해제하시겠습니까?\n해제하면 현재 로드된 시간표 정보가 삭제됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('해제'),
            ),
          ],
        );
      },
    );

    // 확인 버튼을 눌렀을 때만 파일 해제
    if (confirm == true && mounted) {
      _initializeManagers();
      _operationManager?.clearSelectedFile();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenState = ref.watch(exchangeScreenProvider);
    final selectedFile = screenState.selectedFile;
    final timetableFileName = screenState.timetableFileName;
    final hasLoadedTimetable = screenState.hasLoadedTimetable;
    final isLoading = screenState.isLoading;

    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 시간표 파일 선택 카드
            _buildFileSelectionCard(
              theme,
              selectedFile,
              timetableFileName,
              hasLoadedTimetable,
              isLoading,
            ),
            const SizedBox(height: 16),

            // 기본 정보 카드 (교사명·학교명)
            _buildBasicInfoCard(theme),
            const SizedBox(height: 16),

            // 사용 기간 정보 카드
            _buildUsagePeriodCard(theme),

            const SizedBox(height: 24),

            // 설정 카드 (접을 수 있음)
            _buildSettingsCard(context, theme),
          ],
        ),
      ),
    );
  }

  /// 홈 화면 공통 카드 테두리 스타일
  BoxDecoration _homeCardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: theme.primaryColor.withValues(alpha: 0.2),
        width: 1,
      ),
    );
  }

  /// 시간표 파일 선택 카드
  Widget _buildFileSelectionCard(
    ThemeData theme,
    File? selectedFile,
    String? timetableFileName,
    bool hasLoadedTimetable,
    bool isLoading,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _homeCardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 아이콘과 파일 정보
          Row(
            children: [
              Image.asset(
                AppAssets.appIcon,
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '수업 교체 도우미',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 교체 화면과 동일한 파란색 파일 배너 (엑셀 파일명 표시)
          const SizedBox(height: 12),
          SelectedTimetableFileBanner(
            selectedFile: selectedFile,
            displayFileName: timetableFileName,
          ),

          // 하단: 파일 관리 버튼들
          const SizedBox(height: 16),
          Row(
            children: [
              // 파일 선택/변경 버튼
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
                                ? Icons.refresh
                                : Icons.upload_file,
                          ),
                  label: Text(
                    hasLoadedTimetable ? '다른 파일 선택' : '시간표 파일 선택',
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

              // 파일 해제 버튼 (시간표가 로드된 경우 표시)
              if (hasLoadedTimetable) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _clearSelectedFile,
                  icon:
                      isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.delete_outline),
                  label: const Text(
                    '해제',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 기본 정보 카드 (교사명·학교명 입력 및 저장)
  Widget _buildBasicInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _homeCardDecoration(theme),
      child: _buildBasicInfoForm(theme),
    );
  }

  /// 기본 정보 입력 폼 (제목·교사명·학교명·저장 한 줄)
  Widget _buildBasicInfoForm(ThemeData theme) {
    const titleStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

    if (_isLoadingNames) {
      return Row(
        children: [
          Text(
            '기본 정보',
            style: titleStyle.copyWith(color: Colors.grey.shade700),
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
        Text('기본 정보', style: titleStyle.copyWith(color: Colors.grey.shade700)),
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

  /// 기본 정보 입력 필드 한 칸 (라벨 + TextField)
  Widget _buildBasicInfoInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required TextInputAction textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Text('$label :', style: const TextStyle(fontSize: 11)),
        ),
        Expanded(
          child: SizedBox(
            height: 28,
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, height: 1.0),
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(
                  borderSide: BorderSide(width: 1),
                ),
                prefixIcon: Icon(icon, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                constraints: const BoxConstraints(minHeight: 28, maxHeight: 28),
              ),
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
            ),
          ),
        ),
      ],
    );
  }

  /// 설정 카드 생성 (접을 수 있음)
  Widget _buildSettingsCard(BuildContext context, ThemeData theme) {
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
              '설정',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        initiallyExpanded: _isSettingsExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isSettingsExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 언어 설정
                _buildLanguageSection(),
                const SizedBox(height: 8),

                // 연쇄 교체 사용 설정
                _buildChainExchangeSection(),
                const SizedBox(height: 8),

                // 하이라이트 색상 설정
                _buildHighlightColorSection(),
                const SizedBox(height: 8),

                // 데이터 저장 위치 (JSON 폴더 경로)
                DataStorageLocationSection(
                  key: _dataStorageLocationKey,
                  compact: true,
                ),
                const SizedBox(height: 8),

                // 데이터 초기화
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

  /// 연쇄 교체 사용 설정 섹션
  Widget _buildChainExchangeSection() {
    final isEnabled = ref.watch(chainExchangeEnabledProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 스위치를 텍스트 앞(왼쪽)에 작게 배치
        Transform.scale(
          scale: 0.72,
          child: Switch(
            value: isEnabled,
            onChanged: _saveChainExchangeEnabled,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '연쇄 교체',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '교체 화면 연쇄교체 메뉴 표시',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 연쇄 교체 설정 저장
  Future<void> _saveChainExchangeEnabled(bool enabled) async {
    await _saveSetting(
      saver: () =>
          ref.read(chainExchangeEnabledProvider.notifier).setEnabled(enabled),
      successMessage: enabled
          ? '연쇄 교체 기능이 활성화되었습니다.'
          : '연쇄 교체 기능이 비활성화되었습니다.',
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
            '교사 행 하이라이트',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '교체 화면 범례(선택·채움·교체불가 등)와 구분되는 색상입니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _highlightedTeacherColor,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _highlightedTeacherColor,
                    border: Border.all(color: Colors.black26, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '현재 색상: RGB(${(_highlightedTeacherColor.r * 255.0).round()}, ${(_highlightedTeacherColor.g * 255.0).round()}, ${(_highlightedTeacherColor.b * 255.0).round()})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Wrap(
            spacing: 4,
            runSpacing: 4,
            children:
                TeacherRowHighlightColors.presets
                    .map(_buildColorOption)
                    .toList(),
          ),
        ],
      ),
    );
  }

  /// 색상 옵션 버튼 위젯
  Widget _buildColorOption(Color color) {
    final isSelected = _highlightedTeacherColor.toARGB32() == color.toARGB32();

    return InkWell(
      onTap: _isSavingHighlightColor ? null : () => _saveHighlightColor(color),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
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

  /// 사용 기간 정보 카드 생성
  Widget _buildUsagePeriodCard(ThemeData theme) {
    final expiryDate = AppInfo.expiryDate;
    final daysUntilExpiry = AppInfo.getDaysUntilExpiry();
    final isExpired = AppInfo.isExpired();

    // 사용 가능 기간 문자열 생성
    String availablePeriodText;
    if (expiryDate == null) {
      availablePeriodText = '제한 없음';
    } else {
      try {
        final expiry = DateTime.parse(expiryDate);
        availablePeriodText =
            '${expiry.year}년 ${expiry.month}월 ${expiry.day}일까지';
      } catch (e) {
        availablePeriodText = expiryDate;
      }
    }

    // 남은 사용 기간 문자열 생성
    String remainingPeriodText;
    Color remainingPeriodColor;
    if (expiryDate == null) {
      remainingPeriodText = '제한 없음';
      remainingPeriodColor = Colors.green.shade700;
    } else if (isExpired) {
      remainingPeriodText = '만료됨';
      remainingPeriodColor = Colors.red.shade700;
    } else if (daysUntilExpiry != null) {
      if (daysUntilExpiry == 0) {
        remainingPeriodText = '오늘까지';
        remainingPeriodColor = Colors.orange.shade700;
      } else if (daysUntilExpiry <= 30) {
        remainingPeriodText = '$daysUntilExpiry일 남음';
        remainingPeriodColor = Colors.orange.shade700;
      } else {
        remainingPeriodText = '$daysUntilExpiry일 남음';
        remainingPeriodColor = Colors.green.shade700;
      }
    } else {
      remainingPeriodText = '계산 불가';
      remainingPeriodColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_today,
              color: theme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Version : ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      AppInfo.version,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '사용 가능 기간 : ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      availablePeriodText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '남은 사용 기간 : ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      remainingPeriodText,
                      style: TextStyle(
                        fontSize: 13,
                        color: remainingPeriodColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
