import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../utils/resolved_week.dart';
import '../utils/timetable_data_source.dart';
import 'selected_week_provider.dart';
import 'services_provider.dart';

/// 교체 뷰 상태 클래스
///
/// §10.2.1 전환 후: 백업/복원 개념이 사라졌다. 교체 뷰는 원본 시간표를
/// 변형하지 않고 [ResolvedWeek] 합성 결과를 그리드에 넘길 뿐이므로,
/// "되돌리기 위해 무엇을 저장해 두었는가"라는 상태가 필요 없다.
class ExchangeViewState {
  /// 교체 뷰 활성화 여부
  final bool isEnabled;

  /// 로딩 상태
  final bool isLoading;

  /// 마지막 업데이트 시간
  final DateTime lastUpdated;

  /// 현재 실행 중인 작업
  final String? currentOperation;

  /// 오류 메시지
  final String? errorMessage;

  const ExchangeViewState({
    this.isEnabled = false,
    this.isLoading = false,
    required this.lastUpdated,
    this.currentOperation,
    this.errorMessage,
  });

  ExchangeViewState copyWith({
    bool? isEnabled,
    bool? isLoading,
    DateTime? lastUpdated,
    String? currentOperation,
    String? errorMessage,
  }) {
    return ExchangeViewState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentOperation: currentOperation ?? this.currentOperation,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'ExchangeViewState('
        'isEnabled: $isEnabled, '
        'isLoading: $isLoading, '
        'currentOperation: $currentOperation, '
        'errorMessage: $errorMessage'
        ')';
  }
}

/// 교체 뷰 상태를 관리하는 Notifier
///
/// §10.4 B안: 원본 시간표(`timeSlots`)는 **절대 변경하지 않는다.**
/// 교체 뷰 활성화는 "원본 + 현재 선택된 주의 교체 이벤트"를 합성해
/// 그리드에 넘기는 것이고, 비활성화는 원본을 그대로 넘기는 것이다.
class ExchangeViewNotifier extends StateNotifier<ExchangeViewState> {
  final Ref _ref;

  ExchangeViewNotifier(this._ref)
    : super(ExchangeViewState(lastUpdated: DateTime.now()));

  /// 교체 뷰 활성화 — 현재 주의 교체를 합성해 표시
  ///
  /// [timeSlots]에는 **원본**(엑셀 파싱 결과)을 넘겨야 한다. 그리드가 들고 있는
  /// 합성본을 넘기면 교체가 이중 적용된다.
  Future<void> enableExchangeView({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required TimetableDataSource dataSource,
  }) async {
    try {
      state = state.copyWith(
        isLoading: true,
        currentOperation: '교체 뷰 활성화 중...',
        errorMessage: null,
        lastUpdated: DateTime.now(),
      );

      _applyResolvedWeek(timeSlots, teachers, dataSource);

      state = state.copyWith(
        isEnabled: true,
        isLoading: false,
        currentOperation: null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 활성화 중 오류 발생: $e');
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        errorMessage: '교체 뷰 활성화 실패: $e',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 교체 뷰 비활성화 — 원본 그대로 표시
  ///
  /// 복원할 백업이 없다. 원본을 애초에 변경하지 않았으므로 그대로 넘기면 된다.
  Future<void> disableExchangeView({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required TimetableDataSource dataSource,
  }) async {
    try {
      state = state.copyWith(
        isLoading: true,
        currentOperation: '교체 뷰 비활성화 중...',
        errorMessage: null,
        lastUpdated: DateTime.now(),
      );

      dataSource.updateData(
        timeSlots.map((slot) => slot.copy()).toList(),
        teachers,
      );

      state = state.copyWith(
        isEnabled: false,
        isLoading: false,
        currentOperation: null,
        lastUpdated: DateTime.now(),
      );

      AppLogger.exchangeInfo('교체 뷰 비활성화 완료 (원본 표시)');
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 비활성화 중 오류 발생: $e');
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        errorMessage: '교체 뷰 비활성화 실패: $e',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 교체 뷰가 켜져 있으면 현재 주 기준으로 다시 합성해 그린다.
  ///
  /// 주차 전환·교체 실행·되돌리기 직후처럼 "보여줄 내용이 달라졌을 때" 호출한다.
  void refreshIfEnabled({
    required List<TimeSlot> timeSlots,
    required List<Teacher> teachers,
    required TimetableDataSource dataSource,
  }) {
    if (!state.isEnabled) return;
    try {
      _applyResolvedWeek(timeSlots, teachers, dataSource);
      state = state.copyWith(lastUpdated: DateTime.now());
    } catch (e) {
      AppLogger.exchangeDebug('교체 뷰 갱신 중 오류: $e');
    }
  }

  /// 원본 + 현재 선택 주의 교체 이벤트를 합성해 그리드에 반영
  void _applyResolvedWeek(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
    TimetableDataSource dataSource,
  ) {
    final historyService = _ref.read(exchangeHistoryServiceProvider);
    final weekMonday = _ref.read(selectedWeekProvider);
    final events = historyService.getActiveExchangeList();

    final resolved = ResolvedWeek.of(
      base: timeSlots,
      events: events,
      weekMonday: weekMonday,
    );

    dataSource.updateData(resolved.toTimeSlots(timeSlots), teachers);

    final weekEventCount =
        events.where((e) => e.weekMonday == resolved.weekMonday).length;
    AppLogger.exchangeInfo(
      '교체 뷰 합성 완료 - 주 시작 $weekMonday, 이 주 교체 $weekEventCount건 '
      '(전체 활성 ${events.length}건)',
    );
  }

  /// 교체 뷰 상태 초기화
  void reset() {
    state = ExchangeViewState(lastUpdated: DateTime.now());
    AppLogger.exchangeDebug('[ExchangeViewProvider] 교체 뷰 상태 초기화 완료');
  }
}

/// 교체 뷰 상태 Provider
final exchangeViewProvider =
    StateNotifierProvider<ExchangeViewNotifier, ExchangeViewState>(
      (ref) => ExchangeViewNotifier(ref),
    );

/// 교체 뷰 활성화 여부만 반환하는 간단한 Provider
final isExchangeViewEnabledProvider = Provider<bool>((ref) {
  final exchangeViewState = ref.watch(exchangeViewProvider);
  return exchangeViewState.isEnabled;
});
