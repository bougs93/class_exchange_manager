import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/plan_sort.dart';

/// 결보강 일정 화면과 결보강 출력(PDF)이 함께 읽는 정렬 모드 (기본: 등록순)
///
/// 세션 메모리에만 유지한다.
final planSortModeProvider = StateProvider<PlanSortMode>(
  (ref) => PlanSortMode.byRegistration,
);
