/// 교사별 "수업 안내" 한 줄과 그 정렬 기준(실제 날짜·교시)을 함께 담는다.
///
/// 결강/수업 두 줄이 서로 다른 날짜를 가리킬 수 있어(예: 수업 날짜가 결강
/// 날짜보다 빠른 경우) 행 단위 정렬만으로는 줄 단위 시간 순서를 보장할 수
/// 없다 — 그래서 줄마다 자신의 날짜·교시를 갖고 다니다가 한 교사의 모든
/// 줄을 모은 뒤 한 번에 정렬한다(2026-09-30).
class TeacherNoticeLine {
  final DateTime? date;
  final int period;
  final String text;

  TeacherNoticeLine({
    required this.date,
    required this.period,
    required this.text,
  });
}
