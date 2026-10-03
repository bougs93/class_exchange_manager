import '../../../../../models/exchange_history_item.dart';

/// 결보강 백업 내보내기/가져오기의 순수 계산 로직
///
/// [PlanBackupScreen._handleExportBackup]/`_handleImportBackup`에서 쓰이던
/// 파일명 생성·대상 항목 선별처럼, `context`/`ref`/파일 I/O에 의존하지 않는
/// 순수 함수만 모았습니다. 다이얼로그·스낵바·파일 선택기 호출은 여전히
/// [PlanBackupScreen]의 State가 담당합니다.
class PlanBackupIo {
  const PlanBackupIo._();

  /// 예: `정원길 결보강 26.10.05_20261003_결보강백업`
  static String buildBackupFileName({
    required String? teacherName,
    required String? profileName,
    required DateTime now,
  }) {
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final plan =
        (profileName == null || profileName.trim().isEmpty)
            ? '결보강백업'
            : profileName.trim();
    final teacher = teacherName?.trim() ?? '';
    final prefix = teacher.isEmpty ? plan : '$teacher $plan';
    return '${prefix}_${stamp}_결보강백업';
  }

  /// 내보낼 계획서에 속한 교체 항목만 선별 (없으면 미지정 항목으로 대체)
  static List<ExchangeHistoryItem> itemsForPlanBackup(
    List<ExchangeHistoryItem> all,
    String profileId,
  ) {
    final assigned = all.where((e) => e.profileId == profileId).toList();
    if (assigned.isNotEmpty) return assigned;
    return all.where((e) => e.profileId == null).toList();
  }
}
