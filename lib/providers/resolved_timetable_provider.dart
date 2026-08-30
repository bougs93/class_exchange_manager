import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/time_slot.dart';
import '../utils/resolved_week.dart';
import 'exchange_screen_provider.dart';
import 'selected_week_provider.dart';
import 'services_provider.dart';

/// 교체 가능성 **판정**에 사용할 시간표 (§10.8 4d)
///
/// 원본 시간표에 "현재 보고 있는 주"의 활성 교체를 합성한 결과다.
/// 교체 탐색·검증은 이 결과를 기준으로 해야 한다:
///
/// - **다른 주의 교체는 반영되지 않는다** → P3 해소. 8/27 교체가 9/3 건의
///   판정을 방해하지 않는다
/// - **같은 주의 선행 교체는 반영된다** → 이미 그 주에 교체된 칸을 다시
///   교체 대상으로 제시하지 않는다(§10.5 "같은 주 충돌")
///
/// 교체 뷰(보기 토글)의 ON/OFF와 무관하게 항상 합성 결과를 쓴다. 교체 뷰는
/// "무엇을 보여줄지"의 옵션일 뿐이고, 교체는 언제나 누적 상태 위에 쌓이기
/// 때문이다(§1-6).
///
/// **성능**(§10.9 리스크 3): Provider가 의존성(시간표·주·교체 목록 버전)이
/// 바뀔 때만 재계산하므로 렌더링마다 다시 합성하지 않는다.
final resolvedTimetableProvider = Provider<List<TimeSlot>>((ref) {
  final timetableData = ref.watch(
    exchangeScreenProvider.select((state) => state.timetableData),
  );
  if (timetableData == null) return const [];

  // 교체가 추가·삭제·되돌려지면 다시 합성
  ref.watch(exchangeListVersionProvider);
  final weekMonday = ref.watch(selectedWeekProvider);

  final events = ref.read(exchangeHistoryServiceProvider).getActiveExchangeList();
  final base = timetableData.timeSlots;

  return ResolvedWeek.of(
    base: base,
    events: events,
    weekMonday: weekMonday,
  ).toTimeSlots(base);
});
