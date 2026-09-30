import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/timetable_database.dart';
import '../providers/app_settings_provider.dart';
import '../providers/exchange_screen_provider.dart';
import '../providers/non_exchangeable_dated_cells_provider.dart';
import '../providers/selected_week_provider.dart';
import '../providers/services_provider.dart';
import '../providers/substitution_plan_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/timetable_registry_provider.dart';
import '../providers/timetable_repository_provider.dart';
import '../providers/week_lessons_cache_provider.dart';
import '../utils/logger.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/week_date_calculator.dart';
import 'storage_service.dart';

/// JSON·날짜 DB·화면 메모리를 한 번에 지운 결과.
class StoredDataResetResult {
  final Map<String, bool> jsonFiles;

  /// 삭제 전에 날짜 DB 파일이 있었는지.
  final bool databaseExisted;

  /// 날짜 DB 파일을 지우지 못했는지.
  final bool databaseDeleteFailed;

  const StoredDataResetResult({
    required this.jsonFiles,
    required this.databaseExisted,
    required this.databaseDeleteFailed,
  });

  bool get jsonOk => jsonFiles.values.every((ok) => ok);

  bool get hadAnything => jsonFiles.isNotEmpty || databaseExisted;
}

/// 준비 화면과 설정 화면의 "모든 데이터 삭제"가 같은 순서를 쓰게 한다.
///
/// 날짜 기반 수업은 JSON이 아니라 `dated_timetable.db`에 있다. 파일을 지우기
/// 전에 연결을 닫지 않으면 Windows에서 삭제가 실패하고, 화면 캐시를 비우지
/// 않으면 지운 수업이 그대로 보인다.
class StoredDataReset {
  static Future<StoredDataResetResult> deleteAll(WidgetRef ref) async {
    final jsonFiles = await StorageService().deleteAllJsonFiles();
    final database = await _deleteDatedDatabase(ref);
    _clearMemory(ref);
    return StoredDataResetResult(
      jsonFiles: jsonFiles,
      databaseExisted: database.existed,
      databaseDeleteFailed: database.failed,
    );
  }

  static Future<({bool existed, bool failed})> _deleteDatedDatabase(
    WidgetRef ref,
  ) async {
    final path = await TimetableDatabase.defaultDatabasePath();
    final existed = await File(path).exists();
    final asyncDb = ref.read(timetableDatabaseProvider);
    var failed = false;
    // 연결이 없을 때 future를 읽으면 빈 파일을 새로 만든다. 파일이 없고
    // 아직 열리지도 않았으면 건너뛴다.
    if (existed || asyncDb.isLoading || asyncDb.hasValue) {
      try {
        final db = await ref.read(timetableDatabaseProvider.future);
        if (db.isOpen) await db.close();
      } catch (e) {
        AppLogger.error('날짜 DB 연결 닫기 실패: $e', e);
      }

      try {
        await TimetableDatabase.deleteDefaultDatabaseFile();
      } catch (e) {
        failed = true;
        AppLogger.error('날짜 DB 파일 삭제 실패: $e', e);
      }
    }

    // 닫힌 연결을 버리고, 다음 조회가 빈 DB를 새로 만들게 한다.
    ref.invalidate(timetableDatabaseProvider);
    return (existed: existed, failed: failed);
  }

  static void _clearMemory(WidgetRef ref) {
    final exchange = ref.read(exchangeScreenProvider.notifier);
    exchange.setSelectedFile(null);
    exchange.setTimetableData(null);
    exchange.setDataSource(null);
    exchange.setColumns(const []);
    exchange.setStackedHeaders(const []);

    ref.read(exchangeHistoryServiceProvider).resetInMemoryState();
    ref.read(substitutionPlanProvider.notifier).clearInMemory();
    ref.read(nonExchangeableDatedCellsProvider.notifier).state = const [];
    ref.read(weekLessonsCacheProvider).clearAll();
    ref.read(weekLessonsCacheTickerProvider.notifier).bump();
    ref.read(selectedWeekProvider.notifier).state =
        WeekDateCalculator.getThisWeekMonday();

    ref.invalidate(timetableRegistryProvider);
    ref.read(timetableSwitchVersionProvider.notifier).state++;

    // 설정 파일은 이미 없다. 저장 없이 기본값만 화면에 반영한다.
    SimplifiedTimetableTheme.resetHighlightedTeacherColorInMemory();
    ref.invalidate(appThemeTypeProvider);
    ref.invalidate(dualExchangeEnabledProvider);
    ref.invalidate(circularExchangeEnabledProvider);
    ref.invalidate(oneToOneArrowDirectionProvider);
    ref.invalidate(dualArrowDirectionProvider);
  }
}
