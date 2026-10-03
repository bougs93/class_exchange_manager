import 'package:class_exchange_manager/ui/screens/plan_output/widgets/content_input_grid_plan_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('syncCheckedWithActiveChange', () {
    test('복원된 id는 항상 선택에 넣고, 빠진 id는 선택에서 뺀다', () {
      final checked = <String>{'a', 'b'};
      ContentInputGridPlanOps.syncCheckedWithActiveChange(
        checkedGroupIds: checked,
        activeBefore: {'a', 'b'},
        activeAfter: {'a', 'c'}, // b 제거, c 복원
      );
      expect(checked, {'a', 'c'});
    });

    test('이전에 선택되지 않았던 복원 id도 선택된다', () {
      final checked = <String>{}; // 선택 삭제 직후처럼 비어 있음
      ContentInputGridPlanOps.syncCheckedWithActiveChange(
        checkedGroupIds: checked,
        activeBefore: {'a'},
        activeAfter: {'a', 'restored'},
      );
      expect(checked, {'restored'});
    });
  });

  group('deselectedWithoutRestoredIds', () {
    test('복원 id를 제외 목록에서 제거한다', () {
      final next = ContentInputGridPlanOps.deselectedWithoutRestoredIds(
        ['a', 'b', 'c'],
        ['b'],
      );
      expect(next, ['a', 'c']);
    });

    test('복원 id가 없으면 목록을 복사해 반환한다', () {
      final src = ['a', 'b'];
      final next = ContentInputGridPlanOps.deselectedWithoutRestoredIds(
        src,
        const [],
      );
      expect(next, ['a', 'b']);
      expect(identical(next, src), isFalse);
    });
  });
}
