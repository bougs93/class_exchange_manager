/// 인쇄 프로파일(계획서) 1건
///
/// 시간표 안에서 교사별로 여러 개를 관리하며, 교체 건에 지정되어
/// PDF 출력 설정(양식·폰트·비고·추가 필드 등)을 제공합니다.
class PrintProfile {
  /// 고유 식별자 (예: pp_20260826_150000_042)
  final String id;

  /// 계획서 이름 (예: "계획서1")
  final String name;

  /// 귀속 교사명 (시간표 데이터의 교사명과 일치)
  final String teacherName;

  /// 양식 인덱스 (0: 양식 1, 1: 양식 2)
  final int templateIndex;

  /// 본문 폰트 크기
  final double fontSize;

  /// 비고 폰트 크기
  final double remarksFontSize;

  /// 선택된 폰트 파일명
  final String selectedFont;

  /// 비고 포함 여부
  final bool includeRemarks;

  /// 추가 필드 (키: 필드명, 값: 입력값)
  final Map<String, String> additionalFields;

  /// 사용자 지정 PDF 템플릿 파일 경로 (선택)
  final String? selectedTemplateFilePath;

  const PrintProfile({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.templateIndex,
    required this.fontSize,
    required this.remarksFontSize,
    required this.selectedFont,
    required this.includeRemarks,
    this.additionalFields = const {},
    this.selectedTemplateFilePath,
  });

  /// 고유 ID 생성 (동일 시각 연속 생성 충돌 방지를 위해 마이크로초+시퀀스 포함)
  static int _idSequence = 0;

  static String generateId({DateTime? now}) {
    final t = now ?? DateTime.now();
    final sequence = _idSequence++;
    final stamp =
        '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}'
        '_'
        '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}${t.second.toString().padLeft(2, '0')}'
        '_${t.microsecond.toString().padLeft(6, '0')}_$sequence';
    return 'pp_$stamp';
  }

