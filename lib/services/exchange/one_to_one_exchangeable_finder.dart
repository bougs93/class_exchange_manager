import '../../models/teacher.dart';
import '../../models/time_slot.dart';
import '../../utils/day_utils.dart';
import '../../utils/exchange_algorithm.dart';
import '../../utils/logger.dart';
import '../../utils/non_exchangeable_manager.dart';
import '../base_exchange_service.dart';
import 'exchange_query_helper.dart';

/// 1:1 교체 가능 교사/시간 탐색 담당
///
/// `one_to_one_exchange_handler.dart`에서 더 분리된 부분으로, 선택된 셀에 대해
/// 교체 가능한 시간·교사를 찾는 두 갈래 로직을 담당한다:
/// - [generateExchangeOptions]: 시간표 그리드 교체가능 표시와 동일한 로직으로
///   [ExchangeOption] 목록을 생성 (교체 모드 하이라이트용)
/// - [getCurrentExchangeableTeachers]: UI 표시/로그용 교체 가능 교사 맵 목록 생성
class OneToOneExchangeableFinder {
  OneToOneExchangeableFinder(
    this._context,
    this._nonExchangeableManager,
    this._queryHelper,
  );

  final BaseExchangeService _context;
  final NonExchangeableManager _nonExchangeableManager;
  final ExchangeQueryHelper _queryHelper;

  /// 시간표 그리드 교체가능 표시 로직을 기반으로 교체 옵션 생성
  /// 이 메서드는 시간표 그리드에 표시되는 교체가능한 교사 정보와 동일한 로직을 사용
  List<ExchangeOption> generateExchangeOptions(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_context.selectedTeacher == null) return [];

    // 성능 최적화: 빈 셀과 교체불가능한 셀을 사전 필터링
    // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
    List<TimeSlot> validTimeSlots =
        timeSlots.where((slot) => slot.canExchange).toList();

    AppLogger.exchangeDebug(
      '1:1교체 최적화: 전체 ${timeSlots.length}개 → 유효한 ${validTimeSlots.length}개 TimeSlot',
    );

    // 교체 불가 관리자에 TimeSlot 설정
    _nonExchangeableManager.setTimeSlots(timeSlots);

    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = _context.getSelectedClassName(validTimeSlots);
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
        bool hasClass = validTimeSlots.any(
          (slot) =>
              slot.teacher == _context.selectedTeacher &&
              slot.dayOfWeek == DayUtils.getDayNumber(day) &&
              slot.period == period,
        );

        if (!hasClass) {
          // 빈시간에 같은 반을 가르치는 교사 찾기
          List<ExchangeOption> dayExchangeOptions =
              _findSameClassTeachersForExchangeOptions(
                day,
                period,
                selectedClassName,
                validTimeSlots,
                teachers,
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
      if (teacher.name == _context.selectedTeacher) continue; // 자기 자신 제외

      // 해당 교사가 해당 시간에 같은 반을 가르치는지 확인
      // canExchange는 이미 isNotEmpty를 포함하므로 중복 체크 제거
      bool hasSameClass = timeSlots.any(
        (slot) =>
            slot.teacher == teacher.name &&
            slot.dayOfWeek == DayUtils.getDayNumber(day) &&
            slot.period == period &&
            slot.className == selectedClassName &&
            slot.canExchange, // 교체 가능한 셀만 고려 (isNotEmpty 포함)
      );

      if (hasSameClass) {
        // 해당 교사의 과목 정보도 함께 가져오기
        // BaseExchangeService의 공통 메서드 사용 (중복 로직 제거)
        TimeSlot? teacherSlot = _context.findTimeSlot(
          teacher.name,
          day,
          period,
          timeSlots,
        );

        // className이 일치하는지 추가 확인
        if (teacherSlot != null && teacherSlot.className != selectedClassName) {
          teacherSlot = null;
        }

        // 교체 가능한 교사들이 선택된 시간에 실제로 빈 시간인지 검사
        bool isAvailableAtSelectedTime =
            teacherSlot?.isNotEmpty == true &&
            _checkTeacherAvailabilityAtSelectedTime(
              [teacher.name],
              day,
              period,
              timeSlots,
            ).isNotEmpty;

        // 교체 불가 충돌 검증 추가 (양방향 검증)
        bool noExchangeableConflict = _checkExchangeableConflict(
          teacher.name,
          _context.selectedTeacher!,
          day,
          period,
          _context.selectedDay!,
          _context.selectedPeriod!,
          timeSlots,
        );

        if (isAvailableAtSelectedTime &&
            teacherSlot?.isNotEmpty == true &&
            noExchangeableConflict) {
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
    List<TimeSlot> timeSlots,
  ) {
    // 1. 교사가 선택된 교사의 시간으로 이동 가능한지 검증
    bool teacherCanMoveToSelected =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          teacherName,
          selectedDay,
          selectedPeriod,
        );

    // 2. 선택된 교사가 교사의 원래 시간으로 이동 가능한지 검증
    bool selectedCanMoveToTeacher =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          selectedTeacher,
          teacherDay,
          teacherPeriod,
        );

    AppLogger.exchangeDebug(
      '1:1교체 양방향 검증: '
      '$teacherName→$selectedTeacher($selectedDay$selectedPeriod교시): $teacherCanMoveToSelected, '
      '$selectedTeacher→$teacherName($teacherDay$teacherPeriod교시): $selectedCanMoveToTeacher',
    );

    // 양방향 모두 가능해야 교체 성공
    return teacherCanMoveToSelected && selectedCanMoveToTeacher;
  }

  /// 교체 가능한 교사 정보 가져오기
  List<Map<String, dynamic>> getCurrentExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_context.selectedTeacher == null) return [];

