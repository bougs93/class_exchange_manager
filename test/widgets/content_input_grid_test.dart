import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'package:class_exchange_manager/providers/print_profile_provider.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/providers/timetable_registry_provider.dart';
import 'package:class_exchange_manager/services/timetable_registry_service.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/screens/plan_output/widgets/content_input_grid.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/grid_header_widgets.dart';

import '../helpers/in_memory_json_storage.dart';

/// [ContentInputGrid] (결보강 일정 그리드) 렌더링 검증
///
/// `substitutionPlanViewModelProvider`는 실제 노티파이어를 상속한 가짜
/// 구현으로 교체한다 — 실제 구현은 생성자에서 `loadPlanData()`를 호출해
/// `exchangeHistoryServiceProvider`(교체 히스토리) 등을 읽는데, 이를
/// 테스트에서 그대로 쓰면 결과가 외부 싱글톤 상태에 따라 달라진다.
/// `loadPlanData()`를 가짜로 비워 두고 생성자가 직접 넣어준 `state`만
/// 쓰도록 해 디스크/싱글톤 의존 없이 원하는 데이터를 주입한다.
/// `printProfileStoreProvider`와 `timetableRegistryServiceProvider`는
/// `timetable_file_screen_test.dart`와 동일한 패턴으로 인메모리 처리한다.
class _FakeSubstitutionPlanViewModel extends SubstitutionPlanViewModel {
  _FakeSubstitutionPlanViewModel(
    super.ref,
    SubstitutionPlanViewModelState initial,
  ) {
    state = initial;
  }

  @override
  Future<void> loadPlanData() async {
    // 디스크·전역 서비스 접근 없이 생성자가 주입한 state만 사용한다.
  }
}

