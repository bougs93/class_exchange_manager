import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'json_storage.dart';

/// 기본 저장소 서비스 클래스 (웹용)
///
/// 브라우저 로컬 저장소(`shared_preferences` → localStorage)에 파일명 단위로
/// JSON 문자열을 보관한다. 네이티브 구현(`storage_service_io.dart`)과 공개
/// API가 동일하므로 호출부 수정이 필요 없다.
///
/// 요구사항상 로컬 데이터는 삭제되어도 무방하므로, 브라우저 데이터 삭제 시
/// 함께 사라지는 것을 정상 동작으로 간주한다.
class StorageService implements JsonStorage {
  // 싱글톤 인스턴스
  static final StorageService _instance = StorageService._internal();

  // 싱글톤 생성자
  factory StorageService() => _instance;

  // 내부 생성자
  StorageService._internal();

  /// 다른 용도의 설정값과 충돌하지 않도록 접두사를 붙인다.
  static const String _keyPrefix = 'cem_json_';

  String _keyFor(String filename) => '$_keyPrefix$filename';

  String? _filenameFor(String key) {
    if (!key.startsWith(_keyPrefix)) return null;
    final name = key.substring(_keyPrefix.length);
    if (!name.endsWith('.json')) return null;
    return name;
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// JSON 데이터를 저장합니다 (실패 시 false, 예외 없음).
  @override
  Future<bool> saveJson(String filename, dynamic data) async {
    try {
      final prefs = await _prefs();
      final ok = await prefs.setString(_keyFor(filename), jsonEncode(data));
      if (ok) AppLogger.info('JSON 저장 성공(웹): $filename');
      return ok;
    } catch (e) {
      AppLogger.error('JSON 저장 실패(웹): $filename, 오류: $e', e);
      return false;
    }
  }

  /// JSON 객체 로드 (없거나 파싱 실패 시 null).
  @override
  Future<Map<String, dynamic>?> loadJson(String filename) async {
    try {
      final prefs = await _prefs();
      final jsonString = prefs.getString(_keyFor(filename));
      if (jsonString == null) {
        AppLogger.info('JSON 없음(웹): $filename');
        return null;
      }
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      AppLogger.info('JSON 로드 성공(웹): $filename');
      return data;
    } catch (e) {
      AppLogger.error('JSON 로드 실패(웹): $filename, 오류: $e', e);
      return null;
    }
  }

  /// JSON 배열 로드 (없거나 파싱 실패 시 null).
  @override
  Future<List<dynamic>?> loadJsonArray(String filename) async {
    try {
      final prefs = await _prefs();
      final jsonString = prefs.getString(_keyFor(filename));
      if (jsonString == null) {
        AppLogger.info('JSON 배열 없음(웹): $filename');
        return null;
      }
      final data = jsonDecode(jsonString) as List<dynamic>;
      AppLogger.info('JSON 배열 로드 성공(웹): $filename');
      return data;
    } catch (e) {
      AppLogger.error('JSON 배열 로드 실패(웹): $filename, 오류: $e', e);
      return null;
    }
  }

  /// 저장 여부 확인.
  @override
  Future<bool> fileExists(String filename) async {
    try {
      final prefs = await _prefs();
      return prefs.containsKey(_keyFor(filename));
    } catch (e) {
      AppLogger.error('존재 확인 실패(웹): $filename, 오류: $e', e);
      return false;
    }
  }

  /// 저장값 삭제 (없으면 false).
  @override
  Future<bool> deleteFile(String filename) async {
    try {
      final prefs = await _prefs();
      final key = _keyFor(filename);
      if (!prefs.containsKey(key)) return false;
      final ok = await prefs.remove(key);
      if (ok) AppLogger.info('삭제 성공(웹): $filename');
      return ok;
    } catch (e) {
      AppLogger.error('삭제 실패(웹): $filename, 오류: $e', e);
      return false;
    }
  }

  /// 이름 변경 (원본이 없으면 false, 대상이 있으면 덮어씀).
  @override
  Future<bool> renameFile(String from, String to) async {
    try {
      final prefs = await _prefs();
      final value = prefs.getString(_keyFor(from));
      if (value == null) return false;
      final ok = await prefs.setString(_keyFor(to), value);
      if (!ok) return false;
      await prefs.remove(_keyFor(from));
      AppLogger.info('이름 변경 성공(웹): $from → $to');
      return true;
    } catch (e) {
      AppLogger.error('이름 변경 실패(웹): $from → $to, 오류: $e', e);
      return false;
    }
  }

  /// 저장된 JSON 파일명 목록.
  @override
  Future<List<String>> listJsonFiles() async {
    try {
      final prefs = await _prefs();
      final names = <String>[];
      for (final key in prefs.getKeys()) {
        final name = _filenameFor(key);
        if (name != null) names.add(name);
      }
      return names;
    } catch (e) {
      AppLogger.error('JSON 목록 조회 실패(웹): $e', e);
      return [];
    }
  }

  /// 현재 저장 위치 (설정 화면·디버깅용).
  Future<String> getDataDirectoryPath() async {
    return '브라우저 로컬 저장소';
  }

  /// 설정 화면용 저장 위치 설명.
  String getDataLocationDescription() {
    return '웹: 브라우저 로컬 저장소에 저장합니다. '
        '브라우저 데이터를 삭제하면 함께 지워집니다.';
  }

  /// 모든 JSON 삭제. 반환값은 파일명→성공 여부 맵이다.
  Future<Map<String, bool>> deleteAllJsonFiles() async {
    final results = <String, bool>{};
    try {
      final jsonFiles = await listJsonFiles();
      AppLogger.info('JSON 삭제 시작(웹): ${jsonFiles.length}개');
      for (final filename in jsonFiles) {
        try {
          final success = await deleteFile(filename);
          results[filename] = success;
        } catch (e) {
          AppLogger.error('JSON 삭제 중 오류(웹, $filename): $e', e);
          results[filename] = false;
        }
      }
      AppLogger.info(
        'JSON 삭제 완료(웹): 성공 ${results.values.where((v) => v).length}개 / 전체 ${results.length}개',
      );
      return results;
    } catch (e) {
      AppLogger.error('JSON 전체 삭제 중 오류(웹): $e', e);
      return results;
    }
  }
}
