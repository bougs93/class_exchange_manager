
/// 셀 상태 캐시 관리 클래스
class CellCacheManager {
  // 성능 최적화를 위한 캐시
  final Map<String, bool> _cellSelectionCache = {};
  final Map<String, bool> _cellTargetCache = {};
  final Map<String, bool> _cellExchangeableCache = {};
  final Map<String, bool> _cellCircularPathCache = {};
  final Map<String, bool> _cellChainPathCache = {};
  final Map<String, bool> _cellNonExchangeableCache = {};

  /// 캐시 키 생성
  String _createKey(String teacherName, String day, int period) {
    return '${teacherName}_${day}_$period';
  }

  /// 셀 선택 상태 캐시 확인
  bool getCellSelectionCached(String teacherName, String day, int period, bool Function() checker) {
    String key = _createKey(teacherName, day, period);
    if (_cellSelectionCache.containsKey(key)) {
      return _cellSelectionCache[key]!;
    }
    
    bool result = checker();
    _cellSelectionCache[key] = result;
    return result;
  }

  /// 타겟 셀 상태 캐시 확인
  bool getCellTargetCached(String teacherName, String day, int period, bool Function() checker) {
    String key = _createKey(teacherName, day, period);
    if (_cellTargetCache.containsKey(key)) {
      return _cellTargetCache[key]!;
    }
    
    bool result = checker();
    _cellTargetCache[key] = result;
    return result;
  }

  /// 교체 가능 여부 캐시 확인
  bool getExchangeableCached(String teacherName, String day, int period, bool Function() checker) {
    String key = _createKey(teacherName, day, period);
    if (_cellExchangeableCache.containsKey(key)) {
      return _cellExchangeableCache[key]!;
    }
    
    bool result = checker();
    _cellExchangeableCache[key] = result;
    return result;
  }

  /// 순환교체 경로 포함 여부 캐시 확인
  bool getCircularPathCached(String teacherName, String day, int period, bool Function() checker) {
    String key = _createKey(teacherName, day, period);
    if (_cellCircularPathCache.containsKey(key)) {
      return _cellCircularPathCache[key]!;
    }
    
    bool result = checker();
    _cellCircularPathCache[key] = result;
    return result;
  }

  /// 연쇄교체 경로 포함 여부 캐시 확인
  bool getChainPathCached(String teacherName, String day, int period, bool Function() checker) {
    String key = _createKey(teacherName, day, period);
    if (_cellChainPathCache.containsKey(key)) {
      return _cellChainPathCache[key]!;
    }
    
    bool result = checker();
    _cellChainPathCache[key] = result;
    return result;
  }

  /// 교체불가 여부 캐시 확인
  bool getNonExchangeableCached(String teacherName, String day, int period, bool Function() checker) {
    String key = _createKey(teacherName, day, period);
    if (_cellNonExchangeableCache.containsKey(key)) {
      return _cellNonExchangeableCache[key]!;
    }
    
    bool result = checker();
    _cellNonExchangeableCache[key] = result;
    return result;
  }

  /// 모든 캐시 초기화
  void clearAllCaches() {
    _cellSelectionCache.clear();
    _cellTargetCache.clear();
    _cellExchangeableCache.clear();
    _cellCircularPathCache.clear();
    _cellChainPathCache.clear();
    _cellNonExchangeableCache.clear();
  }
}
