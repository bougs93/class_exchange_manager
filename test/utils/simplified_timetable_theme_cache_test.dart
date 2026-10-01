import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/utils/cell_style_config.dart';
import 'package:class_exchange_manager/utils/simplified_timetable_theme.dart';

/// 셀 스타일 캐시 테스트
///
/// 한 화면에 셀이 1,000개 넘게 뜨므로 스타일을 셀마다 새로 만들면
/// 프레임마다 그만큼 객체가 할당된다. 같은 조합이면 같은 인스턴스를
/// 돌려주되, 색상·폰트 배율 같은 정적 설정이 바뀌면 반드시 새로
/// 계산해야 한다(안 그러면 설정 변경이 화면에 반영되지 않는다).
void main() {
  const plain = CellStyleConfig(
    isTeacherColumn: false,
    isSelected: false,
    isExchangeable: false,
    isLastColumnOfDay: false,
  );

  const selected = CellStyleConfig(
    isTeacherColumn: false,
    isSelected: true,
    isExchangeable: false,
    isLastColumnOfDay: false,
  );

  const nonExchangeable = CellStyleConfig(
    isTeacherColumn: false,
    isSelected: false,
    isExchangeable: false,
    isLastColumnOfDay: false,
    isNonExchangeable: true,
  );

  group('SimplifiedTimetableTheme 셀 스타일 캐시', () {
    test('같은 조합이면 같은 인스턴스를 재사용한다', () {
      final a = SimplifiedTimetableTheme.getCellStyleFromConfig(plain);
      final b = SimplifiedTimetableTheme.getCellStyleFromConfig(plain);
      expect(identical(a, b), isTrue);
    });

    test('조합이 다르면 다른 스타일을 만든다', () {
      final a = SimplifiedTimetableTheme.getCellStyleFromConfig(plain);
      final b = SimplifiedTimetableTheme.getCellStyleFromConfig(selected);
      expect(identical(a, b), isFalse);
      expect(a.backgroundColor, isNot(b.backgroundColor));
    });

    test('단계 번호가 다르면 다른 스타일을 만든다', () {
      const step1 = CellStyleConfig(
        isTeacherColumn: false,
        isSelected: false,
        isExchangeable: false,
        isLastColumnOfDay: false,
        isInCircularPath: true,
        circularPathStep: 1,
      );
      const step2 = CellStyleConfig(
        isTeacherColumn: false,
        isSelected: false,
        isExchangeable: false,
        isLastColumnOfDay: false,
        isInCircularPath: true,
        circularPathStep: 2,
      );

      final a = SimplifiedTimetableTheme.getCellStyleFromConfig(step1);
      final b = SimplifiedTimetableTheme.getCellStyleFromConfig(step2);
      expect(identical(a, b), isFalse);
    });

    test('교체불가 색상을 바꾸면 캐시가 갱신된다', () {
      final before = SimplifiedTimetableTheme.getCellStyleFromConfig(
        nonExchangeable,
      );
      final original = SimplifiedTimetableTheme.nonExchangeableColor;

      const newColor = Color(0xFF00FF00);
      SimplifiedTimetableTheme.setNonExchangeableColor(newColor);
      final after = SimplifiedTimetableTheme.getCellStyleFromConfig(
        nonExchangeable,
      );

      expect(before.backgroundColor, isNot(newColor));
      expect(after.backgroundColor, newColor);

      SimplifiedTimetableTheme.setNonExchangeableColor(original);
    });

    test('폰트 배율을 바꾸면 글자 크기가 반영된다', () {
      final before = SimplifiedTimetableTheme.getCellStyleFromConfig(plain);
      final originalScale = SimplifiedTimetableTheme.fontScaleFactor;

      SimplifiedTimetableTheme.setFontScaleFactor(originalScale * 2);
      final after = SimplifiedTimetableTheme.getCellStyleFromConfig(plain);

      expect(
        after.textStyle.fontSize,
        closeTo(before.textStyle.fontSize! * 2, 0.001),
      );

      SimplifiedTimetableTheme.setFontScaleFactor(originalScale);
    });

    test('교체된 셀 선택 플래그를 바꾸면 선택 셀 배경이 갱신된다', () {
      const header = CellStyleConfig(
        isTeacherColumn: false,
        isSelected: true,
        isExchangeable: false,
        isLastColumnOfDay: false,
        isHeader: true,
      );

      SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(false);
      final enabled = SimplifiedTimetableTheme.getCellStyleFromConfig(header);

      SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(true);
      final disabled = SimplifiedTimetableTheme.getCellStyleFromConfig(header);

      expect(enabled.backgroundColor, isNot(disabled.backgroundColor));

      SimplifiedTimetableTheme.setExchangedCellSelectedHeaderDisabled(false);
    });
  });
}
