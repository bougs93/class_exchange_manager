import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 네이티브(모바일·데스크톱) DB 초기화 — 기존 로직 그대로.
///
/// Windows/Linux/macOS는 `sqflite_common_ffi`를, Android/iOS는 기존
/// `sqflite` 플랫폼 구현을 그대로 쓴다.
bool _factoryInitialized = false;

/// `databaseFactory`를 플랫폼에 맞게 한 번만 초기화한다.
void ensureDatabaseFactory() {
  if (_factoryInitialized) return;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  _factoryInitialized = true;
}

/// 기본 DB 파일의 절대 경로.
Future<String> defaultDatabaseFilePath(String fileName) async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, fileName);
}

/// DB 파일 존재 여부.
Future<bool> databaseFileExists(String path) => File(path).exists();
