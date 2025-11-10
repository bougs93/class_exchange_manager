import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../../utils/pdf_field_config.dart';
import '../../../../../utils/date_format_utils.dart';
import '../../../../../services/pdf_export_service.dart';
import '../../../../../services/pdf_export_settings_storage_service.dart';
import '../../../../../services/app_settings_storage_service.dart';
import '../../../../../constants/korean_fonts.dart';
import '../../../../../constants/pdf_notes_template.dart';
import '../../../../../utils/logger.dart';
import 'pdf_settings_section.dart';
import 'pdf_field_inputs_section.dart';
import '../../pdf_preview_screen.dart';

/// 파일 출력 위젯 (리팩토링된 버전)
///
/// 결보강 계획서를 PDF 형식으로 미리보고 저장할 수 있는 위젯입니다.
/// 설정 및 입력 섹션은 별도 위젯으로 분리되어 있습니다.
class FileExportWidget extends ConsumerStatefulWidget {
  const FileExportWidget({super.key});

  @override
  ConsumerState<FileExportWidget> createState() => FileExportWidgetState();
}

/// FileExportWidget의 State 클래스 (외부에서 접근 가능하도록 public)
class FileExportWidgetState extends ConsumerState<FileExportWidget> {
  // PDF 템플릿 설정
  int _selectedTemplateIndex = 0;
  String? _selectedTemplateFilePath;

  // 폰트 설정
  double _fontSize = 10.0;
  double _remarksFontSize = 7.0;
  String _selectedFont = KoreanFontConstants.defaultFont;
  bool _includeRemarks = true;

