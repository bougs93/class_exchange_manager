import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/usage_event.dart';
import 'package:class_exchange_manager/services/usage_stats_service.dart';

import '../helpers/fake_usage_backend.dart';

void main() {
  UsageStatsService make(FakeUsageBackend b, {String name = '김교사'}) =>
      UsageStatsService(
        enabled: true,
        backend: b,
        teacherName: () => name,
        uid: () => 'uid1',
        flushDelay: const Duration(seconds: 15),
        now: () => DateTime.utc(2026, 10, 6, 16, 0), // KST 10-07 01:00
      );

  testWidgets('이벤트는 15초 디바운스 후 한 번에 쓰고 KST 날짜 문서를 쓴다', (tester) async {
    final b = FakeUsageBackend();
    final s = make(b);
    s.record(UsageEvent.tab, tabIndex: 1);
    s.record(UsageEvent.tab, tabIndex: 1);
    s.record(UsageEvent.planPdfSave);
    await tester.pump(const Duration(seconds: 5));
    expect(b.writes, isEmpty);
    await tester.pump(const Duration(seconds: 11));
    expect(b.writes.length, 1);
    final d = b.writes.single;
    expect(d.dayId, '2026-10-07');
    expect(d.totals['tab_1'], 2);
    expect(d.totals['planPdfSave'], 1);
    expect(d.teachers['김교사']!['tab_1'], 2);
    expect(d.visitors, {'uid1'});
  });

  testWidgets('visit는 즉시 플러시, 빈 교사명은 (이름 미설정)', (tester) async {
    final b = FakeUsageBackend();
    final s = make(b, name: '  ');
    s.record(UsageEvent.visit);
    await tester.pump();
    expect(b.writes.length, 1);
    expect(b.writes.single.teachers.keys, [kUsageUnnamedTeacher]);
  });

  testWidgets('관리자 세션은 교사명과 무관하게 (관리자)로 묶는다', (tester) async {
    final b = FakeUsageBackend();
    final s = UsageStatsService(
      enabled: true,
      backend: b,
      teacherName: () => '김교사',
      isAdmin: () => true,
      uid: () => 'uid1',
    );
    s.record(UsageEvent.visit);
    await tester.pump();
    expect(b.writes.single.teachers.keys, [kUsageAdminBucket]);
  });

  testWidgets('쓰기 실패는 삼키고 예외를 던지지 않는다', (tester) async {
    final b = FakeUsageBackend(failWrites: true);
    final s = make(b);
    s.record(UsageEvent.visit);
    await tester.pump();
    expect(b.writes, isEmpty);
  });

  test('disabled 서비스는 no-op', () async {
    final s = UsageStatsService.disabled();
    s.record(UsageEvent.visit);
    await s.flush();
    expect(await s.countRange(), 0);
  });

  test('범위 삭제와 전체 삭제', () async {
    final b = FakeUsageBackend(
      days: const [
        UsageDay(date: '2026-10-01'),
        UsageDay(date: '2026-10-05'),
        UsageDay(date: '2026-10-09'),
      ],
    );
    final s = make(b);
    final from = DateTime(2026, 10, 2);
    final to = DateTime(2026, 10, 8);
    expect(await s.countRange(from: from, to: to), 1);
    expect(await s.deleteRange(from: from, to: to), 1);
    expect(await s.deleteRange(), 2);
  });

  test('교사 삭제는 해당 교사만 지우고 합계에서 차감한다', () async {
    final b = FakeUsageBackend(
      days: [
        UsageDay(
          date: '2026-10-05',
          totals: const {UsageKeys.visits: 5},
          teachers: const {
            '김교사': {UsageKeys.visits: 3},
            '이교사': {UsageKeys.visits: 2},
          },
          visitors: const {'a', 'b'},
        ),
      ],
    );
    final s = make(b);
    final from = DateTime(2026, 10, 1);
    final to = DateTime(2026, 10, 31);
    expect(
      await s.deleteTeacher(from: from, to: to, teacher: '김교사'),
      1,
    );
    final day = b.days.single;
    expect(day.teachers.keys, ['이교사']);
    expect(day.totals[UsageKeys.visits], 2);
    // 방문자(uid)는 교사 귀속이 아니라 남긴다
    expect(day.visitors, {'a', 'b'});
    // 없는 교사는 0
    expect(await s.deleteTeacher(from: from, to: to, teacher: '박교사'), 0);
  });
}
