import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 빠진·맡은·교체불가 수업 X/O 오버레이 표시 여부
///
/// 범례 클릭으로 토글합니다. 기본값 true, JSON 저장 없음(세션 메모리만).
final cellStatusSymbolVisibilityProvider = StateProvider<bool>((ref) => true);
