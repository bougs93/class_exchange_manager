import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../models/exchange_result.dart';
import '../../models/teacher.dart';
import '../../models/time_slot.dart';
import '../../utils/exchange_algorithm.dart';
import '../../utils/logger.dart';
import '../../utils/non_exchangeable_manager.dart';
import '../../utils/timetable_data_source.dart';
import '../base_exchange_service.dart';
import 'exchange_query_helper.dart';
import 'one_to_one_exchangeable_finder.dart';

/// 1:1 교체 처리 담당
///
/// `exchange_service.dart`에서 분리된 부분으로, 다음을 담당한다:
/// - 교체 모드에서 셀 클릭 시작 처리 ([startOneToOneExchange])
/// - 교체 가능한 시간/교사 탐색 ([updateExchangeableTimes], [getCurrentExchangeableTeachers]) —
///   실제 탐색 로직은 [OneToOneExchangeableFinder]에 위임
/// - 실제 1:1 수업 교체 수행 및 검증 ([performOneToOneExchange])
class OneToOneExchangeHandler {
  OneToOneExchangeHandler(
    this._context,
    this._nonExchangeableManager,
    ExchangeQueryHelper queryHelper,
  ) {
    _finder = OneToOneExchangeableFinder(
      _context,
      _nonExchangeableManager,
      queryHelper,
    );
  }

  final BaseExchangeService _context;
  final NonExchangeableManager _nonExchangeableManager;
  late final OneToOneExchangeableFinder _finder;

  // 교체 가능한 시간 관련 변수들
  List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들

  List<ExchangeOption> get exchangeOptions => _exchangeOptions;

  /// 모든 교체 옵션 초기화 (선택 해제 시 사용)
  void clearExchangeOptions() => _exchangeOptions.clear();

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
    String teacherName = _context.getTeacherNameFromCell(details, dataSource);

    // 동일한 셀을 다시 클릭했는지 확인 (베이스 클래스 메서드 사용)
    if (_context.isSameCell(teacherName, day, period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      _context.clearCellSelection();
      return ExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      _context.selectCell(teacherName, day, period);
      return ExchangeResult.selected(teacherName, day, period);
    }
  }

