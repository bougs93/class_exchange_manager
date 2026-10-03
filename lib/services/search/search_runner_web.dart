import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import '../../utils/logger.dart';
import 'search_request.dart';
import 'search_runner.dart' show SearchCancelled;

@JS('Worker')
extension type _SearchWorker._(JSObject _) implements JSObject {
  external factory _SearchWorker(String url);
  external set onmessage(JSFunction? callback);
  external set onerror(JSFunction? callback);
  external void postMessage(JSString message);
  external void terminate();
}

extension type _Message._(JSObject _) implements JSObject {
  external JSString get data;
}

/// Reuse an idle worker. Terminate an obsolete search before starting the next,
/// so a long DFS cannot delay the result for the user's newly selected cell.
class ExchangeSearchRunner {
  _SearchWorker? _worker;
  Completer<List<Map<String, dynamic>>>? _pending;
  Timer? _timeout;

  /// Worker를 못 쓰는 환경으로 판명됨 — 이후 요청은 바로 본 isolate에서 돈다.
  ///
  /// 한 번 실패하면 계속 실패하므로, 매번 Worker 생성을 재시도해 2초씩
  /// 버리지 않도록 기억해 둔다.
  bool _workerUnavailable = false;

  /// 폴백에 다시 쓰기 위해 마지막으로 보낸 요청을 들고 있는다.
  /// Worker의 `onerror`는 요청 내용을 돌려주지 않기 때문이다.
  Map<String, dynamic>? _lastRequest;

  Future<List<Map<String, dynamic>>> run(Map<String, dynamic> request) {
    if (_pending != null) cancel();
    if (_workerUnavailable) return _runInline(request);

    final completer = Completer<List<Map<String, dynamic>>>();
    _pending = completer;
    try {
      _lastRequest = request;
      final worker = _worker ??= _createWorker();
      worker.postMessage(jsonEncode(request).toJS);
      _timeout = Timer(const Duration(seconds: 60), () {
        _fail(TimeoutException('교체 경로 탐색 시간이 초과되었습니다.'));
      });
    } catch (error) {
      // Worker 생성 자체가 막힌 환경(파일 없음·CSP 등) — 폴백으로 넘긴다.
      AppLogger.warning('교체 탐색 Worker 생성 실패 — 본 isolate로 폴백: $error');
      _pending = null;
      _fallBackToInline(completer, request);
    }
    return completer.future;
  }

  /// Worker를 포기하고 본 isolate 결과로 [completer]를 채운다.
  void _fallBackToInline(
    Completer<List<Map<String, dynamic>>> completer,
    Map<String, dynamic> request,
  ) {
    _timeout?.cancel();
    _worker?.terminate();
    _worker = null;
    _workerUnavailable = true;
    if (completer.isCompleted) return;
    unawaited(
      _runInline(
        request,
      ).then(completer.complete, onError: completer.completeError),
    );
  }

  /// Worker 없이 본 isolate에서 바로 탐색한다.
  ///
  /// `exchange_search_worker.js`는 `tool/build_web.dart`(CI의 별도 단계)가
  /// 만들기 때문에, 그 단계를 거치지 않은 빌드(예: 로컬 `flutter run -d chrome`)
  /// 에서는 파일이 없다. 예전에는 이때 순환·2중 교체 탐색이 **통째로 실패**하고
  /// "웹 빌드 파일을 확인하세요"만 떴다(2026-10-04 보고). 탐색 로직
  /// ([executeSearch])은 플랫폼 의존이 없는 순수 Dart라, Worker가 없으면
  /// 느리더라도 여기서 직접 돌리는 편이 낫다.
  ///
  /// UI 스레드를 점유하므로 큰 시간표에서는 잠깐 멈칫할 수 있다 — 어디까지나
  /// Worker가 있을 때를 정상 경로로 본다.
  Future<List<Map<String, dynamic>>> _runInline(Map<String, dynamic> request) {
    try {
      return Future.value(executeSearch(request));
    } catch (error, stack) {
      return Future.error(error, stack);
    }
  }

  _SearchWorker _createWorker() {
    final worker = _SearchWorker('exchange_search_worker.js');
    worker.onmessage =
        ((_Message event) {
          if (worker != _worker) return;
          try {
            final response =
                jsonDecode(event.data.toDart) as Map<String, dynamic>;
            if (response['error'] != null) {
              _fail(StateError(response['error'] as String));
              return;
            }
            final paths =
                (response['paths'] as List)
                    .map((value) => Map<String, dynamic>.from(value as Map))
                    .toList();
            _timeout?.cancel();
            final pending = _pending;
            _pending = null;
            pending?.complete(paths);
          } catch (error, stack) {
            _fail(error, stack);
          }
        }).toJS;
    worker.onerror =
        ((JSAny? event) {
          if (worker != _worker) return;
          // 여기가 실제로 가장 많이 걸리는 경로다 — `exchange_search_worker.js`가
          // 없으면 생성자는 성공하고 onerror로 비동기 통지된다(2026-10-04).
          // 예전에는 그대로 실패시켜 순환·2중 교체가 아예 동작하지 않았다.
          AppLogger.warning('교체 탐색 Worker 로드 실패 — 본 isolate로 폴백');
          final pending = _pending;
          final request = _lastRequest;
          _pending = null;
          if (pending == null || request == null) {
            _fail(StateError('교체 탐색 Worker를 불러오지 못했습니다. 웹 빌드 파일을 확인하세요.'));
            return;
          }
          _fallBackToInline(pending, request);
        }).toJS;
    return worker;
  }

  void _fail(Object error, [StackTrace? stack]) {
    _timeout?.cancel();
    _worker?.terminate();
    _worker = null;
    final pending = _pending;
    _pending = null;
    pending?.completeError(error, stack);
  }

  void cancel() {
    if (_pending != null) _fail(const SearchCancelled());
  }

  void dispose() => _fail(const SearchCancelled());
}
