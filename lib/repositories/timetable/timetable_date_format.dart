/// `TimetableRepository`와 그 보조 저장소들이 공통으로 쓰는 날짜 포맷터.
///
/// SQLite에는 날짜를 `YYYY-MM-DD` 문자열로 저장하므로, 여러 저장소 파일에서
/// 같은 포맷을 써야 한다 — 원래 `TimetableRepository._formatDate`였던 것을
/// 공용 위치로 옮겼다(동작은 동일, 이름만 공개 top-level 함수로 변경).
String formatTimetableDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
