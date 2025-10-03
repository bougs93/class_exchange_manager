import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 네비게이션 상태를 관리하는 Provider
final navigationProvider = StateProvider<int>((ref) => 0);
