import 'dart:io';

import '../models/print_profile.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/date_format_utils.dart' as date_utils;
import '../utils/logger.dart';
import '../utils/pdf_field_config.dart';
import 'pdf_export_service.dart';
import 'pdf_export_settings_storage_service.dart';

/// 일괄 출력 요청 1건 (교체 건 1개 = 계획서 행 그룹 1개)
class BatchExportItem {
  /// 교체 건 ID (ExchangeHistoryItem.id)
  final String itemId;

  /// 해당 교체 건의 계획서 행 목록 (SubstitutionPlanData.groupId == itemId)
  final List<SubstitutionPlanData> rows;

  /// 지정된 계획서 (미지정 시 null → 레거시 기본 설정 사용)
  final PrintProfile? profile;

  const BatchExportItem({
    required this.itemId,
    required this.rows,
    this.profile,
  });

  /// 파일명 생성용 첫 행 (없으면 null)
  SubstitutionPlanData? get firstRow => rows.isNotEmpty ? rows.first : null;
}

/// 일괄 출력 결과
class BatchPdfExportResult {
  final int successCount;
  final int totalCount;

  /// 실패 건 설명 ("파일명: 사유")
  final List<String> errors;

  /// 사용자가 취소해 실행하지 못한 건수
  final int cancelledCount;

  const BatchPdfExportResult({
    required this.successCount,
    required this.totalCount,
    this.errors = const [],
    this.cancelledCount = 0,
  });

  bool get allSucceeded => errors.isEmpty && cancelledCount == 0;
}

/// 미지정 교체 건의 기본 인쇄 설정 (레거시 양식 설정에서 로드)
class _DefaultPrintSettings {
  final int templateIndex;
  final double fontSize;
  final double remarksFontSize;
  final String selectedFont;
  final bool includeRemarks;
  final Map<String, String> additionalFields;

  const _DefaultPrintSettings({
    required this.templateIndex,
    required this.fontSize,
    required this.remarksFontSize,
    required this.selectedFont,
    required this.includeRemarks,
    required this.additionalFields,
  });
}

/// 교체 건 일괄 PDF 출력 서비스
///
/// 선택된 교체 건마다 지정된 계획서(인쇄 프로파일)로 PDF를 생성합니다.
/// 미지정 건은 레거시 양식 설정(마지막 선택 양식)을 사용합니다.
class BatchPdfExportService {
  final PdfExportSettingsStorageService _legacySettings =
      PdfExportSettingsStorageService();

