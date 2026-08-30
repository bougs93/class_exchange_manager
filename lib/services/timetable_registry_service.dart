import '../models/timetable_registry.dart';
import '../utils/logger.dart';
import 'json_storage.dart';
import 'storage_service.dart';

/// 시간표 레지스트리 저장 서비스
///
/// 등록된 시간표(학기) 목록과 활성 시간표를
/// `timetable_registry.json`으로 관리합니다.
class TimetableRegistryService {
  /// 레지스트리 파일명
  static const String filename = 'timetable_registry.json';

  final JsonStorage _storage;

  /// [storage] 미지정 시 실제 파일 저장소([StorageService]) 사용
  TimetableRegistryService({JsonStorage? storage}) : _storage = storage ?? StorageService();

  /// 레지스트리 로드 (파일이 없으면 빈 레지스트리 반환)
  Future<TimetableRegistry> loadRegistry() async {
    try {
      final json = await _storage.loadJson(filename);
      if (json == null) {
        return const TimetableRegistry();
      }
      return TimetableRegistry.fromJson(json);
    } catch (e) {
      AppLogger.error('시간표 레지스트리 로드 실패: $e', e);
      return const TimetableRegistry();
    }
  }

  /// 레지스트리 저장
  Future<bool> saveRegistry(TimetableRegistry registry) async {
    try {
      final success = await _storage.saveJson(filename, registry.toJson());
      if (success) {
        AppLogger.info(
          '시간표 레지스트리 저장 성공: ${registry.timetables.length}개, 활성=${registry.activeId}',
        );
      }
      return success;
    } catch (e) {
      AppLogger.error('시간표 레지스트리 저장 실패: $e', e);
      return false;
    }
  }

  /// 시간표 등록 (첫 항목이면 자동으로 활성 지정)
  ///
  /// 반환값: 등록된 항목 (실패 시 StateError throw)
  Future<TimetableRegistryEntry> registerTimetable({
    required String name,
    required String fileName,
    required String filePath,
    required String hash,
    required String contentHash,
    String? teacherName,
    String? schoolName,
    DateTime? semesterStart,
    DateTime? semesterEnd,
  }) async {
    final registry = await loadRegistry();
    final entry = TimetableRegistryEntry(
      id: TimetableRegistryEntry.generateId(),
      name: name,
      fileName: fileName,
      filePath: filePath,
      hash: hash,
      contentHash: contentHash,
      teacherName: teacherName,
      schoolName: schoolName,
      semesterStart: semesterStart,
      semesterEnd: semesterEnd,
      registeredAt: DateTime.now(),
    );

    final success = await saveRegistry(registry.withEntry(entry));
    if (!success) {
      throw StateError('시간표 등록 저장 실패: $name');
    }
    return entry;
  }

  /// 시간표 이름 변경
  Future<bool> renameTimetable(String id, String newName) async {
    final registry = await loadRegistry();
    final entry = registry.getById(id);
    if (entry == null) {
      AppLogger.warning('이름 변경 대상 시간표를 찾을 수 없음: $id');
      return false;
    }

    final updated = registry.copyWith(
      timetables: registry.timetables
          .map((e) => e.id == id ? e.copyWith(name: newName) : e)
          .toList(),
    );
    return saveRegistry(updated);
  }

  /// 활성 시간표 전환
  Future<bool> switchActive(String id) async {
    final registry = await loadRegistry();
    if (registry.getById(id) == null) {
      AppLogger.warning('전환 대상 시간표를 찾을 수 없음: $id');
      return false;
    }
    return saveRegistry(registry.withActive(id));
  }

  /// 시간표 원본 데이터 갱신 (동일 파일 재선택 시 사용)
  ///
  /// 항목을 새로 만들지 않고 해시·경로 정보만 최신화합니다.
  Future<bool> updateTimetableData(
    String id, {
    required String fileName,
    required String filePath,
    required String hash,
    required String contentHash,
  }) async {
    final registry = await loadRegistry();
    if (registry.getById(id) == null) {
      AppLogger.warning('갱신 대상 시간표를 찾을 수 없음: $id');
      return false;
    }

    final updated = registry.copyWith(
      timetables: registry.timetables
          .map(
            (e) => e.id == id
                ? e.copyWith(
                    fileName: fileName,
                    filePath: filePath,
                    hash: hash,
                    contentHash: contentHash,
                  )
                : e,
          )
          .toList(),
    );
    return saveRegistry(updated);
  }

  /// 시간표의 교사·학교명 갱신
  ///
  /// 계층 정의상 교사는 시간표에 종속되므로 전역 설정이 아닌 이 항목에 저장합니다.
  /// [clearTeacher]/[clearSchool]이 true면 해당 값을 미지정으로 되돌립니다.
  Future<bool> updateTeacherAndSchool(
    String id, {
    String? teacherName,
    String? schoolName,
    bool clearTeacher = false,
    bool clearSchool = false,
  }) async {
    final registry = await loadRegistry();
    if (registry.getById(id) == null) {
      AppLogger.warning('교사·학교명 갱신 대상 시간표를 찾을 수 없음: $id');
      return false;
    }

    final updated = registry.copyWith(
      timetables: registry.timetables
          .map(
            (e) => e.id == id
                ? e.copyWith(
                    teacherName: teacherName,
                    schoolName: schoolName,
                    clearTeacherName: clearTeacher,
                    clearSchoolName: clearSchool,
                  )
                : e,
          )
          .toList(),
    );
    return saveRegistry(updated);
  }

  /// 시간표 제거 (활성이었다면 활성 해제)
  ///
  /// 주의: 시간표 본문·교체 목록 등 스코프 데이터 삭제는 호출자(Provider)가 담당.
  Future<bool> removeTimetable(String id) async {
    final registry = await loadRegistry();
    return saveRegistry(registry.withoutEntry(id));
  }

  /// 현재 활성 시간표 항목 (없으면 null)
  Future<TimetableRegistryEntry?> getActiveEntry() async {
    final registry = await loadRegistry();
    return registry.activeEntry;
  }
}
