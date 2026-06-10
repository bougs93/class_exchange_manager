import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/nav_indices.dart';
import '../models/plan_output_menu.dart';
import 'navigation_provider.dart';

/// 계획서 출력 화면의 왼쪽 서브 메뉴 선택 상태
final planOutputMenuProvider = StateProvider<PlanOutputMenu>(
  (ref) => PlanOutputMenu.contentInput,
);

/// [계획서] 탭의 [날짜 선택] 서브 메뉴로 이동합니다.
void navigateToPlanDateSelection(WidgetRef ref) {
  ref.read(planOutputMenuProvider.notifier).state = PlanOutputMenu.contentInput;
  ref.read(navigationProvider.notifier).state = NavIndices.planOutput;
}
