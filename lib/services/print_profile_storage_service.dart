import '../models/print_profile.dart';
import '../utils/logger.dart';
import 'json_storage.dart';
import 'storage_service.dart';

/// 인쇄 프로파일(계획서) 저장 서비스
///
/// 시간표별로 `print_profiles_{timetableId}.json` 파일로 저장합니다.
/// 계획서는 교사별로 관리되며([PrintProfile.teacherName]),
/// 교체불가·교체 상태와는 독립적입니다.
class PrintProfileStorageService {
  /// 시간표별 계획서 파일명
  static String fileNameFor(String timetableId) =>
      'print_profiles_$timetableId.json';

  final JsonStorage _storage;

  /// [storage] 미지정 시 실제 파일 저장소([StorageService]) 사용
  PrintProfileStorageService({JsonStorage? storage})
    : _storage = storage ?? StorageService();

  /// 계획서 스토어 로드 (파일이 없으면 빈 스토어 반환)
  Future<PrintProfileStore> loadStore(String timetableId) async {
    try {
      final json = await _storage.loadJson(fileNameFor(timetableId));
      if (json == null) {
        return const PrintProfileStore();
      }
      return PrintProfileStore.fromJson(json);
    } catch (e) {
      AppLogger.error('계획서 스토어 로드 실패 ($timetableId): $e', e);
      return const PrintProfileStore();
    }
  }

  /// 계획서 스토어 저장
  Future<bool> saveStore(String timetableId, PrintProfileStore store) async {
    try {
      final success = await _storage.saveJson(
        fileNameFor(timetableId),
        store.toJson(),
      );
      if (success) {
        AppLogger.info(
          '계획서 스토어 저장 성공: $timetableId (${store.profiles.length}개)',
        );
      }
      return success;
    } catch (e) {
      AppLogger.error('계획서 스토어 저장 실패 ($timetableId): $e', e);
      return false;
    }
  }

  /// 계획서 추가/갱신 (ID 기준 upsert) + 마지막 사용 계획서 갱신
  Future<bool> saveProfile(String timetableId, PrintProfile profile) async {
    final store = await loadStore(timetableId);
    final exists = store.getById(profile.id) != null;
    final profiles = exists
        ? store.profiles.map((p) => p.id == profile.id ? profile : p).toList()
        : [...store.profiles, profile];

    return saveStore(
      timetableId,
      store.copyWith(profiles: profiles, lastUsedProfileId: profile.id),
    );
  }

  /// 계획서 삭제
  ///
  /// 삭제된 계획서가 마지막 사용 계획서였다면 해제합니다.
  /// 교체 건이 이 계획서를 가리키고 있으면 조회 시 '미지정'으로 처리됩니다.
  Future<bool> deleteProfile(String timetableId, String profileId) async {
    final store = await loadStore(timetableId);
    final profiles = store.profiles.where((p) => p.id != profileId).toList();
    final clearLastUsed = store.lastUsedProfileId == profileId;

    return saveStore(
      timetableId,
      store.copyWith(
        profiles: profiles,
        clearLastUsedProfileId: clearLastUsed,
      ),
    );
  }

  /// 계획서 이름 변경
  Future<bool> renameProfile(
    String timetableId,
    String profileId,
    String newName,
  ) async {
    final store = await loadStore(timetableId);
    final target = store.getById(profileId);
    if (target == null) {
      AppLogger.warning('이름 변경 대상 계획서를 찾을 수 없음: $profileId');
      return false;
    }
    return saveProfile(timetableId, target.copyWith(name: newName));
  }

  /// 마지막 선택 교사 저장 (탭 재진입 시 복원용)
  Future<bool> setLastSelectedTeacher(String timetableId, String teacherName) async {
    final store = await loadStore(timetableId);
    return saveStore(
      timetableId,
      store.copyWith(lastSelectedTeacher: teacherName),
    );
  }

  /// 계획서 스토어 파일 삭제 (시간표 삭제 시 사용)
  Future<bool> clearStore(String timetableId) async {
    return _storage.deleteFile(fileNameFor(timetableId));
  }
}
