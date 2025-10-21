import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_path.dart';
import '../utils/logger.dart';
import '../utils/class_name_parser.dart';
import 'services_provider.dart';
import 'substitution_plan_provider.dart';

/// 보강계획서 데이터 모델
class SubstitutionPlanData {
  final String exchangeId;      // 교체 식별자 (고유 키)
  final String absenceDate;      // 결강일
  final String absenceDay;       // 결강 요일
  final String period;           // 교시
  final String grade;           // 학년
  final String className;       // 반
  final String subject;         // 과목
  final String teacher;         // 교사
  final String supplementSubject; // 보강/수업변경 과목
  final String supplementTeacher; // 보강/수업변경 교사 성명
  final String substitutionDate; // 교체일
  final String substitutionDay;  // 교체 요일
  final String substitutionPeriod; // 교체 교시
  final String substitutionSubject; // 교체 과목
  final String substitutionTeacher; // 교체 교사 성명
  final String remarks;         // 비고

  SubstitutionPlanData({
    required this.exchangeId,
    required this.absenceDate,
    required this.absenceDay,
    required this.period,
    required this.grade,
    required this.className,
    required this.subject,
    required this.teacher,
    required this.supplementSubject,
    required this.supplementTeacher,
    required this.substitutionDate,
    required this.substitutionDay,
    required this.substitutionPeriod,
    required this.substitutionSubject,
    required this.substitutionTeacher,
    required this.remarks,
  });

  SubstitutionPlanData copyWith({
    String? exchangeId,
    String? absenceDate,
    String? absenceDay,
    String? period,
    String? grade,
    String? className,
    String? subject,
    String? teacher,
    String? supplementSubject,
    String? supplementTeacher,
    String? substitutionDate,
    String? substitutionDay,
    String? substitutionPeriod,
    String? substitutionSubject,
    String? substitutionTeacher,
    String? remarks,
  }) {
    return SubstitutionPlanData(
      exchangeId: exchangeId ?? this.exchangeId,
      absenceDate: absenceDate ?? this.absenceDate,
      absenceDay: absenceDay ?? this.absenceDay,
      period: period ?? this.period,
      grade: grade ?? this.grade,
      className: className ?? this.className,
      subject: subject ?? this.subject,
      teacher: teacher ?? this.teacher,
      supplementSubject: supplementSubject ?? this.supplementSubject,
      supplementTeacher: supplementTeacher ?? this.supplementTeacher,
      substitutionDate: substitutionDate ?? this.substitutionDate,
      substitutionDay: substitutionDay ?? this.substitutionDay,
      substitutionPeriod: substitutionPeriod ?? this.substitutionPeriod,
      substitutionSubject: substitutionSubject ?? this.substitutionSubject,
      substitutionTeacher: substitutionTeacher ?? this.substitutionTeacher,
      remarks: remarks ?? this.remarks,
    );
  }
}

/// 보강계획서 ViewModel 상태
class SubstitutionPlanViewModelState {
  final List<SubstitutionPlanData> planData;
  final bool isLoading;
  final String? errorMessage;