  PrintProfile copyWith({
    String? name,
    String? teacherName,
    int? templateIndex,
    double? fontSize,
    double? remarksFontSize,
    String? selectedFont,
    bool? includeRemarks,
    Map<String, String>? additionalFields,
    String? selectedTemplateFilePath,
    bool clearTemplateFilePath = false,
  }) {
    return PrintProfile(
      id: id,
      name: name ?? this.name,
      teacherName: teacherName ?? this.teacherName,
      templateIndex: templateIndex ?? this.templateIndex,
      fontSize: fontSize ?? this.fontSize,
      remarksFontSize: remarksFontSize ?? this.remarksFontSize,
      selectedFont: selectedFont ?? this.selectedFont,
      includeRemarks: includeRemarks ?? this.includeRemarks,
      additionalFields: additionalFields ?? this.additionalFields,
      selectedTemplateFilePath: clearTemplateFilePath
          ? null
          : (selectedTemplateFilePath ?? this.selectedTemplateFilePath),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacherName': teacherName,
    'templateIndex': templateIndex,
    'fontSize': fontSize,
    'remarksFontSize': remarksFontSize,
    'selectedFont': selectedFont,
    'includeRemarks': includeRemarks,
    'additionalFields': additionalFields,
    if (selectedTemplateFilePath != null)
      'selectedTemplateFilePath': selectedTemplateFilePath,
  };

  factory PrintProfile.fromJson(Map<String, dynamic> json) {
    // 구버전 호환: additionalFields가 Map<String, dynamic>일 수 있음
    final rawFields = json['additionalFields'];
    final fields = <String, String>{};
    if (rawFields is Map) {
      rawFields.forEach((key, value) {
        fields[key.toString()] = value?.toString() ?? '';
      });
    }

    return PrintProfile(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      teacherName: (json['teacherName'] as String?) ?? '',
      templateIndex: (json['templateIndex'] as num?)?.toInt() ?? 0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 10.0,
      remarksFontSize: (json['remarksFontSize'] as num?)?.toDouble() ?? 7.0,
      selectedFont: (json['selectedFont'] as String?) ?? 'hanbatang.ttf',
      includeRemarks: json['includeRemarks'] as bool? ?? false,
      additionalFields: fields,
      selectedTemplateFilePath: json['selectedTemplateFilePath'] as String?,
    );
  }

  /// 설정 내용이 같은지 비교 (id·name·teacherName 제외)
  ///
  /// 화면 값이 저장된 계획서와 달라졌는지(dirty) 판정하는 데 사용합니다.
  /// [operator ==]는 id만 비교하므로 이 목적에는 쓸 수 없습니다.
  ///
  /// [ignoreFields]에 넣은 `additionalFields` 키는 비교에서 제외합니다
  /// (예: 결강기간처럼 사용자가 편집하지 않아도 자동으로 다시 계산되는 값).
  /// 값이 없는 키와 빈 문자열은 같게 취급합니다.
  bool contentEquals(PrintProfile other, {Set<String> ignoreFields = const {}}) {
    if (templateIndex != other.templateIndex ||
        fontSize != other.fontSize ||
        remarksFontSize != other.remarksFontSize ||
        selectedFont != other.selectedFont ||
        includeRemarks != other.includeRemarks ||
        selectedTemplateFilePath != other.selectedTemplateFilePath) {
      return false;
    }

    // 비교 대상 키 합집합 — 한쪽에만 있는 키도 빠짐없이 본다
    final keys = {...additionalFields.keys, ...other.additionalFields.keys}
      ..removeAll(ignoreFields);

    for (final key in keys) {
      if ((additionalFields[key] ?? '') != (other.additionalFields[key] ?? '')) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PrintProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PrintProfile(id: $id, name: $name, teacherName: $teacherName)';
}

/// 시간표 1개의 계획서 저장소 상태
///
/// 파일 단위: `print_profiles_{timetableId}.json`
class PrintProfileStore {
  /// 계획서 목록 (교사별 그룹핑은 UI에서 teacherName으로 수행)
  final List<PrintProfile> profiles;

  /// 마지막으로 사용한 계획서 ID (미지정 교체 건의 기본값)
  final String? lastUsedProfileId;

  /// 마지막으로 선택한 교사 (탭 재진입 시 복원용)
  final String? lastSelectedTeacher;

  const PrintProfileStore({
    this.profiles = const [],
    this.lastUsedProfileId,
    this.lastSelectedTeacher,
  });

  /// ID로 계획서 조회 (없으면 null)
  PrintProfile? getById(String? id) {
    if (id == null) return null;
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// 특정 교사의 계획서 목록
  List<PrintProfile> byTeacher(String teacherName) {
    return profiles.where((p) => p.teacherName == teacherName).toList();
  }

  /// 저장소에 존재하는 교사명 목록 (profiles 등장 순)
  List<String> get teacherNames {
    final names = <String>[];
    for (final profile in profiles) {
      if (!names.contains(profile.teacherName)) {
        names.add(profile.teacherName);
      }
    }
    return names;
  }

  PrintProfileStore copyWith({
    List<PrintProfile>? profiles,
    String? lastUsedProfileId,
    String? lastSelectedTeacher,
    bool clearLastUsedProfileId = false,
  }) {
    return PrintProfileStore(
      profiles: profiles ?? this.profiles,
      lastUsedProfileId: clearLastUsedProfileId
          ? null
          : (lastUsedProfileId ?? this.lastUsedProfileId),
      lastSelectedTeacher: lastSelectedTeacher ?? this.lastSelectedTeacher,
    );
  }

  Map<String, dynamic> toJson() => {
    'profiles': profiles.map((p) => p.toJson()).toList(),
    'lastUsedProfileId': lastUsedProfileId,
    'lastSelectedTeacher': lastSelectedTeacher,
  };

  factory PrintProfileStore.fromJson(Map<String, dynamic> json) {
    final list = (json['profiles'] as List<dynamic>? ?? [])
        .map((e) => PrintProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return PrintProfileStore(
      profiles: list,
      lastUsedProfileId: json['lastUsedProfileId'] as String?,
      lastSelectedTeacher: json['lastSelectedTeacher'] as String?,
    );
  }
}
