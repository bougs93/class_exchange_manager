import 'package:sqflite_common/sqflite.dart';
// 조건부 export의 상위 파일(`database_platform.dart`)이 이미 웹 조건으로
// 이 파일을 선택했으므로, 여기서는 src를 직접 import한다. 패키지 공개
// 진입점(`sqflite_ffi_web.dart`)을 쓰면 분석기(VM 기준)가 io 분기로 해석해
// `databaseFactoryFfiWeb`을 찾을 수 없다는 오진이 나온다.
// ignore: implementation_imports
import 'package:sqflite_common_ffi_web/src/sqflite_ffi_web.dart';

/// 웹 DB 초기화 — `sqflite_common_ffi_web` (sqlite3.wasm + IndexedDB).
///
/// SQL·스키마·쿼리는 그대로이며, 엔진 팩토리와 파일 경로 개념만 바뀐다.
/// `dart run sqflite_common_ffi_web:setup`으로 설치한 `web/sqlite3.wasm`
/// 자산을 사용하므로, 웹 배포 시 `web/` 폴더를 통째로 올린다.
void ensureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}

/// 웹에는 파일 경로 개념이 없으므로 고정 DB 이름을 그대로 쓴다
/// (OPFS/IndexedDB 가상 경로에 보관된다).
Future<String> defaultDatabaseFilePath(String fileName) async => fileName;

/// 웹 팩토리에는 존재 확인 API가 없으므로 항상 true를 반환하고,
/// 실제 삭제(`deleteDatabase`)를 시도한다.
Future<bool> databaseFileExists(String path) async => true;
