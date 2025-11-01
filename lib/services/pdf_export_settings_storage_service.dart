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
}