  /// 일괄 출력 실행
  ///
  /// [onProgress]는 건별 처리 직전에 (완료 수, 전체 수, 파일명)으로 호출됩니다.
  /// [isCancelled]가 true를 반환하면 진행 중인 건까지만 마치고 중단합니다
  /// (건당 수 초가 걸릴 수 있어 진행률과 취소가 필요 — 문서 §3④).
  Future<BatchPdfExportResult> exportAll({
    required List<BatchExportItem> items,
    required String outputDirectory,
    void Function(int done, int total, String fileName)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final defaultSettings = await _loadDefaultSettings();
    final usedFileNames = <String>{};
    int successCount = 0;
    int processed = 0;
    final errors = <String>[];

    for (final item in items) {
      if (isCancelled?.call() ?? false) {
        AppLogger.info('일괄 출력 취소됨: ${items.length - processed}건 남음');
        return BatchPdfExportResult(
          successCount: successCount,
          totalCount: items.length,
          errors: errors,
          cancelledCount: items.length - processed,
        );
      }

      final baseName = _buildBaseFileName(item);
      onProgress?.call(processed, items.length, '$baseName.pdf');
      processed++;

      try {
        final profile = item.profile;
        // 양식 인덱스 범위 검증 (잘못된 값 시 기본 양식으로 폴백)
        final rawIndex = profile?.templateIndex ?? defaultSettings.templateIndex;
        final templateIndex = rawIndex.clamp(0, kPdfTemplates.length - 1);

        // 템플릿 경로 결정 (사용자 지정 파일이 유효하면 우선)
        String templatePath;
        final customPath = profile?.selectedTemplateFilePath;
        if (customPath != null &&
            customPath.isNotEmpty &&
            File(customPath).existsSync()) {
          templatePath = customPath;
        } else {
          templatePath = kPdfTemplates[templateIndex].assetPath;
        }

        final outputPath = await _buildOutputPath(
          outputDirectory,
          baseName,
          usedFileNames,
        );

        // 추가 필드: 계획서 값 + 결강기간은 건별 자동 계산
        final fields = Map<String, String>.from(
          profile?.additionalFields ?? defaultSettings.additionalFields,
        );
        final absencePeriod = date_utils.DateFormatUtils.calculateAbsencePeriod(
          item.rows.map((r) => r.absenceDate).toList(),
        );
        if (absencePeriod.isNotEmpty) {
          fields['absencePeriod'] = absencePeriod;
        }

        final success = await PdfExportService.exportSubstitutionPlan(
          planData: item.rows,
          outputPath: outputPath,
          templatePath: templatePath,
          fontSize: profile?.fontSize ?? defaultSettings.fontSize,
          remarksFontSize:
              profile?.remarksFontSize ?? defaultSettings.remarksFontSize,
          fontType: profile?.selectedFont ?? defaultSettings.selectedFont,
          includeRemarks:
              profile?.includeRemarks ?? defaultSettings.includeRemarks,
          additionalFields: fields,
        );

        if (success) {
          successCount++;
          AppLogger.info('일괄 출력 성공: $outputPath');
        } else {
          errors.add('$baseName: PDF 생성 실패');
        }
      } catch (e) {
        AppLogger.error('일괄 출력 실패 ($baseName): $e', e);
        errors.add('$baseName: $e');
      }
    }

    return BatchPdfExportResult(
      successCount: successCount,
      totalCount: items.length,
      errors: errors,
    );
  }

  /// 미지정 건 기본 설정 로드 (마지막 선택 양식)
  Future<_DefaultPrintSettings> _loadDefaultSettings() async {
    final index = await _legacySettings.loadLastSelectedTemplateIndex() ?? 0;
    final settings = await _legacySettings.loadPdfExportSettings(
      templateIndex: index,
    );
    final defaults = _legacySettings.getDefaultSettings(templateIndex: index);
    final source = settings ?? defaults;

    final fields = <String, String>{};
    final rawFields = source['additionalFields'];
    if (rawFields is Map) {
      rawFields.forEach((key, value) {
        fields[key.toString()] = value?.toString() ?? '';
      });
    }

    return _DefaultPrintSettings(
      templateIndex: index,
      fontSize: (source['fontSize'] as num?)?.toDouble() ?? 10.0,
      remarksFontSize: (source['remarksFontSize'] as num?)?.toDouble() ?? 7.0,
      selectedFont:
          (source['selectedFont'] as String?) ?? 'hanbatang.ttf',
      includeRemarks: source['includeRemarks'] as bool? ?? false,
      additionalFields: fields,
    );
  }

  /// 파일명 기본 이름 생성: {교사명}_{결강일}_{교시과목}
  ///
  /// 한 교체 건이 여러 행(다교시·다일자)이면 첫 행만으로는 서로 구분되지 않으므로
  /// 날짜 범위와 나머지 건수를 덧붙입니다(문서 §3④).
  ///   단일 행      : 홍길동_0827_3교시수학
  ///   같은 날 여러 : 홍길동_0827_3교시수학외2건
  ///   여러 날짜    : 홍길동_0827-0828_3교시수학외4건
  String _buildBaseFileName(BatchExportItem item) {
    final row = item.firstRow;
    if (row == null) {
      return '계획서_${item.itemId}';
    }

    final teacher = _sanitize(row.teacher.isNotEmpty ? row.teacher : '교사없음');
    final periodSubject =
        '${row.period}교시${_sanitize(row.subject.isNotEmpty ? row.subject : '무과목')}';

    // 결강일 범위 (빈 날짜는 제외하고 정렬)
    final dates =
        item.rows
            .map((r) => _toCompactDate(r.absenceDate))
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final String datePart;
    if (dates.isEmpty) {
      datePart = _toCompactDate(row.absenceDate);
    } else if (dates.length == 1) {
      datePart = dates.first;
    } else {
      datePart = '${dates.first}-${dates.last}';
    }

    final extra = item.rows.length - 1;
    final suffix = extra > 0 ? '외$extra건' : '';

    return '${teacher}_${datePart}_$periodSubject$suffix';
  }

  /// 'M.d' 형태의 날짜를 파일명용 'MMdd'로 변환 (빈 값이면 빈 문자열)
  String _toCompactDate(String absenceDate) {
    if (absenceDate.isEmpty) return '';
    return _sanitize(
      date_utils.DateFormatUtils.toMonthDay(absenceDate).replaceAll('.', ''),
    );
  }

  /// 파일명 금지 문자 치환
  String _sanitize(String value) {
    final cleaned = value.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_');
    return cleaned.isEmpty ? '_' : cleaned;
  }

  /// 중복되지 않는 출력 경로 생성
  ///
  /// 실행 내 중복과 디스크에 이미 존재하는 파일 모두 회피합니다
  /// (중복 시 _2, _3 접미사 — 기존 출력물 덮어쓰기 방지).
  Future<String> _buildOutputPath(
    String directory,
    String baseName,
    Set<String> usedNames,
  ) async {
    var candidate = baseName;
    var counter = 2;
    while (usedNames.contains(candidate) ||
        await File(
          '$directory${Platform.pathSeparator}$candidate.pdf',
        ).exists()) {
      candidate = '${baseName}_$counter';
      counter++;
    }
    usedNames.add(candidate);
    return '$directory${Platform.pathSeparator}$candidate.pdf';
  }
}
