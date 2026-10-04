import '../models/teacher.dart';

/// 동명이인 교사 이름 처리 유틸
///
/// 엑셀에 같은 이름의 교사가 여러 행 있으면 [uniqueTeacherNames]가 등장 순서대로
/// 원숫자를 붙여(`김철수①`, `김철수②`) 서로 다른 이름으로 만든다. 앱 안에서는
/// 이 이름이 교사의 고유 키이자 화면 표시 이름이다.
///
/// 계획서(PDF)·안내 문구처럼 사람에게 내보내는 문서에서는 [plainTeacherName]으로
/// 번호를 떼어 실제 이름만 보여준다. **비교·그룹핑은 키 그대로, 문자열을 찍는
/// 곳에서만** 변환할 것.
///
/// 이후 표시 이름과 키를 분리해야 할 때 이 파일이 단일 확장 지점이다.

/// 원숫자 `①`(U+2460) ~ `⑳`(U+2473)
const int _circledOneCodePoint = 0x2460;
const int _circledNumberLimit = 20;

final RegExp _trailingNumberMark = RegExp('^(.+?)(?:[①-⑳]|\\(\\d+\\))\$');

/// 동명이인 구분 번호를 뗀 실제 이름을 돌려준다.
///
/// 번호가 없거나, 번호만 있는 문자열은 그대로 돌려준다.
String plainTeacherName(String key) {
  final match = _trailingNumberMark.firstMatch(key);
  return match?.group(1) ?? key;
}

/// 이름 목록에서 동명이인에게만 등장 순서대로 번호를 붙인 새 목록을 만든다.
///
/// 동명이인이 없는 이름은 그대로 둬서 기존 저장 데이터와 계속 맞는다.
/// 20명을 넘으면 `(21)`처럼 숫자를 괄호로 감싼다.
List<String> uniqueTeacherNames(List<String> names) {
  final totals = <String, int>{};
  for (final name in names) {
    totals[name] = (totals[name] ?? 0) + 1;
  }

  final seen = <String, int>{};
  return [
    for (final name in names)
      if (totals[name]! > 1)
        '$name${_ordinalMark(seen[name] = (seen[name] ?? 0) + 1)}'
      else
        name,
  ];
}

String _ordinalMark(int n) {
  if (n <= _circledNumberLimit) {
    return String.fromCharCode(_circledOneCodePoint + n - 1);
  }
  return '($n)';
}

/// 가져오기 직후 보여줄 동명이인 안내 문구를 만든다(동명이인이 없으면 null).
///
/// 예: `동명이인 1건을 구분해서 불러왔습니다: 김철수①(12행), 김철수②(40행)`
String? duplicateTeacherNotice(List<Teacher> teachers) {
  final groups = findDuplicateTeacherGroups(teachers);
  if (groups.isEmpty) return null;

  final rowByName = {
    for (final t in teachers)
      if (t.sourceRow != null) t.name: t.sourceRow!,
  };
  final labels = [
    for (final names in groups.values)
      for (final name in names)
        rowByName.containsKey(name) ? '$name(${rowByName[name]}행)' : name,
  ];
  return '동명이인 ${groups.length}건을 구분해서 불러왔습니다: ${labels.join(', ')}';
}

/// 동명이인 그룹을 `실제 이름 → 구분된 이름 목록`으로 돌려준다(없으면 빈 맵).
///
/// 가져오기 직후 "동명이인 N건" 안내에 쓴다.
Map<String, List<String>> findDuplicateTeacherGroups(List<Teacher> teachers) {
  final groups = <String, List<String>>{};
  for (final teacher in teachers) {
    final plain = plainTeacherName(teacher.name);
    if (plain != teacher.name) {
      groups.putIfAbsent(plain, () => []).add(teacher.name);
    }
  }
  return groups;
}
