import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/utils/exchange_path_step_resolver.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/timetable_grid_constants.dart';

void main() {
  group('resolvePathStepNumber', () {
    test('2중 교체 경로 셀은 dualPathStep을 그대로 반환한다 (1단계)', () {
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.bidirectional,
        isInOneToOnePath: false,
        isInDualPath: true,
        isSelected: false,
        dualPathStep: 1,
      );
      expect(result, 1);
    });

    test('2중 교체 경로 셀은 dualPathStep을 그대로 반환한다 (2단계)', () {
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.forward,
        isInOneToOnePath: false,
        isInDualPath: true,
        isSelected: true,
        dualPathStep: 2,
      );
      expect(result, 2);
    });

    test('1:1 단방향: 비선택 셀은 1을 반환한다', () {
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.forward,
        isInOneToOnePath: true,
        isInDualPath: false,
        isSelected: false,
        dualPathStep: null,
      );
      expect(result, 1);
    });

    test('1:1 단방향: 선택 셀은 null을 반환한다', () {
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.forward,
        isInOneToOnePath: true,
        isInDualPath: false,
        isSelected: true,
        dualPathStep: null,
      );
      expect(result, isNull);
    });

    test('1:1 양방향: 선택 셀도 1을 반환한다 (양쪽 셀 표시)', () {
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.bidirectional,
        isInOneToOnePath: true,
        isInDualPath: false,
        isSelected: true,
        dualPathStep: null,
      );
      expect(result, 1);
    });

    test('1:1 양방향: 비선택 셀도 1을 반환한다 (양쪽 셀 표시)', () {
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.bidirectional,
        isInOneToOnePath: true,
        isInDualPath: false,
        isSelected: false,
        dualPathStep: null,
      );
      expect(result, 1);
    });

    test('어느 경로에도 속하지 않으면 null을 반환한다', () {
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.forward,
        isInOneToOnePath: false,
        isInDualPath: false,
        isSelected: false,
        dualPathStep: null,
      );
      expect(result, isNull);
    });

    test('2중 경로가 1:1 경로보다 우선한다', () {
      // 두 플래그가 모두 켜진 경우에도 2중 단계 번호가 우선
      final result = resolvePathStepNumber(
        oneToOneArrowDirection: ArrowDirection.bidirectional,
        isInOneToOnePath: true,
        isInDualPath: true,
        isSelected: false,
        dualPathStep: 2,
      );
      expect(result, 2);
    });
  });
}
