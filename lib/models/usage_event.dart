import '../constants/nav_indices.dart';

/// 웹 사용 통계로 수집하는 이벤트 종류.
enum UsageEvent {
  /// 접속(로그인·자동 입장)
  visit,

  /// 상단 탭 진입 (탭 번호는 [UsageKeys.tab]로 구분)
  tab,

  /// 계획서 생성
  planCreate,

  /// 학급 안내 출력
  classOutput,

  /// 계획서 출력
  planOutput,

  /// PDF 저장
  pdfSave,
}

/// Firestore 문서에 쓰는 카운터 필드 키.
class UsageKeys {
  UsageKeys._();

  static const String visits = 'visits';
  static const String planCreate = 'planCreate';
  static const String classOutput = 'classOutput';
  static const String planOutput = 'planOutput';
  static const String pdfSave = 'pdfSave';

  static String tab(int index) => 'tab_$index';

  /// 탭 키 전체 (탭 번호 순).
  static List<String> get tabKeys => List.generate(NavIndices.screenCount, tab);

  /// 모든 카운터 키.
  static List<String> get all => [
    visits,
    ...tabKeys,
    planCreate,
    classOutput,
    planOutput,
    pdfSave,
  ];

  /// 탭 번호별 한글 라벨 (상단 탭 이름과 동일).
  static const List<String> tabLabels = ['준비', '교체', '계획서', '안내', '시간표', '도움말'];

  /// 이벤트 → 카운터 키. [UsageEvent.tab]은 [tabIndex]가 필요하다.
  static String? keyFor(UsageEvent event, {int? tabIndex}) {
    switch (event) {
      case UsageEvent.visit:
        return visits;
      case UsageEvent.tab:
        if (tabIndex == null ||
            tabIndex < 0 ||
            tabIndex >= NavIndices.screenCount) {
          return null;
        }
        return tab(tabIndex);
      case UsageEvent.planCreate:
        return planCreate;
      case UsageEvent.classOutput:
        return classOutput;
      case UsageEvent.planOutput:
        return planOutput;
      case UsageEvent.pdfSave:
        return pdfSave;
    }
  }
}

/// 교사명이 비어 있을 때 쓰는 버킷 이름.
const String kUsageUnnamedTeacher = '(이름 미설정)';

/// 하루치 사용 통계 문서 (`usageStats/yyyy-MM-dd`).
class UsageDay {
  const UsageDay({
    required this.date,
    this.totals = const {},
    this.teachers = const {},
    this.visitors = const {},
  });

  /// KST 날짜 `yyyy-MM-dd`
  final String date;
  final Map<String, int> totals;
  final Map<String, Map<String, int>> teachers;
  final Set<String> visitors;

  factory UsageDay.fromMap(String id, Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    Map<String, int> counters(Object? raw) {
      final out = <String, int>{};
      if (raw is Map) {
        for (final e in raw.entries) {
          final v = e.value;
          if (v is num) out[e.key.toString()] = v.toInt();
        }
      }
      return out;
    }

    final teachers = <String, Map<String, int>>{};
    final rawTeachers = map['teachers'];
    if (rawTeachers is Map) {
      for (final e in rawTeachers.entries) {
        teachers[e.key.toString()] = counters(e.value);
      }
    }
    final rawVisitors = map['visitors'];
    return UsageDay(
      date: id,
      totals: counters(map['totals']),
      teachers: teachers,
      visitors:
          rawVisitors is Map
              ? rawVisitors.keys.map((k) => k.toString()).toSet()
              : <String>{},
    );
  }
}
