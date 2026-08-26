import 'storage_service.dart';

/// JSON 저장소 추상 인터페이스
///
/// 서비스 계층이 실제 파일 I/O([StorageService])와 테스트용 인메모리 구현을
/// 교체할 수 있도록 분리합니다. 모든 메서드는 [StorageService]와 시그니처가
/// 동일합니다.
abstract class JsonStorage {
  /// JSON 데이터를 파일에 저장
  Future<bool> saveJson(String filename, dynamic data);

  /// JSON 객체 파일 로드 (없으면 null)
  Future<Map<String, dynamic>?> loadJson(String filename);

  /// JSON 배열 파일 로드 (없으면 null)
  Future<List<dynamic>?> loadJsonArray(String filename);

  /// 파일 존재 여부
  Future<bool> fileExists(String filename);

  /// 파일 삭제
  Future<bool> deleteFile(String filename);

  /// 저장소의 JSON 파일명 목록
  Future<List<String>> listJsonFiles();
}
