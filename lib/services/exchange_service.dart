import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/exchange_node.dart';
import '../utils/exchange_algorithm.dart';
import '../utils/logger.dart';
import '../utils/day_utils.dart';
import '../utils/timetable_data_source.dart';
import '../utils/non_exchangeable_manager.dart';
import 'base_exchange_service.dart';

/// 1:1 교체 서비스 클래스
/// 교체 관련 비즈니스 로직을 담당
class ExchangeService extends BaseExchangeService {
  // 싱글톤 인스턴스
  static final ExchangeService _instance = ExchangeService._internal();
  
  // 싱글톤 생성자
  factory ExchangeService() => _instance;
  
  // 내부 생성자
  ExchangeService._internal();

  // 타겟 셀 관련 상태 변수들 (교체 대상의 같은 행 셀)
  String? _targetTeacher;     // 타겟 교사명
  String? _targetDay;         // 타겟 요일
  int? _targetPeriod;        // 타겟 교시

  // 교체 가능한 시간 관련 변수들
  List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들
  
  // 교체 불가 관리자
  final NonExchangeableManager _nonExchangeableManager = NonExchangeableManager();

  // Getters
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
    // 교사명 열 클릭은 교사 이름 선택 기능으로 처리
    if (details.column.columnName == 'teacher') {
      return ExchangeResult.noAction(); // 교사 이름 선택은 별도 처리
    }
    
    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      return ExchangeResult.noAction();
    }
    
    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;

    // 교체할 셀의 교사명 찾기 (베이스 클래스 메서드 사용)
    String teacherName = getTeacherNameFromCell(details, dataSource);

    // 동일한 셀을 다시 클릭했는지 확인 (베이스 클래스 메서드 사용)
    if (isSameCell(teacherName, day, period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      clearCellSelection();
      return ExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      selectCell(teacherName, day, period);
      return ExchangeResult.selected(teacherName, day, period);
    }
  }
  
  /// 교체 가능한 시간 업데이트
  /// 선택된 셀에 대해 교체 가능한 시간들을 탐색하고 반환
  List<ExchangeOption> updateExchangeableTimes(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (selectedTeacher == null || selectedDay == null || selectedPeriod == null) {
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
    if (selectedTeacher == null) return [];
    
    // 성능 최적화: 빈 셀과 교체불가능한 셀을 사전 필터링
    List<TimeSlot> validTimeSlots = timeSlots.where((slot) => 
      slot.isNotEmpty && slot.canExchange
    ).toList();
    
    AppLogger.exchangeDebug('1:1교체 최적화: 전체 ${timeSlots.length}개 → 유효한 ${validTimeSlots.length}개 TimeSlot');
    
    // 교체 불가 관리자에 TimeSlot 설정
    _nonExchangeableManager.setTimeSlots(timeSlots);
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = getSelectedClassName(validTimeSlots);
    if (selectedClassName == null) return [];
    
    List<ExchangeOption> exchangeOptions = [];
    
    // 요일별로 빈시간 검사 (실제 데이터 기반)
    const List<String> days = ['월', '화', '수', '목', '금'];
    
    // 실제 데이터에서 교시 목록 추출
    Set<int> availablePeriods = {};
    for (var slot in validTimeSlots) {
      if (slot.period != null) {
        availablePeriods.add(slot.period!);
      }
    }
    
    for (String day in days) {
      // 해당 요일에 실제로 존재하는 교시만 검사
      for (int period in availablePeriods) {
        // 해당 교사의 해당 요일, 교시에 수업이 있는지 확인
        bool hasClass = validTimeSlots.any((slot) => 
          slot.teacher == selectedTeacher &&
          slot.dayOfWeek == DayUtils.getDayNumber(day) &&
          slot.period == period
        );
        
        if (!hasClass) {
          // 빈시간에 같은 반을 가르치는 교사 찾기
          List<ExchangeOption> dayExchangeOptions = _findSameClassTeachersForExchangeOptions(
            day, period, selectedClassName, validTimeSlots, teachers
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
      if (teacher.name == selectedTeacher) continue; // 자기 자신 제외
      
      // 해당 교사가 해당 시간에 같은 반을 가르치는지 확인
      bool hasSameClass = timeSlots.any((slot) => 
        slot.teacher == teacher.name &&
        slot.dayOfWeek == DayUtils.getDayNumber(day) &&
        slot.period == period &&
        slot.className == selectedClassName &&
        slot.isNotEmpty &&
        slot.canExchange // 교체 가능한 셀만 고려
      );
      
      if (hasSameClass) {
        // 해당 교사의 과목 정보도 함께 가져오기
        TimeSlot? teacherSlot;
        try {
          teacherSlot = timeSlots.firstWhere(
            (slot) => slot.teacher == teacher.name &&
                      slot.dayOfWeek == DayUtils.getDayNumber(day) &&
                      slot.period == period &&
                      slot.className == selectedClassName,
          );
        } catch (e) {
          teacherSlot = null;
        }
        
        // 교체 가능한 교사들이 선택된 시간에 실제로 빈 시간인지 검사
        bool isAvailableAtSelectedTime = teacherSlot?.isNotEmpty == true && 
          _checkTeacherAvailabilityAtSelectedTime(
            [teacher.name], day, period, timeSlots
          ).isNotEmpty;
        
        // 교체 불가 충돌 검증 추가 (양방향 검증)
        bool noExchangeableConflict = _checkExchangeableConflict(
          teacher.name, selectedTeacher!, day, period, selectedDay!, selectedPeriod!, timeSlots);
        
        if (isAvailableAtSelectedTime && teacherSlot?.isNotEmpty == true && noExchangeableConflict) {
          // ExchangeOption 생성
          ExchangeOption option = ExchangeOption(
            timeSlot: teacherSlot!,
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
  
  /// 교체 불가 충돌 검증 메서드 (양방향 검증)
  /// 교사간 1:1 교체 시 양쪽 모두 교체 가능한지 확인
  bool _checkExchangeableConflict(
    String teacherName, 
    String selectedTeacher, 
    String teacherDay, 
    int teacherPeriod,
    String selectedDay, 
    int selectedPeriod,
    List<TimeSlot> timeSlots
  ) {
    // 1. 교사가 선택된 교사의 시간으로 이동 가능한지 검증
    bool teacherCanMoveToSelected = !_nonExchangeableManager.isNonExchangeableTimeSlot(
      teacherName, selectedDay, selectedPeriod);
    
    // 2. 선택된 교사가 교사의 원래 시간으로 이동 가능한지 검증
    bool selectedCanMoveToTeacher = !_nonExchangeableManager.isNonExchangeableTimeSlot(
      selectedTeacher, teacherDay, teacherPeriod);
    
    AppLogger.exchangeDebug('1:1교체 양방향 검증: '
      '$teacherName→$selectedTeacher($selectedDay$selectedPeriod교시): $teacherCanMoveToSelected, '
      '$selectedTeacher→$teacherName($teacherDay$teacherPeriod교시): $selectedCanMoveToTeacher');
    
    // 양방향 모두 가능해야 교체 성공
    return teacherCanMoveToSelected && selectedCanMoveToTeacher;
  }
  
  /// 실제 1:1 수업 교체 수행
  /// 
  /// 교체 예시:
  /// - 교체 전: 월|3|1-8|문유란|국어, 금|5|1-8|이숙기|과학
  /// - 교체 후: 금|5|1-8|문유란|국어, 월|3|1-8|이숙기|과학
  /// 
  /// 매개변수:
  /// - `timeSlots`: 전체 시간표 데이터
  /// - `teacher1`: 첫 번째 교사명
  /// - `day1`: 첫 번째 교사의 요일
  /// - `period1`: 첫 번째 교사의 교시
  /// - `teacher2`: 두 번째 교사명
  /// - `day2`: 두 번째 교사의 요일
  /// - `period2`: 두 번째 교사의 교시
  /// 
  /// 반환값:
  /// - `bool`: 교체 성공 여부
  bool performOneToOneExchange(
    List<TimeSlot> timeSlots,
    String teacher1,
    String day1,
    int period1,
    String teacher2,
    String day2,
    int period2,
  ) {
    try {
      AppLogger.exchangeInfo('1:1 교체 시작: $teacher1($day1$period1교시) ↔ $teacher2($day2$period2교시)');
      
      // 1. 교체 가능성 검증
      if (!_validateOneToOneExchange(
        timeSlots, teacher1, day1, period1, teacher2, day2, period2
      )) {
        AppLogger.exchangeDebug('1:1 교체 검증 실패');
        return false;
      }
      
      // 2. 교체할 소스 TimeSlot 찾기 (원본 수업이 있는 셀)
      TimeSlot? slot1s = _findTimeSlot(timeSlots, teacher1, day1, period1); // 문유란의 월6교시 (원본)
      TimeSlot? slot2s = _findTimeSlot(timeSlots, teacher2, day2, period2); // 정영훈의 화3교시 (원본)
      
      if (slot1s == null || slot2s == null) {
        AppLogger.exchangeDebug('교체할 소스 TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 3. 교체 대상 TimeSlot 찾기 (서로 다른 교사의 목적지 시간대)
      TimeSlot? slot2t = _findTimeSlot(timeSlots, teacher2, day1, period1); // 정영훈의 월6교시 (목적지)
      TimeSlot? slot1t = _findTimeSlot(timeSlots, teacher1, day2, period2); // 문유란의 화3교시 (목적지)
            
      if (slot1t == null || slot2t == null) {
        AppLogger.exchangeDebug('교체할 대상 TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 4. 교체 수행 (새로운 이동 방식: 원본 비우기 + 목적지에 복사)
      // 핵심: slot1과 slot2는 timeSlots 리스트에서 가져온 참조이므로,
      //       이들을 수정하면 원본 timeSlots 리스트가 직접 변경됩니다.
      
      // 올바른 교체 방식: 서로의 수업을 바꾸기
      // slot1s(문유란 월6교시) → slot2t(문유란 화3교시)로 이동
      // slot2s(정영훈 화3교시) → slot1t(정영훈 월6교시)로 이동
      bool moveSuccess1 = TimeSlot.moveTime(slot1s, slot1t); // 문유란의 월6교시 → 문유란의 화3교시
      bool moveSuccess2 = TimeSlot.moveTime(slot2s, slot2t); // 정영훈의 화3교시 → 정영훈의 월6교시
      
      AppLogger.exchangeDebug('TimeSlot 이동 결과: moveSuccess1=$moveSuccess1, moveSuccess2=$moveSuccess2');
      
      if (!moveSuccess1 || !moveSuccess2) {
        AppLogger.exchangeDebug('TimeSlot 이동 실패: moveSuccess1=$moveSuccess1, moveSuccess2=$moveSuccess2');
        return false;
      }
      
      // 교체 후 결과 디버그 로깅 (간소화)
      AppLogger.exchangeDebug('교체 완료 - 교체된 셀 상태:');
      AppLogger.exchangeDebug('  월6교시: ${slot2t.dayOfWeek}|${slot2t.period}|${slot2t.className}|${slot2t.teacher}|${slot2t.subject}');
      AppLogger.exchangeDebug('  화3교시: ${slot1t.dayOfWeek}|${slot1t.period}|${slot1t.className}|${slot1t.teacher}|${slot1t.subject}');

      // 히스토리 관리는 ExchangeHistoryService에서 담당
      AppLogger.exchangeInfo('1:1 교체 완료: $teacher1($day1$period1교시) ↔ $teacher2($day2$period2교시) [교체 성공]');
      return true;
      
    } catch (e) {
      AppLogger.exchangeDebug('1:1 교체 중 오류 발생: $e');
      return false;
    }
  }
  
  /// 보강교체 실행
  /// 
  /// 보강교체 예시:
  /// - 보강 전: 문유란 월2교시 "1-3|국어", 김연주 월2교시 빈 셀
  /// - 보강 후: 문유란 월2교시 "1-3|국어" (파란색 테두리), 김연주 월2교시 "1-3|과목 미선택" (연한 파란색 배경)
  /// 
  /// 매개변수:
  /// - `timeSlots`: 전체 시간표 데이터
  /// - `sourceTeacher`: 보강할 셀의 교사명 (문유란)
  /// - `sourceDay`: 보강할 셀의 요일 (월)
  /// - `sourcePeriod`: 보강할 셀의 교시 (2)
  /// - `targetTeacher`: 보강할 교사명 (김연주)
  /// - `targetDay`: 보강할 교사의 요일 (월)
  /// - `targetPeriod`: 보강할 교사의 교시 (2)
  /// 
  /// 반환값:
  /// - `bool`: 보강교체 성공 여부
  bool performSupplementExchange(
    List<TimeSlot> timeSlots,
    String sourceTeacher,
    String sourceDay,
    int sourcePeriod,
    String targetTeacher,
    String targetDay,
    int targetPeriod,
  ) {
    try {
      AppLogger.exchangeInfo('보강교체 시작: $sourceTeacher($sourceDay$sourcePeriod교시) → $targetTeacher($targetDay$targetPeriod교시)');
      
      // 1. 보강 가능성 검증
      if (!_validateSupplementExchange(
        timeSlots, sourceTeacher, sourceDay, sourcePeriod, targetTeacher, targetDay, targetPeriod
      )) {
        AppLogger.exchangeDebug('보강교체 검증 실패');
        return false;
      }
      
      // 2. 보강할 소스 TimeSlot 찾기 (원본 수업이 있는 셀)
      TimeSlot? sourceSlot = _findTimeSlot(timeSlots, sourceTeacher, sourceDay, sourcePeriod);
      
      if (sourceSlot == null) {
        AppLogger.exchangeDebug('보강할 소스 TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 3. 보강 대상 TimeSlot 찾기 (빈 셀)
      TimeSlot? targetSlot = _findTimeSlot(timeSlots, targetTeacher, targetDay, targetPeriod);
            
      if (targetSlot == null) {
        AppLogger.exchangeDebug('보강할 대상 TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 4. 보강 수행 (기존 빈 TimeSlot에 내용 채우기 - B방식)
      // 핵심: targetSlot은 timeSlots 리스트에서 가져온 참조이므로,
      //       이를 수정하면 원본 timeSlots 리스트가 직접 변경됩니다.
      
      // 보강 방식: 빈 TimeSlot에 보강 수업 내용 채우기
      targetSlot.className = sourceSlot.className;        // 원본 셀의 학급 복사
      targetSlot.subject = "과목 미선택";                  // 과목은 "과목 미선택"으로 설정
      // teacher, dayOfWeek, period는 그대로 유지
      
      AppLogger.exchangeDebug('보강 완료 - 보강된 셀 상태:');
      AppLogger.exchangeDebug('  $targetTeacher $targetDay$targetPeriod교시: ${targetSlot.className}|${targetSlot.subject}');

      // 히스토리 관리는 ExchangeHistoryService에서 담당
      AppLogger.exchangeInfo('보강교체 완료: $sourceTeacher($sourceDay$sourcePeriod교시) → $targetTeacher($targetDay$targetPeriod교시) [보강 성공]');
      return true;
      
    } catch (e) {
      AppLogger.exchangeDebug('보강교체 중 오류 발생: $e');
      return false;
    }
  }

  /// 보강교체 가능성 검증
  /// 
  /// 검증 조건:
  /// 1. 보강할 셀에 수업이 있어야 함
  /// 2. 보강 대상 셀이 빈 셀이어야 함
  /// 3. 보강할 셀이 교체 가능한 상태여야 함
  bool _validateSupplementExchange(
    List<TimeSlot> timeSlots,
    String sourceTeacher,
    String sourceDay,
    int sourcePeriod,
    String targetTeacher,
    String targetDay,
    int targetPeriod,
  ) {
    // 1. 보강할 소스 TimeSlot 존재 확인
    TimeSlot? sourceSlot = _findTimeSlot(timeSlots, sourceTeacher, sourceDay, sourcePeriod);
    
    if (sourceSlot == null) {
      AppLogger.exchangeDebug('보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시 TimeSlot을 찾을 수 없습니다');
      return false;
    }
    
    // 2. 보강 대상 TimeSlot 존재 확인
    TimeSlot? targetSlot = _findTimeSlot(timeSlots, targetTeacher, targetDay, targetPeriod);
    
    if (targetSlot == null) {
      AppLogger.exchangeDebug('보강 실패: $targetTeacher의 $targetDay$targetPeriod교시 TimeSlot을 찾을 수 없습니다');
      return false;
    }
    
    // 3. 보강할 셀에 수업이 있는지 확인
    if (!sourceSlot.isNotEmpty) {
      AppLogger.exchangeDebug('보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시에 수업이 없습니다');
      return false;
    }
    
    // 4. 보강 대상 셀이 빈 셀인지 확인
    if (targetSlot.isNotEmpty) {
      AppLogger.exchangeDebug('보강 실패: $targetTeacher의 $targetDay$targetPeriod교시가 빈 셀이 아닙니다');
      return false;
    }
    
    // 5. 보강할 셀이 교체 가능한 상태인지 확인
    if (!sourceSlot.canExchange) {
      AppLogger.exchangeDebug('보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시 수업은 교체 불가능합니다 (${sourceSlot.exchangeReason})');
      return false;
    }
    
    AppLogger.exchangeDebug('보강교체 검증 성공');
    return true;
  }

  /// 보강교체 되돌리기
  /// 
  /// 매개변수:
  /// - `timeSlots`: 전체 시간표 데이터
  /// - `targetTeacher`: 보강된 교사명
  /// - `targetDay`: 보강된 교사의 요일
  /// - `targetPeriod`: 보강된 교사의 교시
  /// 
  /// 반환값:
  /// - `bool`: 되돌리기 성공 여부
  bool undoSupplementExchange(
    List<TimeSlot> timeSlots,
    String targetTeacher,
    String targetDay,
    int targetPeriod,
  ) {
    try {
      AppLogger.exchangeInfo('보강교체 되돌리기: $targetTeacher($targetDay$targetPeriod교시)');
      
      // 보강된 TimeSlot 찾기
      TimeSlot? targetSlot = _findTimeSlot(timeSlots, targetTeacher, targetDay, targetPeriod);
      
      if (targetSlot == null) {
        AppLogger.exchangeDebug('보강교체 되돌리기 실패: TimeSlot을 찾을 수 없습니다');
        return false;
      }
      
      // 보강된 셀을 다시 빈 상태로 복원
      targetSlot.className = null;
      targetSlot.subject = null;
      
      AppLogger.exchangeInfo('보강교체 되돌리기 완료: $targetTeacher($targetDay$targetPeriod교시) → 빈 셀');
      return true;
      
    } catch (e) {
      AppLogger.exchangeDebug('보강교체 되돌리기 중 오류 발생: $e');
      return false;
    }
  }

  /// 교체를 되돌리기 (Deprecated)
  /// ExchangeHistoryService.undoLastExchange()를 사용하세요.
  @Deprecated('ExchangeHistoryService.undoLastExchange()를 사용하세요.')
  bool undoExchange(List<TimeSlot> timeSlots) {
    AppLogger.exchangeDebug('undoExchange는 더 이상 사용되지 않습니다. ExchangeHistoryService를 사용하세요.');
    return false;
  }
  
  /// 1:1 교체 가능성 검증
  /// 
  /// 검증 조건:
  /// 1. 두 교사 모두 해당 시간에 수업이 있어야 함
  /// 2. 같은 학급을 가르치는 교사들끼리만 교체 가능
  /// 3. 교체 불가 충돌 검증
  bool _validateOneToOneExchange(
    List<TimeSlot> timeSlots,
    String teacher1,
    String day1,
    int period1,
    String teacher2,
    String day2,
    int period2,
  ) {
    // 1. 교체할 TimeSlot 존재 확인
    TimeSlot? slot1 = _findTimeSlot(timeSlots, teacher1, day1, period1);
    TimeSlot? slot2 = _findTimeSlot(timeSlots, teacher2, day2, period2);
    
    if (slot1 == null) {
      AppLogger.exchangeDebug('교체 실패: $teacher1의 $day1$period1교시 TimeSlot을 찾을 수 없습니다');
      return false;
    }
    
    if (slot2 == null) {
      AppLogger.exchangeDebug('교체 실패: $teacher2의 $day2$period2교시 TimeSlot을 찾을 수 없습니다');
      return false;
    }
    
    // 2. 수업이 있는지 확인
    if (!slot1.isNotEmpty) {
      AppLogger.exchangeDebug('교체 실패: $teacher1의 $day1$period1교시에 수업이 없습니다');
      return false;
    }
    
    if (!slot2.isNotEmpty) {
      AppLogger.exchangeDebug('교체 실패: $teacher2의 $day2$period2교시에 수업이 없습니다');
      return false;
    }
    
    // 3. 교체 가능한 상태인지 확인
    if (!slot1.canExchange) {
      AppLogger.exchangeDebug('교체 실패: $teacher1의 $day1$period1교시 수업은 교체 불가능합니다 (${slot1.exchangeReason})');
      return false;
    }
    
    if (!slot2.canExchange) {
      AppLogger.exchangeDebug('교체 실패: $teacher2의 $day2$period2교시 수업은 교체 불가능합니다 (${slot2.exchangeReason})');
      return false;
    }
    
    // 4. 같은 학급인지 확인
    if (slot1.className != slot2.className) {
      AppLogger.exchangeDebug('교체 실패: 다른 학급의 수업은 교체할 수 없습니다 - ${slot1.className} vs ${slot2.className}');
      return false;
    }
    
    // 5. 교체 불가 충돌 검증
    bool teacher1CanMoveToSlot2 = !_nonExchangeableManager.isNonExchangeableTimeSlot(
      teacher1, day2, period2);
    bool teacher2CanMoveToSlot1 = !_nonExchangeableManager.isNonExchangeableTimeSlot(
      teacher2, day1, period1);
    
    if (!teacher1CanMoveToSlot2) {
      AppLogger.exchangeDebug('교체 실패: $teacher1이 $day2$period2교시로 이동할 수 없습니다 (교체 불가 시간)');
      return false;
    }
    
    if (!teacher2CanMoveToSlot1) {
      AppLogger.exchangeDebug('교체 실패: $teacher2가 $day1$period1교시로 이동할 수 없습니다 (교체 불가 시간)');
      return false;
    }
    
    AppLogger.exchangeDebug('1:1 교체 검증 통과: $teacher1($day1$period1교시) ↔ $teacher2($day2$period2교시)');
    return true;
  }

  /// 순환 교체 실행
  /// 
  /// 매개변수:
  /// - `timeSlots`: 현재 시간표 데이터
  /// - `nodes`: 순환 교체에 참여하는 노드들 (순서대로)
  /// 
  /// 반환값:
  /// - `bool`: 교체 성공 여부
  bool performCircularExchange(
    List<TimeSlot> timeSlots,
    List<ExchangeNode> nodes,
  ) {
    try {
      if (nodes.length < 3) {
        AppLogger.exchangeDebug('순환 교체 실패: 최소 3개 노드가 필요합니다 (현재: ${nodes.length}개)');
        return false;
      }

      AppLogger.exchangeInfo('순환 교체 시작: ${nodes.length}개 노드');
      
      // 1. 교체 가능성 검증
      if (!_validateCircularExchange(timeSlots, nodes)) {
        AppLogger.exchangeDebug('순환 교체 검증 실패');
        return false;
      }

      AppLogger.exchangeDebug('[wg]순환 교체 노드: ${nodes.map((node) => node.displayText).join(' → ')}');

      // 3. 순환 교체 실행 (마지막 노드는 제외) - 각 노드가 다음 노드의 위치로 이동
      for (int i = 0; i < nodes.length - 1; i++) {
        final currentNode = nodes[i];
        final nextNode = nodes[i + 1];
        
        // 현재 노드의 원본 TimeSlot 찾기
        final currentSlot = _findTimeSlot(timeSlots, currentNode.teacherName, currentNode.day, currentNode.period);
        if (currentSlot == null) {
          AppLogger.exchangeDebug('순환 교체 실패: ${currentNode.teacherName}의 ${currentNode.day}${currentNode.period}교시 TimeSlot을 찾을 수 없습니다');
          return false;
        }
        
        // 현재 노드가 이동할 목적지 TimeSlot 찾기 (다음 노드의 위치에 있는 현재 노드의 TimeSlot)
        final targetSlot = _findTimeSlot(timeSlots, currentNode.teacherName, nextNode.day, nextNode.period);
        if (targetSlot == null) {
          AppLogger.exchangeDebug('순환 교체 실패: ${currentNode.teacherName}의 ${nextNode.day}${nextNode.period}교시 TimeSlot을 찾을 수 없습니다');
          return false;
        }
        
        // TimeSlot.moveTime() 방식으로 교체 수행
        bool moveSuccess = TimeSlot.moveTime(currentSlot, targetSlot);
        
        if (!moveSuccess) {
          AppLogger.exchangeDebug('순환 교체 실패: ${currentNode.teacherName} → ${nextNode.day}${nextNode.period}교시 이동 실패');
          return false;
        }
        
      }

      AppLogger.exchangeInfo('순환 교체 완료: ${nodes.length}개 노드 [교체 성공]');
      return true;
      
    } catch (e) {
      AppLogger.exchangeDebug('순환 교체 중 오류 발생: $e');
      return false;
    }
  }

  /// 순환 교체 검증 (단순화된 버전)
  bool _validateCircularExchange(List<TimeSlot> timeSlots, List<ExchangeNode> nodes) {
    try {
      // 모든 노드의 TimeSlot 존재 확인만 수행
      for (final node in nodes) {
        final slot = _findTimeSlot(timeSlots, node.teacherName, node.day, node.period);
        if (slot == null) {
          AppLogger.exchangeDebug('순환 교체 검증 실패: ${node.teacherName}의 ${node.day}${node.period}교시 TimeSlot을 찾을 수 없습니다');
          return false;
        }
      }

      AppLogger.exchangeDebug('순환 교체 검증 통과: ${nodes.length}개 노드');
      return true;
      
    } catch (e) {
      AppLogger.exchangeDebug('순환 교체 검증 중 오류 발생: $e');
      return false;
    }
  }
  
  /// 특정 교사, 요일, 교시의 TimeSlot 찾기
  TimeSlot? _findTimeSlot(
    List<TimeSlot> timeSlots,
    String teacher,
    String day,
    int period,
  ) {
    int dayNumber = DayUtils.getDayNumber(day);
    
    for (TimeSlot slot in timeSlots) {
      if (slot.teacher == teacher &&
          slot.dayOfWeek == dayNumber &&
          slot.period == period) {
        return slot;
      }
    }
    
    return null;
  }
  
  /// 교체 가능한 교사 정보 가져오기
  List<Map<String, dynamic>> getCurrentExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (selectedTeacher == null) return [];
    
    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = getSelectedClassName(timeSlots);
    if (selectedClassName == null) return [];
    
    List<Map<String, dynamic>> exchangeableTeachers = [];
    
    // 요일별로 빈시간 검사 (실제 데이터 기반)
    const List<String> days = ['월', '화', '수', '목', '금'];
    
    // 실제 데이터에서 교시 목록 추출
    Set<int> availablePeriods = {};
    for (var slot in timeSlots) {
      if (slot.period != null) {
        availablePeriods.add(slot.period!);
      }
    }
    
    for (String day in days) {
      List<String> emptySlots = [];
      
      // 해당 요일에 실제로 존재하는 교시만 검사
      for (int period in availablePeriods) {
        // 해당 교사의 해당 요일, 교시에 수업이 있는지 확인
        bool hasClass = timeSlots.any((slot) => 
          slot.teacher == selectedTeacher &&
          slot.dayOfWeek == DayUtils.getDayNumber(day) &&
          slot.period == period &&
          slot.isNotEmpty &&
          slot.canExchange // 교체 가능한 셀만 고려
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
        if (teacher.name == selectedTeacher) continue; // 자기 자신 제외
        
        // 해당 교사가 해당 시간에 같은 반을 가르치는지 확인
        bool hasSameClass = timeSlots.any((slot) => 
          slot.teacher == teacher.name &&
          slot.dayOfWeek == DayUtils.getDayNumber(day) &&
          slot.period == period &&
          slot.className == selectedClassName &&
          slot.isNotEmpty &&
          slot.canExchange // 교체 가능한 셀만 고려
        );
        
        if (hasSameClass) {
          // 해당 교사의 과목 정보도 함께 출력
          TimeSlot? teacherSlot;
          try {
            teacherSlot = timeSlots.firstWhere(
              (slot) => slot.teacher == teacher.name &&
                        slot.dayOfWeek == DayUtils.getDayNumber(day) &&
                        slot.period == period &&
                        slot.className == selectedClassName,
            );
          } catch (e) {
            teacherSlot = null;
          }
          
          String subject = teacherSlot?.subject ?? '과목 없음';
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
    if (selectedDay == null || selectedPeriod == null) return sameClassTeachers;
    
    List<String> actuallyAvailableTeachers = [];
    
    for (String teacherInfo in sameClassTeachers) {
      // 교사명 추출 (예: "박지혜(사회)" -> "박지혜" 또는 단순히 "박지혜")
      String teacherName = teacherInfo.contains('(') 
          ? teacherInfo.split('(')[0] 
          : teacherInfo;
      
      // 해당 교사가 선택된 시간에 수업이 있는지 확인
      bool hasClassAtSelectedTime = timeSlots.any((slot) => 
        slot.teacher == teacherName &&
        slot.dayOfWeek == DayUtils.getDayNumber(selectedDay!) &&
        slot.period == selectedPeriod &&
        slot.isNotEmpty &&
        slot.canExchange // 교체 가능한 셀만 고려
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
    if (selectedTeacher == null) return;
    
    // 현재 선택된 교사, 요일, 시간 정보를 첫 번째 줄에 출력
    AppLogger.teacherEmptySlotsInfo('선택된 셀: $selectedTeacher 교사, $selectedDay요일, $selectedPeriod교시');
    
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
  
  /// 타겟 셀 해제 (내부용)
  void _clearTargetCell() {
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
    
    AppLogger.exchangeDebug('타겟 셀 상태 업데이트: $teacher $day ${period != null ? '$period교시' : 'null'}');
  }
  
  /// 타겟 셀이 설정되어 있는지 확인
  bool hasTargetCell() {
    return _targetTeacher != null && _targetDay != null && _targetPeriod != null;
  }
  
  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    clearCellSelection();
    _clearTargetCell();
    _exchangeOptions.clear();
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
