import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// 기본 저장소 서비스 클래스
/// JSON 파일 읽기/쓰기 유틸리티를 제공합니다.
class StorageService {
  // 싱글톤 인스턴스
  static final StorageService _instance = StorageService._internal();
  
  // 싱글톤 생성자
  factory StorageService() => _instance;
  
  // 내부 생성자
  StorageService._internal();
  
  /// 앱 데이터 디렉토리 경로를 반환합니다.
  /// 
  /// Windows: %APPDATA%\com.example.class_exchange_manager
  /// 기타 플랫폼: 플랫폼별 앱 데이터 디렉토리
  Future<Directory> _getAppDataDirectory() async {
    try {
      // 앱 문서 디렉토리 가져오기
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      AppLogger.error('앱 데이터 디렉토리 가져오기 실패: $e', e);
      rethrow;
    }
  }
  
  /// 파일의 전체 경로를 생성합니다.
  /// 
  /// 매개변수:
  /// - `filename`: 파일명 (예: "timetable_data.json")
  /// 
  /// 반환값:
  /// - `String`: 전체 파일 경로
  Future<String> _getFilePath(String filename) async {
    final directory = await _getAppDataDirectory();
    return '${directory.path}${Platform.pathSeparator}$filename';
  }
  
  /// JSON 데이터를 파일에 저장합니다.
  /// 
  /// 매개변수:
  /// - `filename`: 저장할 파일명
  /// - `data`: 저장할 데이터 (Map 또는 List)
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부 (true: 성공, false: 실패)
  /// 
  /// 예외:
  /// - 저장 실패 시 예외를 throw하지 않고 false를 반환합니다.
  Future<bool> saveJson(String filename, dynamic data) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);
      
      // JSON 문자열로 변환
      final jsonString = jsonEncode(data);
      
      // 파일에 쓰기
      await file.writeAsString(jsonString, encoding: utf8);
      
      AppLogger.info('JSON 파일 저장 성공: $filename');
      return true;
    } catch (e) {
      AppLogger.error('JSON 파일 저장 실패: $filename, 오류: $e', e);
      return false;
    }
  }
  
  /// JSON 파일에서 데이터를 로드합니다.
  /// 
  /// 매개변수:
  /// - `filename`: 로드할 파일명
  /// 
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: 로드된 데이터 (실패 또는 파일 없음 시 null)
  /// 
  /// 예외:
  /// - 파일이 없거나 읽기 실패 시 null을 반환합니다.
  Future<Map<String, dynamic>?> loadJson(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);
      
      // 파일 존재 여부 확인
      if (!await file.exists()) {
        AppLogger.info('JSON 파일이 존재하지 않음: $filename');
        return null;
      }
      
      // 파일 읽기
      final jsonString = await file.readAsString(encoding: utf8);
      
      // JSON 파싱
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      AppLogger.info('JSON 파일 로드 성공: $filename');
      return data;
    } catch (e) {
      AppLogger.error('JSON 파일 로드 실패: $filename, 오류: $e', e);
      return null;
    }
  }
  
  /// JSON 배열 파일에서 데이터를 로드합니다.
  /// 
  /// 매개변수:
  /// - `filename`: 로드할 파일명
  /// 
  /// 반환값:
  /// - `Future<List<dynamic>?>`: 로드된 배열 데이터 (실패 또는 파일 없음 시 null)
  /// 
  /// 예외:
  /// - 파일이 없거나 읽기 실패 시 null을 반환합니다.
  Future<List<dynamic>?> loadJsonArray(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);
      
      // 파일 존재 여부 확인
      if (!await file.exists()) {
        AppLogger.info('JSON 배열 파일이 존재하지 않음: $filename');
        return null;
      }
      
      // 파일 읽기
      final jsonString = await file.readAsString(encoding: utf8);
      
      // JSON 파싱
      final data = jsonDecode(jsonString) as List<dynamic>;
      
      AppLogger.info('JSON 배열 파일 로드 성공: $filename');
      return data;
    } catch (e) {
      AppLogger.error('JSON 배열 파일 로드 실패: $filename, 오류: $e', e);
      return null;
    }
  }
  
  /// 파일이 존재하는지 확인합니다.
  /// 
  /// 매개변수:
  /// - `filename`: 확인할 파일명
  /// 
  /// 반환값:
  /// - `Future<bool>`: 파일 존재 여부
  Future<bool> fileExists(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      AppLogger.error('파일 존재 확인 실패: $filename, 오류: $e', e);
      return false;
    }
  }
  
  /// 파일을 삭제합니다.
  /// 
  /// 매개변수:
  /// - `filename`: 삭제할 파일명
  /// 
  /// 반환값:
  /// - `Future<bool>`: 삭제 성공 여부
  Future<bool> deleteFile(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        AppLogger.info('파일 삭제 성공: $filename');
        return true;
      }
      
      return false;
    } catch (e) {
      AppLogger.error('파일 삭제 실패: $filename, 오류: $e', e);
      return false;
    }
  }
  
  /// 앱 데이터 디렉토리의 모든 JSON 파일 목록을 반환합니다.
  /// 
  /// 반환값:
  /// - `Future<List<String>>`: 파일명 목록
  Future<List<String>> listJsonFiles() async {
    try {
      final directory = await _getAppDataDirectory();
      final files = directory.listSync();
      
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .map((file) => file.path.split(Platform.pathSeparator).last)
          .toList();
    } catch (e) {
      AppLogger.error('JSON 파일 목록 조회 실패: $e', e);
      return [];
    }
  }
}


