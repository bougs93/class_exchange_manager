import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/firebase_app_config.dart';
import '../models/usage_event.dart';
import '../utils/logger.dart';
import '../utils/usage_stats_aggregator.dart';

/// 하루치 문서에 합산할 증분 (메모리 버퍼 1건).
class UsageDelta {
  UsageDelta(this.dayId);

  final String dayId;

  /// 전체 합계 증분 (카운터 키 → n)
  final Map<String, int> totals = {};

  /// 교사명 → 카운터 키 → n
  final Map<String, Map<String, int>> teachers = {};

  /// 이 증분에 기여한 익명 uid들
  final Set<String> visitors = {};

  /// 교사명 → 마지막 기록 시각(epoch ms)
  final Map<String, int> lastSeen = {};

  bool get isEmpty => totals.isEmpty;
}

/// 통계 저장소 추상화. 운영은 Firestore, 테스트는 인메모리 가짜.
abstract class UsageStatsBackend {
  Future<void> writeDelta(UsageDelta delta);
  Future<List<UsageDay>> fetchRange(String fromId, String toId);

  /// 범위 안 문서를 지우고 지운 개수를 돌려준다. [fromId]·[toId]가 null이면 전체.
  Future<int> deleteRange(String? fromId, String? toId);
  Future<int> countRange(String? fromId, String? toId);

  /// 범위 안 문서에서 해당 교사 항목만 지우고, 합계에서 그 교사분을
  /// 차감한다. 손댄 문서 수를 돌려준다. 방문자(uid)는 교사 귀속이
  /// 아니라 남긴다.
  Future<int> deleteTeacher(String? fromId, String? toId, String teacherName);
}

/// Firestore 구현. Firestore 인스턴스는 처음 쓸 때 가져온다(지연).
class FirestoreUsageBackend implements UsageStatsBackend {
  FirestoreUsageBackend({FirebaseFirestore? firestore}) : _injected = firestore;

  static const String collection = 'usageStats';
  static const int _batchLimit = 400;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(collection);

  Query<Map<String, dynamic>> _range(String? fromId, String? toId) {
    Query<Map<String, dynamic>> q = _col.orderBy(FieldPath.documentId);
    if (fromId != null) q = q.startAt([fromId]);
    if (toId != null) q = q.endAt([toId]);
    return q;
  }

  @override
  Future<void> writeDelta(UsageDelta delta) async {
    Map<String, dynamic> inc(Map<String, int> m) => {
      for (final e in m.entries) e.key: FieldValue.increment(e.value),
    };
    final data = <String, dynamic>{
      'date': delta.dayId,
      'totals': inc(delta.totals),
      'teachers': {
        for (final e in delta.teachers.entries)
          e.key: {
            ...inc(e.value),
            if (delta.lastSeen[e.key] != null)
              'lastSeen': delta.lastSeen[e.key],
          },
      },
      if (delta.visitors.isNotEmpty)
        'visitors': {for (final u in delta.visitors) u: true},
    };
    await _col
        .doc(delta.dayId)
        .set(data, SetOptions(merge: true))
        .timeout(FirebaseAppConfig.networkTimeout);
  }

