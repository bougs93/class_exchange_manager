import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../constants/screen_usage_hints.dart';
import '../../../../../models/plan_output_menu.dart';
import '../../../../../models/print_profile.dart';
import '../../../../../models/timetable_registry.dart';
import '../../../../../providers/exchange_screen_provider.dart';
import '../../../../../providers/print_profile_provider.dart';
import '../../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../../providers/timetable_registry_provider.dart';
import '../../../../../theme/design_tokens.dart';
import '../../../../widgets/content_toolbar_layout.dart';
import '../../../../widgets/content_usage_hint_bar.dart';
import '../../../../widgets/timetable_grid/grid_header_widgets.dart';
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

/// 결강기간 업데이트 모드
enum AbsencePeriodUpdateMode {
  /// 자동 업데이트 가능 (기본값)
  autoUpdate,

  /// 사용자가 수동으로 수정함 (자동 업데이트 중지)
  manualOverride,

  /// 업데이트 진행 중 (리스너 무시)
  updating,
}

/// 파일 출력 위젯 (리팩토링된 버전)
///
/// 결보강 계획서를 PDF 형식으로 미리보고 저장할 수 있는 위젯입니다.
/// 설정 및 입력 섹션은 별도 위젯으로 분리되어 있습니다.
class SubstitutionOutputWidget extends ConsumerStatefulWidget {
  const SubstitutionOutputWidget({super.key});

  @override
  ConsumerState<SubstitutionOutputWidget> createState() =>
      SubstitutionOutputWidgetState();
}

