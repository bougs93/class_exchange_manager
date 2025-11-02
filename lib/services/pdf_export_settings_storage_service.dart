import 'storage_service.dart';
import '../utils/logger.dart';

/// PDF 출력 설정 저장 서비스
/// 
/// PDF 출력 설정(폰트, 추가 필드)을 JSON 파일로 저장하고 로드합니다.
class PdfExportSettingsStorageService {
  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final PdfExportSettingsStorageService _instance = PdfExportSettingsStorageService._internal();
  
  factory PdfExportSettingsStorageService() => _instance;
  
  PdfExportSettingsStorageService._internal();
  
  /// PDF 출력 설정 저장
  /// 
  /// 매개변수:
  /// - `fontSize`: 폰트 사이즈
  /// - `remarksFontSize`: 비고 폰트 사이즈
  /// - `selectedFont`: 선택된 폰트
  /// - `includeRemarks`: 비고 포함 여부
  /// - `additionalFields`: 추가 필드 맵 (키: 필드명, 값: 입력값)
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> savePdfExportSettings({
    required double fontSize,
    required double remarksFontSize,
    required String selectedFont,
    required bool includeRemarks,
    required Map<String, String> additionalFields,
  }) async {
    try {
      final settings = {
        'fontSize': fontSize,
        'remarksFontSize': remarksFontSize,
        'selectedFont': selectedFont,
        'includeRemarks': includeRemarks,
        'additionalFields': additionalFields,
      };
      
      final success = await _storageService.saveJson('pdf_export_settings.json', settings);
      
      if (success) {
        AppLogger.info('PDF 출력 설정 저장 성공');
      } else {
        AppLogger.error('PDF 출력 설정 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('PDF 출력 설정 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// PDF 출력 설정 로드
  /// 
  /// 저장된 PDF 출력 설정을 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: PDF 출력 설정 (없으면 null)
  Future<Map<String, dynamic>?> loadPdfExportSettings() async {
    try {
      final settings = await _storageService.loadJson('pdf_export_settings.json');
      
      if (settings == null) {
        AppLogger.info('PDF 출력 설정 파일이 없습니다.');
        return null;
      }
      
      AppLogger.info('PDF 출력 설정 로드 성공');
      return settings;
    } catch (e) {
      AppLogger.error('PDF 출력 설정 로드 중 오류: $e', e);
      return null;
    }
  }
  
  /// 기본 PDF 출력 설정 가져오기
  /// 
  /// 저장된 설정이 없을 때 사용할 기본값을 반환합니다.
  /// 
  /// 반환값:
  /// - `Map<String, dynamic>`: 기본 설정 맵
  Map<String, dynamic> getDefaultSettings() {
    return {
      'fontSize': 10.0,
      'remarksFontSize': 7.0,
      'selectedFont': 'NanumGothic',
      'includeRemarks': true,
      'additionalFields': <String, String>{},
    };
  }
  
  /// 교사명과 학교명만 초기화
  /// 
  /// PDF 출력 설정의 additionalFields에서 교사명(teacherName)과 
  /// 학교명(schoolName)만 삭제하고 나머지 설정은 유지합니다.
  /// 
  /// 반환값:
  /// - `Future<bool>`: 초기화 성공 여부
  Future<bool> clearTeacherAndSchoolName() async {
    try {
      // 현재 설정 로드
      final settings = await loadPdfExportSettings();
      if (settings == null) {
        // 설정 파일이 없으면 이미 초기화된 상태로 간주
        AppLogger.info('PDF 출력 설정이 없습니다. 이미 초기화된 상태입니다.');
        return true;
      }
      
      // additionalFields 가져오기
      final additionalFields = (settings['additionalFields'] as Map<String, dynamic>?)
          ?.cast<String, String>() ?? <String, String>{};
      
      // 교사명과 학교명만 제거 (나머지 필드는 유지)
      final newAdditionalFields = Map<String, String>.from(additionalFields);
      newAdditionalFields.remove('teacherName');
      newAdditionalFields.remove('schoolName');
      
      // 나머지 설정은 그대로 유지하고 additionalFields만 업데이트
      final updatedSettings = Map<String, dynamic>.from(settings);
      updatedSettings['additionalFields'] = newAdditionalFields;
      
      // 저장
      final success = await _storageService.saveJson('pdf_export_settings.json', updatedSettings);
      
      if (success) {
        AppLogger.info('교사명과 학교명 초기화 성공');
      } else {
        AppLogger.error('교사명과 학교명 초기화 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('교사명과 학교명 초기화 중 오류: $e', e);
      return false;
    }
  }
  
  /// 교사명과 학교명만 저장
  /// 
  /// PDF 출력 설정의 additionalFields에서 교사명(teacherName)과 
  /// 학교명(schoolName)만 업데이트하고 나머지 설정은 유지합니다.
  /// 
  /// 매개변수:
  /// - `teacherName`: 교사명
  /// - `schoolName`: 학교명
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveTeacherAndSchoolName({
    required String teacherName,
    required String schoolName,
  }) async {
    try {
      // 현재 설정 로드
      final settings = await loadPdfExportSettings();
      Map<String, dynamic> updatedSettings;
      
      if (settings == null) {
        // 설정 파일이 없으면 기본 설정 사용
        updatedSettings = getDefaultSettings();
      } else {
        updatedSettings = Map<String, dynamic>.from(settings);
      }
      
      // additionalFields 가져오기
      final additionalFields = (updatedSettings['additionalFields'] as Map<String, dynamic>?)
          ?.cast<String, String>() ?? <String, String>{};
      
      // 교사명과 학교명만 업데이트 (나머지 필드는 유지)
      final newAdditionalFields = Map<String, String>.from(additionalFields);
      newAdditionalFields['teacherName'] = teacherName;
      newAdditionalFields['schoolName'] = schoolName;
      
      // additionalFields 업데이트
      updatedSettings['additionalFields'] = newAdditionalFields;
      
      // 저장
      final success = await _storageService.saveJson('pdf_export_settings.json', updatedSettings);
      
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
  
  /// 기본 교사명과 학교명 저장 (설정 화면용)
  /// 
  /// PDF 출력 시 입력 필드가 비어있을 때 사용할 기본값을 저장합니다.
  /// 기본값은 별도 필드(defaultTeacherName, defaultSchoolName)에 저장됩니다.
  /// 
  /// 매개변수:
  /// - `teacherName`: 기본 교사명
  /// - `schoolName`: 기본 학교명
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveDefaultTeacherAndSchoolName({
    required String teacherName,
    required String schoolName,
  }) async {
    try {
      // 현재 설정 로드
      final settings = await loadPdfExportSettings();
      Map<String, dynamic> updatedSettings;
      
      if (settings == null) {
        // 설정 파일이 없으면 기본 설정 사용
        updatedSettings = getDefaultSettings();
      } else {
        updatedSettings = Map<String, dynamic>.from(settings);
      }
      
      // 기본값 필드에 저장
      updatedSettings['defaultTeacherName'] = teacherName;
      updatedSettings['defaultSchoolName'] = schoolName;
      
      // 저장
      final success = await _storageService.saveJson('pdf_export_settings.json', updatedSettings);
      
      if (success) {
        AppLogger.info('기본 교사명과 학교명 저장 성공: teacherName=$teacherName, schoolName=$schoolName');
      } else {
        AppLogger.error('기본 교사명과 학교명 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('기본 교사명과 학교명 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// 기본 교사명과 학교명 로드
  /// 
  /// 설정 화면에서 저장한 기본값을 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<Map<String, String>>`: 기본값 맵 (키: defaultTeacherName, defaultSchoolName)
  Future<Map<String, String>> loadDefaultTeacherAndSchoolName() async {
    try {
      final settings = await loadPdfExportSettings();
      if (settings == null) {
        return {'defaultTeacherName': '', 'defaultSchoolName': ''};
      }
      
      return {
        'defaultTeacherName': (settings['defaultTeacherName'] as String?) ?? '',
        'defaultSchoolName': (settings['defaultSchoolName'] as String?) ?? '',
      };
    } catch (e) {
      AppLogger.error('기본 교사명과 학교명 로드 중 오류: $e', e);
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
      final settings = await loadPdfExportSettings();
      Map<String, dynamic> updatedSettings;
      
      if (settings == null) {
        // 설정 파일이 없으면 기본 설정 사용
        updatedSettings = getDefaultSettings();
      } else {
        updatedSettings = Map<String, dynamic>.from(settings);
      }
      
      // 하이라이트 색상 저장
      updatedSettings['highlightedTeacherColor'] = colorValue;
      
      // 저장
      final success = await _storageService.saveJson('pdf_export_settings.json', updatedSettings);
      
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
      final settings = await loadPdfExportSettings();
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


