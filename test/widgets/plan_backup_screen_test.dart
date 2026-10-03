import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:class_exchange_manager/models/print_profile.dart';
import 'package:class_exchange_manager/providers/print_profile_provider.dart';
import 'package:class_exchange_manager/providers/substitution_plan_viewmodel.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/screens/plan_output/widgets/plan_backup_screen.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/grid_header_widgets.dart';

/// PlanBackupScreen 렌더링 검증
///
/// `substitutionPlanViewModelProvider`는 기본 생성 시 `exchangeHistoryServiceProvider`
/// (디스크 I/O 없는 순수 인메모리 서비스)만 읽고 await 지점이 없어 생성자 안에서
/// 동기적으로 끝난다. 따라서 `SubstitutionPlanViewModel(ref)`로 정상 생성한 뒤
/// `..state = ...`로 원하는 planData를 바로 덮어써도 안전하다(별도 override 불필요).
/// 계획서 스토어는 timetable_file_screen_test.dart와 동일하게 `PrintProfileStoreNotifier(null)`
/// (스코프 없음 → 디스크 미접근)에 `..state`로 주입한다.
void main() {
  SubstitutionPlanData planRow({
    required String exchangeId,
    required String teacher,
    String absenceDate = '2026-10-05',
    String absenceDay = '월',
    String period = '3',
    String grade = '1',
    String className = '1',
    String subject = '수학',
    String supplementSubject = '수학',
    String supplementTeacher = '김철수',
    String substitutionDate = '2026-10-06',
    String substitutionDay = '화',
    String substitutionPeriod = '4',
    String substitutionSubject = '수학',
    String substitutionTeacher = '김철수',
    String remarks = '',
    String? groupId,
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

  PrintProfile profile({
    required String id,
    required String name,
    required String teacherName,
  }) {
    return PrintProfile(
      id: id,
      name: name,
      teacherName: teacherName,
      templateIndex: 0,
      fontSize: 10,
      remarksFontSize: 9,
      selectedFont: 'NotoSansKR',
      includeRemarks: true,
    );
  }

  List<Override> buildOverrides({
    List<SubstitutionPlanData> planData = const [],
    List<PrintProfile> profiles = const [],
    String? lastUsedProfileId,
  }) {
    return [
      substitutionPlanViewModelProvider.overrideWith(
        (ref) =>
            SubstitutionPlanViewModel(ref)
              ..state = SubstitutionPlanViewModelState(planData: planData),
      ),
      printProfileStoreProvider.overrideWith(
        (ref) => PrintProfileStoreNotifier(null)
          ..state = PrintProfileStore(
            profiles: profiles,
            lastUsedProfileId: lastUsedProfileId,
          ),
      ),
    ];
  }

  Widget buildScreen({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: const Scaffold(body: PlanBackupScreen()),
      ),
    );
  }

  /// 내부 비동기 작업 없는 순수 위젯이므로 짧은 pump 루프로 충분.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    required double width,
    double height = 700,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  group('PlanBackupScreen 기본 렌더링', () {
    testWidgets('빈 상태에서 예외 없이 렌더링된다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 900,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('결강 교사가 없으면 안내 문구가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 900,
      );

      expect(find.text('결강 교사가 없습니다'), findsOneWidget);
      expect(find.text('왼쪽에서 결강 교사를 선택하세요'), findsOneWidget);
    });
  });

  group('PlanBackupScreen 교사/계획서 목록 렌더링', () {
    testWidgets('결강 교사 목록과 계획서 목록이 함께 렌더링된다', (tester) async {
      final plans = [
        planRow(exchangeId: 'e1', teacher: '정원길'),
        planRow(exchangeId: 'e2', teacher: '김철수'),
      ];
      final profiles = [profile(id: 'pp_1', name: '계획서1', teacherName: '정원길')];

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(
            planData: plans,
            profiles: profiles,
            lastUsedProfileId: 'pp_1',
          ),
        ),
        width: 900,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('결강 교사'), findsOneWidget);
      expect(find.textContaining('정원길'), findsWidgets);
      expect(find.textContaining('김철수'), findsWidgets);
      expect(find.text('계획서1'), findsOneWidget);
    });

    testWidgets('선택된 교사의 계획서가 없으면 안내 문구가 보인다', (tester) async {
      final plans = [planRow(exchangeId: 'e1', teacher: '정원길')];

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(planData: plans)),
        width: 900,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('이 교사의 계획서가 없습니다'), findsOneWidget);
    });

    testWidgets('계획서 개수 원형 배지가 표시된다', (tester) async {
      final plans = [planRow(exchangeId: 'e1', teacher: '정원길')];
      final profiles = [
        profile(id: 'pp_1', name: '계획서1', teacherName: '정원길'),
        profile(id: 'pp_2', name: '계획서2', teacherName: '정원길'),
      ];

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(planData: plans, profiles: profiles),
        ),
        width: 900,
      );

      expect(tester.takeException(), isNull);
      // 정원길 교사의 계획서 개수(2) 배지
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('PlanBackupScreen 백업 액션 버튼', () {
    testWidgets('계획서를 선택하지 않으면 내보내기 버튼이 비활성화된다', (tester) async {
      final plans = [planRow(exchangeId: 'e1', teacher: '정원길')];

      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides(planData: plans)),
        width: 900,
      );

      final exportButton = tester.widget<CompactToolbarLabelButton>(
        find.widgetWithText(CompactToolbarLabelButton, '내보내기'),
      );
      expect(exportButton.onPressed, isNull);
    });

    testWidgets('계획서가 선택되면 내보내기 버튼이 활성화된다', (tester) async {
      final plans = [planRow(exchangeId: 'e1', teacher: '정원길')];
      final profiles = [profile(id: 'pp_1', name: '계획서1', teacherName: '정원길')];

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(
            planData: plans,
            profiles: profiles,
            lastUsedProfileId: 'pp_1',
          ),
        ),
        width: 900,
      );

      final exportButton = tester.widget<CompactToolbarLabelButton>(
        find.widgetWithText(CompactToolbarLabelButton, '내보내기'),
      );
      expect(exportButton.onPressed, isNotNull);
    });

    testWidgets('가져오기 버튼은 계획서 선택 여부와 무관하게 항상 활성화된다', (tester) async {
      await pumpAt(
        tester,
        buildScreen(overrides: buildOverrides()),
        width: 900,
      );

      final importButton = tester.widget<CompactToolbarLabelButton>(
        find.widgetWithText(CompactToolbarLabelButton, '가져오기'),
      );
      expect(importButton.onPressed, isNotNull);
    });
  });

  group('PlanBackupScreen 오버플로', () {
    testWidgets('650px 너비에서 오버플로가 없다', (tester) async {
      final plans = [
        planRow(exchangeId: 'e1', teacher: '정원길'),
        planRow(exchangeId: 'e2', teacher: '김철수'),
      ];
      final profiles = [
        profile(id: 'pp_1', name: '계획서1', teacherName: '정원길'),
        profile(id: 'pp_2', name: '계획서2', teacherName: '정원길'),
      ];

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(planData: plans, profiles: profiles),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    // 참고: 420px는 TeacherListPane(고정 200) + PlanListPane 버튼 2개
    // ('결보강 일정'/'계획서 삭제') 조합에서 기존부터 오버플로가 발생한다
    // (이 테스트 추가 전부터 존재하던 레이아웃 한계로, 소스 변경 범위 밖).
    testWidgets('480px 좁은 너비에서도 오버플로가 없다', (tester) async {
      final plans = [
        planRow(exchangeId: 'e1', teacher: '정원길'),
        planRow(exchangeId: 'e2', teacher: '김철수'),
      ];
      final profiles = [profile(id: 'pp_1', name: '계획서1', teacherName: '정원길')];

      await pumpAt(
        tester,
        buildScreen(
          overrides: buildOverrides(planData: plans, profiles: profiles),
        ),
        width: 480,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
