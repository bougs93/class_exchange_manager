import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/school_semester.dart';
import 'timetable_registry_provider.dart';
import 'timetable_repository_provider.dart';

/// 현재 활성 시간표의 SQLite 저장 학기 범위 (S4.1)
///
/// 아직 어떤 화면도 이 Provider를 구독하지 않는다 — S4.2에서 교체 화면
/// 주간바에 "학기 범위 밖" 안내를 붙일 때 처음 사용한다.
///
/// 활성 시간표가 없거나, 있어도 날짜 기반 데이터가 없는 시간표라면(S4.0 패널에서
/// "날짜별 데이터가 없습니다"로 보이는 경우와 동일 조건) null을 반환한다 —
/// 이 경우 호출부는 [WeekSemesterStatus.unknown]으로 처리해야 한다.
final datedSemesterProvider = FutureProvider<SchoolSemester?>((ref) async {
  await ref.watch(timetableRegistryProvider.notifier).ensureInitialized();
  final activeId = ref.watch(timetableRegistryProvider).valueOrNull?.activeId;
  if (activeId == null) return null;

  final repository = await ref.watch(timetableRepositoryProvider.future);
  final timetable = await repository.getTimetable(activeId);
  return timetable?.semester;
});
