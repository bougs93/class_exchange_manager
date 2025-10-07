import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/timetable_data_source.dart';
import '../models/time_slot.dart';
import '../utils/day_utils.dart';

/// 교체 서비스의 공통 베이스 클래스
///
/// 모든 교체 서비스(1:1, 순환, 연쇄)에서 공통으로 사용되는
/// 셀 선택 로직과 교사명 추출 로직을 제공합니다.
abstract class BaseExchangeService {
  // ==================== 공통 상태 변수 ====================

  String? _selectedTeacher;   // 선택된 교사명
  String? _selectedDay;       // 선택된 요일
  int? _selectedPeriod;       // 선택된 교시

  // ==================== Getters ====================

  String? get selectedTeacher => _selectedTeacher;
  String? get selectedDay => _selectedDay;
  int? get selectedPeriod => _selectedPeriod;

  // ==================== 공통 메서드 ====================

  /// 셀 선택 상태 설정
  void selectCell(String teacherName, String day, int period) {
    _selectedTeacher = teacherName;
    _selectedDay = day;
    _selectedPeriod = period;
  }

  /// 셀 선택 해제
  void clearCellSelection() {
    _selectedTeacher = null;
    _selectedDay = null;
    _selectedPeriod = null;
  }

  /// 교체 모드 활성화 상태 확인
  bool hasSelectedCell() {
    return _selectedTeacher != null &&
           _selectedDay != null &&
           _selectedPeriod != null;
  }

  /// 셀에서 교사명 추출
  ///
  /// Syncfusion DataGrid에서 헤더 구조:
  /// - 일반 헤더: 1개 (컬럼명 표시)
  /// - 스택된 헤더: 1개 (요일별 병합)
  /// 총 2개의 헤더 행이 있으므로 실제 데이터 행 인덱스는 2를 빼야 함
  String getTeacherNameFromCell(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  ) {
    String teacherName = '';

    const int headerRowCount = 2;
    int actualRowIndex = details.rowColumnIndex.rowIndex - headerRowCount;

    if (actualRowIndex >= 0 && actualRowIndex < dataSource.rows.length) {
      DataGridRow row = dataSource.rows[actualRowIndex];
      for (DataGridCell rowCell in row.getCells()) {
        if (rowCell.columnName == 'teacher') {
          teacherName = rowCell.value.toString();
          break;
        }
      }
    }
    return teacherName;
  }

  /// 동일한 셀인지 확인
  bool isSameCell(String teacherName, String day, int period) {
    return _selectedTeacher == teacherName &&
           _selectedDay == day &&
           _selectedPeriod == period;
  }

  /// 선택된 셀의 학급 정보 가져오기
  String? getSelectedClassName(List<TimeSlot> timeSlots) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return null;
    }

    TimeSlot? selectedSlot = timeSlots.cast<TimeSlot?>().firstWhere(
      (slot) => slot != null &&
                slot.teacher == _selectedTeacher &&
                slot.dayOfWeek == DayUtils.getDayNumber(_selectedDay!) &&
                slot.period == _selectedPeriod &&
                slot.isNotEmpty,
      orElse: () => null,
    );

    return selectedSlot?.className;
  }

  /// 특정 교사가 특정 시간에 비어있는지 확인
  bool isTeacherEmptyAtTime(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots,
  ) {
    return !timeSlots.any((slot) =>
      slot.teacher == teacherName &&
      slot.dayOfWeek == DayUtils.getDayNumber(day) &&
      slot.period == period &&
      slot.isNotEmpty
    );
  }

  /// 특정 시간의 과목 정보 가져오기
  String getSubjectFromTimeSlot(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots,
  ) {
    int dayNumber = DayUtils.getDayNumber(day);

    TimeSlot? slot = timeSlots.cast<TimeSlot?>().firstWhere(
      (slot) => slot != null &&
                slot.teacher == teacherName &&
                slot.dayOfWeek == dayNumber &&
                slot.period == period &&
                slot.isNotEmpty,
      orElse: () => null,
    );

    return slot?.subject ?? '과목명 없음';
  }

  /// 특정 시간의 학급 정보 가져오기
  String getClassNameFromTimeSlot(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots,
  ) {
    int dayNumber = DayUtils.getDayNumber(day);

    TimeSlot? slot = timeSlots.cast<TimeSlot?>().firstWhere(
      (slot) => slot != null &&
                slot.teacher == teacherName &&
                slot.dayOfWeek == dayNumber &&
                slot.period == period &&
                slot.isNotEmpty,
      orElse: () => null,
    );

    return slot?.className ?? '';
  }
}
