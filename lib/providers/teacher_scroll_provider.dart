import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

/// 홈에서 지정한 교사 행으로 스크롤 요청을 관리하는 Provider
class TeacherScrollNotifier extends StateNotifier<String?> {
  TeacherScrollNotifier() : super(null);

  /// 교사명 행으로 스크롤 요청
  void requestScrollToTeacher(String teacherName) {
    final trimmed = teacherName.trim();
    if (trimmed.isEmpty) return;

    AppLogger.exchangeDebug('🎯 [교사 스크롤] 스크롤 요청: $trimmed');
    state = trimmed;
  }

  /// 스크롤 요청 처리 완료 후 상태 초기화
  void clearScrollRequest() {
    state = null;
  }
}

final teacherScrollProvider =
    StateNotifierProvider<TeacherScrollNotifier, String?>((ref) {
      return TeacherScrollNotifier();
    });
