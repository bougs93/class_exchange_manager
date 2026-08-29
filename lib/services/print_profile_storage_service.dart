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
  static final Map<String, Future<void>> _operationQueues = {};

  /// 시간표별 계획서 파일명
  static String fileNameFor(String timetableId) =>
      'print_profiles_$timetableId.json';

  final JsonStorage _storage;

  /// [storage] 미지정 시 실제 파일 저장소([StorageService]) 사용
  PrintProfileStorageService({JsonStorage? storage})
    : _storage = storage ?? StorageService();

  Future<T> _runSerialized<T>(
    String timetableId,
    Future<T> Function() operation,
  ) {
    final previous = _operationQueues[timetableId] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _operationQueues[timetableId] = tail;
    tail.whenComplete(() {
      if (identical(_operationQueues[timetableId], tail)) {
        _operationQueues.remove(timetableId);
      }
    });
    return result;
  }

  /// 계획서 스토어 로드 (파일이 없으면 빈 스토어 반환)
  Future<PrintProfileStore> loadStore(String timetableId) async {
    await (_operationQueues[timetableId] ?? Future<void>.value());
    return _loadStoreNow(timetableId);
  }

  Future<PrintProfileStore> _loadStoreNow(String timetableId) async {
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
  Future<bool> saveStore(String timetableId, PrintProfileStore store) {
    return _runSerialized(timetableId, () => _saveStoreNow(timetableId, store));
  }

  Future<bool> _saveStoreNow(
    String timetableId,
    PrintProfileStore store,
  ) async {
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
  Future<bool> saveProfile(String timetableId, PrintProfile profile) {
    return _runSerialized(timetableId, () async {
      final store = await _loadStoreNow(timetableId);
      final exists = store.getById(profile.id) != null;
      final profiles =
          exists
              ? store.profiles
                  .map((p) => p.id == profile.id ? profile : p)
                  .toList()
              : [...store.profiles, profile];

      return _saveStoreNow(
        timetableId,
        store.copyWith(profiles: profiles, lastUsedProfileId: profile.id),
      );
    });
  }

  Future<bool> deleteProfile(String timetableId, String profileId) {
    return _runSerialized(timetableId, () async {
      final store = await _loadStoreNow(timetableId);
      final profiles = store.profiles.where((p) => p.id != profileId).toList();
      final clearLastUsed = store.lastUsedProfileId == profileId;

      return _saveStoreNow(
        timetableId,
        store.copyWith(
          profiles: profiles,
          clearLastUsedProfileId: clearLastUsed,
        ),
      );
    });
  }

  /// 계획서 이름 변경
  Future<bool> renameProfile(
    String timetableId,
    String profileId,
    String newName,
  ) {
    return _runSerialized(timetableId, () async {
      final store = await _loadStoreNow(timetableId);
      final target = store.getById(profileId);
      if (target == null) {
        AppLogger.warning('이름 변경 대상 계획서를 찾을 수 없음: $profileId');
        return false;
      }
      final profiles =
          store.profiles
              .map(
                (profile) =>
                    profile.id == profileId
                        ? target.copyWith(name: newName)
                        : profile,
              )
              .toList();
      return _saveStoreNow(timetableId, store.copyWith(profiles: profiles));
    });
  }

  /// 마지막 선택 교사 저장 (탭 재진입 시 복원용)
  Future<bool> setLastSelectedTeacher(String timetableId, String teacherName) {
    return _runSerialized(timetableId, () async {
      final store = await _loadStoreNow(timetableId);
      return _saveStoreNow(
        timetableId,
        store.copyWith(lastSelectedTeacher: teacherName),
      );
    });
  }

  /// 마지막 사용 계획서를 기존 프로파일을 보존하며 갱신합니다.
  Future<bool> setLastUsedProfile(String timetableId, String profileId) {
    return _runSerialized(timetableId, () async {
      final store = await _loadStoreNow(timetableId);
      if (store.getById(profileId) == null) {
        AppLogger.warning('마지막 사용으로 지정할 계획서를 찾을 수 없음: $profileId');
        return false;
      }
      return _saveStoreNow(
        timetableId,
        store.copyWith(lastUsedProfileId: profileId),
      );
    });
  }

  /// 계획서 스토어 파일 삭제 (시간표 삭제 시 사용)
  Future<bool> clearStore(String timetableId) {
    return _runSerialized(
      timetableId,
      () => _storage.deleteFile(fileNameFor(timetableId)),
    );
  }
}
