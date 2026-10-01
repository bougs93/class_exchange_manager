// 플랫폼별 DB 초기화 선택 (웹 전환 1단계)
//
// - 네이티브: `database_platform_io.dart` (`sqflite_common_ffi`)
// - 웹: `database_platform_web.dart` (`sqflite_common_ffi_web`, WASM+IndexedDB)
export 'database_platform_stub.dart'
    if (dart.library.io) 'database_platform_io.dart'
    if (dart.library.html) 'database_platform_web.dart';
