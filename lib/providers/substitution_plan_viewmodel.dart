import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_path.dart';
import '../utils/day_utils.dart';
import '../utils/event_date_resolver.dart';
import '../utils/logger.dart';
import '../utils/date_format_utils.dart';
import '../utils/teacher_display.dart';
import 'services_provider.dart';
import 'substitution_plan_provider.dart';
import 'substitution_plan_helpers.dart';

/// 보강계획서 데이터 모델
class SubstitutionPlanData {
  final String exchangeId; // 교체 식별자 (고유 키)
  final String absenceDate; // 결강일
  final String absenceDay; // 결강 요일
  final String period; // 교시
  final String grade; // 학년
  final String className; // 반
  final String subject; // 과목
  final String teacher; // 교사
  final String supplementSubject; // 보강/수업변경 과목
  final String supplementTeacher; // 보강/수업변경 교사 성명
  final String substitutionDate; // 교체일
  final String substitutionDay; // 교체 요일
  final String substitutionPeriod; // 교체 교시
  final String substitutionSubject; // 교체 과목
  final String substitutionTeacher; // 교체 교사 성명
  final String remarks; // 비고
  final String? groupId; // 교체 그룹 ID (순환교체 4단계 이상에서 그룹 구분용)

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

  /// 포맷팅된 결강일 (월.일 형식)
  String get formattedAbsenceDate => DateFormatUtils.toMonthDay(absenceDate);

  /// 포맷팅된 교체일 (월.일 형식)
  String get formattedSubstitutionDate =>
      DateFormatUtils.toMonthDay(substitutionDate);

  /// 학급명 (학년-반)
  String get fullClassName => '$grade-$className';

  /// 문서·안내 문구에 찍을 교사 이름 (동명이인 구분 번호 제거).
  /// 비교·그룹핑에는 번호가 붙은 [teacher] 등을 그대로 쓴다.
  String get plainTeacher => plainTeacherName(teacher);
  String get plainSupplementTeacher => plainTeacherName(supplementTeacher);
  String get plainSubstitutionTeacher => plainTeacherName(substitutionTeacher);

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
class SubstitutionPlanViewModel
    extends StateNotifier<SubstitutionPlanViewModelState> {
  SubstitutionPlanViewModel(this._ref)
    : super(const SubstitutionPlanViewModelState()) {
    _parser = ExchangeNodeParser();

    // 초기 데이터 로드
    loadPlanData();

    // 🔥 교체 리스트 변경 감지 및 자동 새로고침
    // exchangeListVersionProvider의 값이 변경되면 (즉, 교체 리스트가 변경되면)
    // 자동으로 결보강계획서를 새로고침합니다.
    _ref.listen(exchangeListVersionProvider, (previous, next) {
      // 이전 버전이 null이 아니고 (초기화되지 않은 상태가 아니고)
      // 버전이 실제로 변경되었을 때만 새로고침을 실행합니다.
      if (previous != null && previous != next) {
        AppLogger.exchangeDebug(
          '[자동 새로고침] 교체 리스트 변경 감지 (버전: $previous → $next)',
        );

        // 로딩 중이 아닐 때만 새로고침 (중복 호출 방지)
        if (!state.isLoading) {
          loadPlanData();
        }
      }
    });

    // 🔥 Provider 상태 변경 감지 및 자동 복원
    // substitutionPlanProvider의 상태가 변경되면(저장된 보강 과목이 로드되면)
    // 자동으로 보강계획서 데이터를 다시 로드하여 복원된 과목을 반영합니다.
    // §10.10: 날짜(savedDates)는 여기서 더 이상 다루지 않는다 — 결강일·교체일은
    // ExchangeHistoryItem.absenceDate/substitutionDate가 유일한 진실원본이며,
    // 그 값이 바뀌면 exchangeListVersionProvider가 바뀌어 아래 리스너로 이미 갱신된다.
    _ref.listen(substitutionPlanProvider, (previous, next) {
      final hasSavedData = next.savedSupplementSubjects.isNotEmpty;
      final previousHasSavedData =
          previous?.savedSupplementSubjects.isNotEmpty == true;

      // 이전에는 데이터가 없었고, 현재는 데이터가 있는 경우 (프로그램 시작 후 데이터 로드 완료)
      if (!previousHasSavedData && hasSavedData) {
        AppLogger.info('🔄 [보강계획서] Provider에 저장된 데이터 로드 완료 감지 - 자동 복원 실행');

        // 로딩 중이 아닐 때만 새로고침 (중복 호출 방지)
        if (!state.isLoading && state.planData.isNotEmpty) {
          // 저장된 날짜/과목 정보 반영을 위해 다시 로드
          loadPlanData();
        }
      }
    });
  }

  final Ref _ref;
  late final ExchangeNodeParser _parser;

  /// 교체 항목의 고유 식별자 생성
  String _generateExchangeId(
    String teacher,
    String day,
    String period,
    String subject, {
    String? suffix,
  }) {
    final base = '${teacher}_$day${period}_$subject';
    return suffix != null ? '${base}_$suffix' : base;
  }

  /// 교체 히스토리에서 보강계획서 데이터 로드
  ///
  /// §10.10: 결강일·교체일은 `item.absenceDate`/`item.substitutionDate`
  /// (DateTime, 실행 시 자동 확정됨)에서 바로 채운다 — 더 이상 사용자가
  /// 별도로 입력한 값을 저장소에서 복원해오지 않는다. 보강 과목만 여전히
  /// `substitutionPlanProvider`(savedSupplementSubjects)에서 복원한다.
  ///
  /// **버그 수정 (2026-09-30, 사용자 발견)**: `getExchangeList()`는 되돌린
  /// (`isReverted == true`) 건도 그대로 포함한다 — "교체" 화면에서 되돌리기를
  /// 눌러 목록에서 사라진 건이 계획서에는 계속 남아있는 원인이었다.
  /// `getActiveExchangeList()`로 바꿔 되돌린 건을 제외한다. S5.5(SQLite 조회
  /// 경로) 작업과는 무관한 기존 버그 — 이 메서드는 SQLite를 전혀 읽지 않고
  /// JSON 기반 `_exchangeList`만 직접 읽는다.
  Future<void> loadPlanData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final historyService = _ref.read(exchangeHistoryServiceProvider);
      final exchangeList = historyService.getActiveExchangeList();
      final substitutionPlanNotifier = _ref.read(
        substitutionPlanProvider.notifier,
      );
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
        final absenceDateStr = DateFormatUtils.toYearMonthDay(item.absenceDate);
        final substitutionDateStr = DateFormatUtils.toYearMonthDay(
          item.substitutionDate,
        );

        AppLogger.exchangeDebug('교체 타입 처리: ${exchangeType.displayName}');

        switch (exchangeType) {
          case ExchangePathType.oneToOne:
            _handleOneToOneExchange(
              nodes,
              item.notes,
              newPlanData,
              item.id,
              absenceDateStr,
              substitutionDateStr,
            );
            break;

          case ExchangePathType.circular:
            _handleCircularExchange(
              nodes,
              newPlanData,
              item.id,
              absenceDateStr,
              substitutionDateStr,
              resolveEventDates(item),
            );
            break;

          case ExchangePathType.dual:
            _handleDualExchange(
              nodes,
              newPlanData,
              item.id,
              absenceDateStr,
              substitutionDateStr,
              resolveEventDates(item),
            );
            break;

          case ExchangePathType.supplement:
            _handleSupplementExchange(
              nodes,
              newPlanData,
              item.id,
              absenceDateStr,
            );
            break;
        }
      }