  /// 교체 가능한 시간 업데이트
  /// 선택된 셀에 대해 교체 가능한 시간들을 탐색하고 반환
  List<ExchangeOption> updateExchangeableTimes(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) {
    if (_context.selectedTeacher == null ||
        _context.selectedDay == null ||
        _context.selectedPeriod == null) {
      _exchangeOptions = [];
      return _exchangeOptions;
    }

    // 시간표 그리드 교체가능 표시 로직을 기반으로 교체 옵션 생성
    List<ExchangeOption> options = _finder.generateExchangeOptions(
      timeSlots,
      teachers,
    );

    _exchangeOptions = options;
    return _exchangeOptions;
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
      AppLogger.exchangeInfo(
        '1:1 교체 시작: $teacher1($day1$period1교시) ↔ $teacher2($day2$period2교시)',
      );

      // 1. 교체 가능성 검증
      if (!_validateOneToOneExchange(
        timeSlots,
        teacher1,
        day1,
        period1,
        teacher2,
        day2,
        period2,
      )) {
        AppLogger.exchangeDebug('1:1 교체 검증 실패');
        return false;
      }

      // 2. 교체할 소스 TimeSlot 찾기 (원본 수업이 있는 셀)
      TimeSlot? slot1s = _context.findTimeSlot(
        teacher1,
        day1,
        period1,
        timeSlots,
      ); // 문유란의 월6교시 (원본)
      TimeSlot? slot2s = _context.findTimeSlot(
        teacher2,
        day2,
        period2,
        timeSlots,
      ); // 정영훈의 화3교시 (원본)

      if (slot1s == null || slot2s == null) {
        AppLogger.exchangeDebug('교체할 소스 TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 3. 교체 대상 TimeSlot 찾기 (서로 다른 교사의 목적지 시간대)
      TimeSlot? slot2t = _context.findTimeSlot(
        teacher2,
        day1,
        period1,
        timeSlots,
      ); // 정영훈의 월6교시 (목적지)
      TimeSlot? slot1t = _context.findTimeSlot(
        teacher1,
        day2,
        period2,
        timeSlots,
      ); // 문유란의 화3교시 (목적지)

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
      bool moveSuccess1 = TimeSlot.moveTime(
        slot1s,
        slot1t,
      ); // 문유란의 월6교시 → 문유란의 화3교시
      bool moveSuccess2 = TimeSlot.moveTime(
        slot2s,
        slot2t,
      ); // 정영훈의 화3교시 → 정영훈의 월6교시

      AppLogger.exchangeDebug(
        'TimeSlot 이동 결과: moveSuccess1=$moveSuccess1, moveSuccess2=$moveSuccess2',
      );

      if (!moveSuccess1 || !moveSuccess2) {
        AppLogger.exchangeDebug(
          'TimeSlot 이동 실패: moveSuccess1=$moveSuccess1, moveSuccess2=$moveSuccess2',
        );
        return false;
      }

      // 교체 후 결과 디버그 로깅 (간소화)
      AppLogger.exchangeDebug('교체 완료 - 교체된 셀 상태:');
      AppLogger.exchangeDebug(
        '  월6교시: ${slot2t.dayOfWeek}|${slot2t.period}|${slot2t.className}|${slot2t.teacher}|${slot2t.subject}',
      );
      AppLogger.exchangeDebug(
        '  화3교시: ${slot1t.dayOfWeek}|${slot1t.period}|${slot1t.className}|${slot1t.teacher}|${slot1t.subject}',
      );

      // 히스토리 관리는 ExchangeHistoryService에서 담당
      AppLogger.exchangeInfo(
        '1:1 교체 완료: $teacher1($day1$period1교시) ↔ $teacher2($day2$period2교시) [교체 성공]',
      );
      return true;
    } catch (e) {
      AppLogger.exchangeDebug('1:1 교체 중 오류 발생: $e');
      return false;
    }
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
    TimeSlot? slot1 = _context.findTimeSlot(teacher1, day1, period1, timeSlots);
    TimeSlot? slot2 = _context.findTimeSlot(teacher2, day2, period2, timeSlots);

    if (slot1 == null) {
      AppLogger.exchangeDebug(
        '교체 실패: $teacher1의 $day1$period1교시 TimeSlot을 찾을 수 없습니다',
      );
      return false;
    }

    if (slot2 == null) {
      AppLogger.exchangeDebug(
        '교체 실패: $teacher2의 $day2$period2교시 TimeSlot을 찾을 수 없습니다',
      );
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
      AppLogger.exchangeDebug(
        '교체 실패: $teacher1의 $day1$period1교시 수업은 교체 불가능합니다 (${slot1.exchangeReason})',
      );
      return false;
    }

    if (!slot2.canExchange) {
      AppLogger.exchangeDebug(
        '교체 실패: $teacher2의 $day2$period2교시 수업은 교체 불가능합니다 (${slot2.exchangeReason})',
      );
      return false;
    }

    // 4. 같은 학급인지 확인
    if (slot1.className != slot2.className) {
      AppLogger.exchangeDebug(
        '교체 실패: 다른 학급의 수업은 교체할 수 없습니다 - ${slot1.className} vs ${slot2.className}',
      );
      return false;
    }

    // 5. 교체 불가 충돌 검증
    bool teacher1CanMoveToSlot2 =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          teacher1,
          day2,
          period2,
        );
    bool teacher2CanMoveToSlot1 =
        !_nonExchangeableManager.isNonExchangeableTimeSlot(
          teacher2,
          day1,
          period1,
        );

    if (!teacher1CanMoveToSlot2) {
      AppLogger.exchangeDebug(
        '교체 실패: $teacher1이 $day2$period2교시로 이동할 수 없습니다 (교체 불가 시간)',
      );
      return false;
    }

    if (!teacher2CanMoveToSlot1) {
      AppLogger.exchangeDebug(
        '교체 실패: $teacher2가 $day1$period1교시로 이동할 수 없습니다 (교체 불가 시간)',
      );
      return false;
    }

    AppLogger.exchangeDebug(
      '1:1 교체 검증 통과: $teacher1($day1$period1교시) ↔ $teacher2($day2$period2교시)',
    );
    return true;
  }

  /// 교체 가능한 교사 정보 가져오기 (탐색 로직은 [OneToOneExchangeableFinder]에 위임)
  List<Map<String, dynamic>> getCurrentExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) => _finder.getCurrentExchangeableTeachers(timeSlots, teachers);
}
