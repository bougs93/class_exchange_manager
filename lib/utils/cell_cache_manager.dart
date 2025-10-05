
/// 캐시 타입 열거형
enum CacheType {
  cellSelection,
  cellTarget,
  exchangeable,
  circularPath,
  chainPath,
  nonExchangeable,
}

/// 셀 상태 캐시 관리 클래스 (통합 버전)
class CellCacheManager {
  // 성능 최적화를 위한 통합 캐시 맵
  final Map<CacheType, Map<String, bool>> _caches = {
    CacheType.cellSelection: {},
    CacheType.cellTarget: {},
    CacheType.exchangeable: {},
    CacheType.circularPath: {},
    CacheType.chainPath: {},
    CacheType.nonExchangeable: {},
  };

  /// 캐시 키 생성
  String _createKey(String teacherName, String day, int period) {
    return '${teacherName}_${day}_$period';
  }

  /// 통합 캐시 확인 메서드
  bool _getCached(
    CacheType cacheType,
    String teacherName,
    String day,
    int period,
    bool Function() checker,
  ) {
    String key = _createKey(teacherName, day, period);
    Map<String, bool> cache = _caches[cacheType]!;

    if (cache.containsKey(key)) {
      // 캐시 히트 - 성능 최적화 확인용 로그 (필요시 제거)
      // print('[CellCacheManager] 캐시 히트: ${cacheType.name} - $key');
      return cache[key]!;
    }

    // 캐시 미스 - 실제 계산 수행
    bool result = checker();
    cache[key] = result;
    
    // 캐시 미스 로그 (디버깅용, 필요시 제거)
    // print('[CellCacheManager] 캐시 미스: ${cacheType.name} - $key = $result');
    
    return result;
  }

  /// 셀 선택 상태 캐시 확인
  bool getCellSelectionCached(String teacherName, String day, int period, bool Function() checker) {
    return _getCached(CacheType.cellSelection, teacherName, day, period, checker);
  }

  /// 타겟 셀 상태 캐시 확인
  bool getCellTargetCached(String teacherName, String day, int period, bool Function() checker) {
    return _getCached(CacheType.cellTarget, teacherName, day, period, checker);
  }

  /// 교체 가능 여부 캐시 확인
  bool getExchangeableCached(String teacherName, String day, int period, bool Function() checker) {
    return _getCached(CacheType.exchangeable, teacherName, day, period, checker);
  }

  /// 순환교체 경로 포함 여부 캐시 확인
  bool getCircularPathCached(String teacherName, String day, int period, bool Function() checker) {
    return _getCached(CacheType.circularPath, teacherName, day, period, checker);
  }

  /// 연쇄교체 경로 포함 여부 캐시 확인
  bool getChainPathCached(String teacherName, String day, int period, bool Function() checker) {
    return _getCached(CacheType.chainPath, teacherName, day, period, checker);
  }

  /// 교체불가 여부 캐시 확인
  bool getNonExchangeableCached(String teacherName, String day, int period, bool Function() checker) {
    return _getCached(CacheType.nonExchangeable, teacherName, day, period, checker);
  }

  /// 모든 캐시 초기화
  void clearAllCaches() {
    for (var cache in _caches.values) {
      cache.clear();
    }
  }

  /// 순환교체 경로 캐시만 초기화
  void clearCircularPathCache() {
    _caches[CacheType.circularPath]?.clear();
  }

  /// 1:1 교체 경로 캐시만 초기화
  void clearOneToOnePathCache() {
    _caches[CacheType.cellSelection]?.clear();
  }

  /// 연쇄교체 경로 캐시만 초기화
  void clearChainPathCache() {
    _caches[CacheType.chainPath]?.clear();
  }
}
