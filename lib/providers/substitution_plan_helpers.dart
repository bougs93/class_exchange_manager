import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/class_name_parser.dart';
import 'substitution_plan_viewmodel.dart';
import 'substitution_plan_provider.dart';

/// 교체 노드 파싱 헬퍼 클래스
///
/// 중복된 노드 파싱 로직을 통합하고 결과를 캐싱합니다.
class ExchangeNodeParser {
  final Ref _ref;
  final Map<String, String> _savedDateCache = {};

  ExchangeNodeParser(this._ref);

  /// 저장된 날짜 정보 복원 (캐싱 포함)
  /// 
  /// Provider에서 직접 가져오되, 캐시를 통해 성능 최적화합니다.
  /// 저장된 날짜가 없으면 '선택'을 반환합니다.
  String getSavedDate(String exchangeId, String columnName) {
    final key = '${exchangeId}_$columnName';

    // 캐시에서 먼저 확인
    if (_savedDateCache.containsKey(key)) {
      return _savedDateCache[key]!;
    }

    // Provider에서 가져오기 (항상 최신 데이터)
    final date = _ref.read(substitutionPlanProvider.notifier).getSavedDate(exchangeId, columnName);
    final result = date.isNotEmpty ? date : '선택';

    // 캐시에 저장
    _savedDateCache[key] = result;
    return result;
  }

  /// 공통 노드 파싱 메서드
  SubstitutionPlanData parseNode({
    required dynamic sourceNode,
    required dynamic targetNode,
    required String exchangeId,
    required String groupId,
    String? remarks,
    bool isCircular = false,
    bool isChain = false,
    bool isSupplement = false,
  }) {
    final parsed = ClassNameParser.parse(sourceNode.className);

    if (isSupplement) {
      // 보강 교체
      return SubstitutionPlanData(
        exchangeId: exchangeId,
        absenceDate: getSavedDate(exchangeId, 'absenceDate'),
        absenceDay: sourceNode.day,
        period: sourceNode.period.toString(),
        grade: parsed['grade']!,
        className: parsed['class']!,
        subject: sourceNode.subjectName,
        teacher: sourceNode.teacherName,
        supplementSubject: '',
        supplementTeacher: targetNode.teacherName,
        substitutionDate: '',
        substitutionDay: '',
        substitutionPeriod: '',
        substitutionSubject: '',
        substitutionTeacher: '',
        remarks: remarks ?? '보강',
        groupId: groupId,
      );
    }

    // 수업 교체 (1:1, 순환, 연쇄)
    return SubstitutionPlanData(
      exchangeId: exchangeId,
      absenceDate: getSavedDate(exchangeId, 'absenceDate'),
      absenceDay: sourceNode.day,
      period: sourceNode.period.toString(),
      grade: parsed['grade']!,
      className: parsed['class']!,
      subject: sourceNode.subjectName,
      teacher: sourceNode.teacherName,
      supplementSubject: '',
      supplementTeacher: '',
      substitutionDate: getSavedDate(exchangeId, 'substitutionDate'),
      substitutionDay: targetNode.day,
      substitutionPeriod: targetNode.period.toString(),
      substitutionSubject: targetNode.subjectName,
      substitutionTeacher: targetNode.teacherName,
      remarks: remarks ?? '',
      groupId: groupId,
    );
  }

  /// 캐시 클리어
  void clearCache() {
    _savedDateCache.clear();
  }
}

/// 수업 조건 매칭 헬퍼 클래스
///
/// updateDate의 성능을 O(n²) → O(n)으로 개선합니다.
class ClassConditionMatcher {
  /// 수업 조건 키 생성
  static String generateKey(String day, String period, String grade, String className, String subject, String teacher) {
    return '$day|$period|$grade|$className|$subject|$teacher';
  }

  /// planData에서 인덱스 맵 생성
  static ClassConditionIndexMap buildIndexMap(List<SubstitutionPlanData> planData) {
    final Map<String, List<int>> absenceIndex = {};
    final Map<String, List<int>> substitutionIndex = {};

    for (int i = 0; i < planData.length; i++) {
      final data = planData[i];

      // 결강일 섹션 인덱싱
      final absenceKey = generateKey(
        data.absenceDay,
        data.period,
        data.grade,
        data.className,
        data.subject,
        data.teacher,
      );
      absenceIndex.putIfAbsent(absenceKey, () => []).add(i);

      // 교체일 섹션 인덱싱
      if (data.substitutionDay.isNotEmpty) {
        final substitutionKey = generateKey(
          data.substitutionDay,
          data.substitutionPeriod,
          data.grade,
          data.className,
          data.substitutionSubject,
          data.substitutionTeacher,
        );
        substitutionIndex.putIfAbsent(substitutionKey, () => []).add(i);
      }
    }

    return ClassConditionIndexMap(absenceIndex, substitutionIndex);
  }

  /// 대상 키 추출 (컬럼명에 따라)
  static String extractTargetKey(SubstitutionPlanData data, String columnName) {
    if (columnName == 'absenceDate') {
      return generateKey(
        data.absenceDay,
        data.period,
        data.grade,
        data.className,
        data.subject,
        data.teacher,
      );
    } else {
      // substitutionDate
      return generateKey(
        data.substitutionDay,
        data.substitutionPeriod,
        data.grade,
        data.className,
        data.substitutionSubject,
        data.substitutionTeacher,
      );
    }
  }
}

/// 인덱스 맵 클래스
class ClassConditionIndexMap {
  final Map<String, List<int>> absenceIndex;
  final Map<String, List<int>> substitutionIndex;

  ClassConditionIndexMap(this.absenceIndex, this.substitutionIndex);

  /// 특정 키에 해당하는 모든 인덱스 반환
  List<int> getIndices(String key) {
    return [
      ...absenceIndex[key] ?? [],
      ...substitutionIndex[key] ?? [],
    ];
  }
}
