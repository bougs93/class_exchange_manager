import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_path.dart';
import '../utils/logger.dart';
import 'services_provider.dart';
import 'substitution_plan_provider.dart';
import 'substitution_plan_helpers.dart';

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
  final String? groupId;        // 교체 그룹 ID (순환교체 4단계 이상에서 그룹 구분용)

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
    this.groupId,
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
    String? groupId,
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
      groupId: groupId ?? this.groupId,
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
    _parser = ExchangeNodeParser(_ref);
    
    // 초기 데이터 로드
    loadPlanData();
    
    // 🔥 교체 리스트 변경 감지 및 자동 새로고침
    // exchangeListVersionProvider의 값이 변경되면 (즉, 교체 리스트가 변경되면)
    // 자동으로 결보강계획서를 새로고침합니다.
    _ref.listen(exchangeListVersionProvider, (previous, next) {
      // 이전 버전이 null이 아니고 (초기화되지 않은 상태가 아니고)
      // 버전이 실제로 변경되었을 때만 새로고침을 실행합니다.
      if (previous != null && previous != next) {
        AppLogger.exchangeDebug('[자동 새로고침] 교체 리스트 변경 감지 (버전: $previous → $next)');
        
        // 로딩 중이 아닐 때만 새로고침 (중복 호출 방지)
        if (!state.isLoading) {
          loadPlanData();
        }
      }
    });
  }

  final Ref _ref;
  late final ExchangeNodeParser _parser;

  /// 교체 항목의 고유 식별자 생성
  String _generateExchangeId(String teacher, String day, String period, String subject, {String? suffix}) {
    final base = '${teacher}_$day${period}_$subject';
    return suffix != null ? '${base}_$suffix' : base;
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

      // 캐시 클리어
      _parser.clearCache();

      final List<SubstitutionPlanData> newPlanData = [];

      for (final item in exchangeList) {
        final nodes = item.originalPath.nodes;
        final exchangeType = item.type;

        AppLogger.exchangeDebug('교체 타입 처리: ${exchangeType.displayName}');

        switch (exchangeType) {
          case ExchangePathType.oneToOne:
            _handleOneToOneExchange(nodes, item.notes, newPlanData, item.id);
            break;

          case ExchangePathType.circular:
            _handleCircularExchange(nodes, newPlanData, item.id);
            break;

          case ExchangePathType.chain:
            _handleChainExchange(nodes, newPlanData, item.id);
            break;

          case ExchangePathType.supplement:
            _handleSupplementExchange(nodes, newPlanData, item.id);
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
  void _handleOneToOneExchange(List nodes, String? notes, List<SubstitutionPlanData> planData, String groupId) {
    if (nodes.length < 2) {
      AppLogger.exchangeDebug('1:1 교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final sourceNode = nodes[0];
    final targetNode = nodes[1];
    final exchangeId = _generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName);

    final data = _parser.parseNode(
      sourceNode: sourceNode,
      targetNode: targetNode,
      exchangeId: exchangeId,
      groupId: groupId,
      remarks: notes,
    );

    planData.add(data);
    AppLogger.exchangeDebug('1:1 교체 처리 완료');
  }

  /// 순환 교체 처리
  void _handleCircularExchange(List nodes, List<SubstitutionPlanData> planData, String groupId) {
    if (nodes.length < 3) {
      AppLogger.exchangeDebug('순환교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    // 순환교체 단계 수 계산
    final stepCount = nodes.length - 1;
    AppLogger.exchangeDebug('순환교체 단계 수: $stepCount, 그룹ID: $groupId');

    // 3개 노드: 첫 번째 쌍만 표시
    if (nodes.length == 3) {
      final sourceNode = nodes[0];
      final targetNode = nodes[1];
      final exchangeId = _generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName, suffix: '순환');

      final data = _parser.parseNode(
        sourceNode: sourceNode,
        targetNode: targetNode,
        exchangeId: exchangeId,
        groupId: groupId,
        remarks: _getCircularExchangeRemarks(0, nodes.length),
        isCircular: true,
      );

      planData.add(data);
    } else {
      // 4개 이상: 모든 교체 쌍 표시
      for (int i = 0; i < nodes.length - 1; i++) {
        final sourceNode = nodes[i];
        final targetNode = nodes[i + 1];
        final exchangeId = _generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName, suffix: '순환${i + 1}');

        final data = _parser.parseNode(
          sourceNode: sourceNode,
          targetNode: targetNode,
          exchangeId: exchangeId,
          groupId: groupId,
          remarks: _getCircularExchangeRemarks(i, nodes.length),
          isCircular: true,
        );

        planData.add(data);
      }
    }

    AppLogger.exchangeDebug('순환교체 처리 완료');
  }

  /// 순환교체 비고란 생성 헬퍼 메서드
  String _getCircularExchangeRemarks(int index, int totalNodes) {
    final stepCount = totalNodes;

    // 2단계, 3단계 순환교체: 비고란 빈칸
    if (stepCount <= 3) {
      return '';
    }

    // 4단계 이상
    return index == totalNodes - 2 ? '순환대체${index + 1}*' : '순환대체${index + 1}';
  }

  /// 연쇄 교체 처리
  void _handleChainExchange(List nodes, List<SubstitutionPlanData> planData, String groupId) {
    if (nodes.length < 4) {
      AppLogger.exchangeDebug('연쇄교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final absentNode = nodes[0];
    final substituteNode = nodes[1];
    final intermediateNode1 = nodes[2];
    final intermediateNode2 = nodes[3];

    // 최종 교체
    final finalExchangeId = _generateExchangeId(substituteNode.teacherName, substituteNode.day, substituteNode.period.toString(), substituteNode.subjectName, suffix: '연쇄최종');
    final finalData = _parser.parseNode(
      sourceNode: substituteNode,
      targetNode: absentNode,
      exchangeId: finalExchangeId,
      groupId: groupId,
      remarks: '연쇄교체(중간)',
      isChain: true,
    );
    planData.add(finalData);

    // 중간 교체
    final intermediateExchangeId = _generateExchangeId(intermediateNode1.teacherName, intermediateNode1.day, intermediateNode1.period.toString(), intermediateNode1.subjectName, suffix: '연쇄중간');
    final intermediateData = _parser.parseNode(
      sourceNode: intermediateNode1,
      targetNode: intermediateNode2,
      exchangeId: intermediateExchangeId,
      groupId: groupId,
      remarks: '연쇄교체(최종)',
      isChain: true,
    );
    planData.add(intermediateData);

    AppLogger.exchangeDebug('연쇄교체 처리 완료');
  }

  /// 보강 교체 처리
  void _handleSupplementExchange(List nodes, List<SubstitutionPlanData> planData, String groupId) {
    if (nodes.length < 2) {
      AppLogger.exchangeDebug('보강교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final sourceNode = nodes[0];
    final targetNode = nodes[1];
    final exchangeId = _generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName, suffix: '보강');

    final data = _parser.parseNode(
      sourceNode: sourceNode,
      targetNode: targetNode,
      exchangeId: exchangeId,
      groupId: groupId,
      isSupplement: true,
    );

    planData.add(data);
    AppLogger.exchangeDebug('보강교체 처리 완료');
  }

  /// 날짜 업데이트 (동일 수업 조건 연동) - 성능 최적화 버전 O(n)
  void updateDate(String exchangeId, String columnName, String newDate) {
    // Provider에 날짜 저장
    _ref.read(substitutionPlanProvider.notifier).saveDate(exchangeId, columnName, newDate);

    // 현재 항목 찾기
    final currentIndex = state.planData.indexWhere((data) => data.exchangeId == exchangeId);
    if (currentIndex == -1) return;

    final currentData = state.planData[currentIndex];

    // 수업 조건 키 생성
    final targetKey = ClassConditionMatcher.extractTargetKey(currentData, columnName);

    // 연동 대상 인덱스 추출
    final indicesToUpdate = <int, String>{}; // index -> columnName

    for (int i = 0; i < state.planData.length; i++) {
      final data = state.planData[i];

      // 결강일 섹션 검사
      final absenceKey = ClassConditionMatcher.generateKey(
        data.absenceDay,
        data.period,
        data.grade,
        data.className,
        data.subject,
        data.teacher,
      );

      if (absenceKey == targetKey) {
        indicesToUpdate[i] = 'absenceDate';
        _ref.read(substitutionPlanProvider.notifier).saveDate(data.exchangeId, 'absenceDate', newDate);
      }

      // 교체일 섹션 검사
      if (data.substitutionDay.isNotEmpty) {
        final substitutionKey = ClassConditionMatcher.generateKey(
          data.substitutionDay,
          data.substitutionPeriod,
          data.grade,
          data.className,
          data.substitutionSubject,
          data.substitutionTeacher,
        );

        if (substitutionKey == targetKey) {
          indicesToUpdate[i] = 'substitutionDate';
          _ref.read(substitutionPlanProvider.notifier).saveDate(data.exchangeId, 'substitutionDate', newDate);
        }
      }
    }

    // 인덱스 기반 업데이트 (불변성 유지)
    final updatedPlanData = List<SubstitutionPlanData>.from(state.planData);
    for (final entry in indicesToUpdate.entries) {
      final index = entry.key;
      final column = entry.value;

      if (column == 'absenceDate') {
        updatedPlanData[index] = updatedPlanData[index].copyWith(absenceDate: newDate);
      } else {
        updatedPlanData[index] = updatedPlanData[index].copyWith(substitutionDate: newDate);
      }
    }

    state = state.copyWith(planData: updatedPlanData);
  }

  /// 모든 날짜 및 보강 과목 초기화
  void clearAllDates() {
    _ref.read(substitutionPlanProvider.notifier).clearAllDates();

    final clearedPlanData = state.planData.map((data) {
      return data.copyWith(
        absenceDate: '선택',
        substitutionDate: '선택',
        supplementSubject: '', // 보강 과목도 초기화
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
