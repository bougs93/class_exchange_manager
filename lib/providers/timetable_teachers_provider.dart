import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exchange_screen_provider.dart';

/// 현재 로드된 시간표의 교사 이름 목록 (가나다순)
///
/// 엑셀 파싱 결과가 단일 출처이며, 교사 추가·삭제 개념은 없습니다.
/// 교사 선택 UI는 반드시 이 목록에서만 고르게 해 존재하지 않는 교사가
/// 입력되는 것을 막습니다(문서 §2 "교사·학교명을 시간표 속성으로 옮기는 이유").
final activeTimetableTeachersProvider = Provider<List<String>>((ref) {
  final teachers = ref.watch(
    exchangeScreenProvider.select((state) => state.timetableData?.teachers),
  );
  if (teachers == null) return const [];

  final names = teachers
      .map((t) => t.name.trim())
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return names;
});
