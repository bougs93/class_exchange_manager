import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../constants/storage_config.dart';
import '../utils/logger.dart';

/// 기본 저장소 서비스 클래스
/// JSON 파일 읽기/쓰기 유틸리티를 제공합니다.
class StorageService {
  // 싱글톤 인스턴스
  static final StorageService _instance = StorageService._internal();

  // 싱글톤 생성자
  factory StorageService() => _instance;

  // 내부 생성자
  StorageService._internal();

  /// 한 번 결정된 데이터 디렉터리 캐시 (매 파일 I/O마다 경로 재계산 방지)
  Directory? _cachedDataDirectory;

  /// 앱 데이터 디렉토리 경로를 반환합니다.
  ///
  /// 플랫폼별 동작:
  /// - **Windows**: `{실행파일폴더}\data\` (exe와 같은 위치의 하위 폴더)
  /// - **Android / iOS / macOS / Linux / Web**: `getApplicationSupportDirectory()` (기존과 동일)
  ///
  /// Windows에서 `data` 폴더 생성·쓰기에 실패하면 AppData로 폴백합니다.
  Future<Directory> _getAppDataDirectory() async {
    if (_cachedDataDirectory != null) {
      return _cachedDataDirectory!;
    }

    try {
      Directory directory;
      if (Platform.isWindows) {
        directory = await _resolveWindowsDataDirectory();
      } else {
        directory = await getApplicationSupportDirectory();
      }
      _cachedDataDirectory = directory;
      return directory;
    } catch (e) {
      AppLogger.error('앱 데이터 디렉토리 가져오기 실패: $e', e);
      rethrow;
    }
  }

  /// Windows 전용: exe 옆 `data` 폴더 경로 확보
  Future<Directory> _resolveWindowsDataDirectory() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final dataDir = Directory(
        '${exeDir.path}${Platform.pathSeparator}${StorageConfig.windowsDataSubfolder}',
      );

      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      await _migrateFromLegacyAppDataIfNeeded(dataDir);