/// SubstitutionOutputWidget의 State 클래스 (외부에서 접근 가능하도록 public)
class SubstitutionOutputWidgetState
    extends ConsumerState<SubstitutionOutputWidget> {
  // PDF 템플릿 설정
  int _selectedTemplateIndex = 0;
  String? _selectedTemplateFilePath;

  // 폰트 설정
  double _fontSize = 10.0;
  double _remarksFontSize = 7.0;
  String _selectedFont = KoreanFontConstants.defaultFont;
  bool _includeRemarks = true;

  // 폰트 사이즈 옵션
  final List<double> _fontSizeOptions = [
    8.0,
    9.0,
    10.0,
    11.0,
    12.0,
    13.0,
    14.0,
    15.0,
    16.0,
  ];
  final List<double> _remarksFontSizeOptions = [
    6.0,
    7.0,
    8.0,
    9.0,
    10.0,
    11.0,
    12.0,
  ];

  // PDF 출력 설정 저장 서비스
  final PdfExportSettingsStorageService _pdfSettingsStorage =
      PdfExportSettingsStorageService();

  // 결강기간 업데이트 모드
  AbsencePeriodUpdateMode _absencePeriodMode =
      AbsencePeriodUpdateMode.autoUpdate;

  // ===== 계획서(교사별 인쇄 프로파일) 선택 상태 =====

  /// 현재 선택 교사 (null이면 교사 선택 전)
  String? _selectedTeacher;

  /// 현재 선택 계획서 ID (null이면 미지정 → 레거시 양식 설정 사용)
  String? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    AppLogger.info('📄 [결강기간] SubstitutionOutputWidget 초기화');

    // 결강기간 필드 변경 감지 (사용자가 직접 수정한 경우 플래그 설정)
    _absencePeriodController.addListener(_onAbsencePeriodChanged);

    // 계획서 선택 흐름: 스토어 로드 → 마지막 교사/계획서 복원 → 설정 로드
    _initializeProfileFlow().then((_) {
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
  /// 계획서가 선택된 경우 해당 계획서에 저장하고,
  /// 미지정인 경우 레거시 양식별 설정에 저장합니다.
  /// 문서 출력 버튼 클릭 시 또는 프로그램 종료 시 호출됩니다.
  Future<void> _saveCurrentSettings() async {
    if (!mounted) return;

    try {
      // 계획서가 선택된 경우: 계획서에 저장
      final store = ref.read(printProfileStoreProvider);
      final selected = store.getById(_selectedProfileId);
      if (selected != null) {
        final success = await ref
            .read(printProfileStoreProvider.notifier)
            .saveProfile(_collectProfileFromUi(selected));
        if (success) {
          AppLogger.info("계획서 '${selected.name}'에 설정 저장 완료");
        } else {
          AppLogger.warning("계획서 '${selected.name}'에 설정 저장 실패");
        }
        return;
      }

      // 미지정: 레거시 양식별 저장
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
    // 업데이트 진행 중이면 무시
    if (_absencePeriodMode == AbsencePeriodUpdateMode.updating) {
      return;
    }

    if (_absencePeriodMode == AbsencePeriodUpdateMode.autoUpdate) {
      // 자동 업데이트 모드: 계산된 값과 다르면 사용자가 수정한 것으로 간주
      final calculatedPeriod = DateFormatUtils.calculateAbsencePeriod(
        ref
            .read(substitutionPlanViewModelProvider)
            .planData
            .map((data) => data.absenceDate)
            .toList(),
      );

      // 빈 값인 경우는 제외 (저장된 설정 로드 중일 수 있음)
      if (_absencePeriodController.text.isNotEmpty &&
          _absencePeriodController.text != calculatedPeriod) {
        _absencePeriodMode = AbsencePeriodUpdateMode.manualOverride;
        AppLogger.exchangeDebug(
          '결강기간 수동 수정 감지: ${_absencePeriodController.text}',
        );
      }
    }
  }

  /// 결강기간 자동 계산 및 업데이트 (외부에서 호출 가능한 public 메서드)
  /// 탭 진입 시 PlanOutputScreen에서 호출됩니다.
  void updateAbsencePeriod() {
    AppLogger.info('📅 [결강기간] updateAbsencePeriod() 호출됨');
    final planData = ref.read(substitutionPlanViewModelProvider).planData;
    AppLogger.exchangeDebug('결강기간 계산 대상: ${planData.length}개 항목');
    _updateAbsencePeriod(planData);
  }

  /// 결강기간 자동 계산 및 업데이트 (내부 메서드)
  void _updateAbsencePeriod(List<SubstitutionPlanData> planData) {
    AppLogger.exchangeDebug('결강기간 업데이트 시작 - 모드: $_absencePeriodMode');

    // 사용자가 수동으로 수정한 경우 자동 업데이트하지 않음
    if (_absencePeriodMode == AbsencePeriodUpdateMode.manualOverride) {
      AppLogger.exchangeDebug('결강기간 자동 업데이트 건너뜀: 사용자가 수동 수정함');
      return;
    }

    final absenceDates = planData.map((data) => data.absenceDate).toList();
    AppLogger.exchangeDebug('결강일 목록: ${absenceDates.join(", ")}');

    final absencePeriod = DateFormatUtils.calculateAbsencePeriod(absenceDates);
    AppLogger.exchangeDebug(
      '계산된 결강기간: "$absencePeriod" (현재 값: "${_absencePeriodController.text}")',
    );

    // Controller 값이 다를 때만 업데이트 (무한 루프 방지)
    if (_absencePeriodController.text != absencePeriod) {
      // 업데이트 진행 중 모드로 설정 (리스너가 무시하도록)
      _absencePeriodMode = AbsencePeriodUpdateMode.updating;

      _absencePeriodController.text = absencePeriod;
      AppLogger.info('✅ [결강기간] 자동 업데이트 완료: "$absencePeriod"');

      // UI 업데이트를 위해 setState 호출
      if (mounted) {
        setState(() {});
      }

      // 자동 업데이트 모드로 복원 (다음 프레임에 복원하여 리스너가 정상 작동하도록)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _absencePeriodMode = AbsencePeriodUpdateMode.autoUpdate;
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
      final lastIndex =
          await _pdfSettingsStorage.loadLastSelectedTemplateIndex();
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
      final settings = await _pdfSettingsStorage.loadPdfExportSettings(
        templateIndex: targetIndex,
      );

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
        newRemarksFontSize =
            (settings['remarksFontSize'] as num?)?.toDouble() ?? 7.0;

        // 폰트 값 유효성 검사: 드롭다운 아이템에 있는 값인지 확인
        final savedFont = settings['selectedFont'] as String?;
        final availableFonts =
            KoreanFontConstants.fontListWithNames
                .map((font) => font['file']!)
                .toList();
        // 저장된 폰트가 유효한 목록에 있는지 확인하고, 없으면 기본 폰트 사용
        newSelectedFont =
            (savedFont != null && availableFonts.contains(savedFont))
                ? savedFont
                : KoreanFontConstants.defaultFont;
        newIncludeRemarks = settings['includeRemarks'] as bool? ?? true;

        // 저장된 PDF 템플릿 파일 경로 로드 (파일 존재 여부 확인)
        final savedTemplatePath =
            settings['selectedTemplateFilePath'] as String?;
        if (savedTemplatePath != null && savedTemplatePath.isNotEmpty) {
          // 파일이 존재하는지 확인
          final file = File(savedTemplatePath);
          if (file.existsSync()) {
            newSelectedTemplateFilePath = savedTemplatePath;
            AppLogger.info(
              '저장된 PDF 템플릿 파일 경로 로드 (양식 ${targetIndex + 1}): $savedTemplatePath',
            );
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
        final additionalFields =
            settings['additionalFields'] as Map<String, dynamic>?;
        // 양식별 기본값 가져오기 (notes 필드 기본값 사용)
        final defaultSettings = _pdfSettingsStorage.getDefaultSettings(
          templateIndex: targetIndex,
        );
        final defaultNotes =
            (defaultSettings['additionalFields']
                    as Map<String, dynamic>?)?['notes']
                as String? ??
            PdfNotesTemplate.defaultNotes;

        if (additionalFields != null) {
          // 결강교사: 저장된 값이 있으면 사용, 없으면 빈 문자열
          newTeacherName = additionalFields['teacherName'] as String? ?? '';

          // 결강기간은 자동 계산으로 덮어씌우므로 저장된 값은 무시
          // _absencePeriodController.text = additionalFields['absencePeriod'] as String? ?? '';

          newWorkStatus = additionalFields['workStatus'] as String? ?? '';
          newReasonForAbsence =
              additionalFields['reasonForAbsence'] as String? ?? '';

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
        final defaultSettings = _pdfSettingsStorage.getDefaultSettings(
          templateIndex: targetIndex,
        );
        newFontSize = (defaultSettings['fontSize'] as num?)?.toDouble() ?? 10.0;
        newRemarksFontSize =
            (defaultSettings['remarksFontSize'] as num?)?.toDouble() ?? 7.0;

        // 폰트 값 유효성 검사
        final defaultFont = defaultSettings['selectedFont'] as String?;
        final availableFonts =
            KoreanFontConstants.fontListWithNames
                .map((font) => font['file']!)
                .toList();
        newSelectedFont =
            (defaultFont != null && availableFonts.contains(defaultFont))
                ? defaultFont
                : KoreanFontConstants.defaultFont;
        newIncludeRemarks = defaultSettings['includeRemarks'] as bool? ?? true;
        newSelectedTemplateFilePath = null;

        // 추가 필드도 양식별 기본값으로 초기화
        final defaultAdditionalFields =
            defaultSettings['additionalFields'] as Map<String, dynamic>?;
        newTeacherName = '';
        newWorkStatus = '';
        newReasonForAbsence = '';
        newSchoolName = '';
        // notes는 양식별 기본값 사용 (양식 2는 빈값, 양식 1은 기본 템플릿 값)
        newNotes =
            defaultAdditionalFields?['notes'] as String? ??
            PdfNotesTemplate.defaultNotes;

        AppLogger.info(
          '양식 ${targetIndex + 1}의 저장된 설정이 없어 기본값으로 초기화 (폰트: $newSelectedFont, 비고 출력: $newIncludeRemarks)',
        );
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
          final defaultTeacherName =
              defaults['defaultTeacherName']?.trim() ?? '';
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
  final TextEditingController _absencePeriodController =
      TextEditingController();
  final TextEditingController _workStatusController = TextEditingController();
  final TextEditingController _reasonForAbsenceController =
      TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();
  // notes Controller는 초기값을 빈 문자열로 설정 (양식별 기본값은 로드 시 적용)
  final TextEditingController _notesController = TextEditingController();

  // ===== 계획서(교사별 인쇄 프로파일) 흐름 =====

  /// 현재 시간표의 교사 목록 (가나다순)
  List<String> _availableTeachers() {
    final teachers = ref.watch(exchangeScreenProvider).timetableData?.teachers;
    if (teachers == null) return const [];
    final names = teachers.map((t) => t.name).where((n) => n.isNotEmpty).toList()
      ..sort();
    return names;
  }

  /// 계획서 선택 흐름 초기화
  ///
  /// 스토어 로드 → 마지막 교사/계획서 복원 → 설정 로드.
  /// 계획서가 없으면 레거시 양식 설정 흐름으로 폴백합니다.
  Future<void> _initializeProfileFlow() async {
    await ref.read(printProfileStoreProvider.notifier).ensureLoaded();
    if (!mounted) return;

    final store = ref.read(printProfileStoreProvider);
    final teachers = _availableTeachers();

    var teacher = store.lastSelectedTeacher;
    if (teacher == null || !teachers.contains(teacher)) {
      teacher = teachers.isNotEmpty ? teachers.first : null;
    }
    _selectedTeacher = teacher;

    final profiles = teacher != null ? store.byTeacher(teacher) : <PrintProfile>[];
    if (profiles.isNotEmpty) {
      final lastUsed = store.getById(store.lastUsedProfileId);
      final selected =
          (lastUsed != null && lastUsed.teacherName == teacher)
          ? lastUsed
          : profiles.first;
      _selectedProfileId = selected.id;
      _applyProfileToUi(selected);
      if (mounted) setState(() {});
      AppLogger.info("계획서 복원: 교사=$teacher, 계획서='${selected.name}'");
    } else {
      // 선택 교사의 계획서가 없으면 미지정 → 레거시 양식 설정 로드
      _selectedProfileId = null;
      await _loadLastSelectedTemplateIndex();
    }
  }

  /// 활성 시간표 전환 후 재초기화 (start_screen이 데이터 재로드한 뒤 호출됨)
  Future<void> _reinitAfterTimetableSwitch() async {
    // 시간표 데이터 재로드가 먼저 끝나도록 한 프레임 대기
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _selectedTeacher = null;
    _selectedProfileId = null;
    await _initializeProfileFlow();
  }

  /// 계획서 설정 → 화면 UI 적용
  void _applyProfileToUi(PrintProfile profile) {
    if (!mounted) return;

    // 폰트 유효성 검사
    final availableFonts = KoreanFontConstants.fontListWithNames
        .map((font) => font['file']!)
        .toList();
    final font = availableFonts.contains(profile.selectedFont)
        ? profile.selectedFont
        : KoreanFontConstants.defaultFont;

    // 템플릿 파일 경로 유효성 검사
    String? templatePath = profile.selectedTemplateFilePath;
    if (templatePath != null && !File(templatePath).existsSync()) {
      AppLogger.warning('계획서의 PDF 템플릿 파일이 없어 경로를 초기화: $templatePath');
      templatePath = null;
    }

    final defaultNotes =
        profile.additionalFields['notes'] ?? PdfNotesTemplate.defaultNotes;

    setState(() {
      _selectedTemplateIndex = profile.templateIndex.clamp(0, 1);
      _fontSize = profile.fontSize;
      _remarksFontSize = profile.remarksFontSize;
      _selectedFont = font;
      _includeRemarks = profile.includeRemarks;
      _selectedTemplateFilePath = templatePath;

      _teacherNameController.text =
          profile.additionalFields['teacherName'] ??
          (profile.teacherName.isNotEmpty ? profile.teacherName : '');
      _workStatusController.text =
          profile.additionalFields['workStatus'] ?? '';
      _reasonForAbsenceController.text =
          profile.additionalFields['reasonForAbsence'] ?? '';
      _schoolNameController.text =
          profile.additionalFields['schoolName'] ?? '';
      _notesController.text = defaultNotes;
    });
  }

  /// 현재 화면 설정 → 계획서 객체로 수집
  PrintProfile _collectProfileFromUi(PrintProfile base) {
    return base.copyWith(
      templateIndex: _selectedTemplateIndex,
      fontSize: _fontSize,
      remarksFontSize: _remarksFontSize,
      selectedFont: _selectedFont,
      includeRemarks: _includeRemarks,
      selectedTemplateFilePath: _selectedTemplateFilePath,
      additionalFields: {
        'teacherName': _teacherNameController.text,
        'absencePeriod': _absencePeriodController.text,
        'workStatus': _workStatusController.text,
        'reasonForAbsence': _reasonForAbsenceController.text,
        'schoolName': _schoolNameController.text,
        'notes': _notesController.text,
      },
    );
  }

  /// 교사 전환: 계획서 목록만 갱신 (교체불가·교체 상태는 시간표 단위 공유라 무변경)
  Future<void> _onTeacherChanged(String? teacher) async {
    if (teacher == null || teacher == _selectedTeacher) return;

    final store = ref.read(printProfileStoreProvider);
    final profiles = store.byTeacher(teacher);

    setState(() {
      _selectedTeacher = teacher;
      _selectedProfileId = profiles.isNotEmpty ? profiles.first.id : null;
    });
    await ref
        .read(printProfileStoreProvider.notifier)
        .setLastSelectedTeacher(teacher);

    if (profiles.isNotEmpty) {
      _applyProfileToUi(profiles.first);
    } else {
      // 계획서가 없는 교사: 미지정 → 레거시 양식 설정 로드
      await _loadSavedSettings();
    }
  }

  /// 계획서 전환: 해당 계획서의 설정을 화면에 적용
  Future<void> _onProfileChanged(String? profileId) async {
    final store = ref.read(printProfileStoreProvider);
    final profile = store.getById(profileId);

    setState(() => _selectedProfileId = profileId);

    if (profile != null) {
      _applyProfileToUi(profile);
      await ref
          .read(printProfileStoreProvider.notifier)
          .setLastUsedProfile(profile.id);
    }
  }

  /// 새 계획서 만들기: 현재 화면 설정을 복사해 생성 + 선택
  Future<void> _createProfile() async {
    final teacher = _selectedTeacher;
    if (teacher == null) {
      _showSnackBar('교사를 먼저 선택하세요.', Colors.orange);
      return;
    }

    final store = ref.read(printProfileStoreProvider);
    final count = store.byTeacher(teacher).length;
    final defaultName = '계획서${count + 1}';

    final name = await _showProfileNameDialog(initialValue: defaultName);
    if (name == null || name.isEmpty || !mounted) return;

    final seed = PrintProfile(
      id: PrintProfile.generateId(),
      name: name,
      teacherName: teacher,
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

    final success = await ref
        .read(printProfileStoreProvider.notifier)
        .saveProfile(seed);
    if (!mounted) return;

    if (success) {
      setState(() => _selectedProfileId = seed.id);
      _showSnackBar("계획서 '$name'이(가) 생성되었습니다.", Colors.green);
    } else {
      _showSnackBar('계획서 생성에 실패했습니다.', Colors.red);
    }
  }

  /// 계획서 이름 변경
  Future<void> _renameSelectedProfile() async {
    final store = ref.read(printProfileStoreProvider);
    final selected = store.getById(_selectedProfileId);
    if (selected == null) return;

    final name = await _showProfileNameDialog(initialValue: selected.name);
    if (name == null || name.isEmpty || name == selected.name || !mounted) {
      return;
    }

    final success = await ref
        .read(printProfileStoreProvider.notifier)
        .renameProfile(selected.id, name);
    if (mounted) {
      _showSnackBar(
        success ? '이름이 변경되었습니다.' : '이름 변경에 실패했습니다.',
        success ? Colors.green : Colors.red,
      );
    }
  }

  /// 계획서 삭제
  ///
  /// 이 계획서가 지정된 교체 건은 조회 시 '미지정'(기본 계획서)으로 처리됩니다.
  Future<void> _deleteSelectedProfile() async {
    final store = ref.read(printProfileStoreProvider);
    final selected = store.getById(_selectedProfileId);
    if (selected == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('계획서 삭제'),
          content: Text(
            "'${selected.name}'을(를) 삭제하시겠습니까?\n"
            '이 계획서가 지정된 교체 건은 미지정 상태가 됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;

    final success = await ref
        .read(printProfileStoreProvider.notifier)
        .deleteProfile(selected.id);
    if (!mounted) return;

    if (success) {
      setState(() => _selectedProfileId = null);
      _showSnackBar("계획서 '${selected.name}'이(가) 삭제되었습니다.", Colors.green);
    } else {
      _showSnackBar('삭제에 실패했습니다.', Colors.red);
    }
  }

  /// 현재 화면 설정을 선택 계획서에 저장
  Future<void> _saveToSelectedProfile() async {
    final store = ref.read(printProfileStoreProvider);
    final selected = store.getById(_selectedProfileId);
    if (selected == null) return;

    final success = await ref
        .read(printProfileStoreProvider.notifier)
        .saveProfile(_collectProfileFromUi(selected));
    if (mounted) {
      _showSnackBar(
        success ? "계획서 '${selected.name}'에 저장되었습니다." : '저장에 실패했습니다.',
        success ? Colors.green : Colors.red,
      );
    }
  }

  /// 계획서 이름 입력 다이얼로그 (취소 시 null)
  Future<String?> _showProfileNameDialog({required String initialValue}) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('계획서 이름'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '계획서 이름',
              hintText: '예: 계획서1',
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 활성 시간표 전환 감지 → 계획서 흐름 재초기화 (교체불가·교체 상태는 시간표 단위 공유)
    ref.listen<TimetableRegistryEntry?>(activeTimetableEntryProvider, (
      previous,
      next,
    ) {
      if (previous != null && next != null && previous.id != next.id) {
        AppLogger.info('활성 시간표 전환 감지 → 계획서 바 재초기화');
        _reinitAfterTimetableSwitch();
      }
    });

    // build는 PlanOutputScreen의 TabController 리스너에서 호출되는 updateAbsencePeriod()로 처리
    // 여기서는 UI만 렌더링

    // SingleChildScrollView로 감싸서 작은 창에서 스크롤 가능하도록 함
    return Container(
      width: double.infinity,
      // 내용 입력(ContentInputGrid) 등 다른 문서 탭과 동일한 16px 여백
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topLeft,
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
            ContentUsageHintBar(
              message: ScreenUsageHints.substitutionOutput,
              accentColor:
                  context.tokens.monochromeMenuAccents
                      ? context.tokens.primary
                      : PlanOutputMenu.substitutionOutput.color,
            ),
            ContentToolbarLayout.hintToToolbarSpacer,

            // 교사별 계획서(인쇄 프로파일) 선택 바
            _buildProfileBar(),

            const SizedBox(height: 15),

            // PDF 출력 버튼 (콘텐츠 영역 최상단)
            _buildPdfOutputButton(),

            const SizedBox(height: 15),

            // PDF 양식 선택
            PdfSettingsSection(
              selectedTemplateIndex: _selectedTemplateIndex,
              selectedTemplateFilePath: _selectedTemplateFilePath,
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
                AppLogger.info(
                  '사용자 정의 PDF 파일 선택: $path (메모리에만 저장, 디스크 저장은 문서 출력 시)',
                );
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

            const SizedBox(height: 15),

            // 폰트 설정 (추가 필드 입력 아래)
            PdfFontSettingsSection(
              fontSize: _fontSize,
              remarksFontSize: _remarksFontSize,
              selectedFont: _selectedFont,
              includeRemarks: _includeRemarks,
              fontSizeOptions: _fontSizeOptions,
              remarksFontSizeOptions: _remarksFontSizeOptions,
              onFontSizeChanged: (size) {
                setState(() => _fontSize = size);
              },
              onRemarksFontSizeChanged: (size) {
                setState(() => _remarksFontSize = size);
              },
              onFontChanged: (font) {
                setState(() => _selectedFont = font);
              },
              onIncludeRemarksChanged: (include) {
                setState(() => _includeRemarks = include);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 교사별 계획서(인쇄 프로파일) 선택 바
  ///
  /// 교사 드롭다운: 현재 시간표의 교사 목록
  /// 계획서 드롭다운: 선택 교사의 계획서 목록 (미지정 = 레거시 양식 설정)
  Widget _buildProfileBar() {
    final tokens = context.tokens;
    final store = ref.watch(printProfileStoreProvider);
    final teachers = _availableTeachers();
    final teacher = _selectedTeacher;
    final profiles = teacher != null ? store.byTeacher(teacher) : <PrintProfile>[];
    final selectedProfile = store.getById(_selectedProfileId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1행: 교사 선택
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: tokens.textSecondary),
              const SizedBox(width: 6),
              const Text('교사', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: teacher,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('교사 선택', style: TextStyle(fontSize: 13)),
                  items: teachers
                      .map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onTeacherChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 2행: 계획서 선택 + 관리 버튼
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: tokens.textSecondary,
              ),
              const SizedBox(width: 6),
              const Text('계획서', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedProfile?.id,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('미지정 (양식 설정 사용)', style: TextStyle(fontSize: 13)),
                  items: profiles
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            p.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onProfileChanged,
                ),
              ),
              IconButton(
                onPressed: _createProfile,
                tooltip: '새로 만들기',
                icon: const Icon(Icons.add, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed:
                    selectedProfile != null ? _renameSelectedProfile : null,
                tooltip: '이름 변경',
                icon: const Icon(Icons.edit_outlined, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed:
                    selectedProfile != null ? _deleteSelectedProfile : null,
                tooltip: '삭제',
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: selectedProfile != null ? Colors.red : null,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          // 3행: 계획서가 없는 교사 안내 / 저장 버튼
          if (teacher != null && profiles.isEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "'$teacher'의 계획서가 없습니다. [새로 만들기]로 생성하세요.",
                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
                  ),
                ),
              ],
            ),
          ] else if (selectedProfile != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saveToSelectedProfile,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  "이 계획서에 저장 ('${selectedProfile.name}')",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// PDF 출력 버튼 (문서 출력 탭 툴바와 동일 높이·아이콘 크기)
  Widget _buildPdfOutputButton() {
    final accentColor = Colors.purple;
    return SizedBox(
      width: double.infinity,
      child: CompactToolbarLabelButton(
        onPressed: _handlePreview,
        icon: Icons.print,
        label: 'PDF 미리보기, 인쇄',
        tooltip: 'PDF 미리보기, 인쇄',
        backgroundColor: accentColor.shade50,
        foregroundColor: accentColor.shade600,
        borderColor: accentColor.shade600,
        width: double.infinity,
        height: ContentToolbarLayout.buttonHeight,
        fontSize: ContentToolbarLayout.buttonFontSize,
        iconSize: ContentToolbarLayout.buttonIconSize,
      ),
    );
  }

  /// 출력 미리 보기 처리
  Future<void> _handlePreview() async {
    if (!mounted) return;

    try {
      // 1. 데이터 수집 (비어 있어도 템플릿·입력란 기준으로 미리보기 가능)
      final planData = ref.read(substitutionPlanViewModelProvider).planData;

      // 2. 임시 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}preview_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 3. PDF 생성
      final String templatePath =
          _selectedTemplateFilePath ??
          kPdfTemplates[_selectedTemplateIndex].assetPath;
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
        _showSnackBar('PDF 미리보기 생성 실패', Colors.red);
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
