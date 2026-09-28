import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "교체" 화면의 날짜표시 스위치 (S1.5)
///
/// - false(기본값·OFF): 요일 헤더에 날짜를 붙이지 않는다 (날짜 미선택 상태).
///   교체를 처음 실행하는 시점의 기본 상태는 반드시 이 값이어야 한다.
/// - true(ON): 요일 헤더·상단 주차 바에 실제 날짜를 표시한다.
///
/// 세션 메모리에만 유지하며 JSON 저장은 하지 않는다 (`cellStatusSymbolVisibilityProvider`와 동일한 방식).
final showWeekHeaderProvider = StateProvider<bool>((ref) => false);
