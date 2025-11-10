import 'storage_service.dart';
import '../utils/logger.dart';

/// 앱 설정 저장 서비스
/// 
/// 언어 설정 등 앱 전역 설정을 JSON 파일로 저장하고 로드합니다.
class AppSettingsStorageService {
  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final AppSettingsStorageService _instance = AppSettingsStorageService._internal();
  
  factory AppSettingsStorageService() => _instance;
  
  AppSettingsStorageService._internal();
  
  /// 앱 설정 저장
  /// 
  /// 매개변수:
  /// - `languageCode`: 언어 코드 (예: "ko", "en")
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveAppSettings({
    required String languageCode,
  }) async {
    try {
      final settings = {
        'languageCode': languageCode,
      };
      
      final success = await _storageService.saveJson('app_settings.json', settings);
      
      if (success) {
        AppLogger.info('앱 설정 저장 성공: languageCode=$languageCode');
      } else {
        AppLogger.error('앱 설정 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('앱 설정 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// 앱 설정 로드
  /// 
  /// 저장된 앱 설정을 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: 앱 설정 (없으면 null)
  Future<Map<String, dynamic>?> loadAppSettings() async {
    try {
      final settings = await _storageService.loadJson('app_settings.json');
      
      if (settings == null) {
        AppLogger.info('앱 설정 파일이 없습니다.');
        return null;
      }
      
      AppLogger.info('앱 설정 로드 성공');
      return settings;
    } catch (e) {
      AppLogger.error('앱 설정 로드 중 오류: $e', e);
      return null;
    }
  }
  
  /// 언어 코드 가져오기
  ///
  /// 반환값:
  /// - `Future<String>`: 언어 코드 (기본값: "ko")
  Future<String> getLanguageCode() async {
    try {
      final settings = await loadAppSettings();
      if (settings == null) {
        return 'ko'; // 기본값: 한국어
      }

      return (settings['languageCode'] as String?) ?? 'ko';
    } catch (e) {
      AppLogger.error('언어 코드 가져오기 실패: $e', e);
      return 'ko'; // 기본값: 한국어
    }
  }
  
  /// 교사명과 학교명 저장
  /// 
  /// 설정 화면에서 입력한 기본 교사명과 학교명을 저장합니다.
  /// 
  /// 매개변수:
  /// - `teacherName`: 기본 교사명
  /// - `schoolName`: 기본 학교명
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveTeacherAndSchoolName({
    required String teacherName,
    required String schoolName,
  }) async {
    try {
      // 현재 설정 로드
      final settings = await loadAppSettings();
      Map<String, dynamic> updatedSettings;
      
      if (settings == null) {
        // 설정 파일이 없으면 새로 생성
        updatedSettings = {};
      } else {
        updatedSettings = Map<String, dynamic>.from(settings);
      }
      
      // 교사명과 학교명 저장
      updatedSettings['defaultTeacherName'] = teacherName;
      updatedSettings['defaultSchoolName'] = schoolName;
      
      // 저장
      final success = await _storageService.saveJson('app_settings.json', updatedSettings);
      
      if (success) {
        AppLogger.info('교사명과 학교명 저장 성공: teacherName=$teacherName, schoolName=$schoolName');
      } else {
        AppLogger.error('교사명과 학교명 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('교사명과 학교명 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// 교사명과 학교명 로드
  /// 
  /// 설정 화면에서 저장한 기본 교사명과 학교명을 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<Map<String, String>>`: 기본값 맵 (키: defaultTeacherName, defaultSchoolName)
  Future<Map<String, String>> loadTeacherAndSchoolName() async {
    try {
      final settings = await loadAppSettings();
      if (settings == null) {
        return {'defaultTeacherName': '', 'defaultSchoolName': ''};
      }
      
      return {
        'defaultTeacherName': (settings['defaultTeacherName'] as String?) ?? '',
        'defaultSchoolName': (settings['defaultSchoolName'] as String?) ?? '',
      };
    } catch (e) {
      AppLogger.error('교사명과 학교명 로드 중 오류: $e', e);
      return {'defaultTeacherName': '', 'defaultSchoolName': ''};
    }
  }
  
  /// 하이라이트된 교사 행 색상 저장
  /// 
  /// 설정에서 지정한 하이라이트 색상을 ARGB 값으로 저장합니다.
  /// 
  /// 매개변수:
  /// - `colorValue`: ARGB 값 (int)
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveHighlightedTeacherColor(int colorValue) async {
    try {
      // 현재 설정 로드
      final settings = await loadAppSettings();
      Map<String, dynamic> updatedSettings;
      
      if (settings == null) {
        // 설정 파일이 없으면 새로 생성
        updatedSettings = {};
      } else {
        updatedSettings = Map<String, dynamic>.from(settings);
      }
      
      // 하이라이트 색상 저장
      updatedSettings['highlightedTeacherColor'] = colorValue;
      
      // 저장
      final success = await _storageService.saveJson('app_settings.json', updatedSettings);
      
      if (success) {
        AppLogger.info('하이라이트 교사 행 색상 저장 성공: $colorValue');
      } else {
        AppLogger.error('하이라이트 교사 행 색상 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('하이라이트 교사 행 색상 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// 하이라이트된 교사 행 색상 로드
  /// 
  /// 저장된 하이라이트 색상을 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<int?>`: ARGB 값 (없으면 null)
  Future<int?> getHighlightedTeacherColor() async {
    try {
      final settings = await loadAppSettings();
      if (settings == null) {
        return null;
      }
      
      final colorValue = settings['highlightedTeacherColor'] as int?;
      return colorValue;
    } catch (e) {
      AppLogger.error('하이라이트 교사 행 색상 로드 중 오류: $e', e);
      return null;
    }
  }
}

