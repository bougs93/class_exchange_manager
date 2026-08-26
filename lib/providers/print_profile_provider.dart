import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/print_profile.dart';
import '../services/print_profile_storage_service.dart';
import 'timetable_registry_provider.dart';

/// 계획서(인쇄 프로파일) 저장 서비스 Provider
final printProfileStorageServiceProvider = Provider<PrintProfileStorageService>(
  (ref) {
    return PrintProfileStorageService();
  },
);

/// 계획서 스토어 Notifier — 활성 시간표 스코프
///
/// 활성 시간표가 바뀌면 Provider가 재생성되어 해당 시간표의 계획서를 로드합니다.
/// 교체불가·교체 상태와는 독립적입니다(계획서는 인쇄 설정만 관리).
class PrintProfileStoreNotifier extends StateNotifier<PrintProfileStore> {
  PrintProfileStoreNotifier(this._timetableId)
    : super(const PrintProfileStore()) {
    _load();
  }

  final String? _timetableId;

  final Completer<void> _loadCompleter = Completer<void>();

  /// 초기 로드 완료 대기 (위젯 초기화 흐름에서 사용)
  Future<void> ensureLoaded() => _loadCompleter.future;

  PrintProfileStorageService get _storage => PrintProfileStorageService();

  Future<void> _load() async {
    try {
      if (_timetableId == null) {
        state = const PrintProfileStore();
        return;
      }
      state = await _storage.loadStore(_timetableId);
    } finally {
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
    }
  }

  /// 계획서 저장(upsert) + 마지막 사용 계획서 갱신
  Future<bool> saveProfile(PrintProfile profile) async {
    if (_timetableId == null) return false;
    final success = await _storage.saveProfile(_timetableId, profile);
    if (success) {
      state = await _storage.loadStore(_timetableId);
    }
    return success;
  }

  /// 계획서 삭제
  Future<bool> deleteProfile(String profileId) async {
    if (_timetableId == null) return false;
    final success = await _storage.deleteProfile(_timetableId, profileId);
    if (success) {
      state = await _storage.loadStore(_timetableId);
    }
    return success;
  }

  /// 계획서 이름 변경
  Future<bool> renameProfile(String profileId, String newName) async {
    if (_timetableId == null) return false;
    final success = await _storage.renameProfile(
      _timetableId,
      profileId,
      newName,
    );
    if (success) {
      state = await _storage.loadStore(_timetableId);
    }
    return success;
  }

  /// 마지막 선택 교사 저장 (탭 재진입 시 복원용)
  Future<void> setLastSelectedTeacher(String teacherName) async {
    if (_timetableId == null) return;
    final success = await _storage.setLastSelectedTeacher(
      _timetableId,
      teacherName,
    );
    if (success) {
      state = state.copyWith(lastSelectedTeacher: teacherName);
    }
  }

  /// 마지막 사용 계획서 갱신 (디스크 저장 포함)
  Future<void> setLastUsedProfile(String profileId) async {
    if (_timetableId == null) return;
    final store = await _storage.loadStore(_timetableId);
    final updated = store.copyWith(lastUsedProfileId: profileId);
    await _storage.saveStore(_timetableId, updated);
    state = updated;
  }
}

/// 계획서 스토어 Provider — 활성 시간표가 바뀌면 재생성되어 새로 로드
final printProfileStoreProvider =
    StateNotifierProvider<PrintProfileStoreNotifier, PrintProfileStore>((
      ref,
    ) {
      final activeId = ref.watch(activeTimetableEntryProvider)?.id;
      return PrintProfileStoreNotifier(activeId);
    });
