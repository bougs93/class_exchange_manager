import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/non_exchangeable_data_storage_service.dart';

/// 날짜가 지정된(특정 주에만 적용되는) 교체불가 셀 목록 (§10.6)
///
/// 매주 반복 셀(`date == null`)은 시작 시 `TimeSlot.isExchangeable`에 직접
/// 구워지므로(기존 동작 유지) 이 provider에 담지 않는다. 여기에는 날짜가 있는
/// 셀만 보관하며, `resolvedTimetableProvider`가 현재 선택된 주에 해당하는
/// 항목만 골라 판정에 반영한다.
///
/// 시간표 로드 시 [start_screen.dart]가 이 상태를 채운다. 저장 시
/// `TimetableDataSource._saveNonExchangeableCells()`가 이 목록을 읽어
/// 매주 반복 셀과 합쳐서 저장한다 — 그렇지 않으면 사용자가 아무 매주 반복
/// 셀을 하나만 토글해도 저장 파일 전체가 덮어써지며 날짜 지정 셀이
/// 조용히 사라진다(§10.9 리스크).
final nonExchangeableDatedCellsProvider =
    StateProvider<List<NonExchangeableCell>>((ref) => const []);
