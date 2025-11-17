import 'storage_service.dart';
import '../utils/logger.dart';

/// PDF 출력 설정 저장 서비스
///
/// PDF 출력 설정(폰트, 추가 필드)을 JSON 파일로 저장하고 로드합니다.
class PdfExportSettingsStorageService {
  // 상수: PDF 템플릿 개수 (양식 1, 양식 2)
  static const int templateCount = 2;

  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final PdfExportSettingsStorageService _instance = PdfExportSettingsStorageService._internal();
  
  factory PdfExportSettingsStorageService() => _instance;
  
  PdfExportSettingsStorageService._internal();
  
  /// PDF 출력 설정 저장
  /// 
  /// 매개변수:
  /// - `templateIndex`: 양식 인덱스 (0: 양식 1, 1: 양식 2)
  /// - `fontSize`: 폰트 사이즈
  /// - `remarksFontSize`: 비고 폰트 사이즈
  /// - `selectedFont`: 선택된 폰트
  /// - `includeRemarks`: 비고 포함 여부
  /// - `additionalFields`: 추가 필드 맵 (키: 필드명, 값: 입력값)
  /// - `selectedTemplateFilePath`: 선택된 PDF 템플릿 파일 경로 (선택사항)
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> savePdfExportSettings({
    required int templateIndex,
    required double fontSize,
    required double remarksFontSize,
    required String selectedFont,
    required bool includeRemarks,
    required Map<String, String> additionalFields,
    String? selectedTemplateFilePath,
  }) async {
    try {
      final settings = {
        'fontSize': fontSize,
        'remarksFontSize': remarksFontSize,
        'selectedFont': selectedFont,
        'includeRemarks': includeRemarks,
        'additionalFields': additionalFields,
      };
      
      // PDF 템플릿 파일 경로가 있으면 저장
      if (selectedTemplateFilePath != null && selectedTemplateFilePath.isNotEmpty) {
        settings['selectedTemplateFilePath'] = selectedTemplateFilePath;
      }
      
      // 양식별로 별도 파일에 저장
      final fileName = 'pdf_export_settings_template_$templateIndex.json';
      final success = await _storageService.saveJson(fileName, settings);
      
      if (success) {
        AppLogger.info('PDF 출력 설정 저장 성공 (양식 ${templateIndex + 1})');
      } else {
        AppLogger.error('PDF 출력 설정 저장 실패 (양식 ${templateIndex + 1})');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('PDF 출력 설정 저장 중 오류 (양식 ${templateIndex + 1}): $e', e);
      return false;
    }
  }
  
  /// PDF 출력 설정 로드
  /// 
  /// 저장된 PDF 출력 설정을 로드합니다.
  /// 
  /// 매개변수:
  /// - `templateIndex`: 양식 인덱스 (0: 양식 1, 1: 양식 2)
  /// 
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: PDF 출력 설정 (없으면 null)
  Future<Map<String, dynamic>?> loadPdfExportSettings({required int templateIndex}) async {
    try {
      // 양식별로 별도 파일에서 로드
      final fileName = 'pdf_export_settings_template_$templateIndex.json';
      final settings = await _storageService.loadJson(fileName);
      
      if (settings == null) {
        AppLogger.info('PDF 출력 설정 파일이 없습니다. (양식 ${templateIndex + 1})');
        return null;
      }
      
      AppLogger.info('PDF 출력 설정 로드 성공 (양식 ${templateIndex + 1})');
      return settings;
    } catch (e) {
      AppLogger.error('PDF 출력 설정 로드 중 오류 (양식 ${templateIndex + 1}): $e', e);
      return null;
    }
  }
  
  /// 호환성을 위한 기존 메서드 (양식 0으로 기본 로드)
  /// 
  /// 기존 코드와의 호환성을 위해 유지됩니다.
  /// 새 코드에서는 loadPdfExportSettings(templateIndex: 0)을 사용하세요.
  @Deprecated('양식 인덱스를 명시적으로 지정하세요. loadPdfExportSettings(templateIndex: 0)을 사용하세요.')
  Future<Map<String, dynamic>?> loadPdfExportSettingsLegacy() async {
    return loadPdfExportSettings(templateIndex: 0);
  }
  
  /// 기본 PDF 출력 설정 가져오기
  /// 
  /// 저장된 설정이 없을 때 사용할 기본값을 반환합니다.
  /// 양식별로 다른 기본값을 설정할 수 있습니다.
  /// 
  /// 매개변수:
  /// - `templateIndex`: 양식 인덱스 (0: 양식 1, 1: 양식 2)
  /// 
  /// 반환값:
  /// - `Map<String, dynamic>`: 기본 설정 맵
  Map<String, dynamic> getDefaultSettings({int templateIndex = 0}) {
    if (templateIndex == 0) {
      // 양식 1의 기본값
      return {
        'fontSize': 10.0,
        'remarksFontSize': 7.0,
        'selectedFont': 'hanbatang.ttf', // 한바탕
        'includeRemarks': false, // 비고 출력 해제
        'additionalFields': <String, String>{},
      };
    } else {
      // 양식 2의 기본값
      return {
        'fontSize': 11.0, // 11pt
        'remarksFontSize': 7.0,
        'selectedFont': 'gulim.ttc', // 굴림
        'includeRemarks': false, // 비고 출력 해제
        'additionalFields': <String, String>{
          'notes': '', // 설명 빈값
        },
      };
    }
  }
  
  /// 교사명과 학교명만 초기화
  /// 
  /// PDF 출력 설정의 additionalFields에서 교사명(teacherName)과 
  /// 학교명(schoolName)만 삭제하고 나머지 설정은 유지합니다.
  /// 모든 양식에 대해 초기화합니다.
  /// 
  /// 반환값:
  /// - `Future<bool>`: 초기화 성공 여부
  Future<bool> clearTeacherAndSchoolName() async {
    try {
      bool allSuccess = true;
      // 모든 양식에 대해 초기화
      for (int templateIndex = 0; templateIndex < templateCount; templateIndex++) {
        // 현재 양식의 설정 로드
        final settings = await loadPdfExportSettings(templateIndex: templateIndex);
        if (settings == null) {
          // 설정 파일이 없으면 이미 초기화된 상태로 간주
          continue;
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
        
        // 양식별로 별도 파일에 저장
        final fileName = 'pdf_export_settings_template_$templateIndex.json';
        final success = await _storageService.saveJson(fileName, updatedSettings);
        
        if (!success) {
          allSuccess = false;
          AppLogger.error('교사명과 학교명 초기화 실패 (양식 ${templateIndex + 1})');
        }
      }
      
      if (allSuccess) {
        AppLogger.info('교사명과 학교명 초기화 성공 (모든 양식)');
      }
      
      return allSuccess;
    } catch (e) {
      AppLogger.error('교사명과 학교명 초기화 중 오류: $e', e);
      return false;
    }
  }
  
  /// 교사명과 학교명만 저장
  /// 
  /// PDF 출력 설정의 additionalFields에서 교사명(teacherName)과 
  /// 학교명(schoolName)만 업데이트하고 나머지 설정은 유지합니다.
  /// 모든 양식에 대해 저장합니다.
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
      bool allSuccess = true;
      // 모든 양식에 대해 저장
      for (int templateIndex = 0; templateIndex < templateCount; templateIndex++) {
        // 현재 양식의 설정 로드
        final settings = await loadPdfExportSettings(templateIndex: templateIndex);
        Map<String, dynamic> updatedSettings;
        
      if (settings == null) {
        // 설정 파일이 없으면 기본 설정 사용 (양식별 기본값)
        updatedSettings = getDefaultSettings(templateIndex: templateIndex);
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
      
      // 양식별로 별도 파일에 저장
      final fileName = 'pdf_export_settings_template_$templateIndex.json';
        final success = await _storageService.saveJson(fileName, updatedSettings);
        
        if (!success) {
          allSuccess = false;
          AppLogger.error('교사명과 학교명 저장 실패 (양식 ${templateIndex + 1})');
        }
      }
      
      if (allSuccess) {
        AppLogger.info('교사명과 학교명 저장 성공 (모든 양식): teacherName=$teacherName, schoolName=$schoolName');
      }
      
      return allSuccess;
    } catch (e) {
      AppLogger.error('교사명과 학교명 저장 중 오류: $e', e);
      return false;
    }
  }
  
  /// PDF 템플릿 파일 경로만 저장
  /// 
  /// PDF 템플릿 파일 경로를 즉시 저장합니다.
  /// 
  /// 매개변수:
  /// - `templateIndex`: 양식 인덱스 (0: 양식 1, 1: 양식 2)
  /// - `filePath`: PDF 템플릿 파일 경로 (null이면 저장된 경로 제거)
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveTemplateFilePath({
    required int templateIndex,
    String? filePath,
  }) async {
    try {
      // 현재 양식의 설정 로드
      final settings = await loadPdfExportSettings(templateIndex: templateIndex);
      Map<String, dynamic> updatedSettings;
      
      if (settings == null) {
        // 설정 파일이 없으면 기본 설정 사용 (양식별 기본값)
        updatedSettings = getDefaultSettings(templateIndex: templateIndex);
      } else {
        updatedSettings = Map<String, dynamic>.from(settings);
      }
      
      // PDF 템플릿 파일 경로 업데이트
      if (filePath != null && filePath.isNotEmpty) {
        updatedSettings['selectedTemplateFilePath'] = filePath;
        AppLogger.info('PDF 템플릿 파일 경로 저장 (양식 ${templateIndex + 1}): $filePath');
      } else {
        // null이면 저장된 경로 제거
        updatedSettings.remove('selectedTemplateFilePath');
        AppLogger.info('PDF 템플릿 파일 경로 제거 (양식 ${templateIndex + 1})');
      }
      
      // 양식별로 별도 파일에 저장
      final fileName = 'pdf_export_settings_template_$templateIndex.json';
      final success = await _storageService.saveJson(fileName, updatedSettings);
      
      if (success) {
        AppLogger.info('PDF 템플릿 파일 경로 저장 성공 (양식 ${templateIndex + 1})');
      } else {
        AppLogger.error('PDF 템플릿 파일 경로 저장 실패 (양식 ${templateIndex + 1})');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('PDF 템플릿 파일 경로 저장 중 오류 (양식 ${templateIndex + 1}): $e', e);
      return false;
    }
  }

  /// 마지막으로 선택된 양식 인덱스 저장
  /// 
  /// 양식 1/양식 2 드롭다운에서 선택한 인덱스를 저장합니다.
  /// 
  /// 매개변수:
  /// - `templateIndex`: 선택된 양식 인덱스 (0: 양식 1, 1: 양식 2)
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveLastSelectedTemplateIndex(int templateIndex) async {
    try {
      final settings = {
        'lastSelectedTemplateIndex': templateIndex,
      };
      
      // 전역 설정 파일에 저장 (양식별 설정과 별도)
      final fileName = 'pdf_export_last_selected_template.json';
      final success = await _storageService.saveJson(fileName, settings);
      
      if (success) {
        AppLogger.info('마지막 선택된 양식 인덱스 저장 성공: 양식 ${templateIndex + 1}');
      } else {
        AppLogger.error('마지막 선택된 양식 인덱스 저장 실패: 양식 ${templateIndex + 1}');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('마지막 선택된 양식 인덱스 저장 중 오류: $e', e);
      return false;
    }
  }

  /// 마지막으로 선택된 양식 인덱스 로드
  /// 
  /// 저장된 마지막 선택 양식 인덱스를 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<int?>`: 마지막 선택된 양식 인덱스 (없으면 null, 기본값은 0)
  Future<int?> loadLastSelectedTemplateIndex() async {
    try {
      // 전역 설정 파일에서 로드
      final fileName = 'pdf_export_last_selected_template.json';
      final settings = await _storageService.loadJson(fileName);
      
      if (settings == null) {
        AppLogger.info('마지막 선택된 양식 인덱스 파일이 없습니다. 기본값(양식 1) 사용');
        return 0; // 기본값: 양식 1
      }
      
      final index = settings['lastSelectedTemplateIndex'] as int?;
      if (index == null) {
        AppLogger.info('마지막 선택된 양식 인덱스가 없습니다. 기본값(양식 1) 사용');
        return 0; // 기본값: 양식 1
      }
      
      // 유효성 검사: 0 또는 1만 허용
      if (index < 0 || index > 1) {
        AppLogger.warning('유효하지 않은 양식 인덱스: $index. 기본값(양식 1) 사용');
        return 0; // 기본값: 양식 1
      }
      
      AppLogger.info('마지막 선택된 양식 인덱스 로드 성공: 양식 ${index + 1}');
      return index;
    } catch (e) {
      AppLogger.error('마지막 선택된 양식 인덱스 로드 중 오류: $e', e);
      return 0; // 기본값: 양식 1
    }
  }
}


