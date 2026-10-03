import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 내용 수정 화면이 등록하는 계획서 CRUD 액션.
///
/// 2열 헤더([PlanContextHeaderBar])에서 호출한다.
/// IndexedStack으로 내용 수정 위젯이 살아 있어도, 헤더는
/// `showPlanCrud`로 계획서 탭에서만 버튼을 그린다.
@immutable
class PlanCrudActions {
  const PlanCrudActions({
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.canCreate,
    required this.canModify,
  });

  final VoidCallback onCreate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool canCreate;
  final bool canModify;
}

/// 내용 수정(ContentInputGrid)이 최신 콜백을 넣고, dispose 시 null로 비운다.
final planCrudActionsProvider = StateProvider<PlanCrudActions?>((ref) => null);
