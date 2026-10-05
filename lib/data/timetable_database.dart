import 'package:sqflite_common/sqflite.dart';

import 'database_platform.dart';

/// 날짜 기반 시간표 SQLite 데이터베이스 초기화 (S2)
///
/// 기존 JSON 저장(`timetable_storage_service.dart` 등)과는 완전히 별개의 새
/// 저장소다. 이 단계에서는 스키마·Repository만 추가하고 화면에는 연결하지
/// 않는다 — 기존 저장 경로에 영향을 주지 않는다.
///
/// 엔진은 플랫폼별로 다르다 (`database_platform.dart` 조건부 export):
/// - 모바일: 기존 `sqflite` 플랫폼 구현
/// - 데스크톱(Windows/Linux/macOS): `sqflite_common_ffi`
/// - 웹: `sqflite_common_ffi_web` (sqlite3.wasm + IndexedDB)
/// 스키마·쿼리·마이그레이션은 전 플랫폼 공통이다.
class TimetableDatabase {
  static const int schemaVersion = 6;
  static const String defaultFileName = 'dated_timetable.db';

  /// 기본 앱 데이터 디렉터리 아래에 DB 파일을 열고, 없으면 스키마를 생성한다.
  ///
  /// [path]를 직접 넘기면(테스트에서 임시 파일·`inMemoryDatabasePath` 사용) 그
  /// 경로를 그대로 연다.
  static Future<Database> open({String? path}) async {
    ensureDatabaseFactory();

    final resolvedPath = path ?? await _defaultDatabasePath();

    return openDatabase(
      resolvedPath,
      version: schemaVersion,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // S3a: 기간 축소 시 "보관하되 활성 조회에서 제외"하기 위한 플래그.
          // 두 테이블 모두 [Lesson.toMap]을 그대로 써서 삽입하므로 동일하게 추가한다
          // (`lesson_snapshots`에서는 항상 1이며 실제로 읽지는 않는다).
          await db.execute(
            'ALTER TABLE lessons ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE lesson_snapshots ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldVersion < 3) {
          // S5.0: 교체 이벤트 저널 — 기존 lessons/lesson_snapshots와는 별개로,
          // "언제 누가 무엇을 바꿨는가"만 기록한다. 이 단계에서는 어떤 화면도
          // 이 테이블을 쓰지 않는다(S5.1에서 부가 기록으로 연결 예정).
          await _createExchangeEventsTable(db);
        }
        if (oldVersion < 4) {
          // S5.4a: lessons가 exchange_events를 어디까지 재생했는지 기록한다.
          // 화면 읽기는 아직 SQLite로 전환되지 않았으므로(S5.5), 이 값은
          // 확인 패널에서 "재생 필요 여부"를 보여주는 용도로만 쓰인다.
          await db.execute(
            'ALTER TABLE timetables ADD COLUMN projected_seq INTEGER NOT NULL DEFAULT -1',
          );
        }
        if (oldVersion < 5) {
          // S5.4a 성능 수정: replayInto가 매번 학기 전체(수만 행)를 다시 훑던
          // 문제를 고치기 위해, "한 번이라도 교체가 건드린 좌표"만 별도로
          // 기록해 둔다. 이 표에 있는 좌표 + 지금 이벤트가 건드리는 좌표만
          // 리셋·재계산하면 지워진 교체의 흔적도 놓치지 않으면서 범위를
          // 좁힐 수 있다(교체가 실제로 건드리는 칸은 보통 학기 전체의 일부일
          // 뿐이다).
          await _createDirtyLessonKeysTable(db);
        }
        if (oldVersion < 6) {
          // 2026-10-05: 1:1·보강의 결강일·교체일이 같은 요일(다른 주)이면
          // 날짜를 요일만으로 찾다가 한쪽이 덮어써져, 잘못된 날짜로 lessons가
          // 투영돼 있다. 재생 표시를 무효화해 다음 조회 때 replayInto가 고친
          // 규칙으로 다시 계산하게 한다(옛 잘못된 좌표는 dirty_lesson_keys에
          // 남아 있으므로 함께 템플릿으로 리셋된다).
          await db.execute('UPDATE timetables SET projected_seq = -1');
        }
      },
    );
  }

  static Future<String> _defaultDatabasePath() {
    return defaultDatabaseFilePath(defaultFileName);
  }

  /// 기본 DB 파일의 절대 경로 (S4.0 — 확인 패널에서 경로를 보여주기 위해 공개).
  static Future<String> defaultDatabasePath() => _defaultDatabasePath();

  /// 기본 DB 파일과 WAL 보조 파일을 지운다.
  ///
  /// 호출 전에 열어 둔 연결을 닫아야 한다. Windows에서는 연결이 살아 있으면
  /// 파일 삭제가 실패한다.
  static Future<bool> deleteDefaultDatabaseFile() async {
    ensureDatabaseFactory();
    final path = await _defaultDatabasePath();
    final existed = await databaseFileExists(path);
    await deleteDatabase(path);
    return existed;
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
        revision INTEGER NOT NULL DEFAULT 1,
        projected_seq INTEGER NOT NULL DEFAULT -1
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
        exchange_reason TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 최초 등록 직후의 배치 — 원본 비교 기준(§10.4). lessons와 동일한 모양이며
    // 스키마를 하나 더 늘리지 않기 위해 같은 컬럼 구성을 그대로 쓴다.
    // is_active는 여기서는 항상 1이며 실제로 읽지 않는다 — [Lesson.toMap]을
    // 두 테이블에 그대로 재사용하기 위해 컬럼만 맞춰둔다.
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
        exchange_reason TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
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

    await _createExchangeEventsTable(db);
    await _createDirtyLessonKeysTable(db);
  }

  /// "한 번이라도 교체가 건드린 좌표" 기록 (S5.4a 성능 수정).
  ///
  /// `replayInto`가 학기 전체를 매번 다시 훑지 않고 이 좌표들 + 지금 이벤트가
  /// 건드리는 좌표만 리셋·재계산하도록 범위를 좁히기 위한 보조 표다. 한 번
  /// 추가된 좌표는 지우지 않는다(grow-only) — 나중에 그 좌표를 건드리던
  /// 교체가 삭제되더라도, 이 표에 남아 있어야 다음 재생 때 그 칸을 다시
  /// 템플릿으로 되돌릴 수 있다.
  static Future<void> _createDirtyLessonKeysTable(Database db) async {
    await db.execute('''
      CREATE TABLE dirty_lesson_keys (
        timetable_id TEXT NOT NULL,
        teacher TEXT NOT NULL,
        date TEXT NOT NULL,
        period INTEGER NOT NULL,
        PRIMARY KEY (timetable_id, teacher, date, period)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_dirty_lesson_keys_timetable ON dirty_lesson_keys(timetable_id)',
    );
  }

  /// 교체 이벤트 저널 (S5.0) — "언제 누가 무엇을 바꿨는가"만 기록한다.
  ///
  /// `lessons`/`lesson_snapshots`처럼 실제 배치를 담지 않는다. 이 테이블이
  /// 진실 원본이 되고(S5.4b), `lessons`는 이 저널을 재생(replay)해 만드는
  /// 파생 뷰로만 갱신한다(S5.4a) — S5 설계 검토서 §1.3 참조.
  static Future<void> _createExchangeEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE exchange_events (
        id TEXT PRIMARY KEY,
        timetable_id TEXT NOT NULL,
        seq INTEGER NOT NULL,
        type TEXT NOT NULL,
        absence_date TEXT NOT NULL,
        substitution_date TEXT NOT NULL,
        is_reverted INTEGER NOT NULL DEFAULT 0,
        path_json TEXT NOT NULL,
        node_dates_json TEXT,
        description TEXT NOT NULL,
        notes TEXT,
        tags_json TEXT NOT NULL,
        profile_id TEXT,
        metadata_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_exchange_events_timetable_seq ON exchange_events(timetable_id, seq)',
    );
  }
}
