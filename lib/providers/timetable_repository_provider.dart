import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/timetable_database.dart';
import '../repositories/timetable_repository.dart';

/// 날짜 기반 시간표 SQLite DB 인스턴스 (S2·S3)
///
/// 앱 생애주기 동안 한 번만 열고 재사용한다. `keepAlive()`로 Provider가
/// 자동 폐기되지 않게 한다 — DB 커넥션은 명시적으로만 닫아야 한다.
final timetableDatabaseProvider = FutureProvider<Database>((ref) async {
  ref.keepAlive();
  final db = await TimetableDatabase.open();
  // 전체 삭제 시 invalidate되면 파일을 지우기 전에 연결을 닫는다.
  // 이미 닫혀 있으면 다시 닫지 않는다.
  ref.onDispose(() {
    if (db.isOpen) {
      db.close();
    }
  });
  return db;
});

/// [TimetableRepository] 인스턴스 (DB가 준비된 뒤에만 값이 채워진다)
///
/// 아직 어떤 화면도 이 Provider를 구독하지 않는다(S3 시점 기준) — 등록 시
/// 부가적으로 날짜별 수업을 저장하는 용도로만 쓰인다.
final timetableRepositoryProvider = FutureProvider<TimetableRepository>((
  ref,
) async {
  final db = await ref.watch(timetableDatabaseProvider.future);
  return TimetableRepository(db);
});
