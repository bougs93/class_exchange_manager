/// 조건부 export의 폴백 (어느 플랫폼 조건에도 해당하지 않을 때).
library;

Future<String> defaultDatabaseFilePath(String fileName) {
  throw UnsupportedError('지원하지 않는 플랫폼입니다: $fileName');
}

void ensureDatabaseFactory() {
  throw UnsupportedError('지원하지 않는 플랫폼입니다.');
}

Future<bool> databaseFileExists(String path) {
  throw UnsupportedError('지원하지 않는 플랫폼입니다: $path');
}
