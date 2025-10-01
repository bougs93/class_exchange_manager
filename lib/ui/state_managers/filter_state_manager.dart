import '../../models/exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';

/// 필터 변경 콜백
typedef FilterChangedCallback = void Function();

/// 필터 상태를 관리하는 클래스
///
/// 단계 필터, 요일 필터, 검색 필터 등의 상태를 관리하고,
/// 필터 변경 시 콜백을 통해 알립니다.
class FilterStateManager {
  // 필터 상태
  int? _selectedStep;
  String? _selectedDayFilter;
  String _searchKeyword = '';

  // 콜백
  FilterChangedCallback? _onFilterChanged;

  // Getters
  int? get selectedStep => _selectedStep;
  String? get selectedDayFilter => _selectedDayFilter;
  String get searchKeyword => _searchKeyword;

  /// 필터 변경 콜백 설정
  void setOnFilterChanged(FilterChangedCallback callback) {
    _onFilterChanged = callback;
  }

  /// 단계 필터 설정
  void setStepFilter(int? step) {
    if (_selectedStep != step) {
      _selectedStep = step;
      _onFilterChanged?.call();
    }
  }

  /// 요일 필터 설정
  void setDayFilter(String? day) {
    if (_selectedDayFilter != day) {
      _selectedDayFilter = day;
      _onFilterChanged?.call();
    }
  }

  /// 검색 키워드 설정
  void setSearchKeyword(String keyword) {
    if (_searchKeyword != keyword) {
      _searchKeyword = keyword;
      _onFilterChanged?.call();
    }
  }

  /// 모든 필터 초기화
  void clearAllFilters() {
    bool changed = _selectedStep != null ||
                   _selectedDayFilter != null ||
                   _searchKeyword.isNotEmpty;

    _selectedStep = null;
    _selectedDayFilter = null;
    _searchKeyword = '';

    if (changed) {
      _onFilterChanged?.call();
    }
  }

  /// 필터가 활성화되어 있는지 확인
  bool get hasActiveFilters {
    return _selectedStep != null ||
           _selectedDayFilter != null ||
           _searchKeyword.isNotEmpty;
  }

  /// 활성화된 필터 개수
  int get activeFilterCount {
    int count = 0;
    if (_selectedStep != null) count++;
    if (_selectedDayFilter != null) count++;
    if (_searchKeyword.isNotEmpty) count++;
    return count;
  }

  /// 경로 목록에 필터 적용
  List<ExchangePath> applyFilters(List<ExchangePath> paths) {
    var filtered = paths;

    // 단계 필터 적용
    filtered = _applyStepFilter(filtered);

    // 요일 필터 적용
    filtered = _applyDayFilter(filtered);

    // 검색 필터 적용
    filtered = _applySearchFilter(filtered);

    return filtered;
  }

  /// 단계 필터 적용
  List<ExchangePath> _applyStepFilter(List<ExchangePath> paths) {
    if (_selectedStep == null) return paths;

    return paths.where((path) {
      if (path is OneToOneExchangePath) {
        return path.nodes.length == _selectedStep;
      } else if (path is CircularExchangePath) {
        return path.nodes.length == _selectedStep;
      } else if (path is ChainExchangePath) {
        return path.steps.length == _selectedStep;
      }
      return true;
    }).toList();
  }

  /// 요일 필터 적용
  List<ExchangePath> _applyDayFilter(List<ExchangePath> paths) {
    if (_selectedDayFilter == null) return paths;

    return paths.where((path) {
      if (path is OneToOneExchangePath) {
        return path.nodes.any((node) => node.day == _selectedDayFilter);
      } else if (path is CircularExchangePath) {
        return path.nodes.any((node) => node.day == _selectedDayFilter);
      } else if (path is ChainExchangePath) {
        return path.steps.any((step) =>
            step.fromNode.day == _selectedDayFilter ||
            step.toNode.day == _selectedDayFilter);
      }
      return true;
    }).toList();
  }

  /// 검색 필터 적용
  List<ExchangePath> _applySearchFilter(List<ExchangePath> paths) {
    if (_searchKeyword.isEmpty) return paths;

    final keyword = _searchKeyword.toLowerCase();

    return paths.where((path) {
      if (path is OneToOneExchangePath) {
        return path.nodes.any((node) =>
            node.teacherName.toLowerCase().contains(keyword) ||
            node.className.toLowerCase().contains(keyword) ||
            node.subjectName.toLowerCase().contains(keyword));
      } else if (path is CircularExchangePath) {
        return path.nodes.any((node) =>
            node.teacherName.toLowerCase().contains(keyword) ||
            node.className.toLowerCase().contains(keyword) ||
            node.subjectName.toLowerCase().contains(keyword));
      } else if (path is ChainExchangePath) {
        return path.steps.any((step) =>
            step.fromNode.teacherName.toLowerCase().contains(keyword) ||
            step.toNode.teacherName.toLowerCase().contains(keyword) ||
            step.fromNode.className.toLowerCase().contains(keyword) ||
            step.toNode.className.toLowerCase().contains(keyword));
      }
      return false;
    }).toList();
  }
}
