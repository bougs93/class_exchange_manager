import 'dart:io';
import 'package:crypto/crypto.dart';
import 'storage_service.dart';
import 'excel_service.dart';
import 'timetable_registry_service.dart';
import '../utils/logger.dart';

/// 시간표 저장 서비스 설정값
class TimetableStorageConfig {
  static const int hashLength = 32; // SHA256 해시 길이
  static const int maxFileNameLength = 20; // 파일명 최대 길이
}

/// 시간표 데이터 저장 서비스
///
/// 시간표 데이터를 JSON 파일로 저장하고 로드합니다.
/// 파일명은 해시값(파일명 + 파일 내용의 SHA256 해시 32자) 기반으로 생성됩니다.
/// 같은 내용의 파일은 중복 저장을 방지하고 기존 데이터를 재사용합니다.
class TimetableStorageService {
  final StorageService _storageService = StorageService();

  // 싱글톤 인스턴스
  static final TimetableStorageService _instance =
      TimetableStorageService._internal();

  factory TimetableStorageService() => _instance;

  TimetableStorageService._internal();

  /// 파일 내용 기반 해시값 계산
  ///
  /// 파일의 실제 내용을 읽어서 SHA256 해시를 계산합니다.
  /// 같은 내용의 파일은 항상 같은 해시값을 반환합니다.
  ///
  /// 매개변수:
  /// - `filePath`: 엑셀 파일의 전체 경로
  ///
  /// 반환값:
  /// - `Future<String?>`: 파일 내용의 SHA256 해시 (32자), 실패 시 null
  Future<String?> calculateContentHash(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return null;
      }

      // 파일 내용 읽기
      final bytes = await file.readAsBytes();

      // SHA256 해시 계산
      final digest = sha256.convert(bytes);
      final hashString = digest.toString();

