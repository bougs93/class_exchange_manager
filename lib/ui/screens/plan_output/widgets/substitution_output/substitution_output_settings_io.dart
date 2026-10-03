/// PDF 출력 설정의 저장/로드와 관련된 순수(ref/setState 비의존) 로직 모음
///
/// [SubstitutionOutputWidgetState]에서 ref/setState/mounted에 의존하지 않는
/// 계산 부분만 추출한 파일입니다. 상태 반영(setState)은 호출부(위젯)에서
/// 이 파일이 돌려주는 값을 그대로 대입하는 방식으로 유지합니다.
library;

import 'dart:io';

import '../../../../../constants/pdf_notes_template.dart';
import '../../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../../services/pdf_export_settings_storage_service.dart';
import '../../../../../utils/date_format_utils.dart';
import '../../../../../utils/logger.dart';
import 'substitution_output_profile_flow.dart';

/// [resolvePdfExportSettingsSnapshot]의 결과를 담는 불변 데이터 클래스
///
/// 위젯은 이 값을 setState로 그대로 화면 상태/Controller에 반영합니다.
class PdfExportSettingsSnapshot {
  const PdfExportSettingsSnapshot({
    required this.fontSize,
    required this.remarksFontSize,
    required this.selectedFont,
    required this.includeRemarks,
    required this.selectedTemplateFilePath,
    required this.teacherName,
    required this.workStatus,
    required this.reasonForAbsence,
    required this.schoolName,
    required this.notes,
  });

  final double fontSize;
  final double remarksFontSize;
  final String selectedFont;
  final bool includeRemarks;
  final String? selectedTemplateFilePath;
  final String teacherName;
  final String workStatus;
  final String reasonForAbsence;
  final String schoolName;
  final String notes;
}

/// 저장된(또는 양식별 기본) PDF 출력 설정을 화면에 반영할 값으로 변환
///
/// [SubstitutionOutputWidgetState._loadSavedSettings]에서 추출한 순수 로직입니다.
/// ref나 setState에 의존하지 않고, 전달된 [settings]/[targetIndex]/[storage]만으로
/// 결과를 계산합니다.
PdfExportSettingsSnapshot resolvePdfExportSettingsSnapshot({
  required Map<String, dynamic>? settings,
  required int targetIndex,
  required PdfExportSettingsStorageService storage,
}) {
  // 폰트 설정 업데이트
  double newFontSize = 10.0;
  double newRemarksFontSize = 7.0;
  String newSelectedFont = resolveValidFont(null);
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
    // 저장된 폰트가 유효한 목록에 있는지 확인하고, 없으면 기본 폰트 사용
    newSelectedFont = resolveValidFont(savedFont);
    newIncludeRemarks = settings['includeRemarks'] as bool? ?? true;

    // 저장된 PDF 템플릿 파일 경로 로드 (파일 존재 여부 확인)
    final savedTemplatePath = settings['selectedTemplateFilePath'] as String?;
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
    final defaultSettings = storage.getDefaultSettings(
      templateIndex: targetIndex,
    );
    final defaultNotes =
        (defaultSettings['additionalFields'] as Map<String, dynamic>?)?['notes']
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
    final defaultSettings = storage.getDefaultSettings(
      templateIndex: targetIndex,
    );
    newFontSize = (defaultSettings['fontSize'] as num?)?.toDouble() ?? 10.0;
    newRemarksFontSize =
        (defaultSettings['remarksFontSize'] as num?)?.toDouble() ?? 7.0;

    // 폰트 값 유효성 검사
    final defaultFont = defaultSettings['selectedFont'] as String?;
    newSelectedFont = resolveValidFont(defaultFont);
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

  return PdfExportSettingsSnapshot(
    fontSize: newFontSize,
    remarksFontSize: newRemarksFontSize,
    selectedFont: newSelectedFont,
    includeRemarks: newIncludeRemarks,
    selectedTemplateFilePath: newSelectedTemplateFilePath,
    teacherName: newTeacherName,
    workStatus: newWorkStatus,
    reasonForAbsence: newReasonForAbsence,
    schoolName: newSchoolName,
    notes: newNotes,
  );
}

/// PDF 저장 다이얼로그 파일명의 초기값 생성
///
/// 체크된 계획 중 가장 이른 결강일 기준 "MM.DD 결보강계획서"를 반환합니다.
/// 결강일이 하나도 없으면 null을 반환하고, 호출부는 오늘 날짜 기준으로 폴백합니다.
///
/// [SubstitutionOutputWidgetState._buildPdfSaveFileName]에서 추출한 순수 로직입니다.
String? buildPdfSaveFileName(List<SubstitutionPlanData> planData) {
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
