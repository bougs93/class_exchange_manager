import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shared_timetable_meta_provider.dart';
import '../../providers/timetable_registry_provider.dart';
import '../../providers/timetable_repository_provider.dart';
import '../../services/shared_timetable_sync_service.dart';
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';

/// 공용 시간표가 서버에서 바뀌면 자동으로 받아 반영한다 (웹 전용).
///
/// 접속 게이트를 통과한 뒤 앱 전체를 감싸며, [sharedTimetableMetaProvider]
/// 구독으로 새 버전을 감지한다. 예전에는 접속 시 1회만 확인해서, 탭을 켜둔
/// 교사는 관리자가 새로 올린 시간표를 새로고침 전까지 볼 수 없었다.
///
/// 동작은 "안내만 띄우고 버튼 없이 바로 적용"으로 확정됐다(2026-10-03 사용자
/// 요청). 받는 동안과 끝난 뒤에 스낵바로 알리되, 교사가 따로 누를 것은 없다.
class SharedTimetableAutoSync extends ConsumerStatefulWidget {
  final Widget child;

  const SharedTimetableAutoSync({super.key, required this.child});

  @override
  ConsumerState<SharedTimetableAutoSync> createState() =>
      _SharedTimetableAutoSyncState();
}

class _SharedTimetableAutoSyncState
    extends ConsumerState<SharedTimetableAutoSync> {
  /// 동시에 두 번 받지 않도록 하는 잠금.
  ///
  /// 구독은 구독 직후에도 현재 값을 한 번 흘리므로, 접속 직후 이미 받아 둔
  /// 버전으로도 한 번 호출된다. 그 경우는 [canSkipFullSync]가 걸러낸다.
  bool _applying = false;

  /// 이미 처리한 버전 (같은 값이 다시 흘러와도 무시).
  int? _handledVersion;

  Future<void> _applyIfChanged(SharedTimetableRemoteMeta meta) async {
    if (_applying || _handledVersion == meta.version) return;

    // 접속 게이트가 방금 이 버전으로 실패했다면 곧바로 또 받지 않는다.
    // 없으면 CORS로 막힌 환경에서 3회 재시도가 두 번(총 6회) 돌고 오류도
    // 두 번 떴다(2026-10-04 보고). 서버 문서가 다시 바뀌면 버전이 달라져
    // 정상적으로 재시도된다.
    if (ref.read(sharedTimetableFailedVersionProvider) == meta.version) {
      AppLogger.info('공용 시간표 v${meta.version}은 접속 때 이미 실패 — 자동 반영 생략');
      _handledVersion = meta.version;
      return;
    }

    _applying = true;
    try {
      final sync = SharedTimetableSyncService();
      final removed = meta.isEmpty;

      // 받을지/지울지/놔둘지 판정은 전부 shouldSyncOnChange에 있다.
      // (문서 없음 → 아무것도 안 함, 비어 있음 → 로컬 정리, 그 외 → 버전 비교)
      final needsSync = SharedTimetableSyncService.shouldSyncOnChange(
        meta: meta,
        // 비어 있을 때는 canSkipFullSync를 보지 않으므로 호출도 생략한다.
        canSkip: removed ? false : await sync.canSkipFullSync(meta),
      );
      if (!needsSync) {
        _handledVersion = meta.version;
        return;
      }

      if (!mounted) return;
      if (!removed) {
        SnackBarHelper.showInfo(context, '새 공용시간표를 받는 중입니다…');
      }

      // 실패한 결과가 캐시돼 있으면 다시 열 수 있게 비운다.
      if (ref.read(timetableDatabaseProvider).hasError) {
        ref.invalidate(timetableDatabaseProvider);
      }
      if (ref.read(timetableRepositoryProvider).hasError) {
        ref.invalidate(timetableRepositoryProvider);
      }
      final repo = await ref.read(timetableRepositoryProvider.future);
      final result = await sync.syncSharedTimetable(
        repo: repo,
        prefetchedMeta: meta,
      );
      _handledVersion = meta.version;
      if (!mounted) return;

      // 받은 게 없으면(이미 최신) 화면을 흔들 이유가 없다.
      if (result.status != SharedTimetableSyncStatus.downloaded) return;

      // 레지스트리만 새로 읽으면 **화면은 옛 시간표 그대로 남는다**.
      // 그리드·교체 목록 재로드는 `timetableSwitchVersionProvider`를 보는
      // start_screen이 하므로(활성 시간표 전환과 같은 경로), 그 값을 올려야
      // 한다. 올리기 전에 `ensureInitialized()`로 레지스트리 재로드와
      // 스코프 적용이 끝나길 기다린다 — 먼저 올리면 화면이 옛 스코프로
      // 데이터를 읽어 간다(2026-10-03).
      ref.invalidate(timetableRegistryProvider);
      await ref.read(timetableRegistryProvider.notifier).ensureInitialized();
      if (!mounted) return;
      ref.read(timetableSwitchVersionProvider.notifier).state++;

      if (!mounted) return;
      if (result.count > 0) {
        SnackBarHelper.showSuccess(
          context,
          '새 공용시간표를 받았습니다. (${result.count}건)',
        );
      } else {
        SnackBarHelper.showInfo(context, '공용시간표가 서버에서 삭제되었습니다.');
      }
    } catch (e, st) {
      // 받지 못해도 기존 시간표로 계속 쓸 수 있어야 하므로 화면을 막지 않는다.
      AppLogger.error('공용 시간표 자동 반영 실패: $e', e, st);
      // 이 버전은 실패로 표시 — 구독이 같은 값을 다시 흘려도 재시도하지 않는다.
      ref.read(sharedTimetableFailedVersionProvider.notifier).state =
          meta.version;
      if (mounted) {
        SnackBarHelper.showWarning(context, '새 공용시간표를 받지 못했습니다.');
      }
    } finally {
      _applying = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // build 안의 ref.listen 대신 listenManual을 쓴다. 이 위젯이 붙기 전에
    // 이미 스트림에 값이 들어와 있을 수도 있는데, ref.listen은 "변화"에만
    // 반응하므로 그 값을 놓친다. fireImmediately로 현재 값부터 확인한다.
    ref.listenManual(sharedTimetableMetaProvider, (previous, next) {
      final meta = next.valueOrNull;
      if (meta == null) return;
      _applyIfChanged(meta);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
