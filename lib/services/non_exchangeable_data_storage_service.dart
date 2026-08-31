import 'storage_service.dart';
import '../services/timetable_registry_service.dart';
import '../models/time_slot.dart';
import '../utils/logger.dart';

/// 교체불가 셀 데이터 저장 서비스
///
/// 교체불가 셀 데이터만 별도 파일로 저장하고 로드합니다.
/// 시간표별로 별도 파일을 관리합니다.
/// 해시는 레지스트리의 활성 시간표를 사용합니다(시간표 단위 공유).
class NonExchangeableDataStorageService {
  final StorageService _storageService = StorageService();

  // 싱글톤 인스턴스
  static final NonExchangeableDataStorageService _instance =
      NonExchangeableDataStorageService._internal();

  factory NonExchangeableDataStorageService() => _instance;

  NonExchangeableDataStorageService._internal();

  /// 현재 시간표의 해시값 가져오기 (레지스트리 활성 시간표 기준)
  Future<String?> _getCurrentTimetableHash() async {
    try {
      final activeEntry = await TimetableRegistryService()
          .loadRegistry()
          .then((registry) => registry.activeEntry);
      if (activeEntry == null || activeEntry.hash.isEmpty) {
        AppLogger.warning('활성 시간표가 없어 교체불가 데이터 해시를 확인할 수 없습니다.');
        return null;
      }
      return activeEntry.hash;
    } catch (e) {
      AppLogger.error('시간표 해시값 가져오기 실패: $e', e);
      return null;
    }
  }

  /// 파일명 생성
  String _getFilename(String hash) {
    return 'non_exchangeable_data_$hash.json';
  }

  /// 교체불가 셀 데이터 저장
  ///
  /// 매개변수:
  /// - `cells`: 저장할 교체불가 셀 리스트
  ///
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveNonExchangeableCells(List<NonExchangeableCell> cells) async {
    try {
      final hash = await _getCurrentTimetableHash();
      if (hash == null) {
        AppLogger.error('시간표 해시값이 없어 교체불가 데이터를 저장할 수 없습니다.');
        return false;
      }

      final filename = _getFilename(hash);

      // 교체불가 셀 리스트를 JSON 배열로 변환
      final jsonArray = cells.map((cell) => cell.toJson()).toList();

      // JSON 파일로 저장
      final success = await _storageService.saveJson(filename, jsonArray);

      if (success) {
        AppLogger.info('교체불가 셀 데이터 저장 성공: $filename (${cells.length}개)');
      } else {
        AppLogger.error('교체불가 셀 데이터 저장 실패');
      }

      return success;
    } catch (e) {
      AppLogger.error('교체불가 셀 데이터 저장 중 오류: $e', e);
      return false;
    }
  }

  /// 교체불가 셀 데이터 로드
  ///
  /// 반환값:
  /// - `Future<List<NonExchangeableCell>>`: 로드된 교체불가 셀 리스트 (없으면 빈 리스트)
  Future<List<NonExchangeableCell>> loadNonExchangeableCells() async {
    try {
      final hash = await _getCurrentTimetableHash();
      if (hash == null) {
        AppLogger.info('시간표 해시값이 없어 교체불가 데이터를 로드할 수 없습니다.');
        return [];
      }

      final filename = _getFilename(hash);

      // JSON 배열 파일 로드
      final jsonArray = await _storageService.loadJsonArray(filename);

      if (jsonArray == null) {
        AppLogger.info('교체불가 셀 데이터 파일이 없습니다: $filename');
        return [];
      }

      // NonExchangeableCell 리스트로 변환
      final cells =
          jsonArray
              .map(
                (json) =>
                    NonExchangeableCell.fromJson(json as Map<String, dynamic>),
              )
              .toList();

      AppLogger.info('교체불가 셀 데이터 로드 성공: $filename (${cells.length}개)');

      return cells;
    } catch (e) {
      AppLogger.error('교체불가 셀 데이터 로드 중 오류: $e', e);
      return [];
    }
  }

  /// 현재 시간표의 교체불가 셀 리스트 생성 (TimeSlot 리스트에서 추출)
  ///
  /// 매개변수:
  /// - `timeSlots`: 시간표 데이터의 TimeSlot 리스트
  ///
  /// 반환값:
  /// - `List<NonExchangeableCell>`: 교체불가 셀 리스트
  List<NonExchangeableCell> extractNonExchangeableCellsFromTimeSlots(
    List<TimeSlot> timeSlots,
  ) {
    final cells = <NonExchangeableCell>[];

    for (var slot in timeSlots) {
      // 교체불가 셀인 경우만 추가
      if (!slot.isExchangeable && slot.exchangeReason == '교체불가') {
        if (slot.teacher != null &&
            slot.dayOfWeek != null &&
            slot.period != null) {
          cells.add(
            NonExchangeableCell(
              teacher: slot.teacher!,
              dayOfWeek: slot.dayOfWeek!,
              period: slot.period!,
            ),
          );
        }
      }
    }

    return cells;
  }
}

/// 교체불가 셀 정보를 나타내는 클래스
///
/// §10.6: [date]가 `null`이면 매주 반복(기존 동작 — 요일·교시만으로 항상 적용),
/// 값이 있으면 그 날짜가 속한 주에만 적용된다(예: "9/1은 지필평가라 교체 불가").
/// 구 형식 JSON에는 `date` 키가 없으므로 `fromJson`은 자연스럽게 `null`(매주 반복)로
/// 해석한다 — 마이그레이션 없이도 기존 데이터가 그대로 동작한다.
class NonExchangeableCell {
  final String teacher;
  final int dayOfWeek;
  final int period;
  final DateTime? date;

  const NonExchangeableCell({
    required this.teacher,
    required this.dayOfWeek,
    required this.period,
    this.date,
  });

  /// 매주 반복(요일·교시 기준, 날짜 무관) 여부
  bool get isRecurring => date == null;

  Map<String, dynamic> toJson() {
    return {
      'teacher': teacher,
      'dayOfWeek': dayOfWeek,
      'period': period,
      if (date != null) 'date': date!.toIso8601String(),
    };
  }

  factory NonExchangeableCell.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String?;
    return NonExchangeableCell(
      teacher: json['teacher'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      period: json['period'] as int,
      date: rawDate != null ? DateTime.tryParse(rawDate) : null,
    );
  }
}
