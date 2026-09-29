import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 날짜 기반 시간표 SQLite 데이터베이스 초기화 (S2)
///
/// 기존 JSON 저장(`timetable_storage_service.dart` 등)과는 완전히 별개의 새
/// 저장소다. 이 단계에서는 스키마·Repository만 추가하고 화면에는 연결하지
/// 않는다 — 기존 저장 경로에 영향을 주지 않는다.
///
/// Windows/Linux는 sqflite가 기본 지원하지 않으므로 `sqflite_common_ffi`를
/// 사용한다. Android/iOS는 기존 `sqflite` 플랫폼 구현을 그대로 쓴다.
class TimetableDatabase {
  static const int schemaVersion = 1;
  static const String defaultFileName = 'dated_timetable.db';

  static bool _ffiInitialized = false;

  /// 데스크톱(Windows/Linux, 그리고 테스트 실행 중인 macOS 개발 환경)에서
  /// `databaseFactoryFfi`를 사용하도록 한 번만 초기화한다.
  ///
  /// `Platform`은 웹에서 사용할 수 없지만, 이 앱은 데스크톱·모바일 전용이라
  /// `kIsWeb` 분기는 두지 않는다(다른 저장소 코드도 동일한 전제를 쓴다).
  static void _ensureFfiInitialized() {
    if (_ffiInitialized) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  /// 기본 앱 데이터 디렉터리 아래에 DB 파일을 열고, 없으면 스키마를 생성한다.
  ///
  /// [path]를 직접 넘기면(테스트에서 임시 파일·`inMemoryDatabasePath` 사용) 그
  /// 경로를 그대로 연다.
  static Future<Database> open({String? path}) async {
    _ensureFfiInitialized();

    final resolvedPath = path ?? await _defaultDatabasePath();

    return openDatabase(
      resolvedPath,
      version: schemaVersion,
      onCreate: (db, version) async => _createSchema(db),
    );
  }

  static Future<String> _defaultDatabasePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, defaultFileName);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE timetables (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        school_year INTEGER NOT NULL,
        semester INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        teacher_name TEXT,
        school_name TEXT,
        registered_at TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE lessons (
        id TEXT PRIMARY KEY,
        timetable_id TEXT NOT NULL REFERENCES timetables(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        period INTEGER NOT NULL,
        teacher TEXT NOT NULL,
        subject TEXT,
        class_name TEXT,
        is_exchangeable INTEGER NOT NULL DEFAULT 1,
        exchange_reason TEXT
      )
    ''');

    // 최초 등록 직후의 배치 — 원본 비교 기준(§10.4). lessons와 동일한 모양이며
    // 스키마를 하나 더 늘리지 않기 위해 같은 컬럼 구성을 그대로 쓴다.
    await db.execute('''
      CREATE TABLE lesson_snapshots (
        id TEXT PRIMARY KEY,
        timetable_id TEXT NOT NULL REFERENCES timetables(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        period INTEGER NOT NULL,
        teacher TEXT NOT NULL,
        subject TEXT,
        class_name TEXT,
        is_exchangeable INTEGER NOT NULL DEFAULT 1,
        exchange_reason TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_lessons_timetable_date ON lessons(timetable_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_lessons_teacher_date ON lessons(timetable_id, teacher, date, period)',
    );
    await db.execute(
      'CREATE INDEX idx_snapshots_timetable_date ON lesson_snapshots(timetable_id, date)',
    );
  }
}
