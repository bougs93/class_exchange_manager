import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_settings_storage_service.dart';
import '../utils/logger.dart';

/// 연쇄 교체 기능 활성화 여부를 관리하는 Notifier
class ChainExchangeEnabledNotifier extends StateNotifier<bool> {
  ChainExchangeEnabledNotifier({
    ChainExchangeSettingsStorage? storageService,
    bool skipInitialLoad = false,
    bool? initialValue,
  })  : _storageService = storageService ?? AppSettingsStorageService(),
        super(initialValue ?? false) {
    if (!skipInitialLoad && initialValue == null) {
      _loadInitial();
    }
  }

  final ChainExchangeSettingsStorage _storageService;

  /// 앱 시작 시 저장된 설정 로드
  Future<void> _loadInitial() async {
    try {
      final enabled = await _storageService.getChainExchangeEnabled();
      state = enabled;
    } catch (e) {
      AppLogger.error('연쇄 교체 설정 초기 로드 실패: $e', e);
      state = false;
    }
  }

  /// 연쇄 교체 사용 여부 변경 및 저장
  Future<bool> setEnabled(bool enabled) async {
    if (state == enabled) {
      return true;
    }

    try {
      final success = await _storageService.saveChainExchangeEnabled(enabled);
      if (success) {
        state = enabled;
      }
      return success;
    } catch (e) {
      AppLogger.error('연쇄 교체 설정 저장 실패: $e', e);
      return false;
    }
  }
}

/// 연쇄 교체 기능 활성화 여부 Provider
final chainExchangeEnabledProvider =
    StateNotifierProvider<ChainExchangeEnabledNotifier, bool>((ref) {
  return ChainExchangeEnabledNotifier();
});
