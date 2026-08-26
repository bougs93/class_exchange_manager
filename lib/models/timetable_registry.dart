/// 등록된 시간표(학기) 1건의 메타데이터
class TimetableRegistryEntry {
  /// 고유 식별자 (예: tt_20260826_143000_042)
  final String id;

  /// 사용자가 지정한 표시 이름 (예: "월계중1학기")
  final String name;

  /// 원본 엑셀 파일명 (UI 표시용)
  final String fileName;

  /// 원본 엑셀 파일 경로
  final String filePath;

  /// 파일명+내용 해시 (timetable_data_{hash}.json 생성용)
  final String hash;

  /// 내용 해시 (무결성 검증용)
  final String contentHash;

  /// 이 시간표에서의 교사 이름 (엑셀 교사 목록에서 선택, 미선택 시 null)
  ///
  /// 교체 화면 행 하이라이트·개인 시간표 기본 교사·계획서 교사명의 기준값입니다.
  /// 전역 설정이 아니라 시간표 속성인 이유는 문서 §2 참조.
  final String? myTeacherName;

  /// 이 시간표의 학교명 (계획서 인쇄용, 미입력 시 null)
  final String? schoolName;

  /// 등록 시각
  final DateTime registeredAt;

  const TimetableRegistryEntry({
    required this.id,
    required this.name,
    required this.fileName,
    required this.filePath,
    required this.hash,
    required this.contentHash,
    this.myTeacherName,
    this.schoolName,
    required this.registeredAt,
  });

  /// 교사가 지정되어 있는지
  bool get hasMyTeacher =>
      myTeacherName != null && myTeacherName!.trim().isNotEmpty;

  /// 고유 ID 생성 (동일 시각 연속 등록 충돌 방지를 위해 마이크로초+시퀀스 포함)
  static int _idSequence = 0;

  static String generateId({DateTime? now}) {
    final t = now ?? DateTime.now();
    final sequence = _idSequence++;
    final stamp =
        '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}'
        '_'
        '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}${t.second.toString().padLeft(2, '0')}'
        '_${t.microsecond.toString().padLeft(6, '0')}_$sequence';
    return 'tt_$stamp';
  }

  TimetableRegistryEntry copyWith({
    String? name,
    String? fileName,
    String? filePath,
    String? hash,
    String? contentHash,
    String? myTeacherName,
    String? schoolName,
    bool clearMyTeacherName = false,
    bool clearSchoolName = false,
  }) {
    return TimetableRegistryEntry(
      id: id,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      hash: hash ?? this.hash,
      contentHash: contentHash ?? this.contentHash,
      myTeacherName: clearMyTeacherName
          ? null
          : (myTeacherName ?? this.myTeacherName),
      schoolName: clearSchoolName ? null : (schoolName ?? this.schoolName),
      registeredAt: registeredAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fileName': fileName,
    'filePath': filePath,
    'hash': hash,
    'contentHash': contentHash,
    if (myTeacherName != null) 'myTeacherName': myTeacherName,
    if (schoolName != null) 'schoolName': schoolName,
    'registeredAt': registeredAt.toIso8601String(),
  };

  factory TimetableRegistryEntry.fromJson(Map<String, dynamic> json) {
    return TimetableRegistryEntry(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? (json['fileName'] as String? ?? ''),
      fileName: (json['fileName'] as String?) ?? '',
      filePath: (json['filePath'] as String?) ?? '',
      hash: (json['hash'] as String?) ?? '',
      contentHash: (json['contentHash'] as String?) ?? '',
      myTeacherName: _trimOrNull(json['myTeacherName'] as String?),
      schoolName: _trimOrNull(json['schoolName'] as String?),
      registeredAt:
          DateTime.tryParse(json['registeredAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 빈 문자열을 null로 정규화 (미지정과 빈 입력을 같게 취급)
  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TimetableRegistryEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TimetableRegistryEntry(id: $id, name: $name)';
}

/// 시간표 레지스트리 — 등록된 시간표 목록 + 활성 시간표 ID
class TimetableRegistry {
  /// 현재 활성 시간표 ID (시간표가 하나도 없으면 null)
  final String? activeId;

  /// 등록된 시간표 목록 (등록 순 유지)
  final List<TimetableRegistryEntry> timetables;

  const TimetableRegistry({this.activeId, this.timetables = const []});

  /// 활성 시간표 항목 (없으면 null)
  TimetableRegistryEntry? get activeEntry {
    if (activeId == null) return null;
    return getById(activeId!);
  }

  /// ID로 항목 조회 (없으면 null)
  TimetableRegistryEntry? getById(String id) {
    for (final entry in timetables) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// 활성 시간표가 유효한지 (목록에 존재하는지)
  bool get hasValidActive => activeEntry != null;

  TimetableRegistry copyWith({String? activeId, List<TimetableRegistryEntry>? timetables}) {
    return TimetableRegistry(
      activeId: activeId ?? this.activeId,
      timetables: timetables ?? this.timetables,
    );
  }

  /// 항목 추가 (비어 있으면 자동으로 활성 지정)
  TimetableRegistry withEntry(TimetableRegistryEntry entry) {
    final next = [...timetables, entry];
    return TimetableRegistry(
      activeId: activeId ?? entry.id,
      timetables: next,
    );
  }

  /// 항목 제거 (활성이었다면 활성 해제)
  TimetableRegistry withoutEntry(String id) {
    final next = timetables.where((e) => e.id != id).toList();
    return TimetableRegistry(
      activeId: activeId == id ? null : activeId,
      timetables: next,
    );
  }

  /// 활성 시간표 전환
  TimetableRegistry withActive(String id) {
    assert(getById(id) != null, '레지스트리에 없는 시간표 ID: $id');
    return TimetableRegistry(activeId: id, timetables: timetables);
  }

  Map<String, dynamic> toJson() => {
    'activeId': activeId,
    'timetables': timetables.map((e) => e.toJson()).toList(),
  };

  factory TimetableRegistry.fromJson(Map<String, dynamic> json) {
    final list = (json['timetables'] as List<dynamic>? ?? [])
        .map(
          (e) => TimetableRegistryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return TimetableRegistry(
      activeId: json['activeId'] as String?,
      timetables: list,
    );
  }
}
