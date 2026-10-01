import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:class_exchange_manager/data/timetable_database.dart';
import 'package:class_exchange_manager/models/lesson.dart';
import 'package:class_exchange_manager/services/excel_service.dart';
import 'package:class_exchange_manager/services/shared_timetable_installer.dart';
import 'package:class_exchange_manager/services/timetable_registry_service.dart';
import 'package:class_exchange_manager/repositories/timetable_repository.dart';
import '../helpers/in_memory_json_storage.dart';

void main() {
  late Database db;
  late TimetableRepository repo;
  late InMemoryJsonStorage storage;
  late SharedTimetableInstaller installer;
  late TimetableRegistryService registryService;

  List<Lesson> published({String subject = '수학'}) => [
    Lesson(
      id: 'a',
      timetableId: 'published',
      date: DateTime(2026, 10, 5),
      period: 1,
      teacher: '교사 A',
      subject: subject,
      className: '1-1',
    ),
    Lesson(
      id: 'b',
      timetableId: 'published',
      date: DateTime(2026, 10, 12),
      period: 1,
      teacher: '교사 A',
      subject: subject,
      className: '1-1',
    ),
    Lesson(
      id: 'c',
      timetableId: 'published',
      date: DateTime(2026, 10, 6),
      period: 2,
      teacher: '교사 B',
    ),
  ];

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await TimetableDatabase.open(path: inMemoryDatabasePath);
    repo = TimetableRepository(db);
    storage = InMemoryJsonStorage();
    installer = SharedTimetableInstaller(storage: storage);
    registryService = TimetableRegistryService(storage: storage);
  });
  tearDown(() async => db.close());

  test('첫 접속: 게시된 수업만으로 활성 목록·주간표·날짜별 수업을 모두 구성한다', () async {
    expect(await installer.isReady(1, repo), isFalse);
    await installer.install(lessons: published(), version: 1, repo: repo);
    final registry = await registryService.loadRegistry();
    final entry = registry.activeEntry!;
    expect(entry.id, 'shared_published');
    expect(entry.filePath, isEmpty);
    expect(entry.teacherName, isNull);
    final data = TimetableData.fromJson(
      (await storage.loadJson('timetable_data_${entry.hash}.json'))!,
    );
    expect(data.teachers.map((e) => e.name), ['교사 A', '교사 B']);
    expect(data.timeSlots.length, 2, reason: '주간표에서는 반복 주차를 중복 표시하지 않는다');
    expect(data.timeSlots.first.subject, '수학');
    final stats = await repo.getLessonStats(entry.id);
    expect(stats.totalCount, 3);
    expect(stats.snapshotCount, 3);
    expect(
      (await repo.getAllLessons(
        entry.id,
      )).every((e) => e.timetableId == entry.id),
      isTrue,
    );
    expect(await installer.isReady(1, repo), isTrue);
    expect(await installer.isReady(2, repo), isFalse);
  });

  test('shared_lessons 캐시만 있던 이전 버전도 실제 등록이 없으면 다시 설치한다', () async {
    await repo.replaceSharedLessons(published());
    expect(await installer.isReady(1, repo), isFalse);
    await installer.install(lessons: published(), version: 1, repo: repo);
    final entry = (await registryService.loadRegistry()).activeEntry!;
    await storage.deleteFile('timetable_data_${entry.hash}.json');
    expect(await installer.isReady(1, repo), isFalse);
    await installer.install(lessons: published(), version: 1, repo: repo);
    expect(await installer.isReady(1, repo), isTrue);
    expect((await registryService.loadRegistry()).timetables.length, 1);
  });

  test('갱신 시 같은 항목을 교체하고 개인 교사 설정은 보존한다', () async {
    await installer.install(lessons: published(), version: 1, repo: repo);
    await registryService.updateTeacherAndSchool(
      'shared_published',
      teacherName: '교사 B',
    );
    await installer.install(
      lessons: published(subject: '국어'),
      version: 2,
      repo: repo,
    );
    final registry = await registryService.loadRegistry();
    expect(registry.timetables.length, 1);
    expect(registry.activeEntry!.teacherName, '교사 B');
    expect((await repo.getAllLessons('shared_published')).first.subject, '국어');
    expect(await installer.isReady(2, repo), isTrue);
  });

  test('관리자 원본·개인 시간표와 활성 선택을 보존하고 공용 항목만 해제한다', () async {
    final personal = await registryService.registerTimetable(
      name: '개인 시간표',
      fileName: 'mine.xlsx',
      filePath: '',
      hash: 'mine',
      contentHash: 'mine',
    );
    await installer.install(lessons: published(), version: 1, repo: repo);
    expect((await registryService.loadRegistry()).activeId, personal.id);
    await installer.install(lessons: [], version: 2, repo: repo);
    final registry = await registryService.loadRegistry();
    expect(registry.timetables.map((e) => e.id), [personal.id]);
    expect(registry.activeId, personal.id);
    expect(await installer.isReady(2, repo), isTrue);
  });
}
