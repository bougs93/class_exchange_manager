export 'search_runner_native.dart'
    if (dart.library.js_interop) 'search_runner_web.dart';

class SearchCancelled implements Exception {
  const SearchCancelled();
}
