import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';

/// ExchangePath 관련 유틸리티 클래스
/// 중복된 타입 필터링 로직을 중앙 집중화
class ExchangePathUtils {
  /// 특정 타입의 경로들만 필터링
  static List<T> filterByType<T extends ExchangePath>(List<ExchangePath> paths) {
    return paths.whereType<T>().toList();
  }
  
  /// 특정 타입을 제외한 경로들 필터링
  static List<ExchangePath> excludeType<T extends ExchangePath>(List<ExchangePath> paths) {
    return paths.where((path) => path is! T).toList();
  }
  
  /// 특정 타입의 경로들을 새로운 경로들로 교체
  static List<ExchangePath> replacePaths<T extends ExchangePath>(
    List<ExchangePath> currentPaths,
    List<T> newPaths,
  ) {
    final otherPaths = excludeType<T>(currentPaths);
    return [...otherPaths, ...newPaths];
  }
  
  /// 특정 타입의 경로들만 제거
  static List<ExchangePath> removePaths<T extends ExchangePath>(List<ExchangePath> paths) {
    return excludeType<T>(paths);
  }
  
  /// 1:1교체 경로들만 반환
  static List<OneToOneExchangePath> getOneToOnePaths(List<ExchangePath> paths) {
    return filterByType<OneToOneExchangePath>(paths);
  }
  
  /// 순환교체 경로들만 반환
  static List<CircularExchangePath> getCircularPaths(List<ExchangePath> paths) {
    return filterByType<CircularExchangePath>(paths);
  }
  
  /// 연쇄교체 경로들만 반환
  static List<ChainExchangePath> getChainPaths(List<ExchangePath> paths) {
    return filterByType<ChainExchangePath>(paths);
  }
  
  /// 특정 타입의 경로가 있는지 확인
  static bool hasPathsOfType<T extends ExchangePath>(List<ExchangePath> paths) {
    return paths.any((path) => path is T);
  }
  
  /// 특정 타입의 경로 개수 반환
  static int countPathsOfType<T extends ExchangePath>(List<ExchangePath> paths) {
    return paths.whereType<T>().length;
  }
}
