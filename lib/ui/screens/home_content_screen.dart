import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../models/exchange_mode.dart';
import '../../constants/app_info.dart';
import '../../services/app_settings_storage_service.dart';
import '../../services/storage_service.dart';
import '../../utils/logger.dart';
import '../../utils/simplified_timetable_theme.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';
import 'help_screen.dart';
import 'info_screen.dart';

/// 홈 콘텐츠 화면
///
/// 메인 홈 화면의 내용을 표시합니다.
/// - 환영 메시지 카드 (파일 관리 기능 포함)
/// - 메뉴 그리드 (교체 관리, 결보강 문서, 개인 시간표, 설정, 도움말, 정보)
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
  Color _highlightedTeacherColor = const Color(0xFFF3E5F5);
  bool _isLoadingHighlightColor = true;
  bool _isSavingHighlightColor = false;
  
  // 데이터 초기화 관련
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    
    // StateProxy 초기화는 build에서 ref를 사용할 수 있으므로 나중에 수행
    _loadSettings();
  }
  
  @override
  void dispose() {
    _teacherNameController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }
  
  /// 설정 로드
  Future<void> _loadSettings() async {
    await Future.wait([
      _loadLanguageSettings(),
      _loadTeacherAndSchoolName(),
      _loadHighlightColor(),
    ]);
  }
  
  /// 언어 설정 로드
  Future<void> _loadLanguageSettings() async {
    try {
      final appSettings = AppSettingsStorageService();
      final languageCode = await appSettings.getLanguageCode();
      
      if (mounted) {
        setState(() {
          _selectedLanguage = languageCode;
          _isLoadingLanguage = false;
        });
      }
    } catch (e) {
      AppLogger.error('설정 로드 중 오류: $e', e);
      if (mounted) {
        setState(() {
          _isLoadingLanguage = false;
        });
      }
    }
  }
  
  /// 교사명과 학교명 로드
  Future<void> _loadTeacherAndSchoolName() async {
    try {
      final appSettings = AppSettingsStorageService();
      final defaults = await appSettings.loadTeacherAndSchoolName();
      
      if (mounted) {
        setState(() {
          _teacherNameController.text = defaults['defaultTeacherName'] ?? '';
          _schoolNameController.text = defaults['defaultSchoolName'] ?? '';
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      AppLogger.error('교사명과 학교명 로드 중 오류: $e', e);
      if (mounted) {
        setState(() {
          _isLoadingNames = false;
        });
      }
    }
  }
  
  /// 하이라이트 색상 로드
  Future<void> _loadHighlightColor() async {
    try {
      final appSettings = AppSettingsStorageService();
      final colorValue = await appSettings.getHighlightedTeacherColor();
      
      if (mounted) {
        setState(() {
          if (colorValue != null) {
            _highlightedTeacherColor = Color(colorValue);
          }
          _isLoadingHighlightColor = false;
        });
      }
    } catch (e) {
      AppLogger.error('하이라이트 색상 로드 중 오류: $e', e);
      if (mounted) {
        setState(() {
          _isLoadingHighlightColor = false;
        });
      }
    }
  }
  
  /// 언어 설정 저장
  Future<void> _saveLanguage(String languageCode) async {
    try {
      final appSettings = AppSettingsStorageService();
      final success = await appSettings.saveAppSettings(languageCode: languageCode);
      
      if (success && mounted) {
        setState(() {
          _selectedLanguage = languageCode;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('언어 설정이 저장되었습니다. 앱을 재시작하면 적용됩니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('언어 설정 저장 중 오류: $e', e);
    }
  }
  
  /// 교사명과 학교명 저장
  Future<void> _saveTeacherAndSchoolName() async {
    setState(() {
      _isSavingNames = true;
    });
    
    try {
      final appSettings = AppSettingsStorageService();
      final success = await appSettings.saveTeacherAndSchoolName(
        teacherName: _teacherNameController.text,
        schoolName: _schoolNameController.text,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('기본 정보가 저장되었습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장에 실패했습니다.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('교사명과 학교명 저장 중 오류: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNames = false;
        });
      }
    }
  }
  
  /// 하이라이트 색상 저장
  Future<void> _saveHighlightColor(Color color) async {
    setState(() {
      _isSavingHighlightColor = true;
    });
    
    try {
      final appSettings = AppSettingsStorageService();
      final success = await appSettings.saveHighlightedTeacherColor(color.toARGB32());
      
      if (success && mounted) {
        setState(() {
          _highlightedTeacherColor = color;
        });
        
        // 교체 화면의 테마도 업데이트
        SimplifiedTimetableTheme.setHighlightedTeacherColor(color);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('하이라이트 색상이 저장되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('하이라이트 색상 저장 중 오류: $e', e);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingHighlightColor = false;
        });
      }
    }
  }
  
  /// 모든 데이터 초기화
  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '데이터 초기화',
          style: TextStyle(color: Colors.red),
        ),
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
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
      final failedFiles = results.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

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
        ref.read(stateResetProvider.notifier).resetAllStates(
          reason: '파일 선택 후 전체 상태 초기화',
        );
        
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
              const Expanded(
                child: Text('파일 선택 해제'),
              ),
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
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
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
    final isLoading = screenState.isLoading;

    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 환영 메시지 카드 (파일 관리 기능 포함)
            _buildWelcomeCard(context, theme, selectedFile, isLoading),
            const SizedBox(height: 16),
            
            // 사용 기간 정보 카드
            _buildUsagePeriodCard(theme),
            
            const SizedBox(height: 24),

            // 메뉴 그리드
            _buildMenuGrid(context, ref, theme),
            
            const SizedBox(height: 24),
            
            // 설정 카드 (접을 수 있음)
            _buildSettingsCard(context, theme),
          ],
        ),
      ),
    );
  }

  /// 환영 메시지 카드 생성 (파일 관리 기능 포함)
  Widget _buildWelcomeCard(
    BuildContext context,
    ThemeData theme,
    File? selectedFile,
    bool isLoading,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 아이콘과 파일 정보
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school,
                  color: theme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '수업 교체 관리자',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedFile != null
                        ? '현재 시간표: ${selectedFile.path.split(Platform.pathSeparator).last}'
                        : '시간표 파일을 선택해주세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 하단: 파일 관리 버튼들
          const SizedBox(height: 16),
          Row(
            children: [
              // 파일 선택/변경 버튼
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _selectExcelFile,
                  icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        selectedFile == null ? Icons.upload_file : Icons.refresh,
                      ),
                  label: Text(
                    selectedFile == null ? '시간표 파일 선택' : '다른 파일 선택',
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
              
              // 파일 해제 버튼 (파일이 선택된 경우에만 표시)
              if (selectedFile != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _clearSelectedFile,
                  icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete_outline),
                  label: const Text(
                    '해제',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
              child: Icon(
                Icons.settings,
                color: theme.primaryColor,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '설정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 언어 설정
                _buildLanguageSection(),
                const SizedBox(height: 4),
                
                // 기본 정보 (교사명, 학교명)
                _buildTeacherAndSchoolNameSection(),
                const SizedBox(height: 8),
                
                // 하이라이트 색상 설정
                _buildHighlightColorSection(),
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        DropdownButton<String>(
          value: _selectedLanguage,
          underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'ko', child: Text('한국어', style: TextStyle(fontSize: 12))),
            ],
          onChanged: (newValue) => newValue != null && newValue != _selectedLanguage ? _saveLanguage(newValue) : null,
        ),
      ],
    );
  }
  
  /// 교사명, 학교명 입력 섹션
  Widget _buildTeacherAndSchoolNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기본 정보',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        
        if (_isLoadingNames)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(4.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '교사명 :',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: TextField(
                        controller: _teacherNameController,
                        style: const TextStyle(fontSize: 13, height: 1.0),
                        decoration: const InputDecoration(
                          hintText: '교사명을 입력하세요',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(width: 1),
                          ),
                          prefixIcon: Icon(Icons.person, size: 16),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          constraints: BoxConstraints(
                            minHeight: 28,
                            maxHeight: 28,
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '학교명 :',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: TextField(
                        controller: _schoolNameController,
                        style: const TextStyle(fontSize: 13, height: 1.0),
                        decoration: const InputDecoration(
                          hintText: '학교명을 입력하세요',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(width: 1),
                          ),
                          prefixIcon: Icon(Icons.school, size: 16),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          constraints: BoxConstraints(
                            minHeight: 28,
                            maxHeight: 28,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveTeacherAndSchoolName(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingNames ? null : _saveTeacherAndSchoolName,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSavingNames
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(fontSize: 14),
                      ),
                ),
              ),
            ],
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
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
            children: [
              _buildColorOption(const Color(0xFFE3F2FD)),
              _buildColorOption(const Color(0xFFE8F5E9)),
              _buildColorOption(const Color(0xFFFFF9C4)),
              _buildColorOption(const Color(0xFFF3E5F5)),
              _buildColorOption(const Color(0xFFE1F5FE)),
              _buildColorOption(const Color(0xFFFFE0B2)),
            ],
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '모든 저장된 데이터를 삭제합니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
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
            child: _isResetting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  '모든 데이터 삭제',
                  style: TextStyle(fontSize: 14),
                ),
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
        availablePeriodText = '${expiry.year}년 ${expiry.month}월 ${expiry.day}일까지';
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
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
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

  /// 메뉴 그리드 생성
  Widget _buildMenuGrid(BuildContext context, WidgetRef ref, ThemeData theme) {
    final menuItems = [
      {
        'title': '교체 관리',
        'icon': Icons.swap_horiz,
        'color': theme.primaryColor,
        'onTap': () {
          ref.read(navigationProvider.notifier).state = 1;
        },
      },
      {
        'title': '결보강 문서',
        'icon': Icons.print,
        'color': theme.primaryColor,
        'onTap': () {
          ref.read(navigationProvider.notifier).state = 2;
        },
      },
      {
        'title': '개인 시간표',
        'icon': Icons.person,
        'color': theme.primaryColor,
        'onTap': () {
          ref.read(navigationProvider.notifier).state = 3;
        },
      },
      {
        'title': '도움말',
        'icon': Icons.help_outline,
        'color': Colors.grey.shade600,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HelpScreen(),
            ),
          );
        },
      },
      {
        'title': '정보',
        'icon': Icons.info_outline,
        'color': Colors.grey.shade600,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InfoScreen(),
            ),
          );
        },
      },
    ];

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: menuItems.map((item) {
        return _buildMenuCard(
          context: context,
          theme: theme,
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          onTap: item['onTap'] as VoidCallback,
        );
      }).toList(),
    );
  }

  /// 메뉴 카드 생성
  Widget _buildMenuCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    const double cardWidth = 90.0;
    const double cardHeight = 90.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: cardWidth,
        maxWidth: cardWidth,
        minHeight: cardHeight,
        maxHeight: cardHeight,
      ),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 36,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