  // 폰트 사이즈 옵션
  final List<double> _fontSizeOptions = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0];
  final List<double> _remarksFontSizeOptions = [6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0];
  
  // PDF 출력 설정 저장 서비스
  final PdfExportSettingsStorageService _pdfSettingsStorage = PdfExportSettingsStorageService();
  
  // 결강기간 수동 수정 여부 (사용자가 직접 수정한 경우 자동 업데이트 비활성화)
  bool _isAbsencePeriodManuallyEdited = false;
  // 자동 업데이트 중 플래그 (리스너가 업데이트를 감지하지 않도록)
  bool _isUpdatingAbsencePeriod = false;
  
  @override
  void initState() {
    super.initState();
    AppLogger.info('📄 [결강기간] FileExportWidget 초기화');
    
    // 결강기간 필드 변경 감지 (사용자가 직접 수정한 경우 플래그 설정)
    _absencePeriodController.addListener(_onAbsencePeriodChanged);
    
    // 저장된 PDF 출력 설정 로드 후 결강기간 자동 업데이트
    _loadSavedSettings().then((_) {
      // 설정 로드 완료 후 결강기간 자동 업데이트 (위젯이 생성된 후 실행)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppLogger.info('📄 [결강기간] 초기 진입 시 결강기간 업데이트 (설정 로드 후)');
          updateAbsencePeriod();
        }
      });
    });
  }

  /// 결강기간 필드 변경 리스너
  void _onAbsencePeriodChanged() {
    // 자동 업데이트 중이면 무시
    if (_isUpdatingAbsencePeriod) {
      return;
    }
    
    if (!_isAbsencePeriodManuallyEdited) {
      // 초기 로드가 아닌 경우에만 플래그 설정
      final calculatedPeriod = DateFormatUtils.calculateAbsencePeriod(
        ref.read(substitutionPlanViewModelProvider).planData
            .map((data) => data.absenceDate).toList()
      );
      // 계산된 값과 다르면 사용자가 수정한 것으로 간주
      // 단, 빈 값인 경우는 제외 (저장된 설정 로드 중일 수 있음)
      if (_absencePeriodController.text.isNotEmpty && 
          _absencePeriodController.text != calculatedPeriod) {
        _isAbsencePeriodManuallyEdited = true;
        AppLogger.exchangeDebug('결강기간 수동 수정 감지: ${_absencePeriodController.text}');
      }
    }
  }

  /// 결강기간 자동 계산 및 업데이트 (외부에서 호출 가능한 public 메서드)
  /// 탭 진입 시 DocumentScreen에서 호출됩니다.
  void updateAbsencePeriod() {
    AppLogger.info('📅 [결강기간] updateAbsencePeriod() 호출됨');
    final planData = ref.read(substitutionPlanViewModelProvider).planData;
    AppLogger.exchangeDebug('결강기간 계산 대상: ${planData.length}개 항목');
    _updateAbsencePeriod(planData);
  }

  /// 결강기간 자동 계산 및 업데이트 (내부 메서드)
  void _updateAbsencePeriod(List<SubstitutionPlanData> planData) {
    AppLogger.exchangeDebug('결강기간 업데이트 시작 - 수동 수정 여부: $_isAbsencePeriodManuallyEdited');
    
    // 사용자가 직접 수정한 경우 자동 업데이트하지 않음
    if (_isAbsencePeriodManuallyEdited) {
      AppLogger.exchangeDebug('결강기간 자동 업데이트 건너뜀: 사용자가 수동 수정함');
      return;
    }
    
    final absenceDates = planData.map((data) => data.absenceDate).toList();
    AppLogger.exchangeDebug('결강일 목록: ${absenceDates.join(", ")}');
    
    final absencePeriod = DateFormatUtils.calculateAbsencePeriod(absenceDates);
    AppLogger.exchangeDebug('계산된 결강기간: "$absencePeriod" (현재 값: "${_absencePeriodController.text}")');
    
    // Controller 값이 다를 때만 업데이트 (무한 루프 방지)
    if (_absencePeriodController.text != absencePeriod) {
      // 자동 업데이트 플래그 설정 (리스너가 무시하도록)
      _isUpdatingAbsencePeriod = true;
      
      _absencePeriodController.text = absencePeriod;
      AppLogger.info('✅ [결강기간] 자동 업데이트 완료: "$absencePeriod"');
      
      // UI 업데이트를 위해 setState 호출
      if (mounted) {
        setState(() {});
      }
      
      // 플래그 해제 (다음 프레임에 해제하여 리스너가 정상 작동하도록)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdatingAbsencePeriod = false;
      });
    } else {
      AppLogger.exchangeDebug('결강기간 업데이트 건너뜀: 값이 동일함');
    }
  }
  
  /// PDF 템플릿 파일 경로 저장 (즉시 저장)
  Future<void> _saveTemplateFilePath(String? filePath) async {
    await _pdfSettingsStorage.saveTemplateFilePath(filePath);
  }

  /// 저장된 PDF 출력 설정 로드
  Future<void> _loadSavedSettings() async {
    try {
      final settings = await _pdfSettingsStorage.loadPdfExportSettings();
      if (settings != null) {
        setState(() {
            _fontSize = (settings['fontSize'] as num?)?.toDouble() ?? 10.0;
            _remarksFontSize = (settings['remarksFontSize'] as num?)?.toDouble() ?? 7.0;
            
            // 폰트 값 유효성 검사: 드롭다운 아이템에 있는 값인지 확인
            final savedFont = settings['selectedFont'] as String?;
            final availableFonts = KoreanFontConstants.fontListWithNames
                .map((font) => font['file']!)
                .toList();
            // 저장된 폰트가 유효한 목록에 있는지 확인하고, 없으면 기본 폰트 사용
            _selectedFont = (savedFont != null && availableFonts.contains(savedFont))
                ? savedFont
                : KoreanFontConstants.defaultFont;
          _includeRemarks = settings['includeRemarks'] as bool? ?? true;
          
          // 저장된 PDF 템플릿 파일 경로 로드 (파일 존재 여부 확인)
          final savedTemplatePath = settings['selectedTemplateFilePath'] as String?;
          if (savedTemplatePath != null && savedTemplatePath.isNotEmpty) {
            // 파일이 존재하는지 확인
            final file = File(savedTemplatePath);
            if (file.existsSync()) {
              _selectedTemplateFilePath = savedTemplatePath;
              AppLogger.info('저장된 PDF 템플릿 파일 경로 로드: $savedTemplatePath');
            } else {
              AppLogger.warning('저장된 PDF 템플릿 파일이 존재하지 않습니다: $savedTemplatePath');
              // 파일이 없으면 경로 초기화
              _selectedTemplateFilePath = null;
            }
          }
          
          // 추가 필드 로드 (결강기간 제외 - 자동 계산값으로 덮어씀)
          final additionalFields = settings['additionalFields'] as Map<String, dynamic>?;
          if (additionalFields != null) {
            // 결강교사: 저장된 값이 있으면 사용
            final savedTeacherName = additionalFields['teacherName'] as String? ?? '';
            if (savedTeacherName.isNotEmpty) {
              _teacherNameController.text = savedTeacherName;
            }
            
            // 결강기간은 자동 계산으로 덮어씌우므로 저장된 값은 무시
            // _absencePeriodController.text = additionalFields['absencePeriod'] as String? ?? '';
            _workStatusController.text = additionalFields['workStatus'] as String? ?? '';
            _reasonForAbsenceController.text = additionalFields['reasonForAbsence'] as String? ?? '';
            
            // 학교명: 저장된 값이 있으면 사용
            final savedSchoolName = additionalFields['schoolName'] as String? ?? '';
            if (savedSchoolName.isNotEmpty) {
              _schoolNameController.text = savedSchoolName;
            }
            
            _notesController.text = additionalFields['notes'] as String? ?? PdfNotesTemplate.defaultNotes;
          }
        });
        
        // 설정에서 교사명, 학교명 로드 (입력란이 비어있을 때만 사용)
        // setState 밖에서 호출 (async 함수이므로)
        await loadDefaultValuesIfEmpty();
      }
    } catch (e) {
      // 로드 실패 시 기본값 유지
      // AppLogger를 사용하여 프로덕션 환경에서 안전한 로깅 수행
      AppLogger.warning('PDF 설정 로드 실패: $e');
    }
  }

  /// 설정에서 교사명, 학교명 로드 (입력란이 비어있을 때만 사용)
  /// 
  /// 설정 화면에서 저장한 교사명, 학교명을 가져와서
  /// 입력란이 비어있는 경우에만 자동으로 입력합니다.
  /// 
  /// 외부에서 호출 가능한 public 메서드입니다.
  /// 결보강 문서 탭 클릭 시 호출됩니다.
  Future<void> loadDefaultValuesIfEmpty() async {
    try {
      final appSettings = AppSettingsStorageService();
      final defaults = await appSettings.loadTeacherAndSchoolName();
      
      setState(() {
        // 결강교사 입력란이 비어있으면 설정에서 가져온 값으로 채우기
        if (_teacherNameController.text.trim().isEmpty) {
          final defaultTeacherName = defaults['defaultTeacherName']?.trim() ?? '';
          if (defaultTeacherName.isNotEmpty) {
            _teacherNameController.text = defaultTeacherName;
            AppLogger.info('설정에서 교사명 자동 입력: $defaultTeacherName');
          }
        }
        
        // 학교명 입력란이 비어있으면 설정에서 가져온 값으로 채우기
        if (_schoolNameController.text.trim().isEmpty) {
          final defaultSchoolName = defaults['defaultSchoolName']?.trim() ?? '';
          if (defaultSchoolName.isNotEmpty) {
            _schoolNameController.text = defaultSchoolName;
            AppLogger.info('설정에서 학교명 자동 입력: $defaultSchoolName');
          }
        }
      });
    } catch (e) {
      AppLogger.error('설정에서 기본값 로드 실패: $e', e);
    }
  }

  // PDF 추가 필드 컨트롤러
  final TextEditingController _teacherNameController = TextEditingController();
  final TextEditingController _absencePeriodController = TextEditingController();
  final TextEditingController _workStatusController = TextEditingController();
  final TextEditingController _reasonForAbsenceController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController(
    text: PdfNotesTemplate.defaultNotes,
  );

  @override
  void dispose() {
    _teacherNameController.dispose();
    _absencePeriodController.dispose();
    _workStatusController.dispose();
    _reasonForAbsenceController.dispose();
    _notesController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // build는 DocumentScreen의 TabController 리스너에서 호출되는 updateAbsencePeriod()로 처리
    // 여기서는 UI만 렌더링

    // SingleChildScrollView로 감싸서 작은 창에서 스크롤 가능하도록 함
    return Container(
      padding: const EdgeInsets.all(16),
      // SingleChildScrollView를 사용하여 내용이 화면 높이를 초과할 때 스크롤 가능하게 함
      child: SingleChildScrollView(
        // 스크롤 방향은 수직(기본값)
        scrollDirection: Axis.vertical,
        // 스크롤 동작 설정
        physics: const AlwaysScrollableScrollPhysics(),
        // 패딩으로 인한 스크롤 바운스 효과 활성화
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 문서 출력 버튼 (상단으로 이동)
            _buildDocumentOutputButton(),

            const SizedBox(height: 15),

            // PDF 설정 섹션 (템플릿, 폰트)
            PdfSettingsSection(
              selectedTemplateIndex: _selectedTemplateIndex,
              selectedTemplateFilePath: _selectedTemplateFilePath,
              fontSize: _fontSize,
              remarksFontSize: _remarksFontSize,
              selectedFont: _selectedFont,
              includeRemarks: _includeRemarks,
              fontSizeOptions: _fontSizeOptions,
              remarksFontSizeOptions: _remarksFontSizeOptions,
              onTemplateIndexChanged: (index) {
                setState(() {
                  _selectedTemplateIndex = index;
                  _selectedTemplateFilePath = null;
                });
                // 드롭다운에서 기본 템플릿 선택 시 저장된 경로 제거
                _saveTemplateFilePath(null);
              },
              onTemplateFilePathChanged: (path) {
                setState(() => _selectedTemplateFilePath = path);
                // PDF 파일 선택 시 즉시 저장
                if (path != null) {
                  _saveTemplateFilePath(path);
                }
              },
              onFontSizeChanged: (size) => setState(() => _fontSize = size),
              onRemarksFontSizeChanged: (size) => setState(() => _remarksFontSize = size),
              onFontChanged: (font) => setState(() => _selectedFont = font),
              onIncludeRemarksChanged: (include) => setState(() => _includeRemarks = include),
            ),

            const SizedBox(height: 15),

            // PDF 추가 필드 입력 섹션
            PdfFieldInputsSection(
              teacherNameController: _teacherNameController,
              absencePeriodController: _absencePeriodController,
              workStatusController: _workStatusController,
              reasonForAbsenceController: _reasonForAbsenceController,
              notesController: _notesController,
              schoolNameController: _schoolNameController,
            ),
          ],
        ),
      ),
    );
  }

  /// 문서 출력 버튼
  Widget _buildDocumentOutputButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handlePreview,
        icon: const Icon(Icons.description, size: 20),
        label: const Text(
          '문서 출력',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.purple.shade600,
          side: BorderSide(color: Colors.purple.shade600),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// 출력 미리 보기 처리
  Future<void> _handlePreview() async {
    if (!mounted) return;

    try {
      // 1. 데이터 수집
      final planData = ref.read(substitutionPlanViewModelProvider).planData;
      if (planData.isEmpty) {
        if (!mounted) return;
        _showSnackBar('미리볼 데이터가 없습니다.', Colors.orange);
        return;
      }

      // 2. 임시 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}${Platform.pathSeparator}preview_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 3. PDF 생성
      final String templatePath = _selectedTemplateFilePath ?? kPdfTemplates[_selectedTemplateIndex].assetPath;
      final success = await PdfExportService.exportSubstitutionPlan(
        planData: planData,
        outputPath: tempPath,
        templatePath: templatePath,
        fontSize: _fontSize,
        remarksFontSize: _remarksFontSize,
        fontType: _selectedFont,
        includeRemarks: _includeRemarks,
        additionalFields: {
          'teacherName': _teacherNameController.text,
          'absencePeriod': _absencePeriodController.text,
          'workStatus': _workStatusController.text,
          'reasonForAbsence': _reasonForAbsenceController.text,
          'notes': _notesController.text,
          'schoolName': _schoolNameController.text,
        },
      );

      if (!mounted) return;

      if (!success) {
        _showSnackBar('출력 미리 보기 생성 실패', Colors.red);
        return;
      }

      // 4. PDF 출력 설정 저장 (문서 출력 버튼 클릭 시)
      final saveSuccess = await _pdfSettingsStorage.savePdfExportSettings(
        fontSize: _fontSize,
        remarksFontSize: _remarksFontSize,
        selectedFont: _selectedFont,
        includeRemarks: _includeRemarks,
        additionalFields: {
          'teacherName': _teacherNameController.text,
          'absencePeriod': _absencePeriodController.text,
          'workStatus': _workStatusController.text,
          'reasonForAbsence': _reasonForAbsenceController.text,
          'schoolName': _schoolNameController.text,
          'notes': _notesController.text,
        },
        selectedTemplateFilePath: _selectedTemplateFilePath, // PDF 템플릿 파일 경로 저장
      );
      
      if (!saveSuccess && mounted) {
        _showSnackBar('PDF 설정 저장에 실패했습니다.', Colors.orange);
      }
      
      // 5. 미리보기 화면으로 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(pdfPath: tempPath),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('오류: $e', Colors.red);
      }
    }
  }

  /// 스낵바 표시
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
