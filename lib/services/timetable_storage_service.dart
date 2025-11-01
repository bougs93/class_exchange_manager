import 'dart:io';
import 'package:crypto/crypto.dart';
import 'storage_service.dart';
import 'excel_service.dart';
import '../utils/logger.dart';

/// 시간표 데이터 저장 서비스
/// 
/// 시간표 데이터를 JSON 파일로 저장하고 로드합니다.
/// 파일명은 해시값(파일명 + 파일 내용의 SHA256 해시 32자) 기반으로 생성됩니다.
/// 같은 내용의 파일은 중복 저장을 방지하고 기존 데이터를 재사용합니다.
class TimetableStorageService {
  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final TimetableStorageService _instance = TimetableStorageService._internal();
  
  factory TimetableStorageService() => _instance;
  
  TimetableStorageService._internal();
  
  /// 파일 내용 기반 해시값 계산 (public)
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
      return hashString.substring(0, 32);
    } catch (e) {
      AppLogger.error('파일 내용 해시 계산 실패: $e', e);
      return null;
    }
  }
  
  /// 파일 내용 기반 해시값 계산 (private - 내부 사용)
  /// 
  /// 파일의 실제 내용을 읽어서 SHA256 해시를 계산합니다.
  /// 같은 내용의 파일은 항상 같은 해시값을 반환합니다.
  /// 
  /// 매개변수:
  /// - `filePath`: 엑셀 파일의 전체 경로
  /// 
  /// 반환값:
  /// - `Future<String>`: 파일 내용의 SHA256 해시 (32자)
  /// 
  /// 예외:
  /// - 파일이 없거나 읽기 실패 시 예외를 throw합니다.
  Future<String> _calculateContentHash(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('파일이 존재하지 않습니다: $filePath');
      }
      
      // 파일 내용 읽기
      final bytes = await file.readAsBytes();
      
      // SHA256 해시 계산
      final digest = sha256.convert(bytes);
      final hashString = digest.toString();
      
      // 32자만 사용 (충돌 확률이 매우 낮음)
      return hashString.substring(0, 32);
    } catch (e) {
      AppLogger.error('파일 내용 해시 계산 실패: $e', e);
      rethrow;
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
      final fileNameWithoutExt = fileName.replaceAll(RegExp(r'\.(xlsx|xls)$'), '');
      
      // 파일명에서 안전한 문자만 사용
      final safeFileName = fileNameWithoutExt
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(0, fileNameWithoutExt.length > 20 ? 20 : fileNameWithoutExt.length);
      
      // 파일명 + 내용 해시 조합
      return '${safeFileName}_$contentHash';
    } catch (e) {
      AppLogger.error('해시 생성 실패: $e', e);
      // 실패 시 타임스탬프 기반 해시 사용
      return 'timetable_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// 시간표 데이터 저장
  /// 
  /// 파일 내용 기반 해시를 사용하여 저장합니다.
  /// 같은 내용의 파일이 이미 저장되어 있으면 기존 파일을 재사용하고 중복 저장을 방지합니다.
  /// 
  /// 매개변수:
  /// - `timetableData`: 저장할 시간표 데이터
  /// - `filePath`: 원본 엑셀 파일 경로 (해시 생성용)
  /// - `fileName`: 원본 엑셀 파일명 (UI 표시용)
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveTimetableData(
    TimetableData timetableData,
    String filePath,
    String fileName,
  ) async {
    try {
      // 1. 파일 내용 기반 해시 계산 (32자)
      final contentHash = await _calculateContentHash(filePath);
      
      // 2. 파일명 + 내용 해시로 최종 해시 생성
      final hash = _generateHash(filePath, contentHash);
      final filename = 'timetable_data_$hash.json';
      
      // 3. 중복 저장 방지: 같은 내용의 파일이 이미 있는지 확인
      final existingData = await _storageService.loadJson(filename);
      bool isReusingExisting = existingData != null;
      
      if (isReusingExisting) {
        AppLogger.info('같은 내용의 파일이 이미 저장되어 있습니다. 기존 데이터 재사용: $filename');
        // 기존 데이터가 있으면 JSON 저장을 건너뛰고 메타데이터만 업데이트
      } else {
        // 시간표 데이터를 JSON으로 변환
        final jsonData = timetableData.toJson();
        
        // 데이터 검증 로그 추가
        AppLogger.info('시간표 데이터 저장 시작: $filename');
        AppLogger.info('저장할 데이터: ${timetableData.teachers.length}명 교사, ${timetableData.timeSlots.length}개 TimeSlot');
        
        // 비어있지 않은 TimeSlot 개수 확인
        final nonEmptySlots = timetableData.timeSlots.where((slot) => slot.isNotEmpty).length;
        AppLogger.info('수업이 있는 TimeSlot: $nonEmptySlots개 / 전체 ${timetableData.timeSlots.length}개');
        
        // 교체불가 셀 개수 확인
        final nonExchangeableSlots = timetableData.timeSlots.where((slot) => 
          !slot.isExchangeable && slot.exchangeReason == '교체불가'
        ).toList();
        AppLogger.info('교체불가 셀 개수: ${nonExchangeableSlots.length}개');
        if (nonExchangeableSlots.isNotEmpty) {
          AppLogger.info('교체불가 셀 샘플 (최대 5개):');
          for (var slot in nonExchangeableSlots.take(5)) {
            AppLogger.info('  - teacher=${slot.teacher}, dayOfWeek=${slot.dayOfWeek}, period=${slot.period}, isExchangeable=${slot.isExchangeable}, exchangeReason=${slot.exchangeReason}');
          }
        }
        
        // JSON 파일로 저장 (새 파일만)
        final saveSuccess = await _storageService.saveJson(filename, jsonData);
        if (!saveSuccess) {
          AppLogger.error('시간표 데이터 저장 실패');
          return false;
        }
        AppLogger.info('시간표 데이터 저장 완료: $filename');
      }
      
      // 4. 메타데이터 저장 (기존 파일 재사용이든 새 저장이든 항상 업데이트)
      await _saveFileMetadata(filePath, fileName, hash, contentHash);
      
      return true;
    } catch (e) {
      AppLogger.error('시간표 데이터 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// 시간표 데이터 로드
  /// 
  /// 저장된 시간표 데이터를 로드합니다.
  /// 메타데이터에서 해시값을 찾아 해당 파일을 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<TimetableData?>`: 로드된 시간표 데이터 (없으면 null)
  Future<TimetableData?> loadTimetableData() async {
    try {
      // 메타데이터에서 해시값 찾기
      final metadata = await _loadFileMetadata();
      if (metadata == null) {
        AppLogger.info('시간표 메타데이터가 없습니다.');
        return null;
      }
      
      final hash = metadata['hash'] as String?;
      if (hash == null) {
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
      
      // 데이터 검증 로그 추가
      AppLogger.info('시간표 데이터 로드 성공: $filename');
      AppLogger.info('로드된 데이터: ${timetableData.teachers.length}명 교사, ${timetableData.timeSlots.length}개 TimeSlot');
      
      // 비어있지 않은 TimeSlot 개수 확인
      final nonEmptySlots = timetableData.timeSlots.where((slot) => slot.isNotEmpty).length;
      AppLogger.info('수업이 있는 TimeSlot: $nonEmptySlots개 / 전체 ${timetableData.timeSlots.length}개');
      
      // 교체불가 셀 개수 확인
      final nonExchangeableSlots = timetableData.timeSlots.where((slot) => 
        !slot.isExchangeable && slot.exchangeReason == '교체불가'
      ).toList();
      AppLogger.info('교체불가 셀 개수: ${nonExchangeableSlots.length}개');
      if (nonExchangeableSlots.isNotEmpty) {
        AppLogger.info('교체불가 셀 샘플 (최대 5개):');
        for (var slot in nonExchangeableSlots.take(5)) {
          AppLogger.info('  - teacher=${slot.teacher}, dayOfWeek=${slot.dayOfWeek}, period=${slot.period}, isExchangeable=${slot.isExchangeable}, exchangeReason=${slot.exchangeReason}');
        }
      }
      
      // 샘플 TimeSlot 확인 (최대 5개)
      final sampleSlots = timetableData.timeSlots.where((slot) => slot.isNotEmpty).take(5).toList();
      AppLogger.info('TimeSlot 샘플 (최대 5개):');
      for (var slot in sampleSlots) {
        AppLogger.info('  - teacher=${slot.teacher}, dayOfWeek=${slot.dayOfWeek}, period=${slot.period}, subject=${slot.subject}, className=${slot.className}, isExchangeable=${slot.isExchangeable}');
      }
      
      return timetableData;
    } catch (e) {
      AppLogger.error('시간표 데이터 로드 중 오류: $e', e);
      return null;
    }
  }
  
  /// 파일 메타데이터 저장
  /// 
  /// 엑셀 파일 경로, 파일명, 수정 시간, 해시값, 내용 해시를 저장합니다.
  /// 
  /// 매개변수:
  /// - `filePath`: 원본 엑셀 파일 경로
  /// - `fileName`: 원본 엑셀 파일명
  /// - `hash`: 파일명 + 내용 해시 조합
  /// - `contentHash`: 파일 내용 기반 해시 (32자)
  Future<void> _saveFileMetadata(
    String filePath,
    String fileName,
    String hash,
    String contentHash,
  ) async {
    try {
      final file = File(filePath);
      final lastModified = await file.lastModified();
      
      final metadata = {
        'filePath': filePath,
        'fileName': fileName,
        'lastModified': lastModified.toIso8601String(),
        'hash': hash,              // 파일명 + 내용 해시 (파일명 생성용)
        'contentHash': contentHash, // 내용 해시만 (무결성 검증용)
      };
      
      await _storageService.saveJson('timetable_file_metadata.json', metadata);
      AppLogger.info('파일 메타데이터 저장 성공 (내용 해시: ${contentHash.substring(0, 8)}...)');
    } catch (e) {
      AppLogger.error('파일 메타데이터 저장 실패: $e', e);
    }
  }
  
  /// 파일 메타데이터 로드
  /// 
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: 메타데이터 (없으면 null)
  Future<Map<String, dynamic>?> _loadFileMetadata() async {
    try {
      return await _storageService.loadJson('timetable_file_metadata.json');
    } catch (e) {
      AppLogger.error('파일 메타데이터 로드 실패: $e', e);
      return null;
    }
  }
  
  /// 파일 메타데이터 가져오기 (public)
  /// 
  /// 다른 서비스에서 해시값을 가져올 때 사용합니다.
  /// 
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: 메타데이터 (없으면 null)
  Future<Map<String, dynamic>?> getFileMetadata() async {
    return await _loadFileMetadata();
  }
  
  /// 엑셀 파일이 변경되었는지 확인 (내용 기반 해시 사용)
  /// 
  /// 파일 내용 기반 해시를 사용하여 파일이 변경되었는지 확인합니다.
  /// 경로와 관계없이 같은 내용이면 변경되지 않은 것으로 간주합니다.
  /// 
  /// 매개변수:
  /// - `filePath`: 비교할 엑셀 파일 경로
  /// 
  /// 반환값:
  /// - `Future<bool>`: 내용이 다르면 true (파일이 변경됨), 같거나 메타데이터가 없으면 false
  Future<bool> isFileModified(String filePath) async {
    try {
      final metadata = await _loadFileMetadata();
      if (metadata == null) {
        // 메타데이터가 없으면 파일이 변경된 것으로 간주하지 않음 (새 파일)
        return false;
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      
      // 현재 파일의 내용 해시 계산
      final currentContentHash = await _calculateContentHash(filePath);
      
      // 저장된 내용 해시와 비교
      final savedContentHash = metadata['contentHash'] as String?;
      
      if (savedContentHash == null) {
        // 기존 메타데이터에 내용 해시가 없으면 (구버전)
        // 수정 시간으로 대체 비교
        final currentLastModified = await file.lastModified();
        final savedLastModifiedStr = metadata['lastModified'] as String?;
        
        if (savedLastModifiedStr == null) {
          return false;
        }
        
        final savedLastModified = DateTime.parse(savedLastModifiedStr);
        return currentLastModified != savedLastModified;
      }
      
      // 내용 해시 비교 (같으면 false, 다르면 true)
      final isModified = currentContentHash != savedContentHash;
      
      if (isModified) {
        AppLogger.info('파일 내용이 변경되었습니다. (기존 해시: ${savedContentHash.substring(0, 8)}..., 현재 해시: ${currentContentHash.substring(0, 8)}...)');
      }
      
      return isModified;
    } catch (e) {
      AppLogger.error('파일 변경 확인 실패: $e', e);
      return false;
    }
  }
  
  /// 저장된 파일명 가져오기
  /// 
  /// 반환값:
  /// - `Future<String?>`: 저장된 파일명 (없으면 null)
  Future<String?> getSavedFileName() async {
    try {
      final metadata = await _loadFileMetadata();
      return metadata?['fileName'] as String?;
    } catch (e) {
      AppLogger.error('저장된 파일명 가져오기 실패: $e', e);
      return null;
    }
  }
  
  /// 저장된 파일 경로 가져오기
  /// 
  /// 반환값:
  /// - `Future<String?>`: 저장된 파일 경로 (없으면 null)
  Future<String?> getSavedFilePath() async {
    try {
      final metadata = await _loadFileMetadata();
      return metadata?['filePath'] as String?;
    } catch (e) {
      AppLogger.error('저장된 파일 경로 가져오기 실패: $e', e);
      return null;
    }
  }
  
  /// 저장된 내용 해시와 현재 파일의 내용 해시 비교
  /// 
  /// 현재 파일의 내용 해시와 저장된 내용 해시를 비교하여
  /// 동일한 내용의 파일인지 확인합니다.
  /// 
  /// 매개변수:
  /// - `filePath`: 비교할 엑셀 파일 경로
  /// 
  /// 반환값:
  /// - `Future<bool?>`: 동일하면 true, 다르면 false, 비교 불가능하면 null
  Future<bool?> isSameContent(String filePath) async {
    try {
      final metadata = await _loadFileMetadata();
      if (metadata == null) {
        return null; // 메타데이터가 없으면 비교 불가능
      }
      
      final savedContentHash = metadata['contentHash'] as String?;
      if (savedContentHash == null) {
        return null; // 내용 해시가 없으면 비교 불가능 (구버전 데이터)
      }
      
      final currentContentHash = await calculateContentHash(filePath);
      if (currentContentHash == null) {
        return null; // 현재 파일의 해시를 계산할 수 없음
      }
      
      return currentContentHash == savedContentHash;
    } catch (e) {
      AppLogger.error('내용 해시 비교 실패: $e', e);
      return null;
    }
  }
}


