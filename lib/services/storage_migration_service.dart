import '../models/print_profile.dart';
import '../models/timetable_registry.dart';
import '../utils/logger.dart';
import 'json_storage.dart';
import 'pdf_export_settings_storage_service.dart';
import 'storage_service.dart';
import 'timetable_registry_service.dart';

/// 마이그레이션 결과
class StorageMigrationResult {
  /// 마이그레이션이 실행되었는지 (레지스트리가 없어 새로 생성한 경우)
  final bool migrated;

  /// 구 데이터에서 생성된 초기 시간표 ID (구 데이터가 없으면 null)
  final String? initialTimetableId;

  /// 수행된 단계 로그
  final List<String> steps;

  const StorageMigrationResult({
    required this.migrated,
    this.initialTimetableId,
    this.steps = const [],
  });
}

/// 기존 단일 구조 → 다중 시간표 구조 마이그레이션 서비스
///
/// 앱 시작 시 1회 실행하며, 멱등합니다(레지스트리가 있으면 스킵).
/// 구 파일은 원본 보존 원칙에 따라 삭제하지 않고 스코프 파일로 복사합니다.
///
/// | 기존 | 신규 |
/// |---|---|
/// | timetable_file_metadata.json | timetable_registry.json |
/// | exchange_list.json | exchange_list_{id}.json |
/// | substitution_plan_data.json | substitution_plan_data_{id}.json |
/// | pdf_export_settings_template_{0\|1}.json | print_profiles_{id}.json |
class StorageMigrationService {
  static const String _legacyMetadataFile = 'timetable_file_metadata.json';
  static const String _legacyExchangeListFile = 'exchange_list.json';
  static const String _legacySubstitutionPlanFile = 'substitution_plan_data.json';

  final JsonStorage _storage;

  /// ID 생성기 (테스트 주입용)
  final String Function() generateTimetableId;
  final String Function() generateProfileId;

  StorageMigrationService({
    JsonStorage? storage,
    String Function()? generateTimetableId,
    String Function()? generateProfileId,
  }) : _storage = storage ?? StorageService(),
       generateTimetableId = generateTimetableId ?? TimetableRegistryEntry.generateId,
       generateProfileId = generateProfileId ?? PrintProfile.generateId;

  /// 마이그레이션이 필요하면 실행하고, 결과를 반환합니다.
  Future<StorageMigrationResult> migrateIfNeeded() async {
    // 1. 멱등성: 레지스트리가 이미 있으면 스킵
    if (await _storage.fileExists(TimetableRegistryService.filename)) {
      return const StorageMigrationResult(migrated: false);
    }

    final steps = <String>[];

    // 2. 구 메타데이터 → 레지스트리 생성
    final legacyMetadata = await _storage.loadJson(_legacyMetadataFile);
    TimetableRegistryEntry? initialEntry;

    if (legacyMetadata != null) {
      initialEntry = _entryFromLegacyMetadata(legacyMetadata);
    }

    final registry = initialEntry != null
        ? const TimetableRegistry().withEntry(initialEntry)
        : const TimetableRegistry();

    await _storage.saveJson(TimetableRegistryService.filename, registry.toJson());
    steps.add(
      initialEntry != null
          ? '레지스트리 생성 (초기 시간표: ${initialEntry.id})'
          : '레지스트리 생성 (신규/빈 목록)',
    );

    final timetableId = initialEntry?.id;

    // 3. 시간표 스코프 데이터 이전 (구 데이터가 있을 때만)
    if (timetableId != null) {
      await _migrateExchangeList(timetableId, steps);
      await _migrateSubstitutionPlan(timetableId, steps);
      await _migratePdfSettings(timetableId, steps);
    }

    AppLogger.info('저장소 마이그레이션 완료: ${steps.join(' / ')}');

    return StorageMigrationResult(
      migrated: true,
      initialTimetableId: timetableId,
      steps: steps,
    );
  }

  /// 구 메타데이터를 레지스트리 항목으로 변환
  TimetableRegistryEntry _entryFromLegacyMetadata(Map<String, dynamic> metadata) {
    final fileName = (metadata['fileName'] as String?) ?? '';
    return TimetableRegistryEntry(
      id: generateTimetableId(),
      name: fileName, // 초기 이름 = 기존 파일명 (사용자가 나중에 변경 가능)
      fileName: fileName,
      filePath: (metadata['filePath'] as String?) ?? '',
      hash: (metadata['hash'] as String?) ?? '',
      contentHash: (metadata['contentHash'] as String?) ?? '',
      registeredAt: DateTime.now(),
    );
  }

  /// 교체 목록 이전 (배열 파일)
  Future<void> _migrateExchangeList(String timetableId, List<String> steps) async {
    final targetFile = 'exchange_list_$timetableId.json';

    if (await _storage.fileExists(targetFile)) {
      return; // 이미 이전됨 (부분 마이그레이션 재실행 대응)
    }

    final legacy = await _storage.loadJsonArray(_legacyExchangeListFile);
    if (legacy == null) {
      return;
    }

    await _storage.saveJson(targetFile, legacy);
    steps.add('교체 목록 이전 (${legacy.length}건)');
  }

  /// 결보강 데이터 이전
  Future<void> _migrateSubstitutionPlan(
    String timetableId,
    List<String> steps,
  ) async {
    final targetFile = 'substitution_plan_data_$timetableId.json';

    if (await _storage.fileExists(targetFile)) {
      return;
    }

    final legacy = await _storage.loadJson(_legacySubstitutionPlanFile);
    if (legacy == null) {
      return;
    }

    await _storage.saveJson(targetFile, legacy);
    steps.add('결보강 데이터 이전');
  }

  /// PDF 양식 설정 2개 → 계획서 2개 이전
  ///
  /// 설정 파일이 없으면 기본값으로 계획서를 생성합니다.
  Future<void> _migratePdfSettings(String timetableId, List<String> steps) async {
    final targetFile = 'print_profiles_$timetableId.json';

    if (await _storage.fileExists(targetFile)) {
      return;
    }

    final defaultsService = PdfExportSettingsStorageService();
    final profiles = <PrintProfile>[];

    for (var i = 0; i < PdfExportSettingsStorageService.templateCount; i++) {
      final legacyFile = PdfExportSettingsConstants.getSettingsFileName(i);
      final saved = await _storage.loadJson(legacyFile);
      final settings = saved ?? defaultsService.getDefaultSettings(templateIndex: i);

      profiles.add(
        PrintProfile(
          id: generateProfileId(),
          name: '양식 ${i + 1}',
          teacherName: '', // 사용자가 계획서 탭에서 교사 지정
          templateIndex: i,
          fontSize: (settings['fontSize'] as num?)?.toDouble() ?? 10.0,
          remarksFontSize: (settings['remarksFontSize'] as num?)?.toDouble() ?? 7.0,
          selectedFont: (settings['selectedFont'] as String?) ?? 'hanbatang.ttf',
          includeRemarks: settings['includeRemarks'] as bool? ?? false,
          additionalFields: _stringFields(settings['additionalFields']),
          selectedTemplateFilePath: settings['selectedTemplateFilePath'] as String?,
        ),
      );
    }

    await _storage.saveJson(targetFile, PrintProfileStore(profiles: profiles).toJson());
    steps.add('인쇄 계획서 ${profiles.length}개 생성');
  }

  /// additionalFields를 `Map<String, String>`으로 정규화
  Map<String, String> _stringFields(dynamic raw) {
    final fields = <String, String>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        fields[key.toString()] = value?.toString() ?? '';
      });
    }
    return fields;
  }
}
