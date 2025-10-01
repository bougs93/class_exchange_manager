import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../utils/exchange_algorithm.dart';
import '../utils/logger.dart';
import '../utils/day_utils.dart';
import '../utils/timetable_data_source.dart';

/// 1:1 교체 서비스 클래스
/// 교체 관련 비즈니스 로직을 담당
class ExchangeService {
  // 교체 관련 상태 변수들
  String? _selectedTeacher;   // 선택된 교사명
  String? _selectedDay;       // 선택된 요일
  int? _selectedPeriod;       // 선택된 교시
  
  // 타겟 셀 관련 상태 변수들 (교체 대상의 같은 행 셀)
  String? _targetTeacher;     // 타겟 교사명
  String? _targetDay;         // 타겟 요일
  int? _targetPeriod;        // 타겟 교시
  
  // 교체 가능한 시간 관련 변수들
  List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들
  
  // Getters
  String? get selectedTeacher => _selectedTeacher;
  String? get selectedDay => _selectedDay;
  int? get selectedPeriod => _selectedPeriod;
  String? get targetTeacher => _targetTeacher;
  String? get targetDay => _targetDay;
  int? get targetPeriod => _targetPeriod;
  List<ExchangeOption> get exchangeOptions => _exchangeOptions;
  
  /// 1:1 교체 처리 시작
  /// 교체 모드에서 셀을 클릭했을 때 호출되는 메인 함수
  ExchangeResult startOneToOneExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  ) {
    // 교사명 열은 선택하지 않음
    if (details.column.columnName == 'teacher') {
      return ExchangeResult.noAction();
    }
    
    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      return ExchangeResult.noAction();
    }
    
    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;
    
    // 교체할 셀의 교사명 찾기 (헤더를 고려한 행 인덱스 계산)
    String teacherName = _getTeacherNameFromCell(details, dataSource);
    
    // 동일한 셀을 다시 클릭했는지 확인 (토글 기능)
    bool isSameCell = _selectedTeacher == teacherName && 
                     _selectedDay == day && 
                     _selectedPeriod == period;
    
    if (isSameCell) {
      // 동일한 셀 클릭 시 교체 대상 해제
      _clearCellSelection();
      return ExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      _selectCell(teacherName, day, period);
      return ExchangeResult.selected(teacherName, day, period);
    }
  }
  
  /// 셀에서 교사명 추출
  String _getTeacherNameFromCell(DataGridCellTapDetails details, TimetableDataSource dataSource) {
    String teacherName = '';
    
    // Syncfusion DataGrid에서 헤더는 다음과 같이 구성됨:
    // - 일반 헤더: 1개 (컬럼명 표시)
    // - 스택된 헤더: 1개 (요일별 병합)
    // 총 2개의 헤더 행이 있으므로 실제 데이터 행 인덱스는 2를 빼야 함
    int actualRowIndex = details.rowColumnIndex.rowIndex - 2;
    
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
  
  /// 셀 선택 상태 설정
  void _selectCell(String teacherName, String day, int period) {
    _selectedTeacher = teacherName;
    _selectedDay = day;
    _selectedPeriod = period;
  }
  
  /// 셀 선택 해제
  void _clearCellSelection() {
    _selectedTeacher = null;
    _selectedDay = null;
    _selectedPeriod = null;
  }
  
  /// 교체 가능한 시간 업데이트
  /// 선택된 셀에 대해 교체 가능한 시간들을 탐색하고 반환
  List<ExchangeOption> updateExchangeableTimes(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      _exchangeOptions = [];
      return _exchangeOptions;
    }
    
    // 시간표 그리드 교체가능 표시 로직을 기반으로 교체 옵션 생성
    List<ExchangeOption> options = _generateExchangeOptionsFromGridLogic(
      timeSlots,
      teachers,
    );
    
    _exchangeOptions = options;
    return _exchangeOptions;
  }
  
  /// 시간표 그리드 교체가능 표시 로직을 기반으로 교체 옵션 생성
  /// 이 메서드는 시간표 그리드에 표시되는 교체가능한 교사 정보와 동일한 로직을 사용
  List<ExchangeOption> _generateExchangeOptionsFromGridLogic(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_selectedTeacher == null) return [];
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = _getSelectedClassName(timeSlots);
    if (selectedClassName == null) return [];
    
    List<ExchangeOption> exchangeOptions = [];
    
    // 요일별로 빈시간 검사
    const List<String> days = ['월', '화', '수', '목', '금'];
    const List<int> periods = [1, 2, 3, 4, 5, 6, 7];
    
    for (String day in days) {
      for (int period in periods) {
        // 해당 교사의 해당 요일, 교시에 수업이 있는지 확인
        bool hasClass = timeSlots.any((slot) => 
          slot.teacher == _selectedTeacher &&
          slot.dayOfWeek == DayUtils.getDayNumber(day) &&
          slot.period == period &&
          slot.isNotEmpty
        );
        
        if (!hasClass) {
          // 빈시간에 같은 반을 가르치는 교사 찾기
          List<ExchangeOption> dayExchangeOptions = _findSameClassTeachersForExchangeOptions(
            day, period, selectedClassName, timeSlots, teachers
          );
          exchangeOptions.addAll(dayExchangeOptions);
        }
      }
    }
    
    return exchangeOptions;
  }
  
  /// 빈시간에 같은 반을 가르치는 교사를 찾아서 ExchangeOption으로 변환
  List<ExchangeOption> _findSameClassTeachersForExchangeOptions(
    String day, 
    int period, 
    String selectedClassName,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    List<ExchangeOption> exchangeOptions = [];
    
    // 모든 교사 중에서 해당 시간에 같은 반을 가르치는 교사 찾기
    for (Teacher teacher in teachers) {
      if (teacher.name == _selectedTeacher) continue; // 자기 자신 제외
      
      // 해당 교사가 해당 시간에 같은 반을 가르치는지 확인
      bool hasSameClass = timeSlots.any((slot) => 
        slot.teacher == teacher.name &&
        slot.dayOfWeek == DayUtils.getDayNumber(day) &&
        slot.period == period &&
        slot.className == selectedClassName &&
        slot.isNotEmpty
      );
      
      if (hasSameClass) {
        // 해당 교사의 과목 정보도 함께 가져오기
        TimeSlot? teacherSlot = timeSlots.firstWhere(
          (slot) => slot.teacher == teacher.name &&
                    slot.dayOfWeek == DayUtils.getDayNumber(day) &&
                    slot.period == period &&
                    slot.className == selectedClassName,
          orElse: () => TimeSlot.empty(),
        );
        
        // 교체 가능한 교사들이 선택된 시간에 실제로 빈 시간인지 검사
        bool isAvailableAtSelectedTime = _checkTeacherAvailabilityAtSelectedTime(
          [teacher.name], day, period, timeSlots
        ).isNotEmpty;
        
        if (isAvailableAtSelectedTime && teacherSlot.isNotEmpty) {
          // ExchangeOption 생성
          ExchangeOption option = ExchangeOption(
            timeSlot: teacherSlot,
            teacherName: teacher.name,
            type: ExchangeType.sameClass,
            priority: 1,
            reason: '${teacher.name} 교사 - 동일 학급 ($selectedClassName)',
          );
          exchangeOptions.add(option);
        }
      }
    }
    
    return exchangeOptions;
  }
  
  /// 교체 가능한 교사 정보 가져오기
  List<Map<String, dynamic>> getCurrentExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_selectedTeacher == null) return [];
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = _getSelectedClassName(timeSlots);
    if (selectedClassName == null) return [];
    
    List<Map<String, dynamic>> exchangeableTeachers = [];
    
    // 요일별로 빈시간 검사
    const List<String> days = ['월', '화', '수', '목', '금'];
    const List<int> periods = [1, 2, 3, 4, 5, 6, 7];
    
    for (String day in days) {
      List<String> emptySlots = [];
      
      for (int period in periods) {
        // 해당 교사의 해당 요일, 교시에 수업이 있는지 확인
        bool hasClass = timeSlots.any((slot) => 
          slot.teacher == _selectedTeacher &&
          slot.dayOfWeek == DayUtils.getDayNumber(day) &&
          slot.period == period &&
          slot.isNotEmpty
        );
        
        if (!hasClass) {
          emptySlots.add('$period교시');
        }
      }
      
      if (emptySlots.isNotEmpty) {
        // 빈시간에 같은 반을 가르치는 교사 찾기
        List<Map<String, dynamic>> dayExchangeableTeachers = _findSameClassTeachers(
          day, emptySlots, selectedClassName, timeSlots, teachers
        );
        exchangeableTeachers.addAll(dayExchangeableTeachers);
      }
    }
    
    return exchangeableTeachers;
  }
  
  /// 선택된 셀의 학급 정보 가져오기
  String? _getSelectedClassName(List<TimeSlot> timeSlots) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return null;
    }
    
    // 선택된 셀의 TimeSlot 찾기
    TimeSlot? selectedSlot = timeSlots.firstWhere(
      (slot) => slot.teacher == _selectedTeacher &&
                slot.dayOfWeek == DayUtils.getDayNumber(_selectedDay!) &&
                slot.period == _selectedPeriod,
      orElse: () => TimeSlot.empty(),
    );
    
    return selectedSlot.className;
  }
  
  /// 빈시간에 같은 반을 가르치는 교사 찾기
  List<Map<String, dynamic>> _findSameClassTeachers(
    String day, 
    List<String> emptySlots, 
    String selectedClassName,
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    List<Map<String, dynamic>> exchangeableTeachers = [];
    
    for (String emptySlot in emptySlots) {
      int period = int.tryParse(emptySlot.replaceAll('교시', '')) ?? 0;
      if (period == 0) continue;
      
      // 모든 교사 중에서 해당 시간에 같은 반을 가르치는 교사 찾기
      List<String> sameClassTeachers = [];
      
      for (Teacher teacher in teachers) {
        if (teacher.name == _selectedTeacher) continue; // 자기 자신 제외
        
        // 해당 교사가 해당 시간에 같은 반을 가르치는지 확인
        bool hasSameClass = timeSlots.any((slot) => 
          slot.teacher == teacher.name &&
          slot.dayOfWeek == DayUtils.getDayNumber(day) &&
          slot.period == period &&
          slot.className == selectedClassName &&
          slot.isNotEmpty
        );
        
        if (hasSameClass) {
          // 해당 교사의 과목 정보도 함께 출력
          TimeSlot? teacherSlot = timeSlots.firstWhere(
            (slot) => slot.teacher == teacher.name &&
                      slot.dayOfWeek == DayUtils.getDayNumber(day) &&
                      slot.period == period &&
                      slot.className == selectedClassName,
            orElse: () => TimeSlot.empty(),
          );
          
          String subject = teacherSlot.subject ?? '과목 없음';
          sameClassTeachers.add('${teacher.name}($subject)');
        }
      }
      
      if (sameClassTeachers.isNotEmpty) {
        // 교체 가능한 교사들이 선택된 시간에 실제로 빈 시간인지 검사
        List<String> actuallyAvailableTeachers = _checkTeacherAvailabilityAtSelectedTime(
          sameClassTeachers, day, period, timeSlots
        );
        
        if (actuallyAvailableTeachers.isNotEmpty) {
          // 교체 가능한 교사 정보를 수집 (UI 표시용)
          for (String teacherInfo in actuallyAvailableTeachers) {
            String teacherName = teacherInfo.split('(')[0];
            exchangeableTeachers.add({
              'teacherName': teacherName,
              'day': day,
              'period': period,
              'subject': teacherInfo.split('(')[1].replaceAll(')', ''),
            });
          }
        }
      }
    }
    
    return exchangeableTeachers;
  }
  
  /// 교체 가능한 교사들이 선택된 시간에 실제로 빈 시간인지 검사
  List<String> _checkTeacherAvailabilityAtSelectedTime(
    List<String> sameClassTeachers, 
    String day, 
    int period,
    List<TimeSlot> timeSlots,
  ) {
    if (_selectedDay == null || _selectedPeriod == null) return sameClassTeachers;
    
    List<String> actuallyAvailableTeachers = [];
    
    for (String teacherInfo in sameClassTeachers) {
      // 교사명 추출 (예: "박지혜(사회)" -> "박지혜" 또는 단순히 "박지혜")
      String teacherName = teacherInfo.contains('(') 
          ? teacherInfo.split('(')[0] 
          : teacherInfo;
      
      // 해당 교사가 선택된 시간에 수업이 있는지 확인
      bool hasClassAtSelectedTime = timeSlots.any((slot) => 
        slot.teacher == teacherName &&
        slot.dayOfWeek == DayUtils.getDayNumber(_selectedDay!) &&
        slot.period == _selectedPeriod &&
        slot.isNotEmpty
      );
      
      // 선택된 시간에 수업이 없는 교사만 실제 교체 가능한 교사로 추가
      if (!hasClassAtSelectedTime) {
        actuallyAvailableTeachers.add(teacherInfo);
      }
    }
    
    return actuallyAvailableTeachers;
  }
  
  /// 교체 가능한 교사 정보 로그 출력
  void logExchangeableInfo(List<Map<String, dynamic>> exchangeableTeachers) {
    if (_selectedTeacher == null) return;
    
    // 현재 선택된 교사, 요일, 시간 정보를 첫 번째 줄에 출력
    AppLogger.teacherEmptySlotsInfo('선택된 셀: $_selectedTeacher 교사, $_selectedDay요일, $_selectedPeriod교시');
    
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
        AppLogger.teacherEmptySlotsInfo('$day요일 교체 가능한 교사: ${teachersByDay[day]!.join(', ')}');
      }
    }
  }
  
  /// 타겟 셀 설정 (교체 대상의 같은 행 셀)
  /// 교체 대상이 월1교시라면, 선택된 셀의 같은 행의 월1교시를 타겟으로 설정
  void setTargetCell(String targetTeacher, String targetDay, int targetPeriod) {
    _targetTeacher = targetTeacher;
    _targetDay = targetDay;
    _targetPeriod = targetPeriod;
    
    AppLogger.exchangeDebug('타겟 셀 설정: $targetTeacher $targetDay $targetPeriod교시');
  }
  
  /// 타겟 셀 해제
  void clearTargetCell() {
    _targetTeacher = null;
    _targetDay = null;
    _targetPeriod = null;
    
    AppLogger.exchangeDebug('타겟 셀 해제');
  }
  
  /// 타겟 셀이 설정되어 있는지 확인
  bool hasTargetCell() {
    return _targetTeacher != null && _targetDay != null && _targetPeriod != null;
  }
  
  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    _clearCellSelection();
    clearTargetCell();
    _exchangeOptions.clear();
  }
  
  /// 교체 모드 활성화 상태 확인
  bool hasSelectedCell() {
    return _selectedTeacher != null && _selectedDay != null && _selectedPeriod != null;
  }
}

/// 교체 결과를 나타내는 클래스
class ExchangeResult {
  final bool isSelected;
  final bool isDeselected;
  final bool isNoAction;
  final String? teacherName;
  final String? day;
  final int? period;
  
  ExchangeResult._({
    required this.isSelected,
    required this.isDeselected,
    required this.isNoAction,
    this.teacherName,
    this.day,
    this.period,
  });
  
  /// 교체 대상이 선택됨
  factory ExchangeResult.selected(String teacherName, String day, int period) {
    return ExchangeResult._(
      isSelected: true,
      isDeselected: false,
      isNoAction: false,
      teacherName: teacherName,
      day: day,
      period: period,
    );
  }
  
  /// 교체 대상이 해제됨
  factory ExchangeResult.deselected() {
    return ExchangeResult._(
      isSelected: false,
      isDeselected: true,
      isNoAction: false,
    );
  }
  
  /// 아무 동작하지 않음
  factory ExchangeResult.noAction() {
    return ExchangeResult._(
      isSelected: false,
      isDeselected: false,
      isNoAction: true,
    );
  }
}
