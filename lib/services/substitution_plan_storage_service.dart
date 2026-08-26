import 'storage_service.dart';
import '../providers/substitution_plan_provider.dart';
import '../utils/logger.dart';

/// 결보강 계획서 날짜 정보 저장 서비스
///
/// 사용자가 입력한 날짜 정보(`absenceDate`, `substitutionDate`)와
/// 보강 과목 정보를 시간표별 파일
/// (`substitution_plan_data_{timetableId}.json`)로 저장하고 로드합니다.
/// [timetableId]를 지정하지 않으면 기존 전역 파일을 사용합니다.
class SubstitutionPlanStorageService {
  final StorageService _storageService = StorageService();

  // 싱글톤 인스턴스
  static final SubstitutionPlanStorageService _instance =
      SubstitutionPlanStorageService._internal();

  factory SubstitutionPlanStorageService() => _instance;

  SubstitutionPlanStorageService._internal();

  // 레거시 전역 파일명
  static const String _legacyFilename = 'substitution_plan_data.json';

  /// 시간표별 파일명
  static String fileNameFor(String timetableId) =>
      'substitution_plan_data_$timetableId.json';

  /// 스코프에 대응하는 파일명
  static String _resolveFilename(String? timetableId) =>
      timetableId != null ? fileNameFor(timetableId) : _legacyFilename;

  /// 결보강 계획서 날짜 정보 저장
  ///
  /// 매개변수:
  /// - `state`: 저장할 SubstitutionPlanState
  /// - `timetableId`: 시간표 ID (미지정 시 레거시 전역 파일)
  ///
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveSubstitutionPlanData(
    SubstitutionPlanState state, {
    String? timetableId,
  }) async {
    final filename = _resolveFilename(timetableId);
    try {
      // SubstitutionPlanState를 JSON으로 변환
      final jsonData = state.toJson();

      // JSON 파일로 저장
      final success = await _storageService.saveJson(filename, jsonData);

      if (success) {
        AppLogger.info(
          '결보강 계획서 날짜 정보 저장 성공: $filename (${state.savedDates.length}개 날짜, ${state.savedSupplementSubjects.length}개 보강 과목)',
        );
      } else {
        AppLogger.error('결보강 계획서 날짜 정보 저장 실패: $filename');
      }

      return success;
    } catch (e) {
      AppLogger.error('결보강 계획서 날짜 정보 저장 중 오류 ($filename): $e', e);
      return false;
    }
  }

  /// 결보강 계획서 날짜 정보 로드
  ///
  /// 매개변수:
  /// - `timetableId`: 시간표 ID (미지정 시 레거시 전역 파일)
  ///
  /// 반환값:
  /// - `Future<SubstitutionPlanState?>`: 로드된 상태 (없으면 null)
  Future<SubstitutionPlanState?> loadSubstitutionPlanData({String? timetableId}) async {
    final filename = _resolveFilename(timetableId);
    try {
      // JSON 파일 로드
      final jsonData = await _storageService.loadJson(filename);

      if (jsonData == null) {
        AppLogger.info('결보강 계획서 날짜 정보 파일이 없습니다: $filename');
        return null;
      }

      // JSON을 SubstitutionPlanState로 변환
      final state = SubstitutionPlanState.fromJson(jsonData);

      AppLogger.info(
        '결보강 계획서 날짜 정보 로드 성공: $filename (${state.savedDates.length}개 날짜, ${state.savedSupplementSubjects.length}개 보강 과목)',
      );

      return state;
    } catch (e) {
      AppLogger.error('결보강 계획서 날짜 정보 로드 중 오류 ($filename): $e', e);
      return null;
    }
  }

  /// 결보강 계획서 날짜 정보 삭제
  ///
  /// 매개변수:
  /// - `timetableId`: 시간표 ID (미지정 시 레거시 전역 파일)
  ///
  /// 반환값:
  /// - `Future<bool>`: 삭제 성공 여부
  Future<bool> clearSubstitutionPlanData({String? timetableId}) async {
    final filename = _resolveFilename(timetableId);
    try {
      final success = await _storageService.deleteFile(filename);
      if (success) {
        AppLogger.info('결보강 계획서 날짜 정보 삭제 성공: $filename');
      }
      return success;
    } catch (e) {
      AppLogger.error('결보강 계획서 날짜 정보 삭제 중 오류 ($filename): $e', e);
      return false;
    }
  }
}