  const SubstitutionPlanViewModelState({
    this.planData = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SubstitutionPlanViewModelState copyWith({
    List<SubstitutionPlanData>? planData,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SubstitutionPlanViewModelState(
      planData: planData ?? this.planData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// 보강계획서 ViewModel
///
/// 교체 히스토리를 보강계획서 데이터로 변환하고 관리합니다.
class SubstitutionPlanViewModel extends StateNotifier<SubstitutionPlanViewModelState> {
  SubstitutionPlanViewModel(this._ref) : super(const SubstitutionPlanViewModelState()) {
    loadPlanData();
  }

  final Ref _ref;

  /// 교체 항목의 고유 식별자 생성
  String _generateExchangeId(String teacher, String day, String period, String subject) {
    return '${teacher}_$day${period}_$subject';
  }

  /// 수업 조건 키 생성 (요일, 교시, 학년, 반, 과목, 교사)
  String _generateClassConditionKey(String day, String period, String grade, String className, String subject, String teacher) {
    return '$day|$period|$grade|$className|$subject|$teacher';
  }

  /// 저장된 날짜 정보를 복원
  String _getSavedDate(String exchangeId, String columnName) {
    final savedDate = _ref.read(substitutionPlanProvider.notifier).getSavedDate(exchangeId, columnName);
    return savedDate.isNotEmpty ? savedDate : '선택';
  }

  /// 교체 히스토리에서 보강계획서 데이터 로드
  Future<void> loadPlanData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final historyService = _ref.read(exchangeHistoryServiceProvider);
      final exchangeList = historyService.getExchangeList();

      AppLogger.exchangeDebug('교체 히스토리 개수: ${exchangeList.length}');

      if (exchangeList.isEmpty) {
        state = state.copyWith(planData: [], isLoading: false);
        AppLogger.exchangeDebug('교체 히스토리가 없어서 빈 리스트로 설정');
        return;
      }

      final List<SubstitutionPlanData> newPlanData = [];

      for (final item in exchangeList) {
        final nodes = item.originalPath.nodes;
        final exchangeType = item.type;

        AppLogger.exchangeDebug('교체 타입 처리: ${exchangeType.displayName}');

        switch (exchangeType) {
          case ExchangePathType.oneToOne:
            _handleOneToOneExchange(nodes, item.notes, newPlanData);
            break;

          case ExchangePathType.circular:
            _handleCircularExchange(nodes, newPlanData);
            break;

          case ExchangePathType.chain:
            _handleChainExchange(nodes, newPlanData);
            break;

          case ExchangePathType.supplement:
            _handleSupplementExchange(nodes, newPlanData);
            break;
        }
      }

      // 저장된 보강 과목 복원 적용
      final restored = newPlanData.map((d) {
        final saved = _ref.read(substitutionPlanProvider.notifier).getSupplementSubject(d.exchangeId);
        return saved.isNotEmpty ? d.copyWith(supplementSubject: saved) : d;
      }).toList();

      state = state.copyWith(planData: restored, isLoading: false);
      AppLogger.exchangeDebug('최종 planData 개수: ${newPlanData.length}');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '데이터 로드 중 오류: $e',
      );
      AppLogger.exchangeDebug('데이터 로드 중 오류: $e');
    }
  }

  /// 1:1 교체 처리
  void _handleOneToOneExchange(List nodes, String? notes, List<SubstitutionPlanData> planData) {
    if (nodes.length < 2) {
      AppLogger.exchangeDebug('1:1 교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final sourceNode = nodes[0];
    final targetNode = nodes[1];
    final exchangeId = _generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName);
    final parsed = ClassNameParser.parse(sourceNode.className);

    planData.add(SubstitutionPlanData(
      exchangeId: exchangeId,
      absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
      absenceDay: sourceNode.day,
      period: sourceNode.period.toString(),
      grade: parsed['grade']!,
      className: parsed['class']!,
      subject: sourceNode.subjectName,
      teacher: sourceNode.teacherName,
      supplementSubject: '',
      supplementTeacher: '',
      substitutionDate: _getSavedDate(exchangeId, 'substitutionDate'),
      substitutionDay: targetNode.day,
      substitutionPeriod: targetNode.period.toString(),
      substitutionSubject: targetNode.subjectName,
      substitutionTeacher: targetNode.teacherName,
      remarks: notes ?? '',
    ));

    AppLogger.exchangeDebug('1:1 교체 처리 완료');
  }

  /// 순환 교체 처리
  void _handleCircularExchange(List nodes, List<SubstitutionPlanData> planData) {
    if (nodes.length < 3) {
      AppLogger.exchangeDebug('순환교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    // 3개 노드: 첫 번째 쌍만 표시
    if (nodes.length == 3) {
      final sourceNode = nodes[0];
      final targetNode = nodes[1];
      final exchangeId = '${_generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName)}_순환';
      final parsed = ClassNameParser.parse(sourceNode.className);

      planData.add(SubstitutionPlanData(
        exchangeId: exchangeId,
        absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
        absenceDay: sourceNode.day,
        period: sourceNode.period.toString(),
        grade: parsed['grade']!,
        className: parsed['class']!,
        subject: sourceNode.subjectName,
        teacher: sourceNode.teacherName,
        supplementSubject: '',
        supplementTeacher: '',
        substitutionDate: _getSavedDate(exchangeId, 'substitutionDate'),
        substitutionDay: targetNode.day,
        substitutionPeriod: targetNode.period.toString(),
        substitutionSubject: targetNode.subjectName,
        substitutionTeacher: targetNode.teacherName,
        remarks: '',
      ));
    } else {
      // 4개 이상: 모든 교체 쌍 표시
      for (int i = 0; i < nodes.length - 1; i++) {
        final sourceNode = nodes[i];
        final targetNode = nodes[i + 1];
        final exchangeId = '${_generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName)}_순환${i + 1}';
        final parsed = ClassNameParser.parse(sourceNode.className);

        planData.add(SubstitutionPlanData(
          exchangeId: exchangeId,
          absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
          absenceDay: sourceNode.day,
          period: sourceNode.period.toString(),
          grade: parsed['grade']!,
          className: parsed['class']!,
          subject: sourceNode.subjectName,
          teacher: sourceNode.teacherName,
          supplementSubject: '',
          supplementTeacher: '',
          substitutionDate: _getSavedDate(exchangeId, 'substitutionDate'),
          substitutionDay: targetNode.day,
          substitutionPeriod: targetNode.period.toString(),
          substitutionSubject: targetNode.subjectName,
          substitutionTeacher: targetNode.teacherName,
          remarks: i == nodes.length - 2 ? '(삭제가능)' : '순환교체${i + 1}',
        ));
      }
    }

    AppLogger.exchangeDebug('순환교체 처리 완료');
  }

  /// 연쇄 교체 처리
  void _handleChainExchange(List nodes, List<SubstitutionPlanData> planData) {
    if (nodes.length < 4) {
      AppLogger.exchangeDebug('연쇄교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final absentNode = nodes[0];
    final substituteNode = nodes[1];
    final intermediateNode1 = nodes[2];
    final intermediateNode2 = nodes[3];

    // 최종 교체
    final finalExchangeId = '${_generateExchangeId(substituteNode.teacherName, substituteNode.day, substituteNode.period.toString(), substituteNode.subjectName)}_연쇄최종';
    final finalParsed = ClassNameParser.parse(substituteNode.className);

    planData.add(SubstitutionPlanData(
      exchangeId: finalExchangeId,
      absenceDate: _getSavedDate(finalExchangeId, 'absenceDate'),
      absenceDay: substituteNode.day,
      period: substituteNode.period.toString(),
      grade: finalParsed['grade']!,
      className: finalParsed['class']!,
      subject: substituteNode.subjectName,
      teacher: substituteNode.teacherName,
      supplementSubject: '',
      supplementTeacher: '',
      substitutionDate: _getSavedDate(finalExchangeId, 'substitutionDate'),
      substitutionDay: absentNode.day,
      substitutionPeriod: absentNode.period.toString(),
      substitutionSubject: absentNode.subjectName,
      substitutionTeacher: absentNode.teacherName,
      remarks: '연쇄교체(중간)',
    ));

    // 중간 교체
    final intermediateExchangeId = '${_generateExchangeId(intermediateNode1.teacherName, intermediateNode1.day, intermediateNode1.period.toString(), intermediateNode1.subjectName)}_연쇄중간';
    final intermediateParsed = ClassNameParser.parse(intermediateNode1.className);

    planData.add(SubstitutionPlanData(
      exchangeId: intermediateExchangeId,
      absenceDate: _getSavedDate(intermediateExchangeId, 'absenceDate'),
      absenceDay: intermediateNode1.day,
      period: intermediateNode1.period.toString(),
      grade: intermediateParsed['grade']!,
      className: intermediateParsed['class']!,
      subject: intermediateNode1.subjectName,
      teacher: intermediateNode1.teacherName,
      supplementSubject: '',
      supplementTeacher: '',
      substitutionDate: _getSavedDate(intermediateExchangeId, 'substitutionDate'),
      substitutionDay: intermediateNode2.day,
      substitutionPeriod: intermediateNode2.period.toString(),
      substitutionSubject: intermediateNode2.subjectName,
      substitutionTeacher: intermediateNode2.teacherName,
      remarks: '연쇄교체(최종)',
    ));

    AppLogger.exchangeDebug('연쇄교체 처리 완료');
  }

  /// 보강 교체 처리
  void _handleSupplementExchange(List nodes, List<SubstitutionPlanData> planData) {
    if (nodes.length < 2) {
      AppLogger.exchangeDebug('보강교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final sourceNode = nodes[0];
    final targetNode = nodes[1];
    final exchangeId = '${_generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName)}_보강';
    final parsed = ClassNameParser.parse(sourceNode.className);

    planData.add(SubstitutionPlanData(
      exchangeId: exchangeId,
      absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
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
      remarks: '보강',
    ));

    AppLogger.exchangeDebug('보강교체 처리 완료');
  }

  /// 날짜 업데이트 (동일 수업 조건 연동)
  void updateDate(String exchangeId, String columnName, String newDate) {
    // Provider에 날짜 저장
    _ref.read(substitutionPlanProvider.notifier).saveDate(exchangeId, columnName, newDate);

    // 현재 항목 찾기
    final currentIndex = state.planData.indexWhere((data) => data.exchangeId == exchangeId);
    if (currentIndex == -1) return;

    final currentData = state.planData[currentIndex];

    // 수업 조건 키 생성
    String day, period, grade, className, subject, teacher;
    if (columnName == 'absenceDate') {
      day = currentData.absenceDay;
      period = currentData.period;
      grade = currentData.grade;
      className = currentData.className;
      subject = currentData.subject;
      teacher = currentData.teacher;
    } else {
      day = currentData.substitutionDay;
      period = currentData.substitutionPeriod;
      grade = currentData.grade;
      className = currentData.className;
      subject = currentData.substitutionSubject;
      teacher = currentData.substitutionTeacher;
    }

    final classConditionKey = _generateClassConditionKey(day, period, grade, className, subject, teacher);

    // 연동 업데이트
    final updatedPlanData = state.planData.map((data) {
      bool shouldUpdateAbsence = false;
      bool shouldUpdateSubstitution = false;

      // 결강일 섹션 검사
      final absenceKey = _generateClassConditionKey(
        data.absenceDay,
        data.period,
        data.grade,
        data.className,
        data.subject,
        data.teacher,
      );

      if (absenceKey == classConditionKey) {
        shouldUpdateAbsence = true;
        _ref.read(substitutionPlanProvider.notifier).saveDate(data.exchangeId, 'absenceDate', newDate);
      }

      // 교체일 섹션 검사
      final substitutionKey = _generateClassConditionKey(
        data.substitutionDay,
        data.substitutionPeriod,
        data.grade,
        data.className,
        data.substitutionSubject,
        data.substitutionTeacher,
      );

      if (substitutionKey == classConditionKey) {
        shouldUpdateSubstitution = true;
        _ref.read(substitutionPlanProvider.notifier).saveDate(data.exchangeId, 'substitutionDate', newDate);
      }

      if (shouldUpdateAbsence || shouldUpdateSubstitution) {
        return data.copyWith(
          absenceDate: shouldUpdateAbsence ? newDate : data.absenceDate,
          substitutionDate: shouldUpdateSubstitution ? newDate : data.substitutionDate,
        );
      }

      return data;
    }).toList();

    state = state.copyWith(planData: updatedPlanData);
  }

  /// 모든 날짜 초기화
  void clearAllDates() {
    _ref.read(substitutionPlanProvider.notifier).clearAllDates();

    final clearedPlanData = state.planData.map((data) {
      return data.copyWith(
        absenceDate: '선택',
        substitutionDate: '선택',
      );
    }).toList();

    state = state.copyWith(planData: clearedPlanData);
  }

  /// 보강 과목 업데이트 (해당 교체 항목만 반영)
  void updateSupplementSubject(String exchangeId, String newSubject) {
    // 전역 Provider에 저장
    _ref.read(substitutionPlanProvider.notifier).saveSupplementSubject(exchangeId, newSubject);

    final updated = state.planData.map((data) {
      if (data.exchangeId == exchangeId) {
        return data.copyWith(supplementSubject: newSubject);
      }
      return data;
    }).toList();

    state = state.copyWith(planData: updated);
    AppLogger.exchangeInfo('보강 과목 업데이트: $exchangeId -> $newSubject');
  }
}

/// 보강계획서 ViewModel Provider
final substitutionPlanViewModelProvider =
    StateNotifierProvider<SubstitutionPlanViewModel, SubstitutionPlanViewModelState>((ref) {
  return SubstitutionPlanViewModel(ref);
});
