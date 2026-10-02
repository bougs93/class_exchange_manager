import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../constants/screen_usage_hints.dart';
import '../../../../../models/plan_output_menu.dart';
import '../../../../../models/print_profile.dart';
import '../../../../../models/timetable_registry.dart';
import '../../../../../providers/default_school_name_provider.dart';
import '../../../../../providers/exchange_screen_provider.dart';
import '../../../../../providers/plan_output_menu_provider.dart';
import '../../../../../providers/print_profile_provider.dart';
import '../../../../../providers/services_provider.dart';
import '../../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../../providers/timetable_registry_provider.dart';
import '../../../../../services/substitution_backup_service.dart';
import '../../../../../theme/design_tokens.dart';
import '../../../../../utils/dialog_helper.dart';
import '../../../../widgets/content_toolbar_layout.dart';
import '../../../../widgets/content_usage_hint_bar.dart';
import '../../../../widgets/timetable_grid/exchange_executor.dart';
import '../../../../widgets/timetable_grid/grid_header_widgets.dart';
import '../../../../../utils/pdf_field_config.dart';
import '../../../../../utils/date_format_utils.dart';
import '../../../../../services/pdf_export_service.dart';
import '../../../../../services/pdf_export_settings_storage_service.dart';
import '../../../../../constants/korean_fonts.dart';
import '../../../../../constants/pdf_notes_template.dart';
import '../../../../../utils/logger.dart';
import '../../../../../utils/snackbar_helper.dart';
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
  String _selectedFont = KoreanFontConstants.platformDefaultFont;
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

  /// 계획서 설정에 반영되는 입력 컨트롤러 목록 (자동 저장 감지용)
  List<TextEditingController> get _profileFieldControllers => [
    _teacherNameController,
    _absencePeriodController,
    _workStatusController,
    _reasonForAbsenceController,
    _schoolNameController,
    _notesController,
  ];

  /// 자동 저장 디바운스 타이머 (입력 종료 후 1초 뒤 저장)
  Timer? _autoSaveTimer;

  /// 프로그래밍 방식 입력값 적용 중에는 자동 저장을 걸지 않음
  ///
  /// [_applyProfileToUi]처럼 계획서 값을 화면에 채우는 과정에서
  /// 컨트롤러 리스너가 연쇄 발동해 불필요한 저장이 일어나지 않도록 막는다.
  bool _autoSaveSuspended = false;

  /// 설정 변경 시 자동 저장 예약 (디바운스)
  void _scheduleAutoSave() {
    if (_autoSaveSuspended || !mounted) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      _saveCurrentSettings();
    });
  }

  /// 예약된 자동 저장을 즉시 실행 (교사·계획서 전환 전에 호출)
  Future<void> _flushAutoSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    if (!mounted) return;
    await _saveCurrentSettings();
  }

  /// 준비 화면 교사 변경 구독 (build의 ref.listen은 재빌드 타이밍에 끊길 수 있음)
  ProviderSubscription<String>? _prepareTeacherSubscription;

  @override
  void initState() {
    super.initState();
    AppLogger.info('📄 [결강기간] SubstitutionOutputWidget 초기화');

    // 결강기간 필드 변경 감지 (사용자가 직접 수정한 경우 플래그 설정)
    _absencePeriodController.addListener(_onAbsencePeriodChanged);

    // 입력값이 바뀌면 자동 저장 예약 (디바운스 1초)
    for (final controller in _profileFieldControllers) {
      controller.addListener(_scheduleAutoSave);
    }

    // 준비 > 교사 변경을 위젯이 살아 있는 동안 항상 구독
    // (계획서 탭이 IndexedStack에 남아 있어도 build가 안 돌면 listen이 놓칠 수 있음)
    _prepareTeacherSubscription = ref.listenManual<String>(
      activeTeacherNameProvider,
      (previous, next) {
        final teacher = next.trim();
        if (teacher.isEmpty) return;
        if (teacher == previous?.trim()) return;
        AppLogger.info('준비 화면 교사 변경 감지 → 결보강 출력 즉시 동기화: $teacher');
        _syncTeacherFromPrepare(teacher);
      },
    );

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
    _prepareTeacherSubscription?.close();
    _prepareTeacherSubscription = null;

    // 예약된 자동 저장이 있으면 즉시 실행 후 종료
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    // 프로그램 종료 시 현재 양식의 설정 저장
    _saveCurrentSettings();

    // 프로그램 종료 시 마지막 선택된 양식 인덱스 저장
    _pdfSettingsStorage.saveLastSelectedTemplateIndex(_selectedTemplateIndex);

    // Controller 정리
    for (final controller in _profileFieldControllers) {
      controller.removeListener(_scheduleAutoSave);
    }
    _teacherNameController.dispose();
    _absencePeriodController.dispose();
    _workStatusController.dispose();
    _reasonForAbsenceController.dispose();
    _schoolNameController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  /// 준비 화면의 현재 교사를 결보강 출력(교사 드롭다운 + 결강교사)에 반영
  ///
  /// 메뉴/탭 재진입 시 호출합니다. listen이 놓친 변경도 여기서 맞춥니다.
  bool _isSyncingFromPrepare = false;

  Future<void> syncPreferredTeacherFromPrepare() async {
    if (!mounted || _isSyncingFromPrepare) return;
    _isSyncingFromPrepare = true;
    try {
      final teachers = _availableTeachers();
      final preferred = _resolvePreferredTeacher(teachers);
      if (preferred == null || preferred.isEmpty) return;

      // 이미 같은 교사·계획서가 선택돼 있으면 저장/리빌드 유발 작업 생략
      final store = ref.read(printProfileStoreProvider);
      final hasProfileForTeacher = store.byTeacher(preferred).isNotEmpty;
      if (_selectedTeacher == preferred &&
          _selectedProfileId != null &&
          hasProfileForTeacher) {
        return;
      }

      await _attachOrphanProfilesToTeacher(preferred);
      if (!mounted) return;

      AppLogger.info('결보강 출력 진입 → 준비 교사 강제 동기화: $preferred');
      await _syncTeacherFromPrepare(preferred);
    } finally {
      _isSyncingFromPrepare = false;
    }
  }

  /// 현재 설정을 디스크에 저장
  ///
  /// 계획서가 선택된 경우 해당 계획서에 저장하고,
  /// 미지정인 경우 레거시 양식별 설정에 저장합니다.
  /// 입력 변경 시 디바운스 자동 저장, 교사·계획서 전환 시,
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
            .read(checkedSubstitutionPlanDataProvider)
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
    // 내용 수정에서 체크된 건만 결강기간에 반영
    final planData = ref.read(checkedSubstitutionPlanDataProvider);
    _updateAbsencePeriod(planData);
  }

  /// 결강기간 자동 계산 및 업데이트 (내부 메서드)
  void _updateAbsencePeriod(List<SubstitutionPlanData> planData) {
    // 사용자가 수동으로 수정한 경우 자동 업데이트하지 않음
    if (_absencePeriodMode == AbsencePeriodUpdateMode.manualOverride) {
      return;
    }

    final absenceDates = planData.map((data) => data.absenceDate).toList();
    final absencePeriod = DateFormatUtils.calculateAbsencePeriod(absenceDates);

    // Controller 값이 다를 때만 업데이트 (무한 루프 방지)
    if (_absencePeriodController.text != absencePeriod) {
      _absencePeriodMode = AbsencePeriodUpdateMode.updating;
      _absencePeriodController.text = absencePeriod;
      AppLogger.exchangeDebug('결강기간 자동 업데이트: "$absencePeriod"');

      if (mounted) {
        setState(() {});
      }

      _absencePeriodMode = AbsencePeriodUpdateMode.autoUpdate;
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
      String newSelectedFont = KoreanFontConstants.platformDefaultFont;
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
            KoreanFontConstants.platformFontListWithNames
                .map((font) => font['file']!)
                .toList();
        // 저장된 폰트가 유효한 목록에 있는지 확인하고, 없으면 기본 폰트 사용
        newSelectedFont =
            (savedFont != null && availableFonts.contains(savedFont))
                ? savedFont
                : KoreanFontConstants.platformDefaultFont;
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
            KoreanFontConstants.platformFontListWithNames
                .map((font) => font['file']!)
                .toList();
        newSelectedFont =
            (defaultFont != null && availableFonts.contains(defaultFont))
                ? defaultFont
                : KoreanFontConstants.platformDefaultFont;
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

  /// 활성 시간표의 교사명·학교명으로 입력란 채우기 (비어있을 때만)
  ///
  /// 교사명·학교명은 전역 설정이 아니라 활성 시간표의 속성입니다(문서 §2).
  /// 사용자가 매번 타이핑하지 않도록 비어 있는 칸만 자동으로 채웁니다.
  ///
  /// 학교명은 2단계로 찾는다: ① 시간표에 지정된 학교명 ② (그것도 없으면)
  /// 관리자가 접속 설정에서 지정한 기본 학교명(2026-10-02 요청, 웹 전용).
  /// 어느 쪽이든 "추천값"일 뿐이라 교사가 입력하면 그 값이 유지된다.
  ///
  /// 외부에서 호출 가능한 public 메서드입니다.
  /// 결보강 문서 탭 클릭 시 호출됩니다.
  Future<void> loadDefaultValuesIfEmpty() async {
    try {
      final entry = ref.read(activeTimetableEntryProvider);

      // 시간표에 학교명이 없을 때만 필요하므로, 그 경우에만 기다린다.
      final needsAdminDefault =
          _schoolNameController.text.trim().isEmpty &&
          (entry?.schoolName?.trim().isEmpty ?? true);
      final adminDefaultSchoolName =
          needsAdminDefault
              ? await ref.read(defaultSchoolNameProvider.future)
              : '';

      if (!mounted) return;
      setState(() {
        // 결강교사 입력란이 비어있으면 시간표에 지정된 교사로 채우기
        if (_teacherNameController.text.trim().isEmpty) {
          final teacherName = entry?.teacherName?.trim() ?? '';
          if (teacherName.isNotEmpty) {
            _teacherNameController.text = teacherName;
            AppLogger.info('시간표 설정에서 교사명 자동 입력: $teacherName');
          }
        }

        // 학교명 입력란이 비어있으면 시간표 → 관리자 기본값 순으로 채우기
        if (_schoolNameController.text.trim().isEmpty) {
          final schoolName = entry?.schoolName?.trim() ?? '';
          if (schoolName.isNotEmpty) {
            _schoolNameController.text = schoolName;
            AppLogger.info('시간표 설정에서 학교명 자동 입력: $schoolName');
          } else if (adminDefaultSchoolName.isNotEmpty) {
            _schoolNameController.text = adminDefaultSchoolName;
            AppLogger.info('관리자 기본값에서 학교명 자동 입력: $adminDefaultSchoolName');
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
  ///
  /// build 외부에서도 호출되므로 read를 사용합니다.
  /// build에서의 갱신 반응성은 build의 select watch가 담당합니다.
  List<String> _availableTeachers() {
    final teachers = ref.read(exchangeScreenProvider).timetableData?.teachers;
    if (teachers == null) return const [];
    // 준비 화면(activeTimetableTeachersProvider)과 동일하게 trim 후 비교
    final names =
        teachers
            .map((t) => t.name.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  /// 결보강 출력 '교사' 드롭다운의 초기/우선 교사
  ///
  /// 우선순위:
  /// 1. 준비 화면(활성 시간표)에서 고른 교사
  /// 2. 계획서에서 마지막으로 고른 교사
  /// 3. 시간표 교사 목록의 첫 번째
  String? _resolvePreferredTeacher(List<String> teachers) {
    if (teachers.isEmpty) return null;

    // 준비 > 교사 선택이 단일 출처 (activeTeacherNameProvider)
    final prepared =
        ref.read(activeTimetableEntryProvider)?.teacherName?.trim() ?? '';
    if (prepared.isNotEmpty && teachers.contains(prepared)) {
      return prepared;
    }

    final last = ref.read(printProfileStoreProvider).lastSelectedTeacher;
    if (last != null && teachers.contains(last)) {
      return last;
    }

    return teachers.first;
  }

  /// 계획서 선택 흐름 초기화
  ///
  /// 스토어 로드 → 교사 목록 로드 대기 → 준비 화면 교사 우선 복원 → 설정 로드.
  /// 계획서가 없으면 레거시 양식 설정 흐름으로 폴백합니다.
  ///
  /// 재진입 가드: 초기화 대기 중 시간표가 다시 전환되면 이전 흐름을 중단시킵니다.
  int _profileFlowRunId = 0;

  Future<void> _initializeProfileFlow() async {
    final runId = ++_profileFlowRunId;
    bool isStale() => !mounted || runId != _profileFlowRunId;

    await ref.read(printProfileStoreProvider.notifier).ensureLoaded();
    if (isStale()) return;

    // 교사 목록은 시간표 데이터 로드 후 채워집니다 (시작·전환 직후에는 비어 있을 수
    // 있음). 최대 3초까지 대기해 올바른 교사를 복원합니다.
    for (var i = 0; i < 30 && mounted; i++) {
      if (_availableTeachers().isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (isStale()) return;

    final store = ref.read(printProfileStoreProvider);
    final teachers = _availableTeachers();

    // 준비 화면에서 고른 교사(예: 정원길)를 우선 선택
    final teacher = _resolvePreferredTeacher(teachers);
    _selectedTeacher = teacher;

    // 준비 화면 교사와 계획서 lastSelectedTeacher를 맞춰 둔다
    if (teacher != null && store.lastSelectedTeacher != teacher) {
      await ref
          .read(printProfileStoreProvider.notifier)
          .setLastSelectedTeacher(teacher);
    }

    // 내용 수정에서 만든 계획서가 다른/빈 교사명으로 저장된 경우
    // 현재 준비 교사에게 편입해 목록에 보이게 한다
    if (teacher != null) {
      await _attachOrphanProfilesToTeacher(teacher);
    }
    if (isStale()) return;

    final updatedStore = ref.read(printProfileStoreProvider);
    final profiles =
        teacher != null ? updatedStore.byTeacher(teacher) : <PrintProfile>[];
    if (profiles.isNotEmpty) {
      final lastUsed = updatedStore.getById(updatedStore.lastUsedProfileId);
      // lastUsed가 이 교사 소속이면 우선, 아니면 목록 첫 번째
      final selected =
          (lastUsed != null && profiles.any((p) => p.id == lastUsed.id))
              ? lastUsed
              : profiles.first;
      _selectedProfileId = selected.id;
      _applyProfileToUi(selected);
      // 결강교사 = 준비 화면(또는 선택) 교사로 맞춤
      if (mounted && teacher != null) {
        _autoSaveSuspended = true;
        _teacherNameController.text = teacher;
        _autoSaveSuspended = false;
        setState(() {});
      }
      AppLogger.info("계획서 복원: 교사=$teacher, 계획서='${selected.name}'");
    } else {
      // 선택 교사의 계획서가 없으면 미지정 → 레거시 양식 설정 로드
      _selectedProfileId = null;
      await _loadLastSelectedTemplateIndex();
      // 결강교사 입력란도 준비 화면 교사로 채움
      if (mounted && teacher != null) {
        setState(() => _teacherNameController.text = teacher);
      } else {
        await loadDefaultValuesIfEmpty();
      }
    }
  }

  /// 내용 수정에서 만든 계획서를 현재 준비 교사에게 편입
  ///
  /// byTeacher(준비교사)가 비어 있을 때만:
  /// - 교사명이 비어 있는 계획서
  /// - 마지막 사용 계획서(교사명이 다른 경우)
  ///
  /// 주의: 전체 계획서를 일괄 재지정하지 않습니다(앱 멈춤·데이터 혼선 원인).
  bool _isAttachingOrphans = false;

  Future<void> _attachOrphanProfilesToTeacher(String teacher) async {
    if (_isAttachingOrphans) return;
    _isAttachingOrphans = true;
    try {
      final store = ref.read(printProfileStoreProvider);
      if (store.byTeacher(teacher).isNotEmpty) return;
      if (store.profiles.isEmpty) return;

      final toFixIds = <String>{};

      for (final p in store.profiles) {
        if (p.teacherName.trim().isEmpty) {
          toFixIds.add(p.id);
        }
      }

      final lastUsed = store.getById(store.lastUsedProfileId);
      if (lastUsed != null && lastUsed.teacherName.trim() != teacher) {
        toFixIds.add(lastUsed.id);
      }

      if (toFixIds.isEmpty) return;

      final ok = await ref
          .read(printProfileStoreProvider.notifier)
          .reassignTeacherBulk(toFixIds, teacher);
      if (ok) {
        AppLogger.info('계획서 ${toFixIds.length}개를 준비 교사 "$teacher"에게 편입(배치)');
      }
    } finally {
      _isAttachingOrphans = false;
    }
  }

  /// 활성 시간표 전환 후 재초기화
  ///
  /// 교사 목록 대기는 [_initializeProfileFlow]의 폴링이 담당합니다.
  Future<void> _reinitAfterTimetableSwitch() async {
    if (!mounted) return;
    _selectedTeacher = null;
    _selectedProfileId = null;
    await _initializeProfileFlow();
  }

  /// 계획서 설정 → 화면 UI 적용
  void _applyProfileToUi(PrintProfile profile) {
    if (!mounted) return;

    // 폰트 유효성 검사
    final availableFonts =
        KoreanFontConstants.platformFontListWithNames
            .map((font) => font['file']!)
            .toList();
    final font =
        availableFonts.contains(profile.selectedFont)
            ? profile.selectedFont
            : KoreanFontConstants.platformDefaultFont;

    // 템플릿 파일 경로 유효성 검사
    String? templatePath = profile.selectedTemplateFilePath;
    if (templatePath != null && !File(templatePath).existsSync()) {
      AppLogger.warning('계획서의 PDF 템플릿 파일이 없어 경로를 초기화: $templatePath');
      templatePath = null;
    }

    final defaultNotes =
        profile.additionalFields['notes'] ?? PdfNotesTemplate.defaultNotes;

    // 계획서 값을 화면에 채우는 동안 자동 저장을 걸지 않음
    _autoSaveSuspended = true;
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
      _workStatusController.text = profile.additionalFields['workStatus'] ?? '';
      _reasonForAbsenceController.text =
          profile.additionalFields['reasonForAbsence'] ?? '';
      _schoolNameController.text = profile.additionalFields['schoolName'] ?? '';
      _notesController.text = defaultNotes;
    });
    _autoSaveSuspended = false;
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

    // 전환 전 대기 중인 자동 저장을 먼저 실행 (입력 내용 유실 방지)
    await _flushAutoSave();
    if (!mounted) return;

    await _applyTeacherSelection(teacher, syncAbsenceTeacherField: true);
  }

  /// 준비 화면에서 교사가 바뀌었을 때 — 확인 없이 즉시 동기화
  ///
  /// - 상단 '교사' 드롭다운
  /// - 추가 필드 입력 > 결강교사
  Future<void> _syncTeacherFromPrepare(String teacher) async {
    if (!mounted) return;

    final trimmed = teacher.trim();
    if (trimmed.isEmpty) return;

    // 교사 목록이 아직 없으면 드롭다운 value 오류를 피하기 위해 대기 후 재시도
    final teachers = _availableTeachers();
    if (teachers.isNotEmpty && !teachers.contains(trimmed)) {
      AppLogger.warning('준비 교사 "$trimmed"가 시간표 교사 목록에 없어 동기화 생략');
      return;
    }

    if (trimmed == _selectedTeacher &&
        _teacherNameController.text.trim() == trimmed) {
      // 교사명은 같아도, 방금 편입된 계획서가 있을 수 있어 선택만 보강
      final profiles = ref.read(printProfileStoreProvider).byTeacher(trimmed);
      if (_selectedProfileId == null && profiles.isNotEmpty) {
        await _applyTeacherSelection(trimmed, syncAbsenceTeacherField: true);
      } else if (_selectedProfileId != null) {
        // 목록 UI 갱신
        if (mounted) setState(() {});
      }
      return;
    }

    AppLogger.info('준비→결보강 출력 교사 즉시 동기화: $trimmed');
    await _applyTeacherSelection(trimmed, syncAbsenceTeacherField: true);
  }

  /// 교사 선택 적용 (드롭다운 + 해당 교사 계획서 + 선택 시 결강교사 필드)
  Future<void> _applyTeacherSelection(
    String teacher, {
    required bool syncAbsenceTeacherField,
  }) async {
    // 대기 중인 자동 저장을 먼저 실행 (이전 계획서의 입력 내용 유실 방지)
    await _flushAutoSave();
    if (!mounted) return;

    final store = ref.read(printProfileStoreProvider);
    final profiles = store.byTeacher(teacher);
    // 내용 수정에서 쓰던 마지막 계획서를 우선 선택
    final lastUsed = store.getById(store.lastUsedProfileId);
    final preferred =
        (lastUsed != null && profiles.any((p) => p.id == lastUsed.id))
            ? lastUsed
            : (profiles.isNotEmpty ? profiles.first : null);

    setState(() {
      _selectedTeacher = teacher;
      _selectedProfileId = preferred?.id;
      if (syncAbsenceTeacherField) {
        // 추가 필드 입력 > 결강교사
        _teacherNameController.text = teacher;
      }
    });

    // 이미 같은 교사면 디스크 저장을 건너뛰어 UI 멈춤 방지
    if (store.lastSelectedTeacher != teacher) {
      await ref
          .read(printProfileStoreProvider.notifier)
          .setLastSelectedTeacher(teacher);
    }

    // 대기 중 다른 교사로 전환되었으면 이전 교사의 계획서를 적용하지 않음
    if (!mounted || _selectedTeacher != teacher) return;

    if (preferred != null) {
      _applyProfileToUi(preferred);
      // 계획서 additionalFields의 옛 결강교사가 덮어쓸 수 있으므로 항상 재적용
      if (syncAbsenceTeacherField) {
        setState(() => _teacherNameController.text = teacher);
        // 동기화로 맞춘 결강교사 값도 자동 저장되도록 예약
        _scheduleAutoSave();
      }
    } else {
      // 계획서가 없는 교사: 미지정 → 레거시 양식 설정 로드
      await _loadSavedSettings();
      // 레거시 설정의 옛 교사명이 덮어쓰므로 동기화 시 항상 재적용
      if (mounted && syncAbsenceTeacherField) {
        setState(() => _teacherNameController.text = teacher);
      }
    }
  }

  /// 계획서 전환: 해당 계획서의 설정을 화면에 적용
  ///
  /// [profileId]가 null이면 '미지정'(레거시 양식 설정)으로 되돌립니다.
  Future<void> _onProfileChanged(String? profileId) async {
    if (profileId == _selectedProfileId) return;

    // 전환 전 대기 중인 자동 저장을 먼저 실행 (입력 내용 유실 방지)
    await _flushAutoSave();
    if (!mounted) return;

    final store = ref.read(printProfileStoreProvider);
    final profile = store.getById(profileId);

    setState(() => _selectedProfileId = profile?.id);

    if (profile != null) {
      _applyProfileToUi(profile);
      await ref
          .read(printProfileStoreProvider.notifier)
          .setLastUsedProfile(profile.id);
    } else {
      // 미지정: 양식 설정 흐름으로 되돌린다
      await _loadSavedSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 활성 시간표 전환 감지 → 계획서 바 재초기화
    ref.listen<TimetableRegistryEntry?>(activeTimetableEntryProvider, (
      previous,
      next,
    ) {
      if (previous != null && next != null && previous.id != next.id) {
        AppLogger.info('활성 시간표 전환 감지 → 계획서 바 재초기화');
        _reinitAfterTimetableSwitch();
      }
    });

    // 준비 교사명이 바뀌면 이 화면도 다시 그려 드롭다운이 최신 값을 반영
    ref.watch(activeTeacherNameProvider);

    // 관리자가 기본 학교명을 바꾸면(실시간 구독) 비어 있는 학교명 칸에
    // 바로 반영한다. 예전에는 "결보강 출력" 탭을 새로 클릭할 때만
    // `loadDefaultValuesIfEmpty()`가 돌아서, 이미 그 탭에 머물러 있던
    // 화면이나 관리자와는 다른 탭에서 연 화면에는 반영되지 않았다
    // (2026-10-02 실제 보고). 값이 처음 도착할 때도 호출되므로, 탭을 한
    // 번도 새로 누르지 않은 화면도 채워진다.
    ref.listen<AsyncValue<String>>(defaultSchoolNameProvider, (
      previous,
      next,
    ) {
      final value = next.valueOrNull;
      if (value == null || value.isEmpty) return;
      if (previous?.valueOrNull == value) return;
      loadDefaultValuesIfEmpty();
    });

    // 체크 선택(제외 목록)이 바뀔 때만 결강기간 재계산
    ref.listen<(String?, List<String>)>(
      printProfileStoreProvider.select((store) {
        final id = store.lastUsedProfileId;
        final deselected =
            store.getById(id)?.deselectedGroupIds ?? const <String>[];
        return (id, deselected);
      }),
      (previous, next) {
        if (previous == next) return;
        updateAbsencePeriod();
      },
    );

    // 시간표 데이터 변경 감지 → 교사 드롭다운 갱신 (select로 재빌드 최소화)
    ref.watch(exchangeScreenProvider.select((state) => state.timetableData));

    // 다른 화면(내용 수정)에서 지금 선택 중인 계획서를 삭제한 경우 —
    // 드롭다운 표시는 store.getById가 null을 반환해 이미 안전하게
    // "미지정"으로 보이지만, _selectedProfileId 필드 자체는 그대로 남아
    // PDF 출력 가능 여부(canPrint) 판정이 죽은 ID를 기준으로 계속 true가
    // 되는 문제가 있었다 — 여기서 직접 정리한다.
    ref.listen<PrintProfileStore>(printProfileStoreProvider, (previous, next) {
      if (_selectedProfileId != null &&
          next.getById(_selectedProfileId) == null) {
        setState(() => _selectedProfileId = null);
        _loadSavedSettings();
      }
    });

    // build는 PlanOutputScreen의 TabController 리스너에서 호출되는 updateAbsencePeriod()로 처리
    // 여기서는 UI만 렌더링

    // SingleChildScrollView로 감싸서 작은 창에서 스크롤 가능하도록 함
    return Container(
      width: double.infinity,
      // 내용 수정(ContentInputGrid) 등 다른 문서 탭과 동일한 16px 여백
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

            // 교사별 계획서(인쇄 프로파일) 선택 + 출력·백업 동작
            _buildProfileBar(),

            const SizedBox(height: 15),

            // 출력·백업 동작 행 (PDF가 주 동작, 백업은 부 동작)
            _buildOutputActionsRow(),

            const SizedBox(height: 15),

            // PDF 양식 선택
            PdfSettingsSection(
              selectedTemplateIndex: _selectedTemplateIndex,
              selectedTemplateFilePath: _selectedTemplateFilePath,
              onTemplateIndexChanged: (index) async {
                // 양식 변경 시: 현재 설정을 저장한 뒤 양식 인덱스만 갱신한다.

                // 현재 설정 저장 (계획서 선택 중이면 계획서에, 미지정이면 레거시 양식에)
                await _saveCurrentSettings();

                // 양식 인덱스 업데이트
                setState(() {
                  _selectedTemplateIndex = index;
                });
                // 변경된 양식도 자동 저장
                _scheduleAutoSave();

                // 마지막 선택된 양식 인덱스 저장
                await _pdfSettingsStorage.saveLastSelectedTemplateIndex(index);

                if (ref
                        .read(printProfileStoreProvider)
                        .getById(_selectedProfileId) !=
                    null) {
                  // 계획서 선택 중: 다른 설정(폰트·비고·입력값)은 계획서 것을
                  // 유지하고 양식만 메모리에서 변경한다. 레거시 양식 설정을
                  // 로드하면 계획서 값이 덮어써지므로 로드하지 않는다.
                  AppLogger.info('양식 변경: 양식 ${index + 1} (계획서 선택 중, 설정 유지)');
                  return;
                }

                // 미지정: 새 양식의 레거시 설정 로드 (디스크 → 메모리)
                // _loadSavedSettings 내부에서 setState를 호출하여 모든 메모리 변수와 Controller 값을 업데이트함
                await _loadSavedSettings(templateIndex: index);

                AppLogger.info('양식 변경: 양식 ${index + 1} 선택됨, 설정 로드 완료');
              },
              onTemplateFilePathChanged: (path) async {
                // PDF 파일 경로는 메모리 변수만 업데이트 후 자동 저장
                setState(() => _selectedTemplateFilePath = path);
                _scheduleAutoSave();
                AppLogger.info('사용자 정의 PDF 파일 선택: $path');
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
                _scheduleAutoSave();
              },
              onRemarksFontSizeChanged: (size) {
                setState(() => _remarksFontSize = size);
                _scheduleAutoSave();
              },
              onFontChanged: (font) {
                setState(() => _selectedFont = font);
                _scheduleAutoSave();
              },
              onIncludeRemarksChanged: (include) {
                setState(() => _includeRemarks = include);
                _scheduleAutoSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 출력·백업 동작 행 (A안)
  ///
  /// [PDF 미리보기, 인쇄]가 주 동작, 백업 내보내기/가져오기는 선택한 계획서
  /// 1건에 대한 부 동작이다. 좁은 화면에서는 2행으로 나뉜다.
  Widget _buildOutputActionsRow() {
    final canDo = _selectedProfileId != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pdfButton = _buildPdfOutputButton();
        // 내보내기는 계획서 선택 필요, 가져오기는 선택 없이 가능
        final backupActions = _buildBackupActions(
          canExport: canDo,
          canImport: true,
        );
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              Expanded(flex: 3, child: pdfButton),
              const SizedBox(width: 24),
              backupActions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pdfButton,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: backupActions),
          ],
        );
      },
    );
  }

  /// 선택한 계획서 1건의 백업 동작 (내보내기/가져오기)
  ///
  /// 같은 시간표를 여러 PC에서 쓸 때, 선택한 계획서와 그 계획서의 결보강
  /// 내역을 파일로 주고받아 복원할 수 있게 한다. 자세한 검증 규칙은
  /// [SubstitutionBackupService] 참고.
  Widget _buildBackupActions({
    required bool canExport,
    required bool canImport,
  }) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('백업', style: TextStyle(fontSize: 12, color: tokens.textMuted)),
        const SizedBox(width: 6),
        CompactToolbarLabelButton(
          onPressed: canExport ? _handleExportBackup : null,
          icon: Icons.upload_outlined,
          label: '내보내기',
          tooltip:
              canExport
                  ? '선택한 계획서 1건을 파일로 저장 (다른 PC로 옮길 때 사용)'
                  : '계획서를 선택한 뒤에만 내보낼 수 있습니다',
          backgroundColor: ContentToolbarLayout.neutralButtonBackground(tokens),
          foregroundColor: ContentToolbarLayout.neutralButtonForeground(tokens),
          borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
          height: ContentToolbarLayout.buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
        const SizedBox(width: ContentToolbarLayout.buttonGap),
        CompactToolbarLabelButton(
          onPressed: canImport ? _handleImportBackup : null,
          icon: Icons.download_outlined,
          label: '가져오기',
          tooltip: '백업 파일에서 복원합니다 (계획서 미선택 시 새 계획서로 복원)',
          backgroundColor: ContentToolbarLayout.neutralButtonBackground(tokens),
          foregroundColor: ContentToolbarLayout.neutralButtonForeground(tokens),
          borderColor: ContentToolbarLayout.neutralButtonBorder(tokens),
          height: ContentToolbarLayout.buttonHeight,
          fontSize: ContentToolbarLayout.buttonFontSize,
          iconSize: ContentToolbarLayout.buttonIconSize,
        ),
      ],
    );
  }

  /// 파일명 기본값: "<계획서명>_YYYYMMDD_결보강백업"
  String _buildBackupFileName(String? profileName) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final name =
        (profileName == null || profileName.trim().isEmpty)
            ? '결보강백업'
            : profileName.trim();
    return '${name}_${stamp}_결보강백업';
  }

  /// 선택한 계획서 1건(+그 계획서의 결보강 내역)을 파일로 내보낸다.
  Future<void> _handleExportBackup() async {
    final profileStore = ref.read(printProfileStoreProvider);
    final selected = profileStore.getById(_selectedProfileId);
    if (selected == null) {
      if (mounted) {
        SnackBarHelper.showInfo(context, '백업할 계획서를 먼저 선택하세요.');
      }
      return;
    }

    final historyService = ref.read(exchangeHistoryServiceProvider);
    final items =
        historyService
            .getExchangeList()
            .where((e) => e.profileId == selected.id)
            .toList();

    if (items.isEmpty) {
      if (mounted) {
        SnackBarHelper.showInfo(context, '내보낼 결보강 내역이 없습니다.');
      }
      return;
    }

    final activeEntry = ref.read(activeTimetableEntryProvider);

    final bundle = SubstitutionBackupBundle(
      timetableName: activeEntry?.name,
      teacherName: activeEntry?.teacherName,
      schoolName: activeEntry?.schoolName,
      exchangeItems: items,
      printProfiles: [selected],
    );
    final jsonString = const SubstitutionBackupService().encode(bundle);

    String? outputPath;
    try {
      outputPath = await FilePicker.saveFile(
        dialogTitle: '결보강 내보내기',
        fileName: _buildBackupFileName(selected.name),
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (e) {
      AppLogger.error('결보강 내역 저장 대화상자 실패: $e', e);
    }
    if (outputPath == null || outputPath.isEmpty) return;

    final path =
        outputPath.toLowerCase().endsWith('.json')
            ? outputPath
            : '$outputPath.json';

    try {
      await File(path).writeAsString(jsonString);
      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          "계획서 '${selected.name}' ${items.length}건을 내보냈습니다.",
        );
      }
    } catch (e) {
      AppLogger.error('결보강 내역 내보내기 실패: $e', e);
      if (mounted) {
        SnackBarHelper.showError(context, '내보내기에 실패했습니다: $e');
      }
    }
  }

  /// 백업 파일에서 가져온다.
  ///
  /// 계획서를 선택한 상태면: 가져온 교체 건을 현재 계획서에 귀속시키고, 파일
  /// 안의 계획서 설정(양식·폰트·입력값·체크 상태)도 현재 계획서에 덮어쓴다.
  /// 계획서의 id·이름·교사는 유지된다.
  ///
  /// 계획서 미선택 상태면: 파일 안의 계획서와 교체 건을 그대로 복원하고,
  /// 복원한 계획서를 바로 선택한 상태로 보여준다.
  ///
  /// 1차: 원본 칸 정보로 같은 시간표인지 확인 → 다르면 확인 후 진행.
  /// 2차: 날짜(결강일/교체일) 충돌 확인 → 겹치면 확인 후 처리.
  /// (선택 상태: 현재 계획서의 기존 내역을 지우고 교체 / 미선택 상태: 추가)
  Future<void> _handleImportBackup() async {
    final profileStore = ref.read(printProfileStoreProvider);
    final selected = profileStore.getById(_selectedProfileId);

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        dialogTitle: '결보강 가져오기',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      AppLogger.error('결보강 가져오기 대화상자 실패: $e', e);
    }
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    const backupService = SubstitutionBackupService();
    final SubstitutionBackupBundle bundle;
    try {
      final content = await File(path).readAsString();
      bundle = backupService.decode(content);
    } catch (e) {
      AppLogger.error('결보강 가져오기 실패(파일 읽기/형식): $e', e);
      if (mounted) {
        SnackBarHelper.showError(context, '올바른 결보강 백업 파일이 아닙니다.');
      }
      return;
    }

    if (bundle.exchangeItems.isEmpty) {
      if (mounted) {
        SnackBarHelper.showInfo(context, '가져올 결보강 내역이 없습니다.');
      }
      return;
    }

    final currentTimeSlots =
        ref.read(
          exchangeScreenProvider.select(
            (state) => state.timetableData?.timeSlots,
          ),
        ) ??
        const [];

    final matches = backupService.matchesCurrentTimetable(
      bundle.exchangeItems,
      currentTimeSlots,
    );
    if (!mounted) return;
    if (!matches) {
      final proceed = await _showBackupConfirmDialog(
        title: '다른 시간표일 수 있습니다',
        message:
            '가져올 파일의 교체 내역이 지금 이 시간표와 일치하지 않습니다'
            '(다른 시간표이거나, 그 사이 시간표가 바뀌었을 수 있습니다).\n\n'
            '그래도 가져오시겠습니까?',
        confirmLabel: '그래도 가져오기',
      );
      if (proceed != true) return;
    }

    // 가져온 교체 건을 현재 계획서에 귀속시킨다 (미선택 시 원본 귀속 유지)
    final String? selectedId = selected?.id;
    final String? selectedName = selected?.name;
    final retargeted =
        selectedId == null
            ? bundle.exchangeItems
            : bundle.exchangeItems
                .map((e) => e.copyWithProfileId(selectedId))
                .toList();

    final historyService = ref.read(exchangeHistoryServiceProvider);
    final existingItems =
        selectedId == null
            ? historyService.getExchangeList()
            : historyService
                .getExchangeList()
                .where((e) => e.profileId == selectedId)
                .toList();
    final hasConflict = backupService.hasDateConflict(
      retargeted,
      existingItems,
    );

    if (hasConflict) {
      if (!mounted) return;
      final proceed = await _showBackupConfirmDialog(
        title: '날짜가 겹칩니다',
        message:
            selectedName == null
                ? '가져올 결보강 내역이 기존 내역과 날짜가 겹칩니다.\n'
                    '계속하면 가져온 내용을 기존 내역 뒤에 추가합니다.\n\n'
                    '계속하시겠습니까?'
                : "가져올 결보강 내역이 계획서 '$selectedName'의 기존 내역과 "
                    '날짜가 겹칩니다.\n'
                    '계속하면 현재 계획서의 기존 내역을 모두 지우고 가져온 내용으로 교체합니다.\n\n'
                    '계속하시겠습니까?',
        confirmLabel: selectedName == null ? '추가하기' : '지우고 가져오기',
      );
      if (proceed != true) return;
      // 선택 상태의 충돌만 덮어쓰기로 처리한다 (미선택 추가는 항상 병합)
      if (selectedId != null) {
        historyService.removeExchangeItemsByProfile(selectedId);
      }
    }

    historyService.importExchangeItems(retargeted, overwrite: false);

    // 교체 화면 그리드의 "교체된 셀" 강조는 실행/삭제 시점에 명시적으로
    // 갱신해야 한다 — exchangeListVersionProvider 리스너는 데이터그리드
    // 다시 그리기만 트리거할 뿐 cellSelectionProvider는 건드리지 않는다
    // (교체 목록 초기화 때도 _deleteExchangeList가 이렇게 직접 호출한다).
    ExchangeExecutor.restoreExchangedCells(ref);

    if (selected != null) {
      // 파일 안의 계획서 설정을 현재 계획서에 덮어쓴다 (id·이름·교사는 유지)
      if (bundle.printProfiles.isNotEmpty) {
        final src = bundle.printProfiles.first;
        final updated = selected.copyWith(
          templateIndex: src.templateIndex,
          fontSize: src.fontSize,
          remarksFontSize: src.remarksFontSize,
          selectedFont: src.selectedFont,
          includeRemarks: src.includeRemarks,
          additionalFields: Map<String, String>.from(src.additionalFields),
          selectedTemplateFilePath: src.selectedTemplateFilePath,
          clearTemplateFilePath: src.selectedTemplateFilePath == null,
          deselectedGroupIds: List<String>.from(src.deselectedGroupIds),
        );
        await ref.read(printProfileStoreProvider.notifier).saveProfile(updated);
        if (mounted) {
          _applyProfileToUi(updated);
          updateAbsencePeriod();
        }
      }

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          hasConflict
              ? "계획서 '$selectedName'의 기존 내역을 지우고 가져왔습니다."
              : "계획서 '$selectedName'에 ${retargeted.length}건을 가져왔습니다.",
        );
      }
      return;
    }

    // 미선택 상태: 파일 안의 계획서를 그대로 복원하고 바로 선택한다
    if (bundle.printProfiles.isNotEmpty) {
      final profileNotifier = ref.read(printProfileStoreProvider.notifier);
      final currentStore = ref.read(printProfileStoreProvider);
      PrintProfile? firstRestored;
      for (final profile in bundle.printProfiles) {
        if (currentStore.getById(profile.id) == null) {
          await profileNotifier.saveProfile(profile);
          firstRestored ??= profile;
        }
      }

      final toSelect = firstRestored ?? bundle.printProfiles.first;
      if (mounted && _availableTeachers().contains(toSelect.teacherName)) {
        setState(() {
          _selectedTeacher = toSelect.teacherName;
          _selectedProfileId = toSelect.id;
        });
        _applyProfileToUi(toSelect);
        updateAbsencePeriod();
        await profileNotifier.setLastSelectedTeacher(toSelect.teacherName);
        await profileNotifier.setLastUsedProfile(toSelect.id);
      }
    }

    if (mounted) {
      SnackBarHelper.showSuccess(context, '${retargeted.length}건을 가져왔습니다.');
    }
  }

  /// 가져오기 중 사용자 확인이 필요한 경고 다이얼로그 (확인/취소)
  Future<bool?> _showBackupConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  }

  /// 현재 선택된 계획서만 삭제하는 버튼 (2026-09-30)
  ///
  /// 결보강 내역 전체 초기화는 내용 수정 화면에 이미 있다 — 여기는 "지금
  /// 보고 있는 계획서 1건만" 지우고 싶을 때 쓴다. 선택된 계획서가 없으면
  /// 비활성화된다.
  Widget _buildDeleteProfileButton(PrintProfile? selectedProfile) {
    return IconButton(
      onPressed:
          selectedProfile != null
              ? () => _deleteSelectedProfile(selectedProfile)
              : null,
      icon: const Icon(Icons.delete_outline, size: 18),
      tooltip: '선택한 계획서 삭제',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  /// 선택된 계획서 1건 삭제 (확인 후)
  Future<void> _deleteSelectedProfile(PrintProfile profile) async {
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: '계획서 삭제',
      message:
          "'${profile.name}' 계획서와 여기 연결된 결보강 내역(교체 기록)이 모두 삭제됩니다.\n"
          '이 작업은 되돌릴 수 없습니다. 삭제하시겠습니까?',
      confirmText: '삭제',
      isDangerous: true,
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final success = await ref
        .read(printProfileStoreProvider.notifier)
        .deleteProfile(profile.id);
    if (!mounted) return;

    if (success) {
      // 계획서는 특정 결보강 내역 묶음을 대표한다 — 계획서를 지우면 거기
      // 연결된 교체 건도 함께 지워야 "내용 수정"·교체 화면과 어긋나지 않는다.
      ref
          .read(exchangeHistoryServiceProvider)
          .removeExchangeItemsByProfile(profile.id);
      ExchangeExecutor.restoreExchangedCells(ref);

      setState(() => _selectedProfileId = null);
      await _loadSavedSettings();
      if (mounted) {
        SnackBarHelper.showSuccess(context, "'${profile.name}' 계획서를 삭제했습니다.");
      }
    } else {
      SnackBarHelper.showError(context, '계획서 삭제에 실패했습니다.');
    }
  }

  /// 교사·계획서 선택 바
  ///
  /// 결보강 출력은 내용 수정에서 만든 계획서를 **선택·출력만** 합니다.
  /// 새로 만들기/이름 변경/삭제는 내용 수정 화면에서 합니다.
  ///
  /// 화면이 넓으면 교사·계획서를 1행에, 좁으면 2행에 배치한다.
  Widget _buildProfileBar() {
    final tokens = context.tokens;
    final store = ref.watch(printProfileStoreProvider);
    final teachers = _availableTeachers();
    final teacher = _selectedTeacher;
    final profiles =
        teacher != null ? store.byTeacher(teacher) : <PrintProfile>[];
    final selectedProfile = store.getById(_selectedProfileId);

    // 드롭다운 value는 items에 있어야 함 (미지정 null 항목 제거)
    final dropdownValue =
        selectedProfile != null &&
                profiles.any((p) => p.id == selectedProfile.id)
            ? selectedProfile.id
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '선택한 계획서',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              // 선택 바 본문 (안내 문구 제외)
              final Widget selectors;
              if (constraints.maxWidth >= 620) {
                // 1행: 교사 | 계획서 | 내용 수정
                selectors = Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    const Text('교사', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTeacherDropdown(
                        tokens,
                        store,
                        teachers,
                        teacher,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    const Text('계획서', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPlanDropdown(
                        tokens,
                        profiles,
                        dropdownValue,
                      ),
                    ),
                    _buildContentEditNavButton(),
                    _buildDeleteProfileButton(selectedProfile),
                  ],
                );
              } else {
                // 2행: 1행 교사 선택, 2행 계획서 선택 + 내용 수정
                selectors = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Text('교사', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTeacherDropdown(
                            tokens,
                            store,
                            teachers,
                            teacher,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                          child: _buildPlanDropdown(
                            tokens,
                            profiles,
                            dropdownValue,
                          ),
                        ),
                        _buildContentEditNavButton(),
                        _buildDeleteProfileButton(selectedProfile),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  selectors,
                  // 안내 (설정은 입력 즉시 자동 저장됨)
                  if (teacher != null && profiles.isEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "'$teacher'의 계획서가 없습니다. [내용 수정]에서 결강일을 지정해 계획서를 만드세요.",
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => navigateToPlanDateSelection(ref),
                          child: const Text(
                            '이동',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ] else if (selectedProfile == null &&
                      profiles.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '출력을 위해 위에서 계획서를 선택하세요. (미지정 상태에서는 PDF 출력이 불가합니다)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 교사 선택 드롭다운
  Widget _buildTeacherDropdown(
    DesignTokens tokens,
    PrintProfileStore store,
    List<String> teachers,
    String? teacher,
  ) {
    return DropdownButton<String>(
      value: (teacher != null && teachers.contains(teacher)) ? teacher : null,
      isExpanded: true,
      isDense: true,
      underline: const SizedBox.shrink(),
      hint: const Text('교사 선택', style: TextStyle(fontSize: 13)),
      items:
          teachers.map((name) {
            final count = store.byTeacher(name).length;
            return DropdownMenuItem<String>(
              value: name,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    count > 0 ? '계획서 $count' : '계획서 없음',
                    style: TextStyle(
                      fontSize: 11,
                      color: count > 0 ? tokens.textMuted : Colors.orange,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      onChanged: _onTeacherChanged,
    );
  }

  /// 계획서 선택 드롭다운 (없으면 안내 문구)
  Widget _buildPlanDropdown(
    DesignTokens tokens,
    List<PrintProfile> profiles,
    String? dropdownValue,
  ) {
    if (profiles.isEmpty) {
      return Text(
        '계획서 없음 — 내용 수정에서 지정',
        style: TextStyle(fontSize: 13, color: tokens.textMuted),
      );
    }
    return DropdownButton<String>(
      value: dropdownValue,
      isExpanded: true,
      isDense: true,
      underline: const SizedBox.shrink(),
      hint: Text(
        '계획서를 선택하세요',
        style: TextStyle(fontSize: 13, color: tokens.textMuted),
      ),
      items: [
        for (final p in profiles)
          DropdownMenuItem<String>(
            value: p.id,
            child: Text(
              p.name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) _onProfileChanged(id);
      },
    );
  }

  /// 내용 수정으로 이동 버튼 (계획서 생성·관리는 그쪽에서)
  Widget _buildContentEditNavButton() {
    return TextButton(
      onPressed: () => navigateToPlanDateSelection(ref),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Text('내용 수정', style: TextStyle(fontSize: 12)),
    );
  }

  /// PDF 출력 버튼 — 계획서가 선택된 경우에만 활성
  Widget _buildPdfOutputButton() {
    final accentColor = Colors.purple;
    final canPrint = _selectedProfileId != null;
    return SizedBox(
      width: double.infinity,
      child: CompactToolbarLabelButton(
        onPressed: canPrint ? _handlePreview : null,
        icon: Icons.print,
        label: 'PDF 미리보기, 인쇄',
        tooltip: canPrint ? 'PDF 미리보기, 인쇄' : '계획서를 선택한 뒤에만 출력할 수 있습니다',
        backgroundColor: canPrint ? accentColor.shade50 : Colors.grey.shade200,
        foregroundColor: canPrint ? accentColor.shade600 : Colors.grey.shade500,
        borderColor: canPrint ? accentColor.shade600 : Colors.grey.shade400,
        width: double.infinity,
        height: ContentToolbarLayout.buttonHeight,
        fontSize: ContentToolbarLayout.buttonFontSize,
        iconSize: ContentToolbarLayout.buttonIconSize,
      ),
    );
  }

  /// PDF 저장 다이얼로그 파일명의 초기값 생성
  ///
  /// 체크된 계획 중 가장 이른 결강일 기준 "MM.DD 결보강계획서"를 반환합니다.
  /// 결강일이 하나도 없으면 null을 반환하고, 호출부는 오늘 날짜 기준으로 폴백합니다.
  String? _buildPdfSaveFileName(List<SubstitutionPlanData> planData) {
    DateTime? earliest;
    for (final row in planData) {
      final date = DateFormatUtils.parseYearMonthDay(row.absenceDate);
      if (date == null) continue;
      if (earliest == null || date.isBefore(earliest)) earliest = date;
    }
    if (earliest == null) return null;
    final mm = earliest.month.toString().padLeft(2, '0');
    final dd = earliest.day.toString().padLeft(2, '0');
    return '$mm.$dd 결보강계획서';
  }

  /// 출력 미리 보기 처리
  Future<void> _handlePreview() async {
    if (!mounted) return;

    // 미지정(계획서 없음)이면 출력 불가
    if (_selectedProfileId == null) {
      _showSnackBar(
        '계획서를 선택한 뒤에만 PDF를 출력할 수 있습니다. 내용 수정에서 계획서를 지정하세요.',
        Colors.orange,
      );
      return;
    }

    try {
      // 1. 체크된 교체 건만 수집 (내용 수정 화면의 선택과 동일)
      final planData = ref.read(checkedSubstitutionPlanDataProvider);

      // 2. 템플릿 경로 결정 (웹은 로컬 파일이 없으므로 에셋 양식만 사용)
      final String templatePath =
          kIsWeb
              ? kPdfTemplates[_selectedTemplateIndex].assetPath
              : (_selectedTemplateFilePath ??
                  kPdfTemplates[_selectedTemplateIndex].assetPath);

      // 3. PDF 생성 (웹: 메모리 바이트, 네이티브: 임시 파일)
      if (kIsWeb) {
        final pdfBytes = await PdfExportService.exportSubstitutionPlan(
          planData: planData,
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

        if (pdfBytes == null) {
          _showSnackBar('PDF 미리보기 생성 실패', Colors.red);
          return;
        }

        // 4. PDF 출력 설정 저장 (문서 출력 버튼 클릭 시, 양식별로 저장)
        await _saveCurrentSettings();

        // 5. 미리보기 화면으로 이동 (저장 파일명 초기값: 최초 결강일 기준)
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => PdfPreviewScreen(
                    pdfBytes: pdfBytes,
                    initialFileName: _buildPdfSaveFileName(planData),
                  ),
            ),
          );
        }
        return;
      }

      // 2. 임시 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}preview_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 3. PDF 생성
      final pdfBytes = await PdfExportService.exportSubstitutionPlan(
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

      if (pdfBytes == null) {
        _showSnackBar('PDF 미리보기 생성 실패', Colors.red);
        return;
      }

      // 4. PDF 출력 설정 저장 (문서 출력 버튼 클릭 시, 양식별로 저장)
      await _saveCurrentSettings();

      // 5. 미리보기 화면으로 이동 (저장 파일명 초기값: 최초 결강일 기준)
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => PdfPreviewScreen(
                  pdfPath: tempPath,
                  initialFileName: _buildPdfSaveFileName(planData),
                ),
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
    SnackBarHelper.showInfo(context, message, backgroundColor: color);
  }
}
