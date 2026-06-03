/// 로컬 JSON 저장 경로 관련 상수
class StorageConfig {
  /// Windows: 실행 파일(.exe)과 같은 폴더 아래에 만드는 데이터 폴더 이름
  static const String windowsDataSubfolder = 'data';

  /// AppData → exe/data 마이그레이션 완료 표시 파일 (data 폴더 안)
  static const String migrationMarkerFileName = '.storage_migrated_from_appdata';
}
