import 'dart:convert';

import '../models/exchange_history_item.dart';
import '../models/print_profile.dart';
import '../models/time_slot.dart';
import '../utils/day_utils.dart';
import '../utils/lesson_projection.dart';

/// 결보강 내역 백업 파일의 형식 마커 — 엉뚱한 JSON 파일을 잘못 가져오지
/// 않도록 가져오기 시 반드시 확인한다.
const String substitutionBackupFormatType =
    'class_exchange_manager_substitution_backup';

/// 백업 파일 스키마 버전 (향후 필드 추가 시 올린다)
const int substitutionBackupFormatVersion = 1;

/// 결보강 내역(+연결된 계획서) 내보내기/가져오기 파일 1개의 내용.
class SubstitutionBackupBundle {
  final String? timetableName;
  final String? teacherName;
  final String? schoolName;
  final List<ExchangeHistoryItem> exchangeItems;
  final List<PrintProfile> printProfiles;

  const SubstitutionBackupBundle({
    this.timetableName,
    this.teacherName,
    this.schoolName,
    required this.exchangeItems,
    required this.printProfiles,
  });
}

/// 결보강 내역을 다른 PC와 주고받기 위한 파일 인코딩/디코딩 + 호환성 검사.
///
/// "같은 시간표인가"는 별도 스냅샷을 새로 저장하지 않는다 — 각 교체 건이
/// 이미 교체 당시의 원본 칸 정보([ExchangeHistoryItem.originalPath])를
/// 갖고 있으므로, 그 칸(교사·요일·교시)의 과목·학급이 지금 이 시간표의
/// 같은 칸과 같은지만 보면 충분하다(2026-09-30).
class SubstitutionBackupService {
  const SubstitutionBackupService();

  /// 내보내기용 JSON 문자열 생성
  String encode(SubstitutionBackupBundle bundle) {
    final map = {
      'formatType': substitutionBackupFormatType,
      'formatVersion': substitutionBackupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'timetableName': bundle.timetableName,
      'teacherName': bundle.teacherName,
      'schoolName': bundle.schoolName,
      'exchangeItems': bundle.exchangeItems.map((e) => e.toJson()).toList(),
      'printProfiles': bundle.printProfiles.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// [jsonString]을 파싱한다. 이 앱의 결보강 백업 파일이 아니면
  /// [FormatException]을 던진다.
  SubstitutionBackupBundle decode(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('알 수 없는 파일 형식입니다.');
    }
    if (decoded['formatType'] != substitutionBackupFormatType) {
      throw const FormatException('결보강 내역 백업 파일이 아닙니다.');
    }

    final itemsJson = (decoded['exchangeItems'] as List?) ?? const [];
    final profilesJson = (decoded['printProfiles'] as List?) ?? const [];

    return SubstitutionBackupBundle(
      timetableName: decoded['timetableName'] as String?,
      teacherName: decoded['teacherName'] as String?,
      schoolName: decoded['schoolName'] as String?,
      exchangeItems:
          itemsJson
              .map(
                (e) => ExchangeHistoryItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
      printProfiles:
          profilesJson
              .map(
                (p) => PrintProfile.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList(),
    );
  }

  /// 가져올 교체 건들이 기록해 둔 원본 칸 정보가 지금 이 시간표의 같은
  /// 칸과 일치하는지 확인한다.
  ///
  /// 그 교사·요일·교시 칸이 지금 시간표에 아예 없으면(예: 교사가 없어짐)
  /// 비교할 수 없으므로 건너뛴다 — 존재하는 칸만 내용(과목·학급)을 비교한다.
  bool matchesCurrentTimetable(
    List<ExchangeHistoryItem> importedItems,
    List<TimeSlot> currentTimeSlots,
  ) {
    for (final item in importedItems) {
      for (final node in item.originalPath.nodes) {
        final dayNumber = DayUtils.getDayNumber(node.day);
        TimeSlot? current;
        for (final slot in currentTimeSlots) {
          if (slot.teacher == node.teacherName &&
              slot.dayOfWeek == dayNumber &&
              slot.period == node.period) {
            current = slot;
            break;
          }
        }
        if (current == null) continue;
        if (current.subject != node.subjectName ||
            current.className != node.className) {
          return false;
        }
      }
    }
    return true;
  }

  /// 결강일/교시, 교체(보강)일/교시 중 하나라도 겹치는 건이 있으면 true.
  ///
  /// 되돌린(비활성) 건은 실제로 그 시간을 차지하지 않으므로 양쪽 다
  /// 제외한다. 순환·2중 교체의 노드별 실제 날짜 해석은 [touchedCellsFor]가
  /// 이미 하는 일이므로(§10.4/§10.5와 같은 규칙) 그대로 재사용한다.
  bool hasDateConflict(
    List<ExchangeHistoryItem> importedItems,
    List<ExchangeHistoryItem> existingItems,
  ) {
    final existingKeys = <String>{
      for (final item in existingItems.where((i) => !i.isReverted))
        for (final cell in touchedCellsFor(item)) _cellKey(cell),
    };

    for (final item in importedItems.where((i) => !i.isReverted)) {
      for (final cell in touchedCellsFor(item)) {
        if (existingKeys.contains(_cellKey(cell))) return true;
      }
    }
    return false;
  }

  String _cellKey(TouchedCell cell) =>
      '${cell.teacher}|${cell.date.year}-${cell.date.month}-${cell.date.day}|${cell.period}';
}
