import '../models/time_slot.dart';
import 'day_utils.dart';
import 'logger.dart';

/// 교체불가 관리 클래스
/// 
/// 주요 기능:
/// - 교체 불가 셀 설정/해제
/// - 교체 불가 여부 검사 (모든 교체 유형에서 공통 사용)
/// - 교체 경로 생성 시 교체 불가 셀 필터링
class NonExchangeableManager {
  List<TimeSlot> _timeSlots = [];
  bool _isNonExchangeableEditMode = false;
  
  /// TimeSlot 리스트 설정
  void setTimeSlots(List<TimeSlot> timeSlots) {
    _timeSlots = timeSlots;
  }

  /// 교체불가 편집 모드 설정
  void setNonExchangeableEditMode(bool isEditMode) {
    _isNonExchangeableEditMode = isEditMode;
  }

  /// 교체불가 편집 모드 상태 확인
  bool get isNonExchangeableEditMode => _isNonExchangeableEditMode;

  /// 교체불가 TimeSlot인지 확인
  bool isNonExchangeableTimeSlot(String teacherName, String day, int period) {
    // 교사명 열인 경우는 교체불가가 아님
    if (day.isEmpty || period == 0) {
      return false;
    }
    
    // 공통 헬퍼 메서드 사용 (중복 로직 제거)
    final timeSlot = _findTimeSlot(teacherName, day, period);
    
    if (timeSlot == null) {
      // TimeSlot이 존재하지 않는 경우 (완전히 빈 셀)는 기본 색상으로 표시
      return false;
    }
    
    // 실제로 교체불가로 설정된 셀만 빨간색 배경으로 표시
    // 빈 셀도 교체불가로 설정될 수 있으므로 isEmpty 체크 제거
    return !timeSlot.isExchangeable && timeSlot.exchangeReason == '교체불가';
  }
  
  /// TimeSlot 찾기 헬퍼 메서드 (중복 로직 제거)
  /// 
  /// [teacherName] 교사명
  /// [day] 요일 문자열 (월, 화, 수, 목, 금)
  /// [period] 교시
  /// 
  /// 반환값: 찾은 TimeSlot 또는 null
  TimeSlot? _findTimeSlot(String teacherName, String day, int period) {
    final dayNumber = DayUtils.getDayNumber(day);
    
    try {
      return _timeSlots.firstWhere(
        (slot) => slot.teacher == teacherName &&
                  slot.dayOfWeek == dayNumber &&
                  slot.period == period,
      );
    } catch (e) {
      return null;
    }
  }

  /// 특정 교사의 모든 TimeSlot을 교체불가로 설정
  void setTeacherAsNonExchangeable(String teacherName) {
    int modifiedCount = 0;

    for (var timeSlot in _timeSlots) {
      if (timeSlot.teacher == teacherName && timeSlot.isNotEmpty) {
        timeSlot.isExchangeable = false;
        timeSlot.exchangeReason = '교체불가';
        modifiedCount++;
      }
    }

    if (modifiedCount > 0) {
      AppLogger.exchangeDebug('교사 교체불가 설정: $teacherName ($modifiedCount개 셀)');
    }
  }

  /// 특정 교사의 모든 TimeSlot을 교체가능/교체불가로 토글
  void toggleTeacherAllTimes(String teacherName) {
    // 해당 교사의 모든 TimeSlot 찾기
    List<TimeSlot> teacherSlots = _timeSlots
        .where((slot) => slot.teacher == teacherName)
        .toList();

    if (teacherSlots.isEmpty) {
      AppLogger.exchangeDebug('교사 "$teacherName"의 시간표가 없습니다.');
      return;
    }

    // 현재 상태 확인 (모두 교체불가인지)
    bool allNonExchangeable = teacherSlots.every(
        (slot) => !slot.isExchangeable && slot.exchangeReason == '교체불가');

    // 토글 동작
    if (allNonExchangeable) {
      // 모두 교체불가 -> 모두 교체가능으로
      for (var slot in teacherSlots) {
        slot.isExchangeable = true;
        slot.exchangeReason = null;
      }
      AppLogger.exchangeDebug('교사 "$teacherName"의 모든 시간을 교체 가능으로 설정');
    } else {
      // 일부 또는 전체가 교체가능 -> 모두 교체불가로
      for (var slot in teacherSlots) {
        slot.isExchangeable = false;
        slot.exchangeReason = '교체불가';
      }
      AppLogger.exchangeDebug('교사 "$teacherName"의 모든 시간을 교체 불가능으로 설정');
    }
  }

  /// 특정 셀을 교체불가로 설정 또는 해제 (토글 방식, 빈 셀 포함)
  void setCellAsNonExchangeable(String teacherName, String day, int period) {
    // 공통 헬퍼 메서드 사용 (중복 로직 제거)
    final existingTimeSlot = _findTimeSlot(teacherName, day, period);
    
    if (existingTimeSlot != null) {
      
      // 기존 TimeSlot이 있는 경우 토글 방식으로 처리
      if (!existingTimeSlot.isExchangeable && existingTimeSlot.exchangeReason == '교체불가') {
        // 교체불가 상태인 경우 -> 교체 가능으로 되돌리기
        existingTimeSlot.isExchangeable = true;
        existingTimeSlot.exchangeReason = null;
        AppLogger.exchangeDebug('교체불가 해제: $teacherName $day $period교시 (${existingTimeSlot.subject ?? "빈 셀"})');
      } else {
        // 교체 가능 상태인 경우 -> 교체불가로 설정
        existingTimeSlot.isExchangeable = false;
        existingTimeSlot.exchangeReason = '교체불가';
        AppLogger.exchangeDebug('교체불가 설정: $teacherName $day $period교시 (${existingTimeSlot.subject ?? "빈 셀"})');
      }
    } else {
      // 빈 셀인 경우 새로운 TimeSlot 생성 (교체불가로 설정)
      final dayOfWeek = DayUtils.getDayNumber(day);
      final newTimeSlot = TimeSlot(
        teacher: teacherName,
        dayOfWeek: dayOfWeek,
        period: period,
        subject: null, // 빈 셀
        className: null, // 빈 셀
        isExchangeable: false, // 교체불가로 설정
        exchangeReason: '교체불가',
      );
      
      _timeSlots.add(newTimeSlot);
      AppLogger.exchangeDebug('새로운 TimeSlot 생성 (교체불가): $teacherName $day $period교시');
    }
  }

  /// 모든 교체불가 설정 초기화
  void resetAllNonExchangeableSettings() {
    int modifiedCount = 0;
    
    for (var timeSlot in _timeSlots) {
      if (!timeSlot.isExchangeable && timeSlot.exchangeReason == '교체불가') {
        timeSlot.isExchangeable = true;
        timeSlot.exchangeReason = null;
        modifiedCount++;
      }
    }
    
    if (modifiedCount > 0) {
      AppLogger.exchangeDebug('교체불가 설정 초기화: $modifiedCount개 셀');
    }
  }
}