  @override
  Future<List<UsageDay>> fetchRange(String fromId, String toId) async {
    final snap = await _range(fromId, toId).get();
    return snap.docs.map((d) => UsageDay.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<int> countRange(String? fromId, String? toId) async {
    final snap = await _range(fromId, toId).get();
    return snap.docs.length;
  }

  @override
  Future<int> deleteRange(String? fromId, String? toId) async {
    final snap = await _range(fromId, toId).get();
    final docs = snap.docs;
    for (var i = 0; i < docs.length; i += _batchLimit) {
      final batch = _firestore.batch();
      for (final d in docs.skip(i).take(_batchLimit)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    return docs.length;
  }

  @override
  Future<int> deleteTeacher(
    String? fromId,
    String? toId,
    String teacherName,
  ) async {
    final snap = await _range(fromId, toId).get();
    var touched = 0;
    final batchDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in snap.docs) {
      final raw = d.data()['teachers'];
      if (raw is Map && raw.containsKey(teacherName)) {
        batchDocs.add(d);
      }
    }
    for (var i = 0; i < batchDocs.length; i += _batchLimit) {
      final batch = _firestore.batch();
      for (final d in batchDocs.skip(i).take(_batchLimit)) {
        final teacher =
            (d.data()['teachers'] as Map?)?[teacherName] as Map? ?? const {};
        // 교사명은 FieldPath로 감싼다 — 'teachers.$name' 문자열은 이름에
        // '.'이 있으면 엉뚱한 경로를 지우고(합계만 빠짐), '/'·'[' 등은 assert로 터진다.
        // 합계는 통째로 덮어쓰지 않고 increment(-n)으로 뺀다 — 그 사이에
        // 들어온 다른 사용자의 기록을 지우지 않기 위해.
        final update = <Object, Object?>{
          FieldPath(['teachers', teacherName]): FieldValue.delete(),
          for (final e in teacher.entries)
            if (e.value is num && e.key != 'lastSeen')
              FieldPath(['totals', e.key.toString()]): FieldValue.increment(
                -(e.value as num).toInt(),
              ),
        };
        batch.update<Map<Object, Object?>>(d.reference, update);
      }
      await batch.commit();
      touched += batchDocs.skip(i).take(_batchLimit).length;
    }
    return touched;
  }
}

/// 웹 사용 통계 수집·조회 서비스.
///
/// 수집은 **조용히** 이뤄진다 — 이벤트는 메모리에 쌓다가 [flushDelay] 뒤 한
/// 번에 쓰고(`visit`는 즉시), 모든 Firestore 오류는 경고 로그만 남기고
/// 삼킨다. [enabled]가 false(비웹·Firebase 미설정)면 전부 no-op이다.
class UsageStatsService {
  UsageStatsService({
    required this.enabled,
    UsageStatsBackend? backend,
    String Function()? teacherName,
    bool Function()? isAdmin,
    String? Function()? uid,
    this.flushDelay = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _backend = backend,
       _teacherName = teacherName,
       _isAdmin = isAdmin,
       _uid = uid,
       _now = now ?? DateTime.now;

  /// 아무 것도 하지 않는 서비스.
  UsageStatsService.disabled()
    : enabled = false,
      _backend = null,
      _teacherName = null,
      _isAdmin = null,
      _uid = null,
      flushDelay = Duration.zero,
      _now = DateTime.now;

  final bool enabled;
  final UsageStatsBackend? _backend;
  final String Function()? _teacherName;
  final bool Function()? _isAdmin;
  final String? Function()? _uid;
  final Duration flushDelay;
  final DateTime Function() _now;

  final Map<String, UsageDelta> _buffer = {};
  Timer? _timer;
  Future<void> _inFlight = Future.value();

  bool get _active => enabled && _backend != null;

  /// 이벤트를 기록한다. 절대 예외를 던지지 않는다.
  void record(UsageEvent event, {int? tabIndex}) {
    if (!_active) return;
    try {
      final key = UsageKeys.keyFor(event, tabIndex: tabIndex);
      if (key == null) return;

      final nowTime = _now();
      final dayId = UsageStatsAggregator.todayKstId(nowTime);
      // 관리자 세션은 교사명과 상관없이 따로 묶는다.
      var name =
          (_isAdmin?.call() ?? false)
              ? kUsageAdminBucket
              : (_teacherName?.call() ?? '').trim();
      if (name.isEmpty) name = kUsageUnnamedTeacher;

      final delta = _buffer.putIfAbsent(dayId, () => UsageDelta(dayId));
      delta.totals[key] = (delta.totals[key] ?? 0) + 1;
      final t = delta.teachers.putIfAbsent(name, () => <String, int>{});
      t[key] = (t[key] ?? 0) + 1;
      delta.lastSeen[name] = nowTime.millisecondsSinceEpoch;
      final uid = _uid?.call();
      if (uid != null && uid.isNotEmpty) delta.visitors.add(uid);

      if (event == UsageEvent.visit) {
        flush();
      } else {
        _timer ??= Timer(flushDelay, flush);
      }
    } catch (e) {
      AppLogger.warning('사용 통계 기록 실패: $e');
    }
  }

  /// 버퍼를 즉시 쓴다. 절대 예외를 던지지 않는다.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_active || _buffer.isEmpty) return _inFlight;
    final pending = _buffer.values.toList();
    _buffer.clear();
    // 쓰기를 직렬화해 순서·중복 간섭을 피한다.
    _inFlight = _inFlight.then((_) async {
      for (final delta in pending) {
        try {
          await _backend!.writeDelta(delta);
        } catch (e) {
          AppLogger.warning('사용 통계 저장 실패(무시): $e');
        }
      }
    });
    return _inFlight;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  // ---- 관리자 조회/관리 (오류는 호출부가 처리) ----

  Future<List<UsageDay>> fetchRange(DateTime from, DateTime to) async {
    if (!_active) return const [];
    return _backend!.fetchRange(
      UsageStatsAggregator.dateId(from),
      UsageStatsAggregator.dateId(to),
    );
  }

  /// 범위 안 문서 수. [from]·[to]가 null이면 전체.
  Future<int> countRange({DateTime? from, DateTime? to}) async {
    if (!_active) return 0;
    return _backend!.countRange(_id(from), _id(to));
  }

  /// 범위 안 문서를 지운다. [from]·[to]가 null이면 전체.
  Future<int> deleteRange({DateTime? from, DateTime? to}) async {
    if (!_active) return 0;
    _buffer.clear();
    return _backend!.deleteRange(_id(from), _id(to));
  }

  /// 선택 기간에서 해당 교사의 통계만 지운다 (합계도 함께 차감).
  ///
  /// 아직 버퍼에 쌓인 기록을 먼저 flush한 뒤 지운다 — 안 그러면
  /// flush가 지운 교사를 다시 살려낸다. 지운 게 없으면 0을 돌려준다.
  Future<int> deleteTeacher({
    required DateTime from,
    required DateTime to,
    required String teacher,
  }) async {
    if (!_active || teacher.isEmpty) return 0;
    await flush();
    return _backend!.deleteTeacher(_id(from), _id(to), teacher);
  }

  String? _id(DateTime? d) => d == null ? null : UsageStatsAggregator.dateId(d);
}

/// 현재 익명 로그인 uid (없거나 Firebase 미초기화면 null).
String? currentFirebaseUid() {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
}
