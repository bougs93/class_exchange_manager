import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_settings_storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_type.dart';
import '../utils/logger.dart';

/// 앱 디자인 테마를 관리하는 Notifier
class AppThemeNotifier extends StateNotifier<AppThemeType> {
  AppThemeNotifier({
    required Future<AppThemeType> Function() loader,
    required Future<bool> Function(AppThemeType) saver,
    bool skipInitialLoad = false,
    AppThemeType? initialValue,
  }) : _loader = loader,
       _saver = saver,
       super(initialValue ?? AppThemeType.classic) {
    if (!skipInitialLoad && initialValue == null) {
      _loadInitial();
    }
  }

  final Future<AppThemeType> Function() _loader;
  final Future<bool> Function(AppThemeType) _saver;

  /// 앱 시작 시 저장된 테마 로드
  Future<void> _loadInitial() async {
    try {
      state = await _loader();
    } catch (e) {
      AppLogger.error('디자인 테마 초기 로드 실패: $e', e);
      state = AppThemeType.classic;
    }
  }

  /// 테마 변경 및 저장
  ///
  /// 반환값: 저장 성공 여부
  Future<bool> select(AppThemeType type) async {
    if (state == type) {
      return true;
    }

    try {
      final success = await _saver(type);
      if (success) {
        state = type;
      }
      return success;
    } catch (e) {
      AppLogger.error('디자인 테마 저장 실패: $e', e);
      return false;
    }
  }
}

/// 앱 디자인 테마 유형 Provider
final appThemeTypeProvider =
    StateNotifierProvider<AppThemeNotifier, AppThemeType>((ref) {
      final storage = AppSettingsStorageService();
      return AppThemeNotifier(
        loader: storage.getAppThemeType,
        saver: storage.saveAppThemeType,
      );
    });

/// 현재 테마의 ThemeData Provider
final appThemeProvider = Provider<ThemeData>((ref) {
  final themeType = ref.watch(appThemeTypeProvider);
  return AppTheme.of(themeType);
});
