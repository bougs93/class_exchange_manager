import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice_message.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/notice_message_generator.dart';
import '../utils/logger.dart';

/// 안내 메시지 상태 클래스
class NoticeMessageState {
  /// 학급별 메시지 그룹 리스트
  final List<NoticeMessageGroup> classMessageGroups;
  
  /// 교사별 메시지 그룹 리스트
  final List<NoticeMessageGroup> teacherMessageGroups;
  
  /// 학급 메시지 옵션
  final MessageOption classMessageOption;
  
  /// 교사 메시지 옵션
  final MessageOption teacherMessageOption;
  
  /// 로딩 상태
  final bool isLoading;
  
  /// 에러 메시지
  final String? errorMessage;

  const NoticeMessageState({
    this.classMessageGroups = const [],
    this.teacherMessageGroups = const [],
    this.classMessageOption = MessageOption.option1,
    this.teacherMessageOption = MessageOption.option1,
    this.isLoading = false,
    this.errorMessage,
  });

  /// 복사 생성자
  NoticeMessageState copyWith({
    List<NoticeMessageGroup>? classMessageGroups,
    List<NoticeMessageGroup>? teacherMessageGroups,
    MessageOption? classMessageOption,
    MessageOption? teacherMessageOption,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NoticeMessageState(
      classMessageGroups: classMessageGroups ?? this.classMessageGroups,
      teacherMessageGroups: teacherMessageGroups ?? this.teacherMessageGroups,
      classMessageOption: classMessageOption ?? this.classMessageOption,
      teacherMessageOption: teacherMessageOption ?? this.teacherMessageOption,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// 안내 메시지 Notifier
class NoticeMessageNotifier extends StateNotifier<NoticeMessageState> {
  NoticeMessageNotifier(this._ref) : super(const NoticeMessageState());

  final Ref _ref;

  /// 메시지 옵션 변경 (학급)
  void setClassMessageOption(MessageOption option) {
    AppLogger.exchangeDebug('학급 메시지 옵션 변경: ${option.displayName}');
    state = state.copyWith(classMessageOption: option);
    _regenerateClassMessages();
  }

  /// 메시지 옵션 변경 (교사)
  void setTeacherMessageOption(MessageOption option) {
    AppLogger.exchangeDebug('교사 메시지 옵션 변경: ${option.displayName}');
    state = state.copyWith(teacherMessageOption: option);
    _regenerateTeacherMessages();
  }

  /// 모든 메시지 새로고침
  Future<void> refreshAllMessages() async {
    AppLogger.exchangeDebug('모든 안내 메시지 새로고침 시작');
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 교체 계획 데이터 가져오기
      final planData = _ref.read(substitutionPlanViewModelProvider).planData;
      
      if (planData.isEmpty) {
        AppLogger.exchangeDebug('교체 계획 데이터가 없어서 빈 메시지로 설정');
        state = state.copyWith(
          classMessageGroups: [],
          teacherMessageGroups: [],
          isLoading: false,
        );
        return;
      }

      // 학급 메시지 생성
      final classGroups = NoticeMessageGenerator.generateClassMessages(
        planData,
        state.classMessageOption,
      );

      // 교사 메시지 생성
      final teacherGroups = NoticeMessageGenerator.generateTeacherMessages(
        planData,
        state.teacherMessageOption,
      );

      state = state.copyWith(
        classMessageGroups: classGroups,
        teacherMessageGroups: teacherGroups,
        isLoading: false,
      );

      AppLogger.exchangeDebug('메시지 새로고침 완료 - 학급: ${classGroups.length}개, 교사: ${teacherGroups.length}개');
    } catch (e) {
      AppLogger.error('메시지 새로고침 중 오류 발생', e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: '메시지 생성 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 학급 메시지만 재생성
  void _regenerateClassMessages() {
    try {
      final planData = _ref.read(substitutionPlanViewModelProvider).planData;
      
      if (planData.isEmpty) {
        state = state.copyWith(classMessageGroups: []);
        return;
      }

      final classGroups = NoticeMessageGenerator.generateClassMessages(
        planData,
        state.classMessageOption,
      );

      state = state.copyWith(classMessageGroups: classGroups);
      AppLogger.exchangeDebug('학급 메시지 재생성 완료 - 그룹 개수: ${classGroups.length}');
    } catch (e) {
      AppLogger.error('학급 메시지 재생성 중 오류 발생', e);
      state = state.copyWith(errorMessage: '학급 메시지 생성 중 오류가 발생했습니다: $e');
    }
  }

  /// 교사 메시지만 재생성
  void _regenerateTeacherMessages() {
    try {
      final planData = _ref.read(substitutionPlanViewModelProvider).planData;
      
      if (planData.isEmpty) {
        state = state.copyWith(teacherMessageGroups: []);
        return;
      }

      final teacherGroups = NoticeMessageGenerator.generateTeacherMessages(
        planData,
        state.teacherMessageOption,
      );

      state = state.copyWith(teacherMessageGroups: teacherGroups);
      AppLogger.exchangeDebug('교사 메시지 재생성 완료 - 그룹 개수: ${teacherGroups.length}');
    } catch (e) {
      AppLogger.error('교사 메시지 재생성 중 오류 발생', e);
      state = state.copyWith(errorMessage: '교사 메시지 생성 중 오류가 발생했습니다: $e');
    }
  }

  /// 특정 학급의 메시지 그룹 찾기
  NoticeMessageGroup? findClassMessageGroup(String className) {
    try {
      return state.classMessageGroups.firstWhere(
        (group) => group.groupIdentifier == className,
      );
    } catch (e) {
      return null;
    }
  }

  /// 특정 교사의 메시지 그룹 찾기
  NoticeMessageGroup? findTeacherMessageGroup(String teacherName) {
    try {
      return state.teacherMessageGroups.firstWhere(
        (group) => group.groupIdentifier == teacherName,
      );
    } catch (e) {
      return null;
    }
  }

  /// 학급별 메시지 통계
  Map<String, int> get classMessageStats {
    final stats = <String, int>{};
    for (final group in state.classMessageGroups) {
      stats[group.groupIdentifier] = group.messages.length;
    }
    return stats;
  }

  /// 교사별 메시지 통계
  Map<String, int> get teacherMessageStats {
    final stats = <String, int>{};
    for (final group in state.teacherMessageGroups) {
      stats[group.groupIdentifier] = group.messages.length;
    }
    return stats;
  }

  /// 전체 메시지 개수
  int get totalClassMessages => state.classMessageGroups.fold(0, (sum, group) => sum + group.messages.length);
  int get totalTeacherMessages => state.teacherMessageGroups.fold(0, (sum, group) => sum + group.messages.length);

  /// 교체 유형별 메시지 개수 (학급)
  Map<ExchangeType, int> get classExchangeTypeStats {
    final stats = <ExchangeType, int>{};
    for (final group in state.classMessageGroups) {
      for (final message in group.messages) {
        stats[message.exchangeType] = (stats[message.exchangeType] ?? 0) + 1;
      }
    }
    return stats;
  }

  /// 교체 유형별 메시지 개수 (교사)
  Map<ExchangeType, int> get teacherExchangeTypeStats {
    final stats = <ExchangeType, int>{};
    for (final group in state.teacherMessageGroups) {
      for (final message in group.messages) {
        stats[message.exchangeType] = (stats[message.exchangeType] ?? 0) + 1;
      }
    }
    return stats;
  }
}

/// 안내 메시지 Provider
final noticeMessageProvider = StateNotifierProvider<NoticeMessageNotifier, NoticeMessageState>((ref) {
  return NoticeMessageNotifier(ref);
});