      // 보강 과목만 복원 (날짜는 위에서 이미 item 기준으로 채워짐)
      final restored =
          newPlanData.map((d) {
            final savedSupplementSubject = substitutionPlanNotifier
                .getSupplementSubject(d.exchangeId);
            return savedSupplementSubject.isNotEmpty
                ? d.copyWith(supplementSubject: savedSupplementSubject)
                : d;
          }).toList();

      state = state.copyWith(planData: restored, isLoading: false);

      final restoredSubjectsCount =
          restored.where((d) => d.supplementSubject.isNotEmpty).length;

      AppLogger.info(
        '✅ [보강계획서] 데이터 로드 완료: 전체 ${restored.length}개 항목, 보강 과목 복원 $restoredSubjectsCount개',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '데이터 로드 중 오류: $e');
      AppLogger.exchangeDebug('데이터 로드 중 오류: $e');
    }
  }

  /// 1:1 교체 처리
  void _handleOneToOneExchange(
    List nodes,
    String? notes,
    List<SubstitutionPlanData> planData,
    String groupId,
    String absenceDate,
    String substitutionDate,
  ) {
    if (nodes.length < 2) {
      AppLogger.exchangeDebug('1:1 교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final sourceNode = nodes[0];
    final targetNode = nodes[1];
    final exchangeId = _generateExchangeId(
      sourceNode.teacherName,
      sourceNode.day,
      sourceNode.period.toString(),
      sourceNode.subjectName,
    );

    final data = _parser.parseNode(
      sourceNode: sourceNode,
      targetNode: targetNode,
      exchangeId: exchangeId,
      groupId: groupId,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      remarks: notes,
    );

    planData.add(data);
    AppLogger.exchangeDebug('1:1 교체 처리 완료');
  }

  /// 순환 교체 처리
  ///
  /// [resolution]으로 각 행의 날짜를 그 행이 실제로 가리키는 노드(요일·교시)
  /// 기준으로 다시 계산한다(S5.6.5) — 특정 슬롯이 아직 미확정이면(옛 이력 등)
  /// [_resolveRowDates]가 [absenceDate]/[substitutionDate]로 폴백한다.
  void _handleCircularExchange(
    List nodes,
    List<SubstitutionPlanData> planData,
    String groupId,
    String absenceDate,
    String substitutionDate,
    EventDateResolution resolution,
  ) {
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
      final exchangeId = _generateExchangeId(
        sourceNode.teacherName,
        sourceNode.day,
        sourceNode.period.toString(),
        sourceNode.subjectName,
        suffix: '순환',
      );
      final rowDates = _resolveRowDates(
        resolution,
        sourceNode,
        targetNode,
        absenceDate,
        substitutionDate,
      );

      final data = _parser.parseNode(
        sourceNode: sourceNode,
        targetNode: targetNode,
        exchangeId: exchangeId,
        groupId: groupId,
        absenceDate: rowDates.absenceDate,
        substitutionDate: rowDates.substitutionDate,
        remarks: _getCircularExchangeRemarks(0, nodes.length),
        isCircular: true,
      );

      planData.add(data);
    } else {
      // 4개 이상: 역순으로 교체 쌍 표시 (역방향 순환 흐름)
      // 역순 순환: [0]→[2]→[1]→[0] (정순은 [0]→[1]→[2]→[0])
      // 마지막 교체부터 첫 번째 교체까지 역순으로 생성
      for (int i = 0; i < nodes.length - 1; i++) {
        // 역순 교체 쌍 생성
        // i=0: nodes[0] → nodes[nodes.length-2]
        // i=1: nodes[nodes.length-2] → nodes[nodes.length-3]
        // i=2: nodes[nodes.length-3] → nodes[0]
        final sourceNode = (i == 0) ? nodes[0] : nodes[nodes.length - 1 - i];
        final targetNode = nodes[nodes.length - 2 - i];

        // 비고란 번호: 역순 (i=0일 때 3, i=1일 때 2, i=2일 때 1)
        final stepNumber = nodes.length - 1 - i;
        final exchangeId = _generateExchangeId(
          sourceNode.teacherName,
          sourceNode.day,
          sourceNode.period.toString(),
          sourceNode.subjectName,
          suffix: '순환$stepNumber',
        );

        // 비고란: 순환교체 번호만 표시 (별표 없음)
        final remarks = '순환교체$stepNumber';
        final rowDates = _resolveRowDates(
          resolution,
          sourceNode,
          targetNode,
          absenceDate,
          substitutionDate,
        );

        final data = _parser.parseNode(
          sourceNode: sourceNode,
          targetNode: targetNode,
          exchangeId: exchangeId,
          groupId: groupId,
          absenceDate: rowDates.absenceDate,
          substitutionDate: rowDates.substitutionDate,
          remarks: remarks,
          isCircular: true,
        );

        planData.add(data);
      }
    }

    AppLogger.exchangeDebug('순환교체 처리 완료');
  }

  /// [sourceNode]/[targetNode] 슬롯의 날짜로 계산한다(S5.6.5) — 특정 슬롯이
  /// 아직 미확정이면(옛 이력 등) [fallbackAbsenceDate]/[fallbackSubstitutionDate]
  /// 로 돌려준다.
  ({String absenceDate, String substitutionDate}) _resolveRowDates(
    EventDateResolution resolution,
    dynamic sourceNode,
    dynamic targetNode,
    String fallbackAbsenceDate,
    String fallbackSubstitutionDate,
  ) {
    final source = resolution.forSlot(
      DayUtils.getDayNumber(sourceNode.day as String),
      sourceNode.period as int,
    );
    final target = resolution.forSlot(
      DayUtils.getDayNumber(targetNode.day as String),
      targetNode.period as int,
    );
    return (
      absenceDate:
          source == null
              ? fallbackAbsenceDate
              : DateFormatUtils.toYearMonthDay(source.date),
      substitutionDate:
          target == null
              ? fallbackSubstitutionDate
              : DateFormatUtils.toYearMonthDay(target.date),
    );
  }

  /// 순환교체 비고란 생성 헬퍼 메서드
  String _getCircularExchangeRemarks(int index, int totalNodes) {
    final stepCount = totalNodes;

    // 2단계, 3단계 순환교체: 비고란 빈칸
    if (stepCount <= 3) {
      return '';
    }

    // 4단계 이상
    return index == totalNodes - 2 ? '순환교체${index + 1}*' : '순환교체${index + 1}';
  }

  /// 2중 교체 처리
  ///
  /// [resolution]에 대해서는 [_handleCircularExchange] 문서 참조 — 동일한
  /// 규칙이다.
  void _handleDualExchange(
    List nodes,
    List<SubstitutionPlanData> planData,
    String groupId,
    String absenceDate,
    String substitutionDate,
    EventDateResolution resolution,
  ) {
    if (nodes.length < 4) {
      AppLogger.exchangeDebug('2중교체: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final absentNode = nodes[0];
    final substituteNode = nodes[1];
    final intermediateNode1 = nodes[2];
    final intermediateNode2 = nodes[3];

    // 최종 교체
    final finalExchangeId = _generateExchangeId(
      substituteNode.teacherName,
      substituteNode.day,
      substituteNode.period.toString(),
      substituteNode.subjectName,
      suffix: '2중최종',
    );
    final finalRowDates = _resolveRowDates(
      resolution,
      substituteNode,
      absentNode,
      absenceDate,
      substitutionDate,
    );
    final finalData = _parser.parseNode(
      sourceNode: substituteNode,
      targetNode: absentNode,
      exchangeId: finalExchangeId,
      groupId: groupId,
      absenceDate: finalRowDates.absenceDate,
      substitutionDate: finalRowDates.substitutionDate,
      remarks: '2중교체(중간)',
      isDual: true,
    );
    planData.add(finalData);

    // 중간 교체
    final intermediateExchangeId = _generateExchangeId(
      intermediateNode1.teacherName,
      intermediateNode1.day,
      intermediateNode1.period.toString(),
      intermediateNode1.subjectName,
      suffix: '2중중간',
    );
    final intermediateRowDates = _resolveRowDates(
      resolution,
      intermediateNode1,
      intermediateNode2,
      absenceDate,
      substitutionDate,
    );
    final intermediateData = _parser.parseNode(
      sourceNode: intermediateNode1,
      targetNode: intermediateNode2,
      exchangeId: intermediateExchangeId,
      groupId: groupId,
      absenceDate: intermediateRowDates.absenceDate,
      substitutionDate: intermediateRowDates.substitutionDate,
      remarks: '2중교체(최종)',
      isDual: true,
    );
    planData.add(intermediateData);

    AppLogger.exchangeDebug('2중교체 처리 완료');
  }

  /// 보강 처리
  void _handleSupplementExchange(
    List nodes,
    List<SubstitutionPlanData> planData,
    String groupId,
    String absenceDate,
  ) {
    if (nodes.length < 2) {
      AppLogger.exchangeDebug('보강: 노드가 부족합니다 (${nodes.length}개)');
      return;
    }

    final sourceNode = nodes[0];
    final targetNode = nodes[1];
    final exchangeId = _generateExchangeId(
      sourceNode.teacherName,
      sourceNode.day,
      sourceNode.period.toString(),
      sourceNode.subjectName,
      suffix: '보강',
    );

    final data = _parser.parseNode(
      sourceNode: sourceNode,
      targetNode: targetNode,
      exchangeId: exchangeId,
      groupId: groupId,
      absenceDate: absenceDate,
      substitutionDate: '',
      isSupplement: true,
    );

    planData.add(data);
    AppLogger.exchangeDebug('보강 처리 완료');
  }

  /// 모든 보강 과목 초기화
  ///
  /// §10.10: 결강일·교체일은 더 이상 "지울 수 있는 입력값"이 아니다 —
  /// `ExchangeHistoryItem.absenceDate`/`substitutionDate`는 필수(non-null)
  /// 필드이고 실행 시 항상 정확한 값을 갖는다(§10.9 리스크 2). 그래서 이
  /// 메서드는 보강 과목 선택만 초기화한다. 날짜를 고치고 싶으면 그리드에서
  /// 직접 날짜를 다시 선택해야 한다(그 경우 `ExchangeHistoryService.updateDates`
  /// 경로를 탄다 — `content_input_grid.dart` 참조).
  void clearAllSupplementSubjects() {
    _ref.read(substitutionPlanProvider.notifier).clearAllSupplementSubjects();

    final clearedPlanData =
        state.planData
            .map((data) => data.copyWith(supplementSubject: ''))
            .toList();

    state = state.copyWith(planData: clearedPlanData);
  }

  /// 보강 과목 업데이트 (해당 교체 항목만 반영)
  void updateSupplementSubject(String exchangeId, String newSubject) {
    // 전역 Provider에 저장
    _ref
        .read(substitutionPlanProvider.notifier)
        .saveSupplementSubject(exchangeId, newSubject);

    final updated =
        state.planData.map((data) {
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
final substitutionPlanViewModelProvider = StateNotifierProvider<
  SubstitutionPlanViewModel,
  SubstitutionPlanViewModelState
>((ref) {
  return SubstitutionPlanViewModel(ref);
});
