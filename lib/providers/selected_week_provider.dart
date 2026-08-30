import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/week_date_calculator.dart';

/// 교체 화면에서 현재 보고 있는 주(월요일)
///
/// §10.4/§10.7: 교체 실행 시 이 값을 기준으로 [absenceDate]/[substitutionDate]를
/// 확정한다. 지금은 항상 "이번 주"로 시작한다 — 주차 바 UI(§10.5, 8단계)가
/// 아직 없어 사용자가 다른 주를 선택할 방법이 없기 때문이다. 주차 바가
/// 추가되면 이 provider의 값을 읽고 쓰는 위젯이 될 뿐, 데이터 소스는
/// 그대로 이 provider다.
///
/// 시간표 전환 시 리셋이 필요하면 `stateResetProvider`에서 이 provider의
/// state를 `WeekDateCalculator.getThisWeekMonday()`로 되돌린다.
final selectedWeekProvider = StateProvider<DateTime>((ref) {
  return WeekDateCalculator.getThisWeekMonday();
});
