import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/exchange_algorithm.dart';
import '../utils/timetable_data_source.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';

/// 순환교체 서비스 클래스
/// 여러 교사 간의 순환 교체 비즈니스 로직을 담당
class CircularExchangeService {
  // 교체 관련 상태 변수들
  String? _selectedTeacher;   // 선택된 교사명
  String? _selectedDay;       // 선택된 요일
  int? _selectedPeriod;       // 선택된 교시
  
  // 교체 가능한 시간 관련 변수들
  final List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들
  
  // Getters
  String? get selectedTeacher => _selectedTeacher;
  String? get selectedDay => _selectedDay;
  int? get selectedPeriod => _selectedPeriod;
  List<ExchangeOption> get exchangeOptions => _exchangeOptions;
  
  /// 순환교체 모드에서 셀 탭 처리
  /// 
  /// 매개변수:
  /// - `details`: 셀 탭 상세 정보
  /// - `dataSource`: 데이터 소스
  /// 
  /// 반환값:
  /// - `CircularExchangeResult`: 처리 결과
  CircularExchangeResult startCircularExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  ) {
    // 교사명 열은 선택하지 않음
    if (details.column.columnName == 'teacher') {
      return CircularExchangeResult.noAction();
    }
    
    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      return CircularExchangeResult.noAction();
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
      return CircularExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      _selectCell(teacherName, day, period);
      return CircularExchangeResult.selected(teacherName, day, period);
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
  
  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    _clearCellSelection();
    _exchangeOptions.clear();
  }
  
  /// 교체 모드 활성화 상태 확인
  bool hasSelectedCell() {
    return _selectedTeacher != null && _selectedDay != null && _selectedPeriod != null;
  }
  
  /// 순환교체용 교체 가능한 교사 정보 가져오기 (1스탭: 같은 학급, 다른 시간대, 양쪽 빈시간)
  /// 
  /// 1개 스탭 교체에서는:
  /// - 같은 학급만 교체 가능
  /// - 다른 시간대여야 함
  /// - 양쪽 모두 빈 시간이어야 함
  /// 예: 김선생(월1교시, 1학년 1반) ↔ 이선생(화2교시, 1학년 1반) - 둘 다 빈시간
  List<Map<String, dynamic>> getCircularExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return [];
    }
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = _getSelectedClassName(timeSlots);
    if (selectedClassName == null) return [];
    
    List<Map<String, dynamic>> exchangeableTeachers = [];
    
    // 같은 학급을 가르치는 교사들 중에서 찾기
    for (Teacher teacher in teachers) {
      if (teacher.name == _selectedTeacher) continue; // 자기 자신 제외
      
      // 해당 교사가 다른 시간대에 같은 학급을 가르치는지 확인
      List<TimeSlot> teacherSlots = timeSlots.where((slot) => 
        slot.teacher == teacher.name &&
        slot.className == selectedClassName &&
        slot.isNotEmpty &&
        !(slot.dayOfWeek == _getDayNumber(_selectedDay!) && slot.period == _selectedPeriod) // 다른 시간대
      ).toList();
      
      for (TimeSlot teacherSlot in teacherSlots) {
        // 양쪽 모두 빈 시간인지 확인
        bool selectedTeacherHasEmptyTime = _isTeacherEmptyAtTime(
          _selectedTeacher!, _selectedDay!, _selectedPeriod!, timeSlots);
        bool otherTeacherHasEmptyTime = _isTeacherEmptyAtTime(
          teacher.name, _getDayString(teacherSlot.dayOfWeek ?? 0), teacherSlot.period ?? 0, timeSlots);
        
        if (selectedTeacherHasEmptyTime && otherTeacherHasEmptyTime) {
          exchangeableTeachers.add({
            'teacherName': teacher.name,
            'day': _getDayString(teacherSlot.dayOfWeek ?? 0),
            'period': teacherSlot.period ?? 0,
            'className': selectedClassName,
            'subject': teacherSlot.subject ?? '과목 없음',
          });
        }
      }
    }
    
    return exchangeableTeachers;
  }
  
  /// 선택된 셀의 학급 정보 가져오기
  String? _getSelectedClassName(List<TimeSlot> timeSlots) {
    if (_selectedTeacher == null || _selectedDay == null || _selectedPeriod == null) {
      return null;
    }
    
    TimeSlot? selectedSlot = timeSlots.firstWhere(
      (slot) => slot.teacher == _selectedTeacher &&
                slot.dayOfWeek == _getDayNumber(_selectedDay!) &&
                slot.period == _selectedPeriod &&
                slot.isNotEmpty,
      orElse: () => TimeSlot.empty(),
    );
    
    return selectedSlot.isNotEmpty ? selectedSlot.className : null;
  }
  
  /// 교사가 특정 시간에 빈 시간인지 확인
  bool _isTeacherEmptyAtTime(String teacherName, String day, int period, List<TimeSlot> timeSlots) {
    return !timeSlots.any((slot) => 
      slot.teacher == teacherName &&
      slot.dayOfWeek == _getDayNumber(day) &&
      slot.period == period &&
      slot.isNotEmpty
    );
  }
  
  /// 요일 문자열을 숫자로 변환하는 헬퍼 메서드
  int _getDayNumber(String day) {
    const Map<String, int> dayMap = {
      '월': 1, '화': 2, '수': 3, '목': 4, '금': 5
    };
    return dayMap[day] ?? 0;
  }
  
  /// 요일 숫자를 문자열로 변환하는 헬퍼 메서드
  String _getDayString(int dayNumber) {
    const Map<int, String> dayMap = {
      1: '월', 2: '화', 3: '수', 4: '목', 5: '금'
    };
    return dayMap[dayNumber] ?? '알 수 없음';
  }
  
  /// 순환교체용 오버레이 위젯 생성 예시
  /// 
  /// 사용법:
  /// ```dart
  /// // 기본 사용법
  /// Widget overlay1 = CircularExchangeService.createOverlay(
  ///   color: Colors.blue.shade600,
  ///   number: '2',
  /// );
  /// 
  /// // 크기와 폰트 크기 지정
  /// Widget overlay2 = CircularExchangeService.createOverlay(
  ///   color: Colors.green.shade600,
  ///   number: '3',
  ///   size: 12.0,
  ///   fontSize: 9.0,
  /// );
  /// ```
  static Widget createOverlay({
    required Color color,
    required String number,
    double size = 10.0,
    double fontSize = 8.0,
  }) {
    return SimplifiedTimetableTheme.createExchangeableOverlay(
      color: color,
      number: number,
      size: size,
      fontSize: fontSize,
    );
  }
}

/// 순환교체 결과를 나타내는 클래스
class CircularExchangeResult {
  final bool isSelected;
  final bool isDeselected;
  final bool isNoAction;
  final String? teacherName;
  final String? day;
  final int? period;
  
  CircularExchangeResult._({
    required this.isSelected,
    required this.isDeselected,
    required this.isNoAction,
    this.teacherName,
    this.day,
    this.period,
  });
  
  /// 교체 대상이 선택됨
  factory CircularExchangeResult.selected(String teacherName, String day, int period) {
    return CircularExchangeResult._(
      isSelected: true,
      isDeselected: false,
      isNoAction: false,
      teacherName: teacherName,
      day: day,
      period: period,
    );
  }
  
  /// 교체 대상이 해제됨
  factory CircularExchangeResult.deselected() {
    return CircularExchangeResult._(
      isSelected: false,
      isDeselected: true,
      isNoAction: false,
    );
  }
  
  /// 아무 동작하지 않음
  factory CircularExchangeResult.noAction() {
    return CircularExchangeResult._(
      isSelected: false,
      isDeselected: false,
      isNoAction: true,
    );
  }
}