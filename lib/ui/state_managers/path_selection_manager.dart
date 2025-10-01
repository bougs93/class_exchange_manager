import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';

/// 경로 선택 상태를 관리하는 클래스
///
/// 각 교체 모드별로 선택된 경로를 관리합니다.
class PathSelectionManager {
  // 선택된 경로들
  OneToOneExchangePath? _selectedOneToOnePath;
  CircularExchangePath? _selectedCircularPath;
  ChainExchangePath? _selectedChainPath;

  // Getters
  OneToOneExchangePath? get selectedOneToOnePath => _selectedOneToOnePath;
  CircularExchangePath? get selectedCircularPath => _selectedCircularPath;
  ChainExchangePath? get selectedChainPath => _selectedChainPath;

  /// 1:1 교체 경로 선택
  void selectOneToOnePath(OneToOneExchangePath? path) {
    _selectedOneToOnePath = path;
  }

  /// 순환 교체 경로 선택
  void selectCircularPath(CircularExchangePath? path) {
    _selectedCircularPath = path;
  }

  /// 연쇄 교체 경로 선택
  void selectChainPath(ChainExchangePath? path) {
    _selectedChainPath = path;
  }

  /// 모든 경로 선택 해제
  void clearAllSelections() {
    _selectedOneToOnePath = null;
    _selectedCircularPath = null;
    _selectedChainPath = null;
  }

  /// 현재 선택된 경로가 있는지 확인
  bool hasAnySelection() {
    return _selectedOneToOnePath != null ||
           _selectedCircularPath != null ||
           _selectedChainPath != null;
  }

  /// 특정 경로가 현재 선택되어 있는지 확인
  bool isPathSelected(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      return _selectedOneToOnePath?.id == path.id;
    } else if (path is CircularExchangePath) {
      return _selectedCircularPath?.id == path.id;
    } else if (path is ChainExchangePath) {
      return _selectedChainPath?.id == path.id;
    }
    return false;
  }

  /// 선택된 경로 토글
  void togglePathSelection(ExchangePath path) {
    if (isPathSelected(path)) {
      // 이미 선택된 경로면 해제
      if (path is OneToOneExchangePath) {
        _selectedOneToOnePath = null;
      } else if (path is CircularExchangePath) {
        _selectedCircularPath = null;
      } else if (path is ChainExchangePath) {
        _selectedChainPath = null;
      }
    } else {
      // 선택되지 않은 경로면 선택
      if (path is OneToOneExchangePath) {
        _selectedOneToOnePath = path;
      } else if (path is CircularExchangePath) {
        _selectedCircularPath = path;
      } else if (path is ChainExchangePath) {
        _selectedChainPath = path;
      }
    }
  }
}
