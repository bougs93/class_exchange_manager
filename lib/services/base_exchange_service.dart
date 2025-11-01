import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/timetable_data_source.dart';
import '../models/time_slot.dart';
import '../utils/day_utils.dart';
import '../utils/logger.dart';

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

    // 공통 메서드 사용 (중복 로직 제거)
    TimeSlot? selectedSlot = findTimeSlot(
      _selectedTeacher!,
      _selectedDay!,
      _selectedPeriod!,
      timeSlots,
      requireNotEmpty: true,
    );

    return selectedSlot?.className;
  }

  /// 특정 교사가 특정 시간에 비어있는지 확인
  /// 
  /// 공통 메서드 사용으로 중복 로직 제거
  bool isTeacherEmptyAtTime(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots,
  ) {
    // 공통 메서드를 사용하여 TimeSlot 찾기 (중복 로직 제거)
    final timeSlot = findTimeSlot(
      teacherName,
      day,
      period,
      timeSlots,
      requireNotEmpty: true,
    );
    
    // 찾은 TimeSlot이 없거나 비어있으면 빈 시간
    return timeSlot == null || timeSlot.isEmpty;
  }

  /// 특정 시간의 TimeSlot 가져오기 (공통 헬퍼)
  /// 
  /// [teacherName] 교사명
  /// [day] 요일 문자열 (월, 화, 수, 목, 금)
  /// [period] 교시
  /// [timeSlots] 전체 TimeSlot 리스트
  /// [requireNotEmpty] true이면 isNotEmpty인 슬롯만 반환, false이면 모든 슬롯 반환
  /// 
  /// 반환값: 찾은 TimeSlot 또는 null
  TimeSlot? findTimeSlot(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots, {
    bool requireNotEmpty = false,
  }) {
    final dayNumber = DayUtils.getDayNumber(day);

    try {
      return timeSlots.firstWhere(
        (slot) => slot.teacher == teacherName &&
                  slot.dayOfWeek == dayNumber &&
                  slot.period == period &&
                  (!requireNotEmpty || slot.isNotEmpty),
      );
    } catch (e) {
      // 찾지 못한 경우에만 에러 로깅
      AppLogger.exchangeDebug('TimeSlot을 찾지 못함: $teacherName $day $period교시');
      return null;
    }
  }

  /// 특정 시간의 과목 정보 가져오기
  String getSubjectFromTimeSlot(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots,
  ) {
    return findTimeSlot(teacherName, day, period, timeSlots, requireNotEmpty: true)?.subject ?? '과목명 없음';
  }

  /// 특정 시간의 학급 정보 가져오기
  String getClassNameFromTimeSlot(
    String teacherName,
    String day,
    int period,
    List<TimeSlot> timeSlots,
  ) {
    return findTimeSlot(teacherName, day, period, timeSlots, requireNotEmpty: true)?.className ?? '';
  }
}
