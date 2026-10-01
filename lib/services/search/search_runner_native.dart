import 'package:flutter/foundation.dart';
import 'search_request.dart';

class ExchangeSearchRunner {
  Future<List<Map<String, dynamic>>> run(Map<String, dynamic> request) =>
      compute(executeSearch, request);

  void cancel() {}
  void dispose() {}
}
