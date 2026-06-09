import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_settings_storage_service.dart';
import '../utils/logger.dart';

/// 2중 교체 기능 활성화 여부를 관리하는 Notifier
class DualExchangeEnabledNotifier extends StateNotifier<bool> {
  DualExchangeEnabledNotifier({
    DualExchangeSettingsStorage? storageService,
    bool skipInitialLoad = false,
    bool? initialValue,
  }) : _storageService = storageService ?? AppSettingsStorageService(),
       super(initialValue ?? true) {
    if (!skipInitialLoad && initialValue == null) {
      _loadInitial();
    }
  }

  final DualExchangeSettingsStorage _storageService;

  /// 앱 시작 시 저장된 설정 로드
  Future<void> _loadInitial() async {
    try {
      final enabled = await _storageService.getDualExchangeEnabled();
      state = enabled;
    } catch (e) {
      AppLogger.error('2중 교체 설정 초기 로드 실패: $e', e);
      state = true;
    }
  }

  /// 2중 교체 사용 여부 변경 및 저장
  Future<bool> setEnabled(bool enabled) async {
    if (state == enabled) {
      return true;
    }

    try {
      final success = await _storageService.saveDualExchangeEnabled(enabled);
      if (success) {
        state = enabled;
      }
      return success;
    } catch (e) {
      AppLogger.error('2중 교체 설정 저장 실패: $e', e);
      return false;
    }
  }
}

/// 2중 교체 기능 활성화 여부 Provider
final dualExchangeEnabledProvider =
    StateNotifierProvider<DualExchangeEnabledNotifier, bool>((ref) {
      return DualExchangeEnabledNotifier();
    });

/// 순환 교체 기능 활성화 여부를 관리하는 Notifier
class CircularExchangeEnabledNotifier extends StateNotifier<bool> {
  CircularExchangeEnabledNotifier({
    CircularExchangeSettingsStorage? storageService,
    bool skipInitialLoad = false,
    bool? initialValue,
  }) : _storageService = storageService ?? AppSettingsStorageService(),
       super(initialValue ?? false) {
    if (!skipInitialLoad && initialValue == null) {
      _loadInitial();
    }
  }

  final CircularExchangeSettingsStorage _storageService;

  Future<void> _loadInitial() async {
    try {
      final enabled = await _storageService.getCircularExchangeEnabled();
      state = enabled;
    } catch (e) {
      AppLogger.error('순환 교체 설정 초기 로드 실패: $e', e);
      state = false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (state == enabled) {
      return true;
    }

    try {
      final success = await _storageService.saveCircularExchangeEnabled(
        enabled,
      );
      if (success) {
        state = enabled;
      }
      return success;
    } catch (e) {
      AppLogger.error('순환 교체 설정 저장 실패: $e', e);
      return false;
    }
  }
}

/// 순환 교체 기능 활성화 여부 Provider
final circularExchangeEnabledProvider =
    StateNotifierProvider<CircularExchangeEnabledNotifier, bool>((ref) {
      return CircularExchangeEnabledNotifier();
    });