      AppLogger.info('Windows 데이터 폴더: ${dataDir.path}');
      return dataDir;
    } catch (e) {
      AppLogger.warning('Windows data 폴더 사용 실패, AppData로 폴백: $e');
      return await getApplicationSupportDirectory();
    }
  }

  /// Windows: 예전 %APPDATA% 저장소에만 JSON이 있으면 exe\data 로 1회 복사
  Future<void> _migrateFromLegacyAppDataIfNeeded(Directory targetDir) async {
    try {
      final markerFile = File(
        '${targetDir.path}${Platform.pathSeparator}${StorageConfig.migrationMarkerFileName}',
      );
      if (await markerFile.exists()) {
        return;
      }

      if (await _directoryHasJsonFiles(targetDir)) {
        await markerFile.writeAsString(DateTime.now().toIso8601String());
        return;
      }

      final legacyDir = await getApplicationSupportDirectory();
      final legacyJsonNames = await _listJsonFileNamesIn(legacyDir);
      if (legacyJsonNames.isEmpty) {
        await markerFile.writeAsString(DateTime.now().toIso8601String());
        return;
      }

      int copied = 0;
      for (final name in legacyJsonNames) {
        final source = File(
          '${legacyDir.path}${Platform.pathSeparator}$name',
        );
        final dest = File(
          '${targetDir.path}${Platform.pathSeparator}$name',
        );
        if (!await dest.exists()) {
          await source.copy(dest.path);
          copied++;
        }
      }

      await markerFile.writeAsString(DateTime.now().toIso8601String());
      AppLogger.info(
        'Windows 데이터 마이그레이션: AppData → ${targetDir.path} ($copied개 JSON 복사)',
      );
    } catch (e) {
      AppLogger.warning('Windows 데이터 마이그레이션 실패(무시하고 계속): $e');
    }
  }

  Future<bool> _directoryHasJsonFiles(Directory directory) async {
    return (await _listJsonFileNamesIn(directory)).isNotEmpty;
  }

  Future<List<String>> _listJsonFileNamesIn(Directory directory) async {
    final names = <String>[];
    if (!await directory.exists()) {
      return names;
    }

    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.endsWith('.json')) {
        names.add(name);
      }
    }
    return names;
  }

  /// 현재 JSON 저장 폴더 경로 (설정 화면·디버깅용)
  Future<String> getDataDirectoryPath() async {
    final directory = await _getAppDataDirectory();
    return directory.path;
  }

  /// 설정 화면용 저장 위치 설명 (플랫폼별)
  String getDataLocationDescription() {
    if (Platform.isWindows) {
      return 'Windows: 프로그램(exe) 폴더 아래 data 폴더에 JSON을 저장합니다. '
          '(쓰기 불가 시 AppData로 자동 전환)';
    }
    if (Platform.isAndroid) {
      return 'Android: 앱 전용 내부 저장소에 저장합니다.';
    }
    if (Platform.isIOS) {
      return 'iOS: 앱 전용 저장소에 저장합니다.';
    }
    return '시스템 앱 지원(Application Support) 폴더에 저장합니다.';
  }

  /// 파일의 전체 경로를 생성합니다.
  ///
  /// 매개변수:
  /// - `filename`: 파일명 (예: "timetable_data.json")
  ///
  /// 반환값:
  /// - `String`: 전체 파일 경로
  Future<String> _getFilePath(String filename) async {
    final directory = await _getAppDataDirectory();
    return '${directory.path}${Platform.pathSeparator}$filename';
  }

  /// JSON 데이터를 파일에 저장합니다.
  ///
  /// 매개변수:
  /// - `filename`: 저장할 파일명
  /// - `data`: 저장할 데이터 (Map 또는 List)
  ///
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부 (true: 성공, false: 실패)
  ///
  /// 예외:
  /// - 저장 실패 시 예외를 throw하지 않고 false를 반환합니다.
  Future<bool> saveJson(String filename, dynamic data) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);

      // JSON 문자열로 변환
      final jsonString = jsonEncode(data);

      // 파일에 쓰기
      await file.writeAsString(jsonString, encoding: utf8);

      AppLogger.info('JSON 파일 저장 성공: $filename');
      return true;
    } catch (e) {
      AppLogger.error('JSON 파일 저장 실패: $filename, 오류: $e', e);
      return false;
    }
  }

  /// JSON 파일에서 데이터를 로드합니다.
  ///
  /// 매개변수:
  /// - `filename`: 로드할 파일명
  ///
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: 로드된 데이터 (실패 또는 파일 없음 시 null)
  ///
  /// 예외:
  /// - 파일이 없거나 읽기 실패 시 null을 반환합니다.
  Future<Map<String, dynamic>?> loadJson(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);

      // 파일 존재 여부 확인
      if (!await file.exists()) {
        AppLogger.info('JSON 파일이 존재하지 않음: $filename');
        return null;
      }

      // 파일 읽기
      final jsonString = await file.readAsString(encoding: utf8);

      // JSON 파싱
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      AppLogger.info('JSON 파일 로드 성공: $filename');
      return data;
    } catch (e) {
      AppLogger.error('JSON 파일 로드 실패: $filename, 오류: $e', e);
      return null;
    }
  }

  /// JSON 배열 파일에서 데이터를 로드합니다.
  ///
  /// 매개변수:
  /// - `filename`: 로드할 파일명
  ///
  /// 반환값:
  /// - `Future<List<dynamic>?>`: 로드된 배열 데이터 (실패 또는 파일 없음 시 null)
  ///
  /// 예외:
  /// - 파일이 없거나 읽기 실패 시 null을 반환합니다.
  Future<List<dynamic>?> loadJsonArray(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);

      // 파일 존재 여부 확인
      if (!await file.exists()) {
        AppLogger.info('JSON 배열 파일이 존재하지 않음: $filename');
        return null;
      }

      // 파일 읽기
      final jsonString = await file.readAsString(encoding: utf8);

      // JSON 파싱
      final data = jsonDecode(jsonString) as List<dynamic>;

      AppLogger.info('JSON 배열 파일 로드 성공: $filename');
      return data;
    } catch (e) {
      AppLogger.error('JSON 배열 파일 로드 실패: $filename, 오류: $e', e);
      return null;
    }
  }

  /// 파일이 존재하는지 확인합니다.
  ///
  /// 매개변수:
  /// - `filename`: 확인할 파일명
  ///
  /// 반환값:
  /// - `Future<bool>`: 파일 존재 여부
  Future<bool> fileExists(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      AppLogger.error('파일 존재 확인 실패: $filename, 오류: $e', e);
      return false;
    }
  }

  /// 파일을 삭제합니다.
  ///
  /// 매개변수:
  /// - `filename`: 삭제할 파일명
  ///
  /// 반환값:
  /// - `Future<bool>`: 삭제 성공 여부
  Future<bool> deleteFile(String filename) async {
    try {
      final filePath = await _getFilePath(filename);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        AppLogger.info('파일 삭제 성공: $filename');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('파일 삭제 실패: $filename, 오류: $e', e);
      return false;
    }
  }

  /// 앱 데이터 디렉토리의 모든 JSON 파일 목록을 반환합니다.
  ///
  /// 반환값:
  /// - `Future<List<String>>`: 파일명 목록
  Future<List<String>> listJsonFiles() async {
    try {
      final directory = await _getAppDataDirectory();
      return await _listJsonFileNamesIn(directory);
    } catch (e) {
      AppLogger.error('JSON 파일 목록 조회 실패: $e', e);
      return [];
    }
  }

  /// 모든 JSON 파일 삭제
  ///
  /// 앱 데이터 디렉토리에 있는 모든 JSON 파일을 삭제합니다.
  ///
  /// 반환값:
  /// - `Future<Map<String, bool>>`: 삭제 결과 맵 (키: 파일명, 값: 삭제 성공 여부)
  Future<Map<String, bool>> deleteAllJsonFiles() async {
    final results = <String, bool>{};

    try {
      // 모든 JSON 파일 목록 가져오기
      final jsonFiles = await listJsonFiles();

      AppLogger.info('JSON 파일 삭제 시작: ${jsonFiles.length}개 파일');

      // 각 파일 삭제
      for (String filename in jsonFiles) {
        try {
          final success = await deleteFile(filename);
          results[filename] = success;

          if (success) {
            AppLogger.info('JSON 파일 삭제 성공: $filename');
          } else {
            AppLogger.warning('JSON 파일 삭제 실패: $filename');
          }
        } catch (e) {
          AppLogger.error('JSON 파일 삭제 중 오류 ($filename): $e', e);
          results[filename] = false;
        }
      }

      AppLogger.info(
        '모든 JSON 파일 삭제 완료: 성공 ${results.values.where((v) => v).length}개 / 전체 ${results.length}개',
      );

      return results;
    } catch (e) {
      AppLogger.error('모든 JSON 파일 삭제 중 오류: $e', e);
      return results;
    }
  }
}
