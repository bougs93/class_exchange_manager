import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/dated_timetable.dart';
import '../models/lesson.dart';
import '../models/school_semester.dart';
import '../models/teacher.dart';
import '../models/time_slot.dart';
import '../models/timetable_registry.dart';
import '../repositories/timetable_repository.dart';
import 'excel_service.dart';
import 'json_storage.dart';
import 'storage_service.dart';
import 'timetable_registry_service.dart';

/// 다운로드 캐시를 앱이 실제 사용하는 레지스트리·주간표·날짜별 DB에 연결한다.
class SharedTimetableInstaller {
  static const manifestFile = 'shared_timetable_installation.json';
  final JsonStorage storage;

  SharedTimetableInstaller({JsonStorage? storage})
    : storage = storage ?? StorageService();

  Future<bool> isReady(int version, TimetableRepository repo) async {
    final manifest = await storage.loadJson(manifestFile);
    if (manifest == null || manifest['version'] != version) return false;
    final id = manifest['id'] as String?;
    if (id == null) return manifest['count'] == 0;
    final registry =
        await TimetableRegistryService(storage: storage).loadRegistry();
    final entry = registry.getById(id);
    if (entry == null || await repo.getTimetable(id) == null) return false;
    if (await storage.loadJson('timetable_data_${entry.hash}.json') == null) {
      return false;
    }
    final stats = await repo.getLessonStats(id);
    return stats.totalCount > 0 && stats.snapshotCount > 0;
  }

  /// DB를 열지 않고 manifest만으로 캐시를 신뢰할지 본다.
  ///
  /// 버전·개수만 맞으면 최신으로 본다. 깨진 캐시는 [isReady]로 다시 받는다.
  Future<bool> hasTrustedCache(int version) async {
    final manifest = await storage.loadJson(manifestFile);
    if (manifest == null || manifest['version'] != version) return false;
    final id = manifest['id'] as String?;
    final count = (manifest['count'] as num?)?.toInt() ?? 0;
    if (id == null) return count == 0;
    return count > 0;
  }

  Future<void> install({
    required List<Lesson> lessons,
    required int version,
    required TimetableRepository repo,
    DatedTimetable? metadata,
  }) async {
    final registryService = TimetableRegistryService(storage: storage);
    final registry = await registryService.loadRegistry();
    final previous = await storage.loadJson(manifestFile);
    final previousId = previous?['id'] as String?;

    if (lessons.isEmpty) {
      final remaining =
          previousId == null ? registry : registry.withoutEntry(previousId);
      if (!await registryService.saveRegistry(remaining)) {
        throw StateError('공용 시간표 목록을 갱신하지 못했습니다.');
      }
      await _save(manifestFile, {'version': version, 'id': null, 'count': 0});
      return;
    }

    final sourceId = lessons.first.timetableId;
    if (lessons.any((lesson) => lesson.timetableId != sourceId)) {
      throw const FormatException('공용 시간표에 여러 시간표 ID가 포함되어 있습니다.');
    }
    if (metadata != null && metadata.id != sourceId) {
      throw const FormatException('공용 시간표 정보와 수업 ID가 일치하지 않습니다.');
    }
    // 관리자 원본 및 개인 시간표와 ID가 겹치지 않도록 별도 스코프를 사용한다.
    final id = 'shared_$sourceId';
    final existing = registry.getById(id);
    final dates = lessons.map((lesson) => lesson.date).toList()..sort();
    final inferred = SchoolSemester.containing(dates.first);
    final semester =
        metadata?.semester ??
        inferred.copyWith(startDate: dates.first, endDate: dates.last);
    final firstByCell = <(String, int, int), Lesson>{};
    for (final lesson in lessons) {
      final key = (lesson.teacher, lesson.date.weekday, lesson.period);
      final first = firstByCell[key];
      if (first == null || lesson.date.isBefore(first.date)) {
        firstByCell[key] = lesson;
      }
    }
    final slots =
        firstByCell.values
            .map(
              (lesson) => TimeSlot(
                teacher: lesson.teacher,
                subject: lesson.subject,
                className: lesson.className,
                dayOfWeek: lesson.date.weekday,
                period: lesson.period,
                isExchangeable: lesson.isExchangeable,
                exchangeReason: lesson.exchangeReason,
              ),
            )
            .toList();
    final names =
        lessons.map((lesson) => lesson.teacher).toSet().toList()..sort();
    final data = TimetableData(
      teachers: [
        for (var i = 0; i < names.length; i++)
          Teacher(
            id: i + 1,
            name: names[i],
            subject: slots
                .where((slot) => slot.teacher == names[i])
                .map((slot) => slot.subject ?? '')
                .where((s) => s.isNotEmpty)
                .toSet()
                .join(', '),
          ),
      ],
      timeSlots: slots,
      config: const ExcelParsingConfig(),
      totalParsedCells: slots.length,
      successCount: slots.length,
      errorCount: 0,
    );
    final hash =
        sha256.convert(utf8.encode(jsonEncode(data.toJson()))).toString();
    final entry = TimetableRegistryEntry(
      id: id,
      name: metadata?.name ?? existing?.name ?? '공용 시간표',
      fileName: '공용 시간표.json',
      filePath: '',
      hash: 'shared_$hash',
      contentHash: hash,
      teacherName: existing?.teacherName,
      schoolName: metadata?.schoolName ?? existing?.schoolName,
      semesterStart: semester.startDate,
      semesterEnd: semester.endDate,
      registeredAt: existing?.registeredAt ?? DateTime.now(),
    );
    final localLessons =
        lessons
            .map(
              (lesson) => Lesson.fromMap({
                ...lesson.toMap(),
                'id': 'shared_${lesson.id}',
                'timetable_id': id,
              }),
            )
            .toList();
    await repo.replaceImportedTimetable(
      DatedTimetable(
        id: id,
        name: entry.name,
        semester: semester,
        teacherName: entry.teacherName,
        schoolName: entry.schoolName,
        registeredAt: entry.registeredAt,
      ),
      localLessons,
    );
    await _save('timetable_data_${entry.hash}.json', data.toJson());
    final keepActive =
        registry.hasValidActive && registry.activeId != previousId;
    final updated = TimetableRegistry(
      activeId: keepActive ? registry.activeId : id,
      timetables: [
        for (final old in registry.timetables)
          if (old.id != id && old.id != previousId) old,
        entry,
      ],
    );
    if (!await registryService.saveRegistry(updated)) {
      throw StateError('공용 시간표 등록에 실패했습니다.');
    }
    // 모든 저장이 성공한 뒤에만 최신 버전으로 표시한다. 실패 시 재시도 가능.
    await _save(manifestFile, {
      'version': version,
      'id': id,
      'count': lessons.length,
    });
  }

  Future<void> _save(String filename, Map<String, dynamic> data) async {
    if (!await storage.saveJson(filename, data)) {
      throw StateError('공용 시간표 저장 실패: $filename');
    }
  }
}
