import 'json_storage.dart';

/// 조건부 export의 폴백 (어느 플랫폼 조건에도 해당하지 않을 때).
///
/// 미지원 플랫폼에서 명확한 런타임 오류를 내기 위해 공개 API 형태만
/// 갖추고, 모든 동작은 [UnsupportedError]를 던진다.
class StorageService implements JsonStorage {
  factory StorageService() => throw UnsupportedError('지원하지 않는 플랫폼입니다.');

  @override
  Future<bool> saveJson(String filename, dynamic data) {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  @override
  Future<Map<String, dynamic>?> loadJson(String filename) {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  @override
  Future<List<dynamic>?> loadJsonArray(String filename) {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  @override
  Future<bool> fileExists(String filename) {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  @override
  Future<bool> deleteFile(String filename) {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  @override
  Future<List<String>> listJsonFiles() {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  @override
  Future<bool> renameFile(String from, String to) {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  Future<String> getDataDirectoryPath() {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  String getDataLocationDescription() {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }

  Future<Map<String, bool>> deleteAllJsonFiles() {
    throw UnsupportedError('지원하지 않는 플랫폼입니다.');
  }
}
