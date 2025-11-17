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
    
    // 추가 필드 Controller는 메모리 변수로만 관리 (자동 저장하지 않음)
    
    // 마지막으로 선택된 양식 인덱스 로드 후 해당 양식의 설정 로드
    _loadLastSelectedTemplateIndex().then((_) {
      // 설정 로드 완료 후 결강기간 자동 업데이트 (위젯이 생성된 후 실행)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppLogger.info('📄 [결강기간] 초기 진입 시 결강기간 업데이트 (설정 로드 후)');
          updateAbsencePeriod();
        }
      });
    });
  }
  
  @override
  void dispose() {
    // 프로그램 종료 시 현재 양식의 설정 저장
    _saveCurrentSettings();
    
    // 프로그램 종료 시 마지막 선택된 양식 인덱스 저장
    _pdfSettingsStorage.saveLastSelectedTemplateIndex(_selectedTemplateIndex);
    
    // Controller 정리
    _teacherNameController.dispose();
    _absencePeriodController.dispose();
    _workStatusController.dispose();
    _reasonForAbsenceController.dispose();
    _schoolNameController.dispose();
    _notesController.dispose();
    
    super.dispose();
  }

  /// 현재 설정을 디스크에 저장
  /// 
  /// 문서 출력 버튼 클릭 시 또는 프로그램 종료 시 호출됩니다.
  Future<void> _saveCurrentSettings() async {
    if (!mounted) return;
    
    try {
      final saveSuccess = await _pdfSettingsStorage.savePdfExportSettings(
        templateIndex: _selectedTemplateIndex,
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
        selectedTemplateFilePath: _selectedTemplateFilePath,
      );
      
      if (saveSuccess) {
        AppLogger.debug('PDF 설정 저장 성공 (양식 ${_selectedTemplateIndex + 1})');
      } else {
        AppLogger.warning('PDF 설정 저장 실패 (양식 ${_selectedTemplateIndex + 1})');
      }
    } catch (e) {
      AppLogger.error('PDF 설정 저장 중 오류: $e', e);
    }
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
  
  /// 마지막으로 선택된 양식 인덱스 로드
  /// 
  /// 프로그램 시작 시 호출되어 마지막으로 선택했던 양식을 로드합니다.
  Future<void> _loadLastSelectedTemplateIndex() async {
    try {
      final lastIndex = await _pdfSettingsStorage.loadLastSelectedTemplateIndex();
      if (lastIndex != null && lastIndex >= 0 && lastIndex <= 1) {
        setState(() {
          _selectedTemplateIndex = lastIndex;
        });
        AppLogger.info('마지막 선택된 양식 인덱스 로드: 양식 ${lastIndex + 1}');
      }
      
      // 선택된 양식의 설정 로드
      await _loadSavedSettings(templateIndex: lastIndex ?? 0);
    } catch (e) {
      AppLogger.error('마지막 선택된 양식 인덱스 로드 실패: $e', e);
      // 오류 발생 시 기본값(양식 1)으로 설정 로드
      await _loadSavedSettings(templateIndex: 0);
    }
  }

  /// 저장된 PDF 출력 설정 로드
  /// 
  /// 지정된 양식의 설정을 로드합니다.
  /// 
  /// 매개변수:
  /// - `templateIndex`: 로드할 양식 인덱스 (기본값: 현재 선택된 양식)
  Future<void> _loadSavedSettings({int? templateIndex}) async {
    try {
      // 지정된 양식 인덱스가 없으면 현재 선택된 양식 사용
      final targetIndex = templateIndex ?? _selectedTemplateIndex;
      
      // 지정된 양식의 설정 로드
      final settings = await _pdfSettingsStorage.loadPdfExportSettings(templateIndex: targetIndex);
      
      // 폰트 설정 업데이트
      double newFontSize = 10.0;
      double newRemarksFontSize = 7.0;
      String newSelectedFont = KoreanFontConstants.defaultFont;
      bool newIncludeRemarks = true;
      String? newSelectedTemplateFilePath;
      
      // 추가 필드 값
      String newTeacherName = '';
      String newWorkStatus = '';
      String newReasonForAbsence = '';
      String newSchoolName = '';
      String newNotes = PdfNotesTemplate.defaultNotes;
      
      if (settings != null) {
        // 저장된 설정이 있는 경우: 저장된 값으로 로드
        newFontSize = (settings['fontSize'] as num?)?.toDouble() ?? 10.0;
        newRemarksFontSize = (settings['remarksFontSize'] as num?)?.toDouble() ?? 7.0;
        
        // 폰트 값 유효성 검사: 드롭다운 아이템에 있는 값인지 확인
        final savedFont = settings['selectedFont'] as String?;
        final availableFonts = KoreanFontConstants.fontListWithNames
            .map((font) => font['file']!)
            .toList();
        // 저장된 폰트가 유효한 목록에 있는지 확인하고, 없으면 기본 폰트 사용
        newSelectedFont = (savedFont != null && availableFonts.contains(savedFont))
            ? savedFont
            : KoreanFontConstants.defaultFont;
        newIncludeRemarks = settings['includeRemarks'] as bool? ?? true;
        
        // 저장된 PDF 템플릿 파일 경로 로드 (파일 존재 여부 확인)
        final savedTemplatePath = settings['selectedTemplateFilePath'] as String?;
        if (savedTemplatePath != null && savedTemplatePath.isNotEmpty) {
          // 파일이 존재하는지 확인
          final file = File(savedTemplatePath);
          if (file.existsSync()) {
            newSelectedTemplateFilePath = savedTemplatePath;
            AppLogger.info('저장된 PDF 템플릿 파일 경로 로드 (양식 ${targetIndex + 1}): $savedTemplatePath');
          } else {
            AppLogger.warning('저장된 PDF 템플릿 파일이 존재하지 않습니다: $savedTemplatePath');
            // 파일이 없으면 경로 초기화
            newSelectedTemplateFilePath = null;
          }
        } else {
          // 저장된 경로가 없으면 null로 설정
          newSelectedTemplateFilePath = null;
        }
        
        // 추가 필드 로드
        final additionalFields = settings['additionalFields'] as Map<String, dynamic>?;
        // 양식별 기본값 가져오기 (notes 필드 기본값 사용)
        final defaultSettings = _pdfSettingsStorage.getDefaultSettings(templateIndex: targetIndex);
        final defaultNotes = (defaultSettings['additionalFields'] as Map<String, dynamic>?)?
            ['notes'] as String? ?? PdfNotesTemplate.defaultNotes;
        
        if (additionalFields != null) {
          // 결강교사: 저장된 값이 있으면 사용, 없으면 빈 문자열
          newTeacherName = additionalFields['teacherName'] as String? ?? '';
          
          // 결강기간은 자동 계산으로 덮어씌우므로 저장된 값은 무시
          // _absencePeriodController.text = additionalFields['absencePeriod'] as String? ?? '';
          
          newWorkStatus = additionalFields['workStatus'] as String? ?? '';
          newReasonForAbsence = additionalFields['reasonForAbsence'] as String? ?? '';
          
          // 학교명: 저장된 값이 있으면 사용, 없으면 빈 문자열
          newSchoolName = additionalFields['schoolName'] as String? ?? '';
          
          // notes: 저장된 값이 있으면 사용, 없으면 양식별 기본값 사용
          newNotes = additionalFields['notes'] as String? ?? defaultNotes;
        } else {
          // 추가 필드가 없는 경우 양식별 기본값으로 초기화
          newTeacherName = '';
          newWorkStatus = '';
          newReasonForAbsence = '';
          newSchoolName = '';
          newNotes = defaultNotes;
        }
        
        AppLogger.info('양식 ${targetIndex + 1}의 설정 로드 완료');
      } else {
        // 저장된 설정이 없는 경우: 양식별 기본값으로 초기화
        final defaultSettings = _pdfSettingsStorage.getDefaultSettings(templateIndex: targetIndex);
        newFontSize = (defaultSettings['fontSize'] as num?)?.toDouble() ?? 10.0;
        newRemarksFontSize = (defaultSettings['remarksFontSize'] as num?)?.toDouble() ?? 7.0;
        
        // 폰트 값 유효성 검사
        final defaultFont = defaultSettings['selectedFont'] as String?;
        final availableFonts = KoreanFontConstants.fontListWithNames
            .map((font) => font['file']!)
            .toList();
        newSelectedFont = (defaultFont != null && availableFonts.contains(defaultFont))
            ? defaultFont
            : KoreanFontConstants.defaultFont;
        newIncludeRemarks = defaultSettings['includeRemarks'] as bool? ?? true;
        newSelectedTemplateFilePath = null;
        
        // 추가 필드도 양식별 기본값으로 초기화
        final defaultAdditionalFields = defaultSettings['additionalFields'] as Map<String, dynamic>?;
        newTeacherName = '';
        newWorkStatus = '';
        newReasonForAbsence = '';
        newSchoolName = '';
        // notes는 양식별 기본값 사용 (양식 2는 빈값, 양식 1은 기본 템플릿 값)
        newNotes = defaultAdditionalFields?['notes'] as String? ?? PdfNotesTemplate.defaultNotes;
        
        AppLogger.info('양식 ${targetIndex + 1}의 저장된 설정이 없어 기본값으로 초기화 (폰트: $newSelectedFont, 비고 출력: $newIncludeRemarks)');
      }
      
      // UI 업데이트: setState로 상태 변경 및 Controller 값 업데이트
      setState(() {
        // 폰트 설정 업데이트
        _fontSize = newFontSize;
        _remarksFontSize = newRemarksFontSize;
        _selectedFont = newSelectedFont;
        _includeRemarks = newIncludeRemarks;
        _selectedTemplateFilePath = newSelectedTemplateFilePath;
        
        // 추가 필드 Controller 값 업데이트 (UI에 반영됨)
        _teacherNameController.text = newTeacherName;
        _workStatusController.text = newWorkStatus;
        _reasonForAbsenceController.text = newReasonForAbsence;
        _schoolNameController.text = newSchoolName;
        _notesController.text = newNotes;
      });
      
      // 설정에서 교사명, 학교명 로드 (입력란이 비어있을 때만 사용)
      // setState 밖에서 호출 (async 함수이므로)
      await loadDefaultValuesIfEmpty();
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
  // notes Controller는 초기값을 빈 문자열로 설정 (양식별 기본값은 로드 시 적용)
  final TextEditingController _notesController = TextEditingController();


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
              onTemplateIndexChanged: (index) async {
                // 양식 변경 시: 먼저 현재 양식의 메모리 상 설정을 디스크에 저장한 후, 새 양식의 설정을 로드
                
                // 현재 양식의 설정 저장 (메모리 → 디스크)
                await _saveCurrentSettings();
                
                // 양식 인덱스 업데이트 (로드 전에 업데이트하여 올바른 양식의 설정을 로드)
                setState(() {
                  _selectedTemplateIndex = index;
                });
                
                // 마지막 선택된 양식 인덱스 저장
                await _pdfSettingsStorage.saveLastSelectedTemplateIndex(index);
                
                // 새 양식의 설정 로드 (디스크 → 메모리)
                // _loadSavedSettings 내부에서 setState를 호출하여 모든 메모리 변수와 Controller 값을 업데이트함
                await _loadSavedSettings(templateIndex: index);
                
                AppLogger.info('양식 변경: 양식 ${index + 1} 선택됨, 설정 로드 완료');
              },
              onTemplateFilePathChanged: (path) async {
                // PDF 파일 경로는 메모리 변수만 업데이트 (디스크 저장하지 않음)
                setState(() => _selectedTemplateFilePath = path);
                // 파일 경로는 문서 출력 버튼 클릭 시 또는 프로그램 종료 시 저장됨
                AppLogger.info('사용자 정의 PDF 파일 선택: $path (메모리에만 저장, 디스크 저장은 문서 출력 시)');
              },
              onFontSizeChanged: (size) {
                // 폰트 크기 변경 시 메모리 변수만 업데이트 (디스크 저장하지 않음)
                setState(() => _fontSize = size);
              },
              onRemarksFontSizeChanged: (size) {
                // 비고 폰트 크기 변경 시 메모리 변수만 업데이트 (디스크 저장하지 않음)
                setState(() => _remarksFontSize = size);
              },
              onFontChanged: (font) {
                // 폰트 종류 변경 시 메모리 변수만 업데이트 (디스크 저장하지 않음)
                setState(() => _selectedFont = font);
              },
              onIncludeRemarksChanged: (include) {
                // 비고 출력 여부 변경 시 메모리 변수만 업데이트 (디스크 저장하지 않음)
                setState(() => _includeRemarks = include);
              },
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

      // 4. PDF 출력 설정 저장 (문서 출력 버튼 클릭 시, 양식별로 저장)
      await _saveCurrentSettings();
      
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
