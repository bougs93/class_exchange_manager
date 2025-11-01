import 'storage_service.dart';
import '../models/exchange_history_item.dart';
import '../utils/logger.dart';

/// 교체 리스트 저장 서비스
/// 
/// 모든 교체 리스트를 하나의 파일(`exchange_list.json`)에 저장하고 로드합니다.
class ExchangeListStorageService {
  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final ExchangeListStorageService _instance = ExchangeListStorageService._internal();
  
  factory ExchangeListStorageService() => _instance;
  
  ExchangeListStorageService._internal();
  
  /// 교체 리스트 저장
  /// 
  /// 매개변수:
  /// - `exchangeList`: 저장할 교체 리스트
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveExchangeList(List<ExchangeHistoryItem> exchangeList) async {
    try {
      // ExchangeHistoryItem 리스트를 JSON 배열로 변환
      final jsonArray = exchangeList.map((item) => item.toJson()).toList();
      
      // JSON 파일로 저장 (배열 형태)
      final success = await _storageService.saveJson('exchange_list.json', jsonArray);
      
      if (success) {
        AppLogger.info('교체 리스트 저장 성공: ${exchangeList.length}개 항목');
      } else {
        AppLogger.error('교체 리스트 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('교체 리스트 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// 교체 리스트 로드
  /// 
  /// 저장된 교체 리스트를 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<List<ExchangeHistoryItem>>`: 로드된 교체 리스트 (없으면 빈 리스트)
  Future<List<ExchangeHistoryItem>> loadExchangeList() async {
    try {
      // JSON 배열 파일 로드
      final jsonArray = await _storageService.loadJsonArray('exchange_list.json');
      
      if (jsonArray == null) {
        AppLogger.info('교체 리스트 파일이 없습니다.');
        return [];
      }
      
      // JSON 배열을 ExchangeHistoryItem 리스트로 변환
      final exchangeList = jsonArray
          .map((itemJson) {
            try {
              return ExchangeHistoryItem.fromJson(itemJson as Map<String, dynamic>);
            } catch (e) {
              AppLogger.error('교체 항목 역직렬화 실패: $e', e);
              return null;
            }
          })
          .whereType<ExchangeHistoryItem>()
          .toList();
      
      AppLogger.info('교체 리스트 로드 성공: ${exchangeList.length}개 항목');
      return exchangeList;
    } catch (e) {
      AppLogger.error('교체 리스트 로드 중 오류: $e', e);
      return [];
    }
  }
  
  /// 교체 리스트 삭제
  /// 
  /// 저장된 교체 리스트 파일을 삭제합니다.
  /// 
  /// 반환값:
  /// - `Future<bool>`: 삭제 성공 여부
  Future<bool> clearExchangeList() async {
    try {
      final success = await _storageService.deleteFile('exchange_list.json');
      if (success) {
        AppLogger.info('교체 리스트 삭제 성공');
      }
      return success;
    } catch (e) {
      AppLogger.error('교체 리스트 삭제 중 오류: $e', e);
      return false;
    }
  }
}


