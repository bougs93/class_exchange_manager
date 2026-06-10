import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_settings_storage_service.dart';
import '../ui/widgets/timetable_grid/timetable_grid_constants.dart';
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

/// 교체 화살표 방향을 관리하는 Notifier (1:1·2중 공용)
///
/// [initialDirection] 기본값과 저장/로드 키를 주입받아 두 설정에서 재사용한다.
class ArrowDirectionNotifier extends StateNotifier<ArrowDirection> {
  ArrowDirectionNotifier({
    required ArrowDirection initialDirection,
    required Future<ArrowDirection> Function() loader,
    required Future<bool> Function(ArrowDirection) saver,
    bool skipInitialLoad = false,
    ArrowDirection? initialValue,
  }) : _initialDirection = initialDirection,
       _loader = loader,
       _saver = saver,
       super(initialValue ?? initialDirection) {
    if (!skipInitialLoad && initialValue == null) {
      _loadInitial();
    }
  }

  final ArrowDirection _initialDirection;
  final Future<ArrowDirection> Function() _loader;
  final Future<bool> Function(ArrowDirection) _saver;

  /// 앱 시작 시 저장된 설정 로드
  Future<void> _loadInitial() async {
    try {
      state = await _loader();
    } catch (e) {
      AppLogger.error('화살표 방향 설정 초기 로드 실패: $e', e);
      state = _initialDirection;
    }
  }

  /// 화살표 방향 변경 및 저장
  Future<bool> setDirection(ArrowDirection direction) async {
    if (state == direction) {
      return true;
    }

    try {
      final success = await _saver(direction);
      if (success) {
        state = direction;
      }
      return success;
    } catch (e) {
      AppLogger.error('화살표 방향 설정 저장 실패: $e', e);
      return false;
    }
  }
}

/// 1:1 교체 화살표 방향 Provider (기본값: 양방향)
final oneToOneArrowDirectionProvider =
    StateNotifierProvider<ArrowDirectionNotifier, ArrowDirection>((ref) {
      final storage = AppSettingsStorageService();
      return ArrowDirectionNotifier(
        initialDirection: ArrowDirection.bidirectional,
        loader: storage.getOneToOneArrowDirection,
        saver: storage.saveOneToOneArrowDirection,
      );
    });

/// 2중 교체 화살표 방향 Provider (기본값: 양방향)
final dualArrowDirectionProvider =
    StateNotifierProvider<ArrowDirectionNotifier, ArrowDirection>((ref) {
      final storage = AppSettingsStorageService();
      return ArrowDirectionNotifier(
        initialDirection: ArrowDirection.bidirectional,
        loader: storage.getDualArrowDirection,
        saver: storage.saveDualArrowDirection,
      );
    });
