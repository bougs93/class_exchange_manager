import 'teacher.dart';
import 'time_slot.dart';

/// 엑셀 파일 파싱 설정을 위한 클래스
class ExcelParsingConfig {
  final int dayHeaderRow; // 요일 헤더가 있는 행 (1-based)
  final int periodHeaderRow; // 교시 번호가 있는 행 (1-based)
  final int teacherColumn; // 교사명이 있는 열 (A열 = 1)
  final int dataStartRow; // 실제 데이터가 시작하는 행 (1-based)
  final int dataStartColumn; // 실제 데이터가 시작하는 열 (1-based, 첫 번째 요일의 1교시 열)

  const ExcelParsingConfig({
    this.dayHeaderRow = 2,
    this.periodHeaderRow = 3,
    this.teacherColumn = 1,
    this.dataStartRow = 4,
    this.dataStartColumn = 2, // 기본값: B열 (A열은 교사명)
  });
}

/// 시간표 파싱 결과를 담는 클래스
///
/// 엑셀에서 만들어지지만 **엑셀에 의존하지 않는 순수 데이터**다. 그래서
/// `excel_service.dart`가 아니라 여기(models)에 둔다 — 예전에는 이 타입 하나를
/// 쓰려고 24개 파일이 `excel_service.dart`를 import했고, 그 바람에 `dart:io`·
/// `package:excel`·`file_picker`까지 함께 끌려왔다(2026-10-03 분리).
class TimetableData {
  final List<Teacher> teachers;
  final List<TimeSlot> timeSlots;
  final ExcelParsingConfig config;
  final int totalParsedCells;
  final int successCount;
  final int errorCount;

  TimetableData({
    required this.teachers,
    required this.timeSlots,
    required this.config,
    required this.totalParsedCells,
    required this.successCount,
    required this.errorCount,
  });

  /// 파싱 성공률 계산
  double get successRate =>
      totalParsedCells > 0 ? successCount / totalParsedCells : 0.0;

  /// JSON 직렬화 (저장용)
  ///
  /// TimetableData를 Map 형태로 변환하여 JSON 파일에 저장할 수 있도록 합니다.
  Map<String, dynamic> toJson() {
    return {
      'teachers': teachers.map((teacher) => teacher.toJson()).toList(),
      'timeSlots': timeSlots.map((slot) => slot.toJson()).toList(),
      'config': {
        'dayHeaderRow': config.dayHeaderRow,
        'periodHeaderRow': config.periodHeaderRow,
        'teacherColumn': config.teacherColumn,
        'dataStartRow': config.dataStartRow,
        'dataStartColumn': config.dataStartColumn,
      },
      'totalParsedCells': totalParsedCells,
      'successCount': successCount,
      'errorCount': errorCount,
    };
  }

  /// JSON 역직렬화 (로드용)
  ///
  /// JSON 파일에서 읽어온 Map 데이터를 TimetableData 객체로 변환합니다.
  factory TimetableData.fromJson(Map<String, dynamic> json) {
    final teachersJson = json['teachers'] as List<dynamic>;
    final teachers =
        teachersJson
            .map(
              (teacherJson) =>
                  Teacher.fromJson(teacherJson as Map<String, dynamic>),
            )
            .toList();

    final timeSlotsJson = json['timeSlots'] as List<dynamic>;
    final timeSlots =
        timeSlotsJson
            .map(
              (slotJson) => TimeSlot.fromJson(slotJson as Map<String, dynamic>),
            )
            .toList();

    final configJson = json['config'] as Map<String, dynamic>;
    final config = ExcelParsingConfig(
      dayHeaderRow: configJson['dayHeaderRow'] as int? ?? 2,
      periodHeaderRow: configJson['periodHeaderRow'] as int? ?? 3,
      teacherColumn: configJson['teacherColumn'] as int? ?? 1,
      dataStartRow: configJson['dataStartRow'] as int? ?? 4,
      dataStartColumn: configJson['dataStartColumn'] as int? ?? 2,
    );

    return TimetableData(
      teachers: teachers,
      timeSlots: timeSlots,
      config: config,
      totalParsedCells: json['totalParsedCells'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      errorCount: json['errorCount'] as int? ?? 0,
    );
  }
}
