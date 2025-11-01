import 'storage_service.dart';
import '../utils/logger.dart';

/// 시간표 테마 저장 서비스
/// 
/// 시간표 테이블의 테마 설정을 JSON 파일로 저장하고 로드합니다.
class TimetableThemeStorageService {
  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final TimetableThemeStorageService _instance = TimetableThemeStorageService._internal();
  
  factory TimetableThemeStorageService() => _instance;
  
  TimetableThemeStorageService._internal();
  
  /// 테마 설정 저장
  /// 
  /// 매개변수:
  /// - `fontScaleFactor`: 폰트 사이즈 배율
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveThemeSettings({
    required double fontScaleFactor,
  }) async {
    try {
      final settings = {
        'fontScaleFactor': fontScaleFactor,
      };
      
      final success = await _storageService.saveJson('timetable_theme.json', settings);
      
      if (success) {
        AppLogger.info('테마 설정 저장 성공');
      } else {
        AppLogger.error('테마 설정 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('테마 설정 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// 테마 설정 로드
  /// 
  /// 저장된 테마 설정을 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: 테마 설정 (없으면 null)
  ///   - `fontScaleFactor`: 폰트 사이즈 배율 (기본값: 1.0)
  Future<Map<String, dynamic>?> loadThemeSettings() async {
    try {
      final settings = await _storageService.loadJson('timetable_theme.json');
      
      if (settings == null) {
        AppLogger.info('테마 설정 파일이 없습니다.');
        return null;
      }
      
      AppLogger.info('테마 설정 로드 성공');
      return settings;
    } catch (e) {
      AppLogger.error('테마 설정 로드 중 오류: $e', e);
      return null;
    }
  }
  
  /// 폰트 사이즈 배율 가져오기
  /// 
  /// 반환값:
  /// - `Future<double>`: 폰트 사이즈 배율 (기본값: 1.0)
  Future<double> getFontScaleFactor() async {
    try {
      final settings = await loadThemeSettings();
      if (settings == null) {
        return 1.0; // 기본값
      }
      
      return (settings['fontScaleFactor'] as num?)?.toDouble() ?? 1.0;
    } catch (e) {
      AppLogger.error('폰트 사이즈 배율 가져오기 실패: $e', e);
      return 1.0; // 기본값
    }
  }
}


