import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:class_exchange_manager/models/exchange_node.dart';
import 'package:class_exchange_manager/models/exchange_path.dart';
import 'package:class_exchange_manager/models/one_to_one_exchange_path.dart';
import 'package:class_exchange_manager/models/circular_exchange_path.dart';
import 'package:class_exchange_manager/models/dual_exchange_path.dart';
import 'package:class_exchange_manager/utils/exchange_algorithm.dart';
import 'package:class_exchange_manager/models/time_slot.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/widgets/unified_exchange_sidebar.dart';

/// [UnifiedExchangeSidebar] (통합 교체 사이드바) 렌더링 검증
///
/// 이 위젯은 cellSelectionProvider/exchangeScreenProvider 등을 내부에서
/// 읽지만(§CellSelectionNotifier, §ExchangeScreenNotifier) 둘 다 디스크
/// I/O 없는 순수 인메모리 기본 상태로 생성되므로, Provider 오버라이드 없이도
/// ProviderScope만 감싸면 안전하게 렌더링된다 (timetable_file_screen_test.dart
/// 등과 달리 레지스트리/저장소 목(mock)이 필요 없다).
void main() {
  ExchangeNode node({
    String teacher = '정원길',
    String day = '월',
    int period = 1,
    String className = '1-1',
    String subject = '수학',
  }) {
    return ExchangeNode(
      teacherName: teacher,
      day: day,
      period: period,
      className: className,
      subjectName: subject,
    );
  }

  OneToOneExchangePath makeOneToOnePath({
    String sourceTeacher = '정원길',
    String targetTeacher = '김철수',
  }) {
    final source = node(teacher: sourceTeacher, day: '월', period: 1);
    final target = node(teacher: targetTeacher, day: '화', period: 2);
    final option = ExchangeOption(
      timeSlot: TimeSlot(
        teacher: targetTeacher,
        dayOfWeek: 2,
        period: 2,
        className: '1-1',
        subject: '수학',
      ),
      teacherName: targetTeacher,
      type: ExchangeType.sameClass,
      priority: 1,
      reason: '동일 학급 교체 가능',
    );
    return OneToOneExchangePath(
      sourceNode: source,
      targetNode: target,
      option: option,
    );
  }

  CircularExchangePath makeCircularPath({int extraSteps = 1}) {
    final nodes = <ExchangeNode>[
      node(teacher: '정원길', day: '월', period: 1),
      node(teacher: '김철수', day: '화', period: 2),
      node(teacher: '이영희', day: '수', period: 3),
    ];
    if (extraSteps > 1) {
      nodes.add(node(teacher: '박민수', day: '목', period: 4));
    }
    // 순환이려면 첫 노드와 동일한 값으로 닫혀야 하므로 fromNodes 대신
    // 직접 생성자를 사용해 자유로운 노드 구성을 허용한다.
    return CircularExchangePath(
      nodes: nodes,
      steps: nodes.length - 1,
      description: '순환교체 테스트 경로',
    );
  }

  DualExchangePath makeDualPath() {
    final nodeA = node(teacher: '정원길', day: '월', period: 1);
    final nodeB = node(teacher: '김철수', day: '화', period: 2);
    final node1 = node(teacher: '이영희', day: '수', period: 3);
    final node2 = node(teacher: '박민수', day: '목', period: 4);
    return DualExchangePath.build(
      nodeA: nodeA,
      nodeB: nodeB,
      node1: node1,
      node2: node2,
    );
  }

  String getSubjectName(ExchangeNode n) => n.subjectName;

  Widget buildSidebar({
    required List<ExchangePath> paths,
    required List<ExchangePath> filteredPaths,
    ExchangePath? selectedPath,
    required ExchangePathType mode,
    bool isLoading = false,
    double loadingProgress = 0.0,
    String searchQuery = '',
    double width = 320,
  }) {
    final controller = TextEditingController(text: searchQuery);
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 700,
              child: UnifiedExchangeSidebar(
                width: width,
                paths: paths,
                filteredPaths: filteredPaths,
                selectedPath: selectedPath,
                mode: mode,
                isLoading: isLoading,
                loadingProgress: loadingProgress,
                searchQuery: searchQuery,
                searchController: controller,
                onToggleSidebar: () {},
                onSelectPath: (_) {},
                onUpdateSearchQuery: (_) {},
                onClearSearch: () {},
                getSubjectName: getSubjectName,
                availableSteps: const [2, 3],
                selectedStep: null,
                onStepChanged: (_) {},
                selectedDay: null,
                onDayChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 내부 비동기 작업 없는 순수 위젯이므로 짧은 pump 루프로 충분.
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
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  group('UnifiedExchangeSidebar 기본 렌더링', () {
    testWidgets('예외 없이 렌더링된다', (tester) async {
      final path = makeOneToOnePath();
      await pumpAt(
        tester,
        buildSidebar(
          paths: [path],
          filteredPaths: [path],
          mode: ExchangePathType.oneToOne,
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('검색바가 표시된다', (tester) async {
      final path = makeOneToOnePath();
      await pumpAt(
        tester,
        buildSidebar(
          paths: [path],
          filteredPaths: [path],
          mode: ExchangePathType.oneToOne,
        ),
        width: 800,
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('닫기 버튼이 표시된다', (tester) async {
      final path = makeOneToOnePath();
      await pumpAt(
        tester,
        buildSidebar(
          paths: [path],
          filteredPaths: [path],
          mode: ExchangePathType.oneToOne,
        ),
        width: 800,
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('UnifiedExchangeSidebar 로딩/빈 상태', () {
    testWidgets('로딩 중에는 진행률 표시가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildSidebar(
          paths: const [],
          filteredPaths: const [],
          mode: ExchangePathType.circular,
          isLoading: true,
          loadingProgress: 0.5,
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('경로 탐색 중...'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('경로가 없으면 빈 상태 안내가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildSidebar(
          paths: const [],
          filteredPaths: const [],
          mode: ExchangePathType.oneToOne,
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('교체 가능한 경로가 없습니다'), findsOneWidget);
    });

    testWidgets('검색어가 있는데 결과가 없으면 검색 결과 없음 안내가 보인다', (tester) async {
      await pumpAt(
        tester,
        buildSidebar(
          paths: const [],
          filteredPaths: const [],
          mode: ExchangePathType.oneToOne,
          searchQuery: '없는교사',
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('검색 결과가 없습니다'), findsOneWidget);
    });
  });

  group('UnifiedExchangeSidebar 경로 타입별 아이템', () {
    testWidgets('1:1 교체 경로 아이템이 노드 2개와 양방향 화살표로 렌더링된다', (tester) async {
      final path = makeOneToOnePath();
      await pumpAt(
        tester,
        buildSidebar(
          paths: [path],
          filteredPaths: [path],
          mode: ExchangePathType.oneToOne,
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.textContaining('정원길'), findsWidgets);
      expect(find.textContaining('김철수'), findsWidgets);
    });

    testWidgets('순환교체 경로 아이템이 단계별 화살표 배지로 렌더링된다', (tester) async {
      final path = makeCircularPath(extraSteps: 2);
      await pumpAt(
        tester,
        buildSidebar(
          paths: [path],
          filteredPaths: [path],
          mode: ExchangePathType.circular,
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.arrow_downward), findsWidgets);
      expect(find.textContaining('정원길'), findsWidgets);
    });

    testWidgets('2중교체 경로 아이템이 1·2단계 빨간 배지로 렌더링된다', (tester) async {
      final path = makeDualPath();
      await pumpAt(
        tester,
        buildSidebar(
          paths: [path],
          filteredPaths: [path],
          mode: ExchangePathType.dual,
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('정원길'), findsWidgets);
      expect(find.textContaining('김철수'), findsWidgets);
    });
  });

  group('UnifiedExchangeSidebar 오버플로', () {
    testWidgets('넓은 너비(800)에서 오버플로가 없다', (tester) async {
      final oneToOne = makeOneToOnePath();
      final circular = makeCircularPath(extraSteps: 2);
      final dual = makeDualPath();
      await pumpAt(
        tester,
        buildSidebar(
          paths: [oneToOne, circular, dual],
          filteredPaths: [oneToOne, circular, dual],
          mode: ExchangePathType.oneToOne,
          width: 360,
        ),
        width: 800,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('좁은 너비(360)에서도 오버플로가 없다', (tester) async {
      final oneToOne = makeOneToOnePath();
      final circular = makeCircularPath(extraSteps: 2);
      final dual = makeDualPath();
      await pumpAt(
        tester,
        buildSidebar(
          paths: [oneToOne, circular, dual],
          filteredPaths: [oneToOne, circular, dual],
          mode: ExchangePathType.oneToOne,
          width: 260,
        ),
        width: 360,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
