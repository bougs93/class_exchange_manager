import 'dart:convert';
import 'dart:js_interop';
import 'package:class_exchange_manager/services/search/search_request.dart';

@JS('self.onmessage')
external set onMessage(JSFunction callback);
@JS('self.postMessage')
external void postMessage(JSString message);

extension type _Message._(JSObject _) implements JSObject {
  external JSString get data;
}

void main() {
  onMessage =
      ((_Message event) {
        try {
          final request = jsonDecode(event.data.toDart) as Map<String, dynamic>;
          postMessage(jsonEncode({'paths': executeSearch(request)}).toJS);
        } catch (error) {
          postMessage(jsonEncode({'error': error.toString()}).toJS);
        }
      }).toJS;
}
