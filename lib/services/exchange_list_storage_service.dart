import 'json_storage.dart';
import 'storage_service.dart';
import '../models/exchange_history_item.dart';
import '../utils/logger.dart';

/// 교체 리스트 로드 결과
///
/// [legacyBackupPerformed]가 true면 구 스키마(날짜 필드 없음) 파일을 발견해
/// `.v1.bak`으로 백업하고 빈 목록으로 시작했다는 뜻이다. 호출부(Provider 계층)는
/// 이 플래그로 "왜 교체 목록이 비었는지" 사용자에게 1회 안내해야 한다(§10.6).
class ExchangeListLoadResult {
  final List<ExchangeHistoryItem> items;
  final bool legacyBackupPerformed;

  const ExchangeListLoadResult({
    required this.items,
    required this.legacyBackupPerformed,
  });
}

/// 교체 리스트 저장 서비스
///
/// 교체 리스트를 시간표별 파일(`exchange_list_{timetableId}.json`)로 저장합니다.
/// 시간표 안의 교체 목록은 모든 교사·계획서가 공유하는
/// 누적 교체 상태(단일 진실원본)입니다.
///
/// §10.6: 파일은 `{ "schemaVersion": 2, "items": [...] }` 형태의 객체로
/// 저장한다. 구 버전(§1~§9)은 최상위가 배열이었으므로, 객체 파싱 실패 자체가
/// "구 스키마"의 신호가 된다. 구 데이터는 마이그레이션하지 않고 백업 후
/// 빈 목록으로 시작한다(마이그레이션 없음 정책).
class ExchangeListStorageService {
  /// 현재 스키마 버전. `absenceDate`/`substitutionDate`가 필수가 된 시점(§10)에 2로 승격.
  static const int currentSchemaVersion = 2;

  /// 구 스키마 파일 백업 접미사
  static const String legacyBackupSuffix = '.v1.bak';

  /// 시간표별 파일명
  static String fileNameFor(String timetableId) =>
      'exchange_list_$timetableId.json';

  final JsonStorage _storage;

  /// [storage] 미지정 시 실제 파일 저장소([StorageService]) 사용.
  /// [StorageService] 자체가 내부적으로 싱글톤이므로 인자 없이 매번 새로
  /// 생성해도 파일 I/O는 항상 같은 하부 인스턴스로 향한다.
  ExchangeListStorageService({JsonStorage? storage})
    : _storage = storage ?? StorageService();

  /// 교체 리스트 저장
  ///
  /// 매개변수:
  /// - `exchangeList`: 저장할 교체 리스트
  /// - `timetableId`: 시간표 ID (필수 — 없으면 저장 건너뜀)
  ///
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveExchangeList(
    List<ExchangeHistoryItem> exchangeList, {
    required String? timetableId,
  }) async {
    if (timetableId == null || timetableId.isEmpty) {
      AppLogger.warning('시간표 스코프가 없어 교체 리스트 저장을 건너뜁니다.');
      return false;
    }
    final filename = fileNameFor(timetableId);
    try {
      final payload = {
        'schemaVersion': currentSchemaVersion,
        'items': exchangeList.map((item) => item.toJson()).toList(),
      };

      final success = await _storage.saveJson(filename, payload);

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
  /// - `timetableId`: 시간표 ID (필수 — 없으면 빈 결과 반환)
  ///
  /// 반환값:
  /// - `Future<ExchangeListLoadResult>`: 로드된 교체 리스트 + 구 데이터 백업 여부
  Future<ExchangeListLoadResult> loadExchangeList({
    required String? timetableId,
  }) async {
    if (timetableId == null || timetableId.isEmpty) {
      AppLogger.warning('시간표 스코프가 없어 교체 리스트 로드를 건너뜁니다.');
      return const ExchangeListLoadResult(
        items: [],
        legacyBackupPerformed: false,
      );
    }
    final filename = fileNameFor(timetableId);
    try {
      final data = await _storage.loadJson(filename);

      if (data != null) {
        final schemaVersion = data['schemaVersion'];
        if (schemaVersion is int && schemaVersion >= currentSchemaVersion) {
          final itemsJson = data['items'];
          final items =
              (itemsJson is List ? itemsJson : const [])
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

          AppLogger.info('교체 리스트 로드 성공: $filename (${items.length}개 항목)');
          return ExchangeListLoadResult(
            items: items,
            legacyBackupPerformed: false,
          );
        }
      }

      // 여기 도달 = 새 스키마로 파싱 실패. 파일이 아예 없는 것(정상 첫 실행)과
      // 구 스키마 파일이 있는 것(백업 필요)을 구분해야 한다.
      final exists = await _storage.fileExists(filename);
      if (!exists) {
        return const ExchangeListLoadResult(
          items: [],
          legacyBackupPerformed: false,
        );
      }

      final backupName = '$filename$legacyBackupSuffix';
      final backedUp = await _storage.renameFile(filename, backupName);
      if (backedUp) {
        AppLogger.warning(
          '구 버전(날짜 정보 없음) 교체 목록을 감지해 백업 후 빈 목록으로 시작합니다: '
          '$filename → $backupName',
        );
      } else {
        AppLogger.error('구 버전 교체 목록 백업 실패, 원본 파일은 그대로 둡니다: $filename');
      }
      return ExchangeListLoadResult(
        items: const [],
        legacyBackupPerformed: backedUp,
      );
    } catch (e) {
      AppLogger.error('교체 리스트 로드 중 오류 ($filename): $e', e);
      return const ExchangeListLoadResult(
        items: [],
        legacyBackupPerformed: false,
      );
    }
  }

  /// 교체 리스트 삭제
  ///
  /// 매개변수:
  /// - `timetableId`: 시간표 ID (필수 — 없으면 건너뜀)
  ///
  /// 반환값:
  /// - `Future<bool>`: 삭제 성공 여부
  Future<bool> clearExchangeList({required String? timetableId}) async {
    if (timetableId == null || timetableId.isEmpty) {
      AppLogger.warning('시간표 스코프가 없어 교체 리스트 삭제를 건너뜁니다.');
      return false;
    }
    final filename = fileNameFor(timetableId);
    try {
      final success = await _storage.deleteFile(filename);
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
