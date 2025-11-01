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
  /// getApplicationSupportDirectory()는 크로스 플랫폼 함수로,
  /// 각 플랫폼에 맞는 적절한 디렉토리를 자동으로 반환합니다.
  /// 별도의 플랫폼별 설정 없이 공통 코드로 사용 가능합니다.
  /// 
  /// 폴더명 결정 방법:
  /// path_provider는 각 플랫폼의 앱 식별자(패키지명/번들 ID)를 자동으로 읽어서
  /// 폴더명으로 사용합니다. 각 플랫폼별 설정 파일에서 확인/변경 가능합니다.
  /// 
  /// 플랫폼별 실제 경로 및 설정 파일 위치:
  /// - Windows: %APPDATA%\com.example.class_exchange_manager
  ///   (예: C:\Users\사용자명\AppData\Roaming\com.example.class_exchange_manager\)
  ///   설정: path_provider_windows가 실행 파일의 메타데이터에서 자동으로 읽어옴
  ///   또는 windows/CMakeLists.txt의 project() 이름 사용
  /// 
  /// - Android: /data/data/com.example.class_exchange_manager/app_flutter/
  ///   (앱 전용 내부 저장소, 루팅하지 않은 경우 다른 앱에서 접근 불가)
  ///   설정 파일: android/app/build.gradle.kts
  ///   - namespace = "com.example.class_exchange_manager"
  ///   - applicationId = "com.example.class_exchange_manager"
  /// 
  /// - iOS: ~/Library/Application Support/com.example.classExchangeManager/
  ///   (앱 샌드박스 내부, 백업 정책에 따라 iCloud 백업 대상에서 제외 가능)
  ///   설정 파일: ios/Runner.xcodeproj/project.pbxproj
  ///   - PRODUCT_BUNDLE_IDENTIFIER = com.example.classExchangeManager
  ///   (주의: iOS는 대소문자를 구분합니다 - classExchangeManager)
  /// 
  /// - macOS: ~/Library/Application Support/com.example.classExchangeManager/
  ///   설정 파일: macos/Runner/Configs/AppInfo.xcconfig
  ///   - PRODUCT_BUNDLE_IDENTIFIER = com.example.classExchangeManager
  /// 
  /// - Linux: ~/.local/share/com.example.class_exchange_manager/
  ///   설정 파일: linux/CMakeLists.txt
  ///   - APPLICATION_ID = "com.example.class_exchange_manager"
  /// 
  /// 폴더명을 변경하려면:
  /// 1. 해당 플랫폼의 설정 파일에서 앱 식별자 변경
  /// 2. 앱 재빌드 필요
  /// 3. 기존 저장된 데이터는 이전 폴더에 남아있으므로 필요시 마이그레이션 필요
  /// 
  /// 참고: getApplicationDocumentsDirectory() 대신 getApplicationSupportDirectory()를 사용하는 이유:
  /// - 설정 데이터 저장에 더 적합합니다
  /// - 사용자 문서 폴더와 분리되어 관리가 용이합니다
  /// - 시스템 백업 정책에 따라 백업 대상에서 제외될 수 있습니다
  /// - 각 플랫폼의 권장 사항에 부합합니다
  Future<Directory> _getAppDataDirectory() async {
    try {
      // 앱 지원 디렉토리 가져오기 (설정 데이터 저장에 더 적합)
      final directory = await getApplicationSupportDirectory();
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
      final files = <String>[];

      await for (var entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          files.add(entity.path.split(Platform.pathSeparator).last);
        }
      }

      return files;
    } catch (e) {
      AppLogger.error('JSON 파일 목록 조회 실패: $e', e);
      return [];
    }
  }
  
  /// 모든 JSON 파일 삭제
  /// 
  /// 앱 데이터 디렉토리에 있는 모든 JSON 파일을 삭제합니다.
  /// 
  /// 반환값:
  /// - `Future<Map<String, bool>>`: 삭제 결과 맵 (키: 파일명, 값: 삭제 성공 여부)
  Future<Map<String, bool>> deleteAllJsonFiles() async {
    final results = <String, bool>{};
    
    try {
      // 모든 JSON 파일 목록 가져오기
      final jsonFiles = await listJsonFiles();
      
      AppLogger.info('JSON 파일 삭제 시작: ${jsonFiles.length}개 파일');
      
      // 각 파일 삭제
      for (String filename in jsonFiles) {
        try {
          final success = await deleteFile(filename);
          results[filename] = success;
          
          if (success) {
            AppLogger.info('JSON 파일 삭제 성공: $filename');
          } else {
            AppLogger.warning('JSON 파일 삭제 실패: $filename');
          }
        } catch (e) {
          AppLogger.error('JSON 파일 삭제 중 오류 ($filename): $e', e);
          results[filename] = false;
        }
      }
      
      AppLogger.info('모든 JSON 파일 삭제 완료: 성공 ${results.values.where((v) => v).length}개 / 전체 ${results.length}개');
      
      return results;
    } catch (e) {
      AppLogger.error('모든 JSON 파일 삭제 중 오류: $e', e);
      return results;
    }
  }
}


