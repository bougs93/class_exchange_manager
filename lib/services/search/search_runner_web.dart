import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
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

  Future<List<Map<String, dynamic>>> run(Map<String, dynamic> request) {
    if (_pending != null) cancel();
    final completer = Completer<List<Map<String, dynamic>>>();
    _pending = completer;
    try {
      final worker = _worker ??= _createWorker();
      worker.postMessage(jsonEncode(request).toJS);
      _timeout = Timer(const Duration(seconds: 60), () {
        _fail(TimeoutException('교체 경로 탐색 시간이 초과되었습니다.'));
      });
    } catch (error, stack) {
      _fail(error, stack);
    }
    return completer.future;
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
          _fail(StateError('교체 탐색 Worker를 불러오지 못했습니다. 웹 빌드 파일을 확인하세요.'));
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