      // 32자만 사용 (충돌 확률이 매우 낮음)
      return hashString.substring(0, TimetableStorageConfig.hashLength);
    } catch (e) {
      AppLogger.error('파일 내용 해시 계산 실패: $e', e);
      return null;
    }
  }

  /// 파일명 기반 해시값 생성
  ///
  /// 파일명에서 안전한 문자열을 추출하여 해시와 함께 사용합니다.
  ///
  /// 매개변수:
  /// - `filePath`: 엑셀 파일의 전체 경로
  /// - `contentHash`: 파일 내용 기반 해시 (32자)
  ///
  /// 반환값:
  /// - `String`: 생성된 해시값 (예: "시간표2025_a1b2c3d4e5f6789012345678901234")
  String _generateHash(String filePath, String contentHash) {
    try {
      // 파일명 추출 (확장자 제거)
      final file = File(filePath);
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileNameWithoutExt = fileName.replaceAll(
        RegExp(r'\.(xlsx|xls)$'),
        '',
      );

      // 파일명에서 안전한 문자만 사용
      final safeFileName = fileNameWithoutExt
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(
            0,
            fileNameWithoutExt.length > TimetableStorageConfig.maxFileNameLength
                ? TimetableStorageConfig.maxFileNameLength
                : fileNameWithoutExt.length,
          );

      // 파일명 + 내용 해시 조합
      return '${safeFileName}_$contentHash';
    } catch (e) {
      AppLogger.error('해시 생성 실패: $e', e);
      // 실패 시 타임스탬프 기반 해시 사용
      return 'timetable_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// 시간표 데이터 저장 (레지스트리 모드)
  ///
  /// 파일 내용 기반 해시를 사용하여 저장합니다.
  /// 같은 내용의 파일이 이미 저장되어 있으면 기존 파일을 재사용하고 중복 저장을 방지합니다.
  /// 레거시 단일 메타데이터 파일은 기록하지 않습니다.
  ///
  /// 매개변수:
  /// - `timetableData`: 저장할 시간표 데이터
  /// - `filePath`: 원본 엑셀 파일 경로 (해시 생성용)
  /// - `fileName`: 원본 엑셀 파일명 (UI 표시용)
  ///
  /// 반환값:
  /// - `Future<({String hash, String contentHash})?>`: 생성/재사용된 해시 (실패 시 null)
  Future<({String hash, String contentHash})?> saveTimetableDataForRegistry(
    TimetableData timetableData,
    String filePath,
    String fileName,
  ) async {
    try {
      // 1. 파일 내용 기반 해시 계산 (32자)
      final contentHash = await calculateContentHash(filePath);
      if (contentHash == null) {
        AppLogger.error('파일 내용 해시 계산 실패: $filePath');
        return null;
      }

      // 2. 파일명 + 내용 해시로 최종 해시 생성
      final hash = _generateHash(filePath, contentHash);
      final filename = 'timetable_data_$hash.json';

      // 3. 중복 저장 방지: 같은 내용의 파일이 이미 있는지 확인
      final existingData = await _storageService.loadJson(filename);

      if (existingData != null) {
        AppLogger.info('같은 내용의 파일이 이미 저장되어 있습니다. 기존 데이터 재사용: $filename');
      } else {
        // 시간표 데이터를 JSON으로 변환
        final jsonData = timetableData.toJson();

        AppLogger.info(
          '시간표 데이터 저장: $filename (${timetableData.teachers.length}명, ${timetableData.timeSlots.length}개 슬롯)',
        );

        // JSON 파일로 저장
        final saveSuccess = await _storageService.saveJson(filename, jsonData);
        if (!saveSuccess) {
          AppLogger.error('시간표 데이터 저장 실패');
          return null;
        }
      }

      return (hash: hash, contentHash: contentHash);
    } catch (e) {
      AppLogger.error('시간표 데이터 저장 중 오류: $e', e);
      return null;
    }
  }

  /// 시간표 데이터 로드
  ///
  /// 레지스트리의 [timetableId] 항목에 해당하는 시간표 데이터를 로드합니다.
  ///
  /// 반환값:
  /// - `Future<TimetableData?>`: 로드된 시간표 데이터 (없으면 null)
  Future<TimetableData?> loadTimetableData({String? timetableId}) async {
    try {
      // 레지스트리 항목에서 해시값 찾기
      final metadata = await _resolveMetadata(timetableId: timetableId);
      if (metadata == null) {
        AppLogger.info('시간표 메타데이터가 없습니다. (timetableId: $timetableId)');
        return null;
      }

      final hash = metadata['hash'] as String?;
      if (hash == null || hash.isEmpty) {
        AppLogger.error('메타데이터에 해시값이 없습니다.');
        return null;
      }

      final filename = 'timetable_data_$hash.json';

      // JSON 파일 로드
      final jsonData = await _storageService.loadJson(filename);
      if (jsonData == null) {
        AppLogger.info('시간표 데이터 파일이 없습니다: $filename');
        return null;
      }

      // TimetableData로 변환
      final timetableData = TimetableData.fromJson(jsonData);

      AppLogger.info(
        '시간표 데이터 로드 성공: $filename (${timetableData.teachers.length}명, ${timetableData.timeSlots.length}개 슬롯)',
      );

      return timetableData;
    } catch (e) {
      AppLogger.error('시간표 데이터 로드 중 오류: $e', e);
      return null;
    }
  }

  /// 스코프에 대응하는 메타데이터 해석
  ///
  /// 레지스트리 항목에서 메타데이터를 구성합니다.
  /// [timetableId]가 없으면 null을 반환합니다 (레거시 폴백 없음).
  Future<Map<String, dynamic>?> _resolveMetadata({String? timetableId}) async {
    if (timetableId == null) {
      return null;
    }

    try {
      final entry = await TimetableRegistryService()
          .loadRegistry()
          .then((registry) => registry.getById(timetableId));
      if (entry == null) {
        AppLogger.warning('레지스트리에 없는 시간표 ID: $timetableId');
        return null;
      }
      return {
        'filePath': entry.filePath,
        'fileName': entry.fileName,
        'hash': entry.hash,
        'contentHash': entry.contentHash,
      };
    } catch (e) {
      AppLogger.error('레지스트리 메타데이터 해석 실패: $e', e);
      return null;
    }
  }

  /// 저장된 파일명 가져오기
  ///
  /// 매개변수:
  /// - `timetableId`: 시간표 ID (레지스트리 항목 기준)
  ///
  /// 반환값:
  /// - `Future<String?>`: 저장된 파일명 (없으면 null)
  Future<String?> getSavedFileName({String? timetableId}) async {
    try {
      final metadata = await _resolveMetadata(timetableId: timetableId);
      return metadata?['fileName'] as String?;
    } catch (e) {
      AppLogger.error('저장된 파일명 가져오기 실패: $e', e);
      return null;
    }
  }

  /// 저장된 파일 경로 가져오기
  ///
  /// 매개변수:
  /// - `timetableId`: 시간표 ID (레지스트리 항목 기준)
  ///
  /// 반환값:
  /// - `Future<String?>`: 저장된 파일 경로 (없으면 null)
  Future<String?> getSavedFilePath({String? timetableId}) async {
    try {
      final metadata = await _resolveMetadata(timetableId: timetableId);
      return metadata?['filePath'] as String?;
    } catch (e) {
      AppLogger.error('저장된 파일 경로 가져오기 실패: $e', e);
      return null;
    }
  }
}
