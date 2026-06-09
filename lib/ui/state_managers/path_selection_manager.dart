import '../../models/exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/dual_exchange_path.dart';

/// 경로 선택 이벤트 콜백
typedef PathSelectionCallback = void Function(ExchangePath? path);

/// 경로 선택 상태를 관리하는 클래스
///
/// 각 교체 모드별로 선택된 경로를 관리하고,
/// 선택/해제 이벤트에 대한 콜백을 지원합니다.
class PathSelectionManager {
  // 선택된 경로들
  OneToOneExchangePath? _selectedOneToOnePath;
  CircularExchangePath? _selectedCircularPath;
  DualExchangePath? _selectedDualPath;

  // 콜백 함수들
  PathSelectionCallback? _onOneToOnePathChanged;
  PathSelectionCallback? _onCircularPathChanged;
  PathSelectionCallback? _onDualPathChanged;

  // Getters
  OneToOneExchangePath? get selectedOneToOnePath => _selectedOneToOnePath;
  CircularExchangePath? get selectedCircularPath => _selectedCircularPath;
  DualExchangePath? get selectedDualPath => _selectedDualPath;

  /// 콜백 함수 등록
  void setCallbacks({
    PathSelectionCallback? onOneToOnePathChanged,
    PathSelectionCallback? onCircularPathChanged,
    PathSelectionCallback? onDualPathChanged,
  }) {
    _onOneToOnePathChanged = onOneToOnePathChanged;
    _onCircularPathChanged = onCircularPathChanged;
    _onDualPathChanged = onDualPathChanged;
  }

  /// 1:1 교체 경로 선택
  void selectOneToOnePath(OneToOneExchangePath? path) {
    if (_selectedOneToOnePath?.id != path?.id) {
      _selectedOneToOnePath = path;
      _onOneToOnePathChanged?.call(path);
    }
  }

  /// 순환 교체 경로 선택
  void selectCircularPath(CircularExchangePath? path) {
    if (_selectedCircularPath?.id != path?.id) {
      _selectedCircularPath = path;
      _onCircularPathChanged?.call(path);
    }
  }

  /// 2중 교체 경로 선택
  void selectDualPath(DualExchangePath? path) {
    if (_selectedDualPath?.id != path?.id) {
      _selectedDualPath = path;
      _onDualPathChanged?.call(path);
    }
  }

  /// 모든 경로 선택 해제
  void clearAllSelections() {
    _selectedOneToOnePath = null;
    _selectedCircularPath = null;
    _selectedDualPath = null;
  }

  /// 현재 선택된 경로가 있는지 확인
  bool hasAnySelection() {
    return _selectedOneToOnePath != null ||
        _selectedCircularPath != null ||
        _selectedDualPath != null;
  }

  /// 특정 경로가 현재 선택되어 있는지 확인
  bool isPathSelected(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      return _selectedOneToOnePath?.id == path.id;
    } else if (path is CircularExchangePath) {
      return _selectedCircularPath?.id == path.id;
    } else if (path is DualExchangePath) {
      return _selectedDualPath?.id == path.id;
    }
    return false;
  }

  /// 경로 선택 (토글 기능 제거)
  void selectPath(ExchangePath path) {
    // 토글 기능 제거 - 항상 선택만 실행
    _selectPath(path);
  }

  /// 경로 선택 (내부 메서드)
  void _selectPath(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      selectOneToOnePath(path);
    } else if (path is CircularExchangePath) {
      selectCircularPath(path);
    } else if (path is DualExchangePath) {
      selectDualPath(path);
    }
  }

  /// 현재 선택된 경로 가져오기 (타입과 무관)
  ExchangePath? get currentSelectedPath {
    return _selectedOneToOnePath ?? _selectedCircularPath ?? _selectedDualPath;
  }

  /// 경로 타입별 이름 가져오기
  String getPathTypeName(ExchangePath path) {
    if (path is OneToOneExchangePath) return '1:1교체';
    if (path is CircularExchangePath) return '순환교체';
    if (path is DualExchangePath) return '2중교체';
    return '알 수 없음';
  }
}