void main() {
  SubstitutionPlanData makeRow({
    String exchangeId = 'ex_1',
    String groupId = 'g_1',
    String absenceDate = '2026-10-05',
    String absenceDay = '월',
    String period = '1',
    String grade = '1',
    String className = '1',
    String subject = '수학',
    String teacher = '정원길',
    String supplementSubject = '',
    String supplementTeacher = '김철수',
    String substitutionDate = '2026-10-06',
    String substitutionDay = '화',
    String substitutionPeriod = '2',
    String substitutionSubject = '수학',
    String substitutionTeacher = '김철수',
    String remarks = '',
  }) {
    return SubstitutionPlanData(
      exchangeId: exchangeId,
      absenceDate: absenceDate,
      absenceDay: absenceDay,
      period: period,
      grade: grade,
      className: className,
      subject: subject,
      teacher: teacher,
      supplementSubject: supplementSubject,
      supplementTeacher: supplementTeacher,
      substitutionDate: substitutionDate,
      substitutionDay: substitutionDay,
      substitutionPeriod: substitutionPeriod,
      substitutionSubject: substitutionSubject,
      substitutionTeacher: substitutionTeacher,
      remarks: remarks,
      groupId: groupId,
    );
  }

  List<Override> buildOverrides({
    List<SubstitutionPlanData> planData = const [],
    bool isLoading = false,
  }) {
    return [
      // 레지스트리 서비스를 인메모리 저장소로 교체 → 실제 파일 I/O 없이 시작
      timetableRegistryServiceProvider.overrideWith(
        (ref) => TimetableRegistryService(storage: InMemoryJsonStorage()),
      ),
      // 디스크 접근 없이 빈 스토어를 쓰도록 스코프를 null로 둔다
      printProfileStoreProvider.overrideWith(
        (ref) => PrintProfileStoreNotifier(null),
      ),
      substitutionPlanViewModelProvider.overrideWith(
        (ref) => _FakeSubstitutionPlanViewModel(
          ref,
          SubstitutionPlanViewModelState(
            planData: planData,
            isLoading: isLoading,
          ),
        ),
      ),
    ];
  }

  Widget buildWidget({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: const Scaffold(body: ContentInputGrid()),
      ),
    );
  }

  /// 초기 비동기 작업(인메모리 레지스트리 로드 등)이 끝날 때까지 흘려보낸다.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    required double width,
    double height = 900,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  group('ContentInputGrid 빈 상태', () {
    testWidgets('계획 데이터가 없으면 빈 상태 안내가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: const [])),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('교체 기록이 없습니다'), findsOneWidget);
      expect(find.text('교체를 실행하면 여기에 기록이 표시됩니다'), findsOneWidget);
    });

    testWidgets('빈 상태에서는 그리드가 그려지지 않는다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: const [])),
        width: 650,
      );

      expect(find.byType(SfDataGrid), findsNothing);
    });
  });

  group('ContentInputGrid 로딩 상태', () {
    testWidgets('로딩 중이면 로딩 인디케이터가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(isLoading: true)),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('교체 기록이 없습니다'), findsNothing);
    });
  });

  group('ContentInputGrid 데이터 렌더링', () {
    testWidgets('계획 데이터가 있으면 그리드가 렌더링되고 빈 상태 안내는 사라진다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: [makeRow()])),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('교체 기록이 없습니다'), findsNothing);
      // 결보강 안내 바(ContentUsageHintBar)는 데이터 유무와 무관하게 항상 보인다
      expect(find.text('엑셀서식 복사'), findsOneWidget);
    });

    testWidgets('여러 건의 계획 데이터도 오류 없이 렌더링된다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            planData: [
              makeRow(exchangeId: 'ex_1', groupId: 'g_1'),
              makeRow(exchangeId: 'ex_2', groupId: 'g_2', teacher: '박은선'),
              makeRow(exchangeId: 'ex_3', groupId: 'g_3', teacher: '이영희'),
            ],
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('ContentInputGrid 액션 버튼', () {
    testWidgets('데이터가 없으면 모두 선택·선택 삭제·되돌리기·다시실행 버튼이 비활성화된다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: const [])),
        width: 650,
      );

      CompactToolbarLabelButton findButton(String label) =>
          tester.widget<CompactToolbarLabelButton>(
            find.widgetWithText(CompactToolbarLabelButton, label),
          );

      expect(findButton('모두 선택').onPressed, isNull);
      expect(findButton('선택 삭제').onPressed, isNull);
      expect(findButton('되돌리기').onPressed, isNull);
      expect(findButton('다시실행').onPressed, isNull);
    });

    testWidgets('데이터가 있으면 모두 선택·선택 삭제 버튼이 활성화된다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: [makeRow()])),
        width: 650,
      );

      CompactToolbarLabelButton findButton(String label) =>
          tester.widget<CompactToolbarLabelButton>(
            find.widgetWithText(CompactToolbarLabelButton, label),
          );

      // 결보강 그리드는 기본적으로 전체 선택 상태로 시작하므로 라벨은
      // '선택 해제'로 바뀌고(allSelected == true), 체크된 항목이 있어
      // '선택 삭제'는 활성화된다.
      expect(findButton('선택 해제').onPressed, isNotNull);
      expect(findButton('선택 삭제').onPressed, isNotNull);
      // 히스토리 스택이 비어 있으므로 되돌리기/다시실행은 여전히 비활성
      expect(findButton('되돌리기').onPressed, isNull);
      expect(findButton('다시실행').onPressed, isNull);
    });

    testWidgets('새로고침·엑셀서식 복사·결보강 출력 버튼은 항상 보인다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: [makeRow()])),
        width: 650,
      );

      expect(find.text('엑셀서식 복사'), findsOneWidget);
      expect(find.text('결보강 출력'), findsOneWidget);
    });

    testWidgets('데이터가 있으면 선택 해제 버튼을 누를 수 있다 (탭해도 예외 없음)', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: [makeRow()])),
        width: 650,
      );

      // 기본이 전체 선택 상태라 버튼 라벨은 '선택 해제'다.
      await tester.tap(find.text('선택 해제'));
      // CompactToolbarLabelButton 내부 탭 애니메이션 타이머(250ms)를 흘려보낸다.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });

  group('ContentInputGrid 오버플로', () {
    testWidgets('650px 너비(빈 상태)에서 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: const [])),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('650px 너비(데이터 있음)에서 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            planData: [
              makeRow(exchangeId: 'ex_1', groupId: 'g_1'),
              makeRow(exchangeId: 'ex_2', groupId: 'g_2', teacher: '박은선'),
            ],
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('420px 좁은 너비에서도 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: [makeRow()])),
        width: 420,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('420px 좁은 너비(빈 상태)에서도 오버플로가 없다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(overrides: buildOverrides(planData: const [])),
        width: 420,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
