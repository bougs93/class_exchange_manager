import 'dart:convert';

import 'package:class_exchange_manager/services/json_storage.dart';

/// 테스트용 인메모리 JsonStorage 구현
///
/// 실제 파일 I/O 없이 저장소 동작을 시뮬레이션합니다.
/// 저장/로드 시 깊은 복사를 수행해 원본 오염을 방지합니다.
class InMemoryJsonStorage implements JsonStorage {
  /// 파일명 → 디코딩된 JSON 데이터
  final Map<String, Object> files = {};

  /// saveJson 호출 횟수 (검증용)
  int saveCount = 0;

  /// 삭제된 파일 기록 (검증용)
  final List<String> deletedFiles = [];

  /// 테스트 준비용: 파일을 직접 주입
  void seedJson(String filename, dynamic data) {
    files[filename] = jsonDecode(jsonEncode(data)) as Object;
  }

  @override
  Future<bool> saveJson(String filename, dynamic data) async {
    files[filename] = jsonDecode(jsonEncode(data)) as Object;
    saveCount++;
    return true;
  }

  @override
  Future<Map<String, dynamic>?> loadJson(String filename) async {
    final file = files[filename];
    if (file is! Map) return null;
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(file)) as Map);
  }

  @override
  Future<List<dynamic>?> loadJsonArray(String filename) async {
    final file = files[filename];
    if (file is! List) return null;
    return List<dynamic>.from(jsonDecode(jsonEncode(file)) as List);
  }

  @override
  Future<bool> fileExists(String filename) async => files.containsKey(filename);

  @override
  Future<bool> deleteFile(String filename) async {
    final removed = files.remove(filename);
    if (removed != null) deletedFiles.add(filename);
    return removed != null;
  }

  @override
  Future<List<String>> listJsonFiles() async => files.keys.toList();

  @override
  Future<bool> renameFile(String from, String to) async {
    final data = files.remove(from);
    if (data == null) return false;
    files[to] = data;
    return true;
  }
}
