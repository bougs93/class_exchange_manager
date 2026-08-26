import 'storage_service.dart';
import '../models/exchange_history_item.dart';
import '../utils/logger.dart';

/// 교체 리스트 저장 서비스
///
/// 교체 리스트를 시간표별 파일(`exchange_list_{timetableId}.json`)로 저장합니다.
/// [timetableId]를 지정하지 않으면 기존 전역 파일(`exchange_list.json`)을 사용합니다.
///
/// 시간표 안의 교체 목록은 모든 교사·계획서가 공유하는
/// 누적 교체 상태(단일 진실원본)입니다.
class ExchangeListStorageService {
  /// 전역 파일명 (레거시 호환)
  static const String legacyFilename = 'exchange_list.json';

  /// 시간표별 파일명
  static String fileNameFor(String timetableId) =>
      'exchange_list_$timetableId.json';

  final StorageService _storageService = StorageService();

  // 싱글톤 인스턴스
  static final ExchangeListStorageService _instance =
      ExchangeListStorageService._internal();

  factory ExchangeListStorageService() => _instance;

  ExchangeListStorageService._internal();

  /// 스코프에 대응하는 파일명
  static String _resolveFilename(String? timetableId) =>
      timetableId != null ? fileNameFor(timetableId) : legacyFilename;

  /// 교체 리스트 저장
  ///
  /// 매개변수:
  /// - `exchangeList`: 저장할 교체 리스트
  /// - `timetableId`: 시간표 ID (미지정 시 레거시 전역 파일)
  ///
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveExchangeList(
    List<ExchangeHistoryItem> exchangeList, {
    String? timetableId,
  }) async {
    final filename = _resolveFilename(timetableId);
    try {
      // ExchangeHistoryItem 리스트를 JSON 배열로 변환
      final jsonArray = exchangeList.map((item) => item.toJson()).toList();

      // JSON 파일로 저장 (배열 형태)
      final success = await _storageService.saveJson(filename, jsonArray);

      if (success) {
        AppLogger.info('교체 리스트 저장 성공: $filename (${exchangeList.length}개 항목)');
      } else {
        AppLogger.error('교체 리스트 저장 실패: $filename');
      }

      return success;
    } catch (e) {
      AppLogger.error('교체 리스트 저장 중 오류 ($filename): $e', e);
      return false;
    }
  }

  /// 교체 리스트 로드
  ///
  /// 매개변수:
  /// - `timetableId`: 시간표 ID (미지정 시 레거시 전역 파일)
  ///
  /// 반환값:
  /// - `Future<List<ExchangeHistoryItem>>`: 로드된 교체 리스트 (없으면 빈 리스트)
  Future<List<ExchangeHistoryItem>> loadExchangeList({String? timetableId}) async {
    final filename = _resolveFilename(timetableId);
    try {
      // JSON 배열 파일 로드
      final jsonArray = await _storageService.loadJsonArray(filename);

      if (jsonArray == null) {
        AppLogger.info('교체 리스트 파일이 없습니다: $filename');
        return [];
      }

      // JSON 배열을 ExchangeHistoryItem 리스트로 변환
      final exchangeList =
          jsonArray
              .map((itemJson) {
                try {
                  return ExchangeHistoryItem.fromJson(
                    itemJson as Map<String, dynamic>,
                  );
                } catch (e) {
                  AppLogger.error('교체 항목 역직렬화 실패: $e', e);
                  return null;
                }
              })
              .whereType<ExchangeHistoryItem>()
              .toList();

      AppLogger.info('교체 리스트 로드 성공: $filename (${exchangeList.length}개 항목)');
      return exchangeList;
    } catch (e) {
      AppLogger.error('교체 리스트 로드 중 오류 ($filename): $e', e);
      return [];
    }
  }

  /// 교체 리스트 삭제
  ///
  /// 매개변수:
  /// - `timetableId`: 시간표 ID (미지정 시 레거시 전역 파일)
  ///
  /// 반환값:
  /// - `Future<bool>`: 삭제 성공 여부
  Future<bool> clearExchangeList({String? timetableId}) async {
    final filename = _resolveFilename(timetableId);
    try {
      final success = await _storageService.deleteFile(filename);
      if (success) {
        AppLogger.info('교체 리스트 삭제 성공: $filename');
      }
      return success;
    } catch (e) {
      AppLogger.error('교체 리스트 삭제 중 오류 ($filename): $e', e);
      return false;
    }
  }
}
