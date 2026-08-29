import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/exchange_list_storage_service.dart';
import '../services/print_profile_storage_service.dart';
import '../services/substitution_plan_storage_service.dart';
import '../utils/logger.dart';
import 'print_profile_provider.dart';
import 'timetable_registry_provider.dart';

/// 시간표 1개에 딸린 스코프 데이터 요약
///
/// 전환·삭제 다이얼로그와 목록에서 "무엇이 함께 움직이는지"를 미리 보여주기 위한
/// 값입니다. 교체·결보강·교체불가는 교사와 무관하게 시간표 단위로 공유되므로
/// 교사가 아니라 시간표에 귀속된 수치입니다(문서 §3①).
class TimetableSummary {
  /// 교체 건수
  final int exchangeCount;

  /// 결보강 입력 항목 수 (저장된 날짜·보강 과목 입력 건수)
  final int planEntryCount;

  /// 계획서(인쇄 프로파일) 개수
  final int profileCount;

  const TimetableSummary({
    this.exchangeCount = 0,
    this.planEntryCount = 0,
    this.profileCount = 0,
  });

  /// 딸린 데이터가 하나도 없는지
  bool get isEmpty =>
      exchangeCount == 0 && planEntryCount == 0 && profileCount == 0;

  /// "교체 3건 · 결보강 입력 12건 · 계획서 4개" 형태의 요약 문구 (빈 항목은 생략)
  String get description {
    final parts = <String>[];
    if (exchangeCount > 0) parts.add('교체 $exchangeCount건');
    if (planEntryCount > 0) parts.add('결보강 입력 $planEntryCount건');
    if (profileCount > 0) parts.add('계획서 $profileCount개');
    return parts.isEmpty ? '저장된 데이터 없음' : parts.join(' · ');
  }
}

/// 시간표 ID별 요약 조회 (스코프 파일 3개를 읽어 건수만 집계)
final timetableSummaryProvider =
    FutureProvider.family<TimetableSummary, String>((ref, timetableId) async {
      // 전환·등록·삭제로 레지스트리가 바뀌면 다시 계산
      ref.watch(timetableSwitchVersionProvider);
      // 계획서를 만들거나 지우면 개수가 달라지므로 함께 감시한다
      ref.watch(printProfileStoreProvider);

      try {
        final exchanges = await ExchangeListStorageService().loadExchangeList(
          timetableId: timetableId,
        );
        final plan = await SubstitutionPlanStorageService()
            .loadSubstitutionPlanData(timetableId: timetableId);
        final store = await PrintProfileStorageService().loadStore(timetableId);

        return TimetableSummary(
          exchangeCount: exchanges.length,
          planEntryCount:
              (plan?.savedDates.length ?? 0) +
              (plan?.savedSupplementSubjects.length ?? 0),
          profileCount: store.profiles.length,
        );
      } catch (e) {
        AppLogger.error('시간표 요약 집계 실패 ($timetableId): $e', e);
        return const TimetableSummary();
      }
    });
