import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'storage_service.dart';
import 'excel_service.dart';
import '../utils/logger.dart';

/// 시간표 데이터 저장 서비스
/// 
/// 시간표 데이터를 JSON 파일로 저장하고 로드합니다.
/// 파일명은 해시값(파일 경로 일부 + SHA256 해시) 기반으로 생성됩니다.
class TimetableStorageService {
  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final TimetableStorageService _instance = TimetableStorageService._internal();
  
  factory TimetableStorageService() => _instance;
  
  TimetableStorageService._internal();
  
  /// 파일 경로에서 해시값 생성
  /// 
  /// 해시값은 파일 경로 일부 + 전체 경로의 SHA256 해시로 구성됩니다.
  /// 예: 파일명 "시간표2025.xlsx" 경로 일부 + 해시값 일부
  /// 
  /// 매개변수:
  /// - `filePath`: 엑셀 파일의 전체 경로
  /// 
  /// 반환값:
  /// - `String`: 생성된 해시값 (예: "시간표2025_abc123def456")
  String _generateHash(String filePath) {
    try {
      // 파일 경로 일부 추출 (파일명에서 확장자 제거)
      final file = File(filePath);
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileNameWithoutExt = fileName.replaceAll(RegExp(r'\.(xlsx|xls)$'), '');
      
      // 파일 경로의 SHA256 해시 생성
      final bytes = utf8.encode(filePath);
      final digest = sha256.convert(bytes);
      final hashString = digest.toString().substring(0, 12); // 처음 12자만 사용
      
      // 파일명(안전한 문자만) + 해시값 조합
      // 파일명에서 특수문자 제거하고 안전한 문자만 사용
      final safeFileName = fileNameWithoutExt
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(0, fileNameWithoutExt.length > 20 ? 20 : fileNameWithoutExt.length);
      
      return '${safeFileName}_$hashString';
    } catch (e) {
      AppLogger.error('해시 생성 실패: $e', e);
      // 실패 시 타임스탬프 기반 해시 사용
      return 'timetable_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// 시간표 데이터 저장
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
      // 해시 기반 파일명 생성
      final hash = _generateHash(filePath);
      final filename = 'timetable_data_$hash.json';
      
      // 시간표 데이터를 JSON으로 변환
      final jsonData = timetableData.toJson();
      
      // 데이터 검증 로그 추가
      AppLogger.info('시간표 데이터 저장 시작: $filename');
      AppLogger.info('저장할 데이터: ${timetableData.teachers.length}명 교사, ${timetableData.timeSlots.length}개 TimeSlot');
      
      // 비어있지 않은 TimeSlot 개수 확인
      final nonEmptySlots = timetableData.timeSlots.where((slot) => slot.isNotEmpty).length;
      AppLogger.info('수업이 있는 TimeSlot: $nonEmptySlots개 / 전체 ${timetableData.timeSlots.length}개');
      
      // JSON 파일로 저장
      final success = await _storageService.saveJson(filename, jsonData);
      
      if (success) {
        // 메타데이터도 별도로 저장 (파일 경로, 파일명, 수정 시간)
        await _saveFileMetadata(filePath, fileName, hash);
        AppLogger.info('시간표 데이터 저장 성공: $filename');
      } else {
        AppLogger.error('시간표 데이터 저장 실패');
      }
      
      return success;
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
      
      // 샘플 TimeSlot 확인 (최대 5개)
      final sampleSlots = timetableData.timeSlots.where((slot) => slot.isNotEmpty).take(5).toList();
      AppLogger.info('TimeSlot 샘플 (최대 5개):');
      for (var slot in sampleSlots) {
        AppLogger.info('  - teacher=${slot.teacher}, dayOfWeek=${slot.dayOfWeek}, period=${slot.period}, subject=${slot.subject}, className=${slot.className}');
      }
      
      return timetableData;
    } catch (e) {
      AppLogger.error('시간표 데이터 로드 중 오류: $e', e);
      return null;
    }
  }
  
  /// 파일 메타데이터 저장
  /// 
  /// 엑셀 파일 경로, 파일명, 수정 시간, 해시값을 저장합니다.
  Future<void> _saveFileMetadata(String filePath, String fileName, String hash) async {
    try {
      final file = File(filePath);
      final lastModified = await file.lastModified();
      
      final metadata = {
        'filePath': filePath,
        'fileName': fileName,
        'lastModified': lastModified.toIso8601String(),
        'hash': hash,
      };
      
      await _storageService.saveJson('timetable_file_metadata.json', metadata);
      AppLogger.info('파일 메타데이터 저장 성공');
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
  
  /// 엑셀 파일의 수정 시간과 저장된 수정 시간 비교
  /// 
  /// 매개변수:
  /// - `filePath`: 비교할 엑셀 파일 경로
  /// 
  /// 반환값:
  /// - `Future<bool>`: 수정 시간이 다르면 true (파일이 변경됨), 같거나 메타데이터가 없으면 false
  Future<bool> isFileModified(String filePath) async {
    try {
      final metadata = await _loadFileMetadata();
      if (metadata == null) {
        // 메타데이터가 없으면 파일이 변경된 것으로 간주하지 않음 (새 파일)
        return false;
      }
      
      final savedFilePath = metadata['filePath'] as String?;
      if (savedFilePath != filePath) {
        // 파일 경로가 다르면 다른 파일로 간주
        return true;
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      
      final currentLastModified = await file.lastModified();
      final savedLastModifiedStr = metadata['lastModified'] as String?;
      
      if (savedLastModifiedStr == null) {
        return false;
      }
      
      final savedLastModified = DateTime.parse(savedLastModifiedStr);
      
      // 수정 시간이 다르면 true 반환
      return currentLastModified != savedLastModified;
    } catch (e) {
      AppLogger.error('파일 수정 시간 비교 실패: $e', e);
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
}


