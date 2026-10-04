import 'print_profile.dart';

/// 결보강 전체 삭제 때 교체 목록과 **함께** 지워지는 상태의 스냅샷.
///
/// 전체 삭제는 교체 목록 외에 계획서 스토어와 보강 과목도 비운다. 교체 목록은
/// `ExchangeHistoryService`의 묶음 되돌리기로 복원되고, 이 스냅샷은 그 묶음에
/// 붙어 다니다가 되돌리기·다시 실행 때 나머지 상태를 함께 맞추는 데 쓰인다.
class ExchangeClearSnapshot {
  const ExchangeClearSnapshot({
    this.profiles = const [],
    this.lastUsedProfileId,
    this.lastSelectedTeacher,
    this.supplementSubjects = const {},
  });

  /// 삭제 직전 상태를 그대로 뜬다.
  factory ExchangeClearSnapshot.capture({
    required PrintProfileStore store,
    required Map<String, String> supplementSubjects,
  }) {
    return ExchangeClearSnapshot(
      profiles: List.of(store.profiles),
      lastUsedProfileId: store.lastUsedProfileId,
      lastSelectedTeacher: store.lastSelectedTeacher,
      supplementSubjects: Map.of(supplementSubjects),
    );
  }

  final List<PrintProfile> profiles;
  final String? lastUsedProfileId;
  final String? lastSelectedTeacher;

  /// 키: 결보강 계획서의 exchangeId, 값: 보강 과목명
  final Map<String, String> supplementSubjects;

  Set<String> get profileIds => profiles.map((p) => p.id).toSet();

  /// 다시 실행(재삭제) 직전에 스냅샷을 다시 뜬다.
  ///
  /// 이 스냅샷이 복원했던 계획서·보강 과목만 대상으로, **현재** 값을 담는다 —
  /// 복원 후 사용자가 고친 내용이 다음 되돌리기에서 사라지지 않게 한다.
  /// 그 사이 사용자가 직접 지운 것은 담지 않는다.
  ExchangeClearSnapshot recapture({
    required PrintProfileStore store,
    required Map<String, String> supplementSubjects,
  }) {
    final ids = profileIds;
    return ExchangeClearSnapshot(
      profiles: store.profiles.where((p) => ids.contains(p.id)).toList(),
      lastUsedProfileId:
          ids.contains(store.lastUsedProfileId)
              ? store.lastUsedProfileId
              : null,
      lastSelectedTeacher: lastSelectedTeacher,
      supplementSubjects: {
        for (final key in this.supplementSubjects.keys)
          if (supplementSubjects.containsKey(key))
            key: supplementSubjects[key]!,
      },
    );
  }
}
