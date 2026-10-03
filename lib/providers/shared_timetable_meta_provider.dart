import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shared_timetable_sync_service.dart';
import '../utils/logger.dart';

/// 서버 공용 시간표 버전 실시간 구독 (웹 전용).
///
/// 예전에는 접속할 때 딱 한 번만 버전을 확인했다. 그래서 교사가 탭을 켜둔
/// 채 수업에 들어가면, 관리자가 그 사이 새 시간표를 올려도 브라우저를
/// 새로고침하기 전까지는 영영 알 수 없었다(2026-10-03 확인). 문서 하나짜리
/// 구독으로 바꾸면 열려 있는 모든 탭이 새 버전을 바로 받는다.
///
/// `defaultSchoolNameProvider`와 같은 패턴이다 — 값이 바뀔 때만 읽기가
/// 발생하므로 폴링보다 싸고, 구독 중 오류는 로그만 남기고 화면을 깨지
/// 않는다. PC/모바일은 Firebase를 아예 초기화하지 않으므로 빈 스트림이다.
/// 방금 받기에 **실패한** 공용 시간표 버전.
///
/// 접속 게이트(`_enterSession`)와 자동 동기화 감시자(`SharedTimetableAutoSync`)가
/// 같은 서버 상태를 각자 보기 때문에, 게이트가 다운로드에 실패한 직후 감시자가
/// 장착되면 **같은 버전을 곧바로 또 받으려 한다.** 실제로 CORS로 막힌 환경에서
/// 3회 재시도가 두 번(총 6회) 일어나고 오류 로그도 두 번 찍혔다(2026-10-04 보고).
///
/// 실패한 버전을 여기 적어 두면 감시자가 그 버전은 건너뛴다. 서버 문서가 다시
/// 바뀌면(버전이 올라가면) 값이 달라지므로 정상적으로 재시도된다. 접속을
/// 새로 하면(앱 재시작) 다시 null이라 한 번은 시도한다.
final sharedTimetableFailedVersionProvider = StateProvider<int?>((ref) => null);

final sharedTimetableMetaProvider = StreamProvider<SharedTimetableRemoteMeta>((
  ref,
) {
  if (!kIsWeb) return const Stream.empty();
  return SharedTimetableSyncService().watchRemoteMeta().handleError((Object e) {
    AppLogger.warning('공용 시간표 버전 구독 실패: $e');
  });
});
