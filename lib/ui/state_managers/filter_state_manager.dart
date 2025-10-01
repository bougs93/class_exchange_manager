import '../../models/exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';

/// 필터 상태를 관리하는 클래스
///
/// 단계 필터, 요일 필터, 검색 필터 등의 상태를 관리합니다.
class FilterStateManager {
  // 필터 상태
  int? _selectedStep;
  String? _selectedDayFilter;
  String _searchKeyword = '';

  // Getters
  int? get selectedStep => _selectedStep;
  String? get selectedDayFilter => _selectedDayFilter;
  String get searchKeyword => _searchKeyword;

  /// 단계 필터 설정
  void setStepFilter(int? step) {
    _selectedStep = step;
  }

  /// 요일 필터 설정
  void setDayFilter(String? day) {
    _selectedDayFilter = day;
  }

  /// 검색 키워드 설정
  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword;
  }

  /// 모든 필터 초기화
  void clearAllFilters() {
    _selectedStep = null;
    _selectedDayFilter = null;
    _searchKeyword = '';
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
      if (path is CircularExchangePath) {
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
      if (path is CircularExchangePath) {
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
      if (path is CircularExchangePath) {
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
