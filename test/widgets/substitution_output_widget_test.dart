import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:class_exchange_manager/models/print_profile.dart';
import 'package:class_exchange_manager/models/teacher.dart';
import 'package:class_exchange_manager/models/timetable_data.dart';
import 'package:class_exchange_manager/models/timetable_registry.dart';
import 'package:class_exchange_manager/providers/exchange_screen_provider.dart';
import 'package:class_exchange_manager/providers/print_profile_provider.dart';
import 'package:class_exchange_manager/providers/timetable_registry_provider.dart';
import 'package:class_exchange_manager/services/timetable_registry_service.dart';
import 'package:class_exchange_manager/theme/app_theme.dart';
import 'package:class_exchange_manager/theme/app_theme_type.dart';
import 'package:class_exchange_manager/ui/screens/plan_output/widgets/substitution_output/substitution_output_widget.dart';
import 'package:class_exchange_manager/ui/widgets/timetable_grid/grid_header_widgets.dart';

import '../helpers/in_memory_json_storage.dart';

/// [SubstitutionOutputWidget] (결보강 출력 패널) 렌더링·상태 검증
///
/// `printProfileStoreProvider`/`timetableRegistryServiceProvider`는
/// `timetable_file_screen_test.dart`·`content_input_grid_test.dart`와 동일한
/// 패턴으로 인메모리 처리한다 — 계획서 스토어는 `timetableId: null`인
/// [PrintProfileStoreNotifier]를 쓰고(디스크의 모든 쓰기 메서드가
/// `_timetableId == null`일 때 즉시 반환하므로 안전), 레지스트리는
/// [InMemoryJsonStorage]로 교체한다. `exchangeScreenProvider`는 교사 목록을
/// 즉시(동기) 주입해 `initState`의 교사 목록 대기 폴링(최대 3초)을 건너뛴다.
///
/// 교사에게 계획서가 1건 이상 있으면 `_initializeProfileFlow`가 그 계획서를
/// 그대로 선택해 적용하므로(디스크 접근 없음), 대부분의 테스트는 이 경로만
/// 사용한다. 교사에게 계획서가 없는 경로는 레거시 PDF 설정(실제
/// `PdfExportSettingsStorageService` 싱글톤, 파일 I/O)으로 폴백하는데, 이
/// 호출은 위젯 내부에서 전부 try/catch로 감싸여 있어 테스트 환경에서도
/// 예외 없이 끝난다(실제 파일 접근 성패와 무관하게 안전).
void main() {
  List<Override> buildOverrides({
    required List<String> teachers,
    List<PrintProfile> profiles = const [],
    String? lastUsedProfileId,
    String? lastSelectedTeacher,
    String? activeTeacherName,
  }) {
    final storage = InMemoryJsonStorage();
    final entry = TimetableRegistryEntry(
      id: 'tt_1',
      name: '테스트시간표',
      fileName: 'test.xlsx',
      filePath: 'D:/test.xlsx',
      hash: 'h_tt_1',
      contentHash: 'c_tt_1',
      teacherName: activeTeacherName,
      registeredAt: DateTime(2026, 10, 1),
    );
    final registry = const TimetableRegistry().withEntry(entry);
    storage.seedJson(TimetableRegistryService.filename, registry.toJson());

    return [
      // 레지스트리 서비스를 인메모리 저장소로 교체 → 실제 파일 I/O 없이 시작
      timetableRegistryServiceProvider.overrideWith(
        (ref) => TimetableRegistryService(storage: storage),
      ),
      // 디스크 접근 없이 원하는 초기 계획서 상태를 주입 (timetableId: null)
      printProfileStoreProvider.overrideWith(
        (ref) => PrintProfileStoreNotifier(null)
          ..state = PrintProfileStore(
            profiles: profiles,
            lastUsedProfileId: lastUsedProfileId,
            lastSelectedTeacher: lastSelectedTeacher,
          ),
      ),
      // 교사 목록을 동기로 주입 → initState의 교사 목록 대기 폴링을 건너뜀
      exchangeScreenProvider.overrideWith(
        (ref) =>
            ExchangeScreenNotifier()..setTimetableData(
              TimetableData(
                teachers:
                    teachers
                        .map((name) => Teacher(name: name, subject: '수학'))
                        .toList(),
                timeSlots: const [],
                config: const ExcelParsingConfig(),
                totalParsedCells: 0,
                successCount: 0,
                errorCount: 0,
              ),
            ),
      ),
    ];
  }

  PrintProfile makeProfile({
    String id = 'pp_1',
    String name = '계획서1',
    required String teacherName,
  }) {
    return PrintProfile(
      id: id,
      name: name,
      teacherName: teacherName,
      templateIndex: 0,
      fontSize: 10,
      remarksFontSize: 7,
      selectedFont: 'NotoSansKR',
      includeRemarks: true,
    );
  }

  Widget buildWidget({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.of(AppThemeType.classic),
        home: const Scaffold(body: SubstitutionOutputWidget()),
      ),
    );
  }

  /// initState의 비동기 계획서 선택 흐름(`_initializeProfileFlow`)이 끝날
  /// 때까지 흘려보낸다. 실제 디스크 I/O 없는 경로만 쓰므로 짧은 대기로 충분.
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
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  group('SubstitutionOutputWidget 렌더링', () {
    testWidgets('계획서가 선택된 상태로 예외 없이 렌더링된다', (tester) async {
      final profile = makeProfile(teacherName: '정원길');
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길'],
            profiles: [profile],
            lastUsedProfileId: profile.id,
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('선택한 계획서'), findsOneWidget);
      expect(find.text('교사'), findsOneWidget);
      expect(find.text('계획서'), findsOneWidget);
      expect(find.text('PDF 미리보기, 인쇄'), findsOneWidget);
    });

    testWidgets('선택된 계획서 이름이 계획서 드롭다운에 보인다', (tester) async {
      final profile = makeProfile(name: '2학기 계획서', teacherName: '정원길');
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길'],
            profiles: [profile],
            lastUsedProfileId: profile.id,
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('2학기 계획서'), findsOneWidget);
      expect(find.textContaining('정원길'), findsWidgets);
    });
  });

  group('SubstitutionOutputWidget 계획서 없음 안내', () {
    testWidgets('교사에게 계획서가 없으면 안내 문구와 이동 버튼이 보인다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길'],
            profiles: const [],
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining("'정원길'의 계획서가 없습니다"), findsOneWidget);
      expect(find.text('이동'), findsOneWidget);
    });
  });

  group('SubstitutionOutputWidget PDF 출력 버튼', () {
    testWidgets('계획서가 없으면 PDF 출력 버튼이 비활성화된다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길'],
            profiles: const [],
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      final button = tester.widget<CompactToolbarLabelButton>(
        find.widgetWithText(CompactToolbarLabelButton, 'PDF 미리보기, 인쇄'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('계획서가 선택되면 PDF 출력 버튼이 활성화된다', (tester) async {
      final profile = makeProfile(teacherName: '정원길');
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길'],
            profiles: [profile],
            lastUsedProfileId: profile.id,
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      final button = tester.widget<CompactToolbarLabelButton>(
        find.widgetWithText(CompactToolbarLabelButton, 'PDF 미리보기, 인쇄'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('SubstitutionOutputWidget 계획서 삭제 버튼', () {
    testWidgets('계획서가 없으면 삭제 버튼이 비활성화된다', (tester) async {
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길'],
            profiles: const [],
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      final deleteButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(deleteButton.onPressed, isNull);
    });

    testWidgets('계획서가 선택되면 삭제 버튼이 활성화된다', (tester) async {
      final profile = makeProfile(teacherName: '정원길');
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길'],
            profiles: [profile],
            lastUsedProfileId: profile.id,
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      final deleteButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(deleteButton.onPressed, isNotNull);
    });
  });

  group('SubstitutionOutputWidget 오버플로', () {
    testWidgets('650px 너비에서 오버플로가 없다', (tester) async {
      final profile = makeProfile(teacherName: '정원길');
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길', '김철수'],
            profiles: [profile],
            lastUsedProfileId: profile.id,
            activeTeacherName: '정원길',
          ),
        ),
        width: 650,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('420px 좁은 너비에서도 오버플로가 없다', (tester) async {
      final profile = makeProfile(teacherName: '정원길');
      await pumpAt(
        tester,
        buildWidget(
          overrides: buildOverrides(
            teachers: ['정원길', '김철수'],
            profiles: [profile],
            lastUsedProfileId: profile.id,
            activeTeacherName: '정원길',
          ),
        ),
        width: 420,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