    // 선택된 셀의 학급 정보 가져오기
    String? selectedClassName = _context.getSelectedClassName(timeSlots);
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
        bool hasClass = timeSlots.any(
          (slot) =>
              slot.teacher == _context.selectedTeacher &&
              slot.dayOfWeek == DayUtils.getDayNumber(day) &&
              slot.period == period &&
              slot.isNotEmpty &&
              slot.canExchange, // 교체 가능한 셀만 고려
        );

        if (!hasClass) {
          emptySlots.add('$period교시');
        }
      }

      if (emptySlots.isNotEmpty) {
        // 빈시간에 같은 반을 가르치는 교사 찾기
        List<Map<String, dynamic>> dayExchangeableTeachers =
            _findSameClassTeachers(
              day,
              emptySlots,
              selectedClassName,
              timeSlots,
              teachers,
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
        if (teacher.name == _context.selectedTeacher) continue; // 자기 자신 제외

        // 해당 교사가 해당 시간에 같은 반을 가르치는지 확인
        bool hasSameClass = timeSlots.any(
          (slot) =>
              slot.teacher == teacher.name &&
              slot.dayOfWeek == DayUtils.getDayNumber(day) &&
              slot.period == period &&
              slot.className == selectedClassName &&
              slot.isNotEmpty &&
              slot.canExchange, // 교체 가능한 셀만 고려
        );

        if (hasSameClass) {
          // 해당 교사의 과목 정보도 함께 출력
          // BaseExchangeService의 공통 메서드 사용 (중복 로직 제거)
          TimeSlot? teacherSlot = _context.findTimeSlot(
            teacher.name,
            day,
            period,
            timeSlots,
          );

          // className이 일치하는지 추가 확인
          if (teacherSlot != null &&
              teacherSlot.className != selectedClassName) {
            teacherSlot = null;
          }

          String subject = teacherSlot?.subject ?? '과목 없음';
          sameClassTeachers.add('${teacher.name}($subject)');
        }
      }

      if (sameClassTeachers.isNotEmpty) {
        // 교체 가능한 교사들이 선택된 시간에 실제로 빈 시간인지 검사
        List<String> actuallyAvailableTeachers =
            _checkTeacherAvailabilityAtSelectedTime(
              sameClassTeachers,
              day,
              period,
              timeSlots,
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
    if (_context.selectedDay == null || _context.selectedPeriod == null) {
      return sameClassTeachers;
    }

    List<String> actuallyAvailableTeachers = [];

    for (String teacherInfo in sameClassTeachers) {
      // 교사명 추출 (예: "박지혜(사회)" -> "박지혜" 또는 단순히 "박지혜")
      String teacherName =
          teacherInfo.contains('(') ? teacherInfo.split('(')[0] : teacherInfo;

      // 선택된 시간에 수업이 없는 교사만 실제 교체 가능한 교사로 추가
      if (!_queryHelper.isTeacherBusyAtSelectedTime(teacherName, timeSlots)) {
        actuallyAvailableTeachers.add(teacherInfo);
      }
    }

    return actuallyAvailableTeachers;
  }
}
