// 플랫폼별 저장소 구현 선택 (웹 전환 1단계)
//
// - 네이티브(모바일·데스크톱): `storage_service_io.dart` (파일 기반, 기존 로직 그대로)
// - 웹: `storage_service_web.dart` (브라우저 로컬 저장소 기반)
//
// 공개 API(`StorageService` 클래스명·메서드)가 동일하므로 호출부 수정이
// 필요 없다. 로직 변경 없이 분리만 한다.
export 'storage_service_stub.dart'
    if (dart.library.io) 'storage_service_io.dart'
    if (dart.library.html) 'storage_service_web.dart';
