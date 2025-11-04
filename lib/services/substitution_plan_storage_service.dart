import 'storage_service.dart';
import '../providers/substitution_plan_provider.dart';
import '../utils/logger.dart';

/// 결보강 계획서 날짜 정보 저장 서비스
/// 
/// 사용자가 입력한 날짜 정보(`absenceDate`, `substitutionDate`)와 
/// 보강 과목 정보를 JSON 파일로 저장하고 로드합니다.
class SubstitutionPlanStorageService {
  final StorageService _storageService = StorageService();
  
  // 싱글톤 인스턴스
  static final SubstitutionPlanStorageService _instance = SubstitutionPlanStorageService._internal();
  
  factory SubstitutionPlanStorageService() => _instance;
  
  SubstitutionPlanStorageService._internal();

  // 파일명 상수
  static const String _filename = 'substitution_plan_data.json';

  /// 결보강 계획서 날짜 정보 저장
  /// 
  /// 매개변수:
  /// - `state`: 저장할 SubstitutionPlanState
  /// 
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveSubstitutionPlanData(SubstitutionPlanState state) async {
    try {
      // SubstitutionPlanState를 JSON으로 변환
      final jsonData = state.toJson();
      
      // JSON 파일로 저장
      final success = await _storageService.saveJson(_filename, jsonData);
      
      if (success) {
        AppLogger.info('결보강 계획서 날짜 정보 저장 성공: ${state.savedDates.length}개 날짜, ${state.savedSupplementSubjects.length}개 보강 과목');
      } else {
        AppLogger.error('결보강 계획서 날짜 정보 저장 실패');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('결보강 계획서 날짜 정보 저장 중 오류: $e', e);
      return false;
    }
  }

  /// 결보강 계획서 날짜 정보 로드
  /// 
  /// 저장된 날짜 정보를 로드합니다.
  /// 
  /// 반환값:
  /// - `Future<SubstitutionPlanState?>`: 로드된 상태 (없으면 null)
  Future<SubstitutionPlanState?> loadSubstitutionPlanData() async {
    try {
      // JSON 파일 로드
      final jsonData = await _storageService.loadJson(_filename);
      
      if (jsonData == null) {
        AppLogger.info('결보강 계획서 날짜 정보 파일이 없습니다.');
        return null;
      }
      
      // JSON을 SubstitutionPlanState로 변환
      final state = SubstitutionPlanState.fromJson(jsonData);
      
      AppLogger.info('결보강 계획서 날짜 정보 로드 성공: ${state.savedDates.length}개 날짜, ${state.savedSupplementSubjects.length}개 보강 과목');
      
      return state;
    } catch (e) {
      AppLogger.error('결보강 계획서 날짜 정보 로드 중 오류: $e', e);
      return null;
    }
  }

  /// 결보강 계획서 날짜 정보 삭제
  /// 
  /// 저장된 날짜 정보 파일을 삭제합니다.
  /// 
  /// 반환값:
  /// - `Future<bool>`: 삭제 성공 여부
  Future<bool> clearSubstitutionPlanData() async {
    try {
      final success = await _storageService.deleteFile(_filename);
      if (success) {
        AppLogger.info('결보강 계획서 날짜 정보 삭제 성공');
      }
      return success;
    } catch (e) {
      AppLogger.error('결보강 계획서 날짜 정보 삭제 중 오류: $e', e);
      return false;
    }
  }
}






