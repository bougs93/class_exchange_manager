import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/app_settings_storage_service.dart';
import '../../services/pdf_export_settings_storage_service.dart';
import '../../services/storage_service.dart';
import '../../utils/logger.dart';
import '../../utils/simplified_timetable_theme.dart';

/// 설정 화면
/// 
/// 앱의 전역 설정을 관리하는 화면입니다.
/// - 언어 설정: 앱 언어 선택
/// - 데이터 초기화: PDF 출력 설정의 교사명과 학교명 초기화
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // 언어 설정 관련
  String _selectedLanguage = 'ko'; // 기본값: 한국어
  bool _isLoadingLanguage = true;
  
  // 데이터 초기화 관련
  bool _isResetting = false;
  
  // 교사명, 학교명 입력 필드
  final TextEditingController _teacherNameController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();
  bool _isLoadingNames = true;
  bool _isSavingNames = false;
  
  // 하이라이트 색상 관련
  Color _highlightedTeacherColor = const Color(0xFFF5F5F5); // 기본값: 연한 회색
  bool _isLoadingHighlightColor = true;
  bool _isSavingHighlightColor = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTeacherAndSchoolName();
    _loadHighlightColor();
  }
  
  @override
  void dispose() {
    _teacherNameController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  /// 저장된 설정 로드
  Future<void> _loadSettings() async {
    try {
      final appSettings = AppSettingsStorageService();
      final languageCode = await appSettings.getLanguageCode();
      
      setState(() {
        _selectedLanguage = languageCode;
        _isLoadingLanguage = false;
      });
    } catch (e) {
      AppLogger.error('설정 로드 중 오류: $e', e);
      setState(() {
        _isLoadingLanguage = false;
      });
    }
  }
  
  /// 저장된 교사명과 학교명 로드 (기본값)
  Future<void> _loadTeacherAndSchoolName() async {
    try {
      final pdfSettings = PdfExportSettingsStorageService();
      final defaults = await pdfSettings.loadDefaultTeacherAndSchoolName();
      
      setState(() {
        _teacherNameController.text = defaults['defaultTeacherName'] ?? '';
        _schoolNameController.text = defaults['defaultSchoolName'] ?? '';
        _isLoadingNames = false;
      });
    } catch (e) {
      AppLogger.error('교사명과 학교명 로드 중 오류: $e', e);
      setState(() {
        _isLoadingNames = false;
      });
    }
  }
  
  /// 하이라이트 색상 로드
  Future<void> _loadHighlightColor() async {
    try {
      final colorValue = await PdfExportSettingsStorageService().getHighlightedTeacherColor();
      
      setState(() {
        if (colorValue != null) {
          _highlightedTeacherColor = Color(colorValue);
        } else {
          // 기본값 사용
          _highlightedTeacherColor = const Color(0xFFF5F5F5);
        }
        _isLoadingHighlightColor = false;
      });
    } catch (e) {
      AppLogger.error('하이라이트 색상 로드 중 오류: $e', e);
      setState(() {
        _isLoadingHighlightColor = false;
      });
    }
  }
  
  /// 하이라이트 색상 저장
  Future<void> _saveHighlightColor(Color color) async {
    setState(() {
      _isSavingHighlightColor = true;
    });
    
    try {
      await SimplifiedTimetableTheme.setHighlightedTeacherColor(color);
      
      // 테마 설정 다시 로드하여 즉시 반영
      await SimplifiedTimetableTheme.loadThemeSettings();
      
      if (mounted) {
        setState(() {
          _highlightedTeacherColor = color;
          _isSavingHighlightColor = false;
        });
      }
    } catch (e) {
      AppLogger.error('하이라이트 색상 저장 중 오류: $e', e);
      if (mounted) {
        setState(() {
          _isSavingHighlightColor = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('색상 저장에 실패했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// 교사명과 학교명 저장 (기본값으로 저장)
  Future<void> _saveTeacherAndSchoolName() async {
    setState(() {
      _isSavingNames = true;
    });
    
    try {
      final pdfSettings = PdfExportSettingsStorageService();
      // 기본값으로 저장 (PDF 출력 화면에서 입력 필드가 비어있을 때 사용)
      final success = await pdfSettings.saveDefaultTeacherAndSchoolName(
        teacherName: _teacherNameController.text.trim(),
        schoolName: _schoolNameController.text.trim(),
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('교사명과 학교명이 저장되었습니다.'),
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

  /// 언어 설정 저장
  Future<void> _saveLanguage(String languageCode) async {
    try {
      final appSettings = AppSettingsStorageService();
      final success = await appSettings.saveAppSettings(languageCode: languageCode);
      
      if (success) {
        setState(() {
          _selectedLanguage = languageCode;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('언어 설정이 저장되었습니다. 앱을 재시작하면 적용됩니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('언어 설정 저장에 실패했습니다.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('언어 설정 저장 중 오류: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 모든 데이터 초기화 (모든 JSON 파일 삭제)
  Future<void> _resetAllData() async {
    // 확인 대화상자 표시 (경고 메시지)
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

    if (confirmed != true) {
      return; // 사용자가 취소한 경우
    }

    setState(() {
      _isResetting = true;
    });

    try {
      final storageService = StorageService();
      final results = await storageService.deleteAllJsonFiles();
      
      // 삭제 결과 확인
      final successCount = results.values.where((v) => v).length;
      final totalCount = results.length;
      final failedFiles = results.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

      if (mounted) {
        if (failedFiles.isEmpty && totalCount > 0) {
          // 모든 파일 삭제 성공
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('모든 데이터가 삭제되었습니다. ($totalCount개 파일)'),
              duration: const Duration(seconds: 3),
            ),
          );
          
          // 교사명과 학교명 필드도 초기화
          setState(() {
            _teacherNameController.clear();
            _schoolNameController.clear();
          });
        } else if (totalCount == 0) {
          // 삭제할 파일이 없음
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('삭제할 데이터가 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // 일부 파일 삭제 실패
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '일부 데이터 삭제에 실패했습니다.\n'
                '성공: $successCount개 / 전체: $totalCount개\n'
                '실패한 파일: ${failedFiles.join(", ")}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 언어 설정 섹션
          _buildLanguageSection(),
          const SizedBox(height: 32),
          
          // 교사명, 학교명 입력 섹션
          _buildTeacherAndSchoolNameSection(),
          const SizedBox(height: 32),
          
          // 하이라이트 색상 설정 섹션
          _buildHighlightColorSection(),
          const SizedBox(height: 32),
          
          // 데이터 초기화 섹션
          _buildDataResetSection(),
        ],
      ),
    );
  }

  /// 언어 설정 섹션
  Widget _buildLanguageSection() {
    // 언어 선택 Row (한 줄로 표시)
    if (_isLoadingLanguage) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
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
            fontSize: 16,
          ),
        ),
        DropdownButton<String>(
          value: _selectedLanguage,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'ko', child: Text('한국어')),
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_isLoadingNames)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Column(
            children: [
              // 교사명 입력 필드 (레이블과 입력 필드를 한 행에)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '교사명 :',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _teacherNameController,
                      decoration: const InputDecoration(
                        hintText: '교사명을 입력하세요',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 학교명 입력 필드 (레이블과 입력 필드를 한 행에)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '학교명 :',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _schoolNameController,
                      decoration: const InputDecoration(
                        hintText: '학교명을 입력하세요',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveTeacherAndSchoolName(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingNames ? null : _saveTeacherAndSchoolName,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                          style: TextStyle(fontSize: 15),
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
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // 색상 선택 영역을 하나의 컨테이너로 묶음 (제목과 설명 포함)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          const Text(
            '교사 행 하이라이트',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 설명
          const Text(
            '교체관리에서 교사명의 행이 하이라이트됩니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          
          // 현재 선택된 색상 표시
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _highlightedTeacherColor,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 색상 옵션들 (한 줄로 배치)
          Row(
            children: [
              _buildColorOption(const Color(0xFFE3F2FD)),
              const SizedBox(width: 12),
              _buildColorOption(const Color(0xFFE8F5E9)),
              const SizedBox(width: 12),
              _buildColorOption(const Color(0xFFFFF9C4)),
              const SizedBox(width: 12),
              _buildColorOption(const Color(0xFFF3E5F5)),
              const SizedBox(width: 12),
              _buildColorOption(const Color(0xFFE1F5FE)),
              const SizedBox(width: 12),
              _buildColorOption(const Color(0xFFFFE0B2)), // 연한 오렌지색
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
        width: 50,
        height: 50,
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
        const Text(
          '데이터 초기화',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '모든 저장된 데이터를 삭제합니다.\n'
          '시간표, 교체 리스트, 교체불가 셀 데이터, 결보강 계획서, 설정 등 모든 데이터 파일이 삭제됩니다.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        
        // 초기화 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isResetting ? null : _resetAllData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isResetting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '모든 데이터 삭제',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }
}
