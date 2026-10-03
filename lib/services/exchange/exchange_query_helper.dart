import '../../models/time_slot.dart';
import '../../utils/day_utils.dart';
import '../../utils/logger.dart';
import '../base_exchange_service.dart';

/// 교체 관련 조회·상태 관리 담당
///
/// `exchange_service.dart`에서 분리된 부분으로, 다음을 담당한다:
/// - 타겟 셀(교체 대상의 같은 행 셀) 상태 관리
/// - 교사가 특정 과목을 가르치는지, 선택된 시간에 바쁜지 등의 조회
/// - 교체 가능한 교사 정보 로그 출력
///
/// [OneToOneExchangeHandler], [SupplementExchangeHandler] 등 다른 핸들러들이
/// 공통으로 사용하는 조회 메서드([isTeacherBusyAtSelectedTime] 등)를 제공하므로
/// 원래 private(`_`)이던 일부 메서드는 cross-file 호출을 위해 public으로 바뀌었다.
/// (동작은 기존과 동일, 가시성만 변경)
class ExchangeQueryHelper {
  ExchangeQueryHelper(this._context);

  final BaseExchangeService _context;

  // 타겟 셀 관련 상태 변수들 (교체 대상의 같은 행 셀)
  String? _targetTeacher; // 타겟 교사명
  String? _targetDay; // 타겟 요일
  int? _targetPeriod; // 타겟 교시

  // Getters
  String? get targetTeacher => _targetTeacher;
  String? get targetDay => _targetDay;
  int? get targetPeriod => _targetPeriod;

  /// 시간표 어디든 해당 교과를 가르치는지 확인
  bool teacherTeachesSubject(
    String teacherName,
    String subject,
    List<TimeSlot> timeSlots,
  ) {
    final target = subject.trim();
    if (target.isEmpty) {
      return false;
    }

    return timeSlots.any(
      (slot) =>
          slot.teacher == teacherName &&
          slot.isNotEmpty &&
          (slot.subject?.trim() ?? '') == target,
    );
  }

  /// 교사 표시용 과목 — 선택 결강 셀과 같은 교과목이 있으면 우선 표시
  String getTeacherDisplaySubject(
    String teacherName,
    List<TimeSlot> timeSlots,
  ) {
    String? preferredSubject;
    String? fallbackSubject;

    final selectedSubject = _getSelectedCellSubjectName(timeSlots);

    for (final slot in timeSlots) {
      if (slot.teacher != teacherName || !slot.isNotEmpty) {
        continue;
      }

      final slotSubject = slot.subject?.trim();
      if (slotSubject == null || slotSubject.isEmpty) {
        continue;
      }

      fallbackSubject ??= slotSubject;
      if (selectedSubject != null && slotSubject == selectedSubject) {
        preferredSubject = slotSubject;
        break;
      }
    }

    return preferredSubject ?? fallbackSubject ?? '과목정보없음';
  }

  /// 선택된 결강 셀의 교과목명
  String? _getSelectedCellSubjectName(List<TimeSlot> timeSlots) {
    if (_context.selectedTeacher == null ||
        _context.selectedDay == null ||
        _context.selectedPeriod == null) {
      return null;
    }

    final slot = _context.findTimeSlot(
      _context.selectedTeacher!,
      _context.selectedDay!,
      _context.selectedPeriod!,
      timeSlots,
      requireNotEmpty: true,
    );

    final subject = slot?.subject?.trim();
    if (subject == null || subject.isEmpty) {
      return null;
    }
    return subject;
  }

  /// 선택된 시간에 해당 교사가 수업 중인지 확인
  bool isTeacherBusyAtSelectedTime(
    String teacherName,
    List<TimeSlot> timeSlots,
  ) {
    if (_context.selectedDay == null || _context.selectedPeriod == null) {
      return false;
    }

    return timeSlots.any(
      (slot) =>
          slot.teacher == teacherName &&
          slot.dayOfWeek == DayUtils.getDayNumber(_context.selectedDay!) &&
          slot.period == _context.selectedPeriod &&
          slot.isNotEmpty,
    );
  }

  /// 타겟 셀 설정 (교체 대상의 같은 행 셀)
  /// 교체 대상이 월1교시라면, 선택된 셀의 같은 행의 월1교시를 타겟으로 설정
  void setTargetCell(String targetTeacher, String targetDay, int targetPeriod) {
    _targetTeacher = targetTeacher;
    _targetDay = targetDay;
    _targetPeriod = targetPeriod;

    AppLogger.exchangeDebug(
      '타겟 셀 설정: $targetTeacher $targetDay $targetPeriod교시',
    );
  }

  /// 타겟 셀 해제 (내부용)
  void clearTargetCell() {
    _targetTeacher = null;
    _targetDay = null;
    _targetPeriod = null;

    AppLogger.exchangeDebug('타겟 셀 해제 (내부)');
  }

  /// 타겟 셀 상태만 업데이트 (UI 핸들러용)
  void updateTargetCellState(String? teacher, String? day, int? period) {
    _targetTeacher = teacher;
    _targetDay = day;
    _targetPeriod = period;

    AppLogger.exchangeDebug(
      '타겟 셀 상태 업데이트: $teacher $day ${period != null ? '$period교시' : 'null'}',
    );
  }

  /// 타겟 셀이 설정되어 있는지 확인
  bool hasTargetCell() {
    return _targetTeacher != null &&
        _targetDay != null &&
        _targetPeriod != null;
  }

  /// 교체 가능한 교사 정보 로그 출력
  void logExchangeableInfo(List<Map<String, dynamic>> exchangeableTeachers) {
    if (_context.selectedTeacher == null) return;

    // 현재 선택된 교사, 요일, 시간 정보를 첫 번째 줄에 출력
    AppLogger.teacherEmptySlotsInfo(
      '선택된 셀: ${_context.selectedTeacher} 교사, ${_context.selectedDay}요일, ${_context.selectedPeriod}교시',
    );

    if (exchangeableTeachers.isEmpty) {
      AppLogger.teacherEmptySlotsInfo('교체 가능한 교사가 없습니다.');
    } else {
      // 교체 가능한 교사들을 요일별로 그룹화하여 출력
      Map<String, List<String>> teachersByDay = {};
      for (var teacher in exchangeableTeachers) {
        String day = teacher['day'];
        String teacherName = teacher['teacherName'];
        String subject = teacher['subject'];
        int period = teacher['period'];

        teachersByDay.putIfAbsent(day, () => []);
        teachersByDay[day]!.add('$period교시: $teacherName($subject)');
      }

      for (String day in teachersByDay.keys) {
        AppLogger.teacherEmptySlotsInfo(
          '$day요일 교체 가능한 교사: ${teachersByDay[day]!.join(', ')}',
        );
      }
    }
  }
}
