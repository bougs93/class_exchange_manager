import '../../models/teacher.dart';
import '../../models/time_slot.dart';
import '../../utils/logger.dart';
import '../../utils/non_exchangeable_manager.dart';
import '../base_exchange_service.dart';
import 'exchange_query_helper.dart';

/// 보강(결강 대체) 처리 담당
///
/// `exchange_service.dart`에서 분리된 부분으로, 다음을 담당한다:
/// - 보강 가능한 교사 목록 조회 ([getSupplementTeachers])
/// - 보강 실행 및 되돌리기 ([performSupplementExchange], [undoSupplementExchange])
class SupplementExchangeHandler {
  SupplementExchangeHandler(
    this._context,
    this._nonExchangeableManager,
    this._queryHelper,
  );

  final BaseExchangeService _context;
  final NonExchangeableManager _nonExchangeableManager;
  final ExchangeQueryHelper _queryHelper;

  /// 보강 실행
  ///
  /// 보강 예시:
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
  /// - `bool`: 보강 성공 여부
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
      // 다른 경로와 다른 방식 : 타켓(2번째 클릭) -> 소스(1번째 클릭) : [주의]소스,타켓 색상 유지를 위해서 그대로 사용
      AppLogger.exchangeInfo(
        '보강 시작: $targetTeacher($targetDay$targetPeriod교시) → $sourceTeacher($sourceDay$sourcePeriod교시)',
      );

      // 1. 보강 가능성 검증
      if (!_validateSupplementExchange(
        timeSlots,
        sourceTeacher,
        sourceDay,
        sourcePeriod,
        targetTeacher,
        targetDay,
        targetPeriod,
      )) {
        AppLogger.exchangeDebug('보강 검증 실패');
        return false;
      }

      // 2. 보강할 소스 TimeSlot 찾기 (원본 수업이 있는 셀)
      TimeSlot? sourceSlot = _context.findTimeSlot(
        sourceTeacher,
        sourceDay,
        sourcePeriod,
        timeSlots,
      );

      if (sourceSlot == null) {
        AppLogger.exchangeDebug('보강할 소스 TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 3. 보강 대상 TimeSlot 찾기 (빈 셀)
      TimeSlot? targetSlot = _context.findTimeSlot(
        targetTeacher,
        targetDay,
        targetPeriod,
        timeSlots,
      );

      if (targetSlot == null) {
        AppLogger.exchangeDebug('보강할 대상 TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 4. 보강 수행 (기존 빈 TimeSlot에 내용 채우기 - B방식)
      // 핵심: targetSlot은 timeSlots 리스트에서 가져온 참조이므로,
      //       이를 수정하면 원본 timeSlots 리스트가 직접 변경됩니다.

      // 보강 방식: 빈 TimeSlot에 보강 수업 내용 채우기
      bool moveSuccess = TimeSlot.moveTime(sourceSlot, targetSlot);

      if (!moveSuccess) {
        AppLogger.exchangeDebug('보강 실패: moveSuccess=$moveSuccess');
        return false;
      }

      AppLogger.exchangeDebug('보강 완료 - 보강된 셀 상태:');
      AppLogger.exchangeDebug(
        '  $targetTeacher $targetDay$targetPeriod교시: ${targetSlot.className}|${targetSlot.subject}',
      );

      // 히스토리 관리는 ExchangeHistoryService에서 담당
      //     다른 경로와 다른 방식 : 타켓(2번째 클릭) -> 소스(1번째 클릭) : [주의]소스,타켓 색상 유지를 위해서 그대로 사용
      AppLogger.exchangeInfo(
        '보강 완료: $targetTeacher($targetDay$targetPeriod교시) → $sourceTeacher($sourceDay$sourcePeriod교시) [보강 성공]',
      );
      return true;
    } catch (e) {
      AppLogger.exchangeDebug('보강 중 오류 발생: $e');
      return false;
    }
  }

  /// 보강 가능성 검증
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
    TimeSlot? sourceSlot = _context.findTimeSlot(
      sourceTeacher,
      sourceDay,
      sourcePeriod,
      timeSlots,
    );

    if (sourceSlot == null) {
      AppLogger.exchangeDebug(
        '보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시 TimeSlot을 찾을 수 없습니다',
      );
      return false;
    }

    // 2. 보강 대상 TimeSlot 존재 확인
    TimeSlot? targetSlot = _context.findTimeSlot(
      targetTeacher,
      targetDay,
      targetPeriod,
      timeSlots,
    );

    if (targetSlot == null) {
      AppLogger.exchangeDebug(
        '보강 실패: $targetTeacher의 $targetDay$targetPeriod교시 TimeSlot을 찾을 수 없습니다',
      );
      return false;
    }

    // 3. 보강할 셀에 수업이 있는지 확인
    if (!sourceSlot.isNotEmpty) {
      AppLogger.exchangeDebug(
        '보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시에 수업이 없습니다',
      );
      return false;
    }

    // 4. 보강 대상 셀이 빈 셀인지 확인
    if (targetSlot.isNotEmpty) {
      AppLogger.exchangeDebug(
        '보강 실패: $targetTeacher의 $targetDay$targetPeriod교시가 빈 셀이 아닙니다',
      );
      return false;
    }

    // 5. 보강할 셀이 교체 가능한 상태인지 확인
    if (!sourceSlot.canExchange) {
      AppLogger.exchangeDebug(
        '보강 실패: $sourceTeacher의 $sourceDay$sourcePeriod교시 수업은 교체 불가능합니다 (${sourceSlot.exchangeReason})',
      );
      return false;
    }

    // 6. 보강 대상 셀이 교체 불가로 설정되어 있지 않은지 확인
    _nonExchangeableManager.setTimeSlots(timeSlots);
    if (_nonExchangeableManager.isNonExchangeableTimeSlot(
      targetTeacher,
      targetDay,
      targetPeriod,
    )) {
      AppLogger.exchangeDebug(
        '보강 실패: $targetTeacher의 $targetDay$targetPeriod교시는 교체 불가능합니다',
      );
      return false;
    }

    AppLogger.exchangeDebug('보강 검증 성공');
    return true;
  }

  /// 보강 되돌리기
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
      AppLogger.exchangeInfo(
        '보강 되돌리기: $targetTeacher($targetDay$targetPeriod교시)',
      );

      // 보강된 TimeSlot 찾기
      TimeSlot? targetSlot = _context.findTimeSlot(
        targetTeacher,
        targetDay,
        targetPeriod,
        timeSlots,
      );

      if (targetSlot == null) {
        AppLogger.exchangeDebug('보강 되돌리기 실패: TimeSlot을 찾을 수 없습니다');
        return false;
      }

      // 보강된 셀을 다시 빈 상태로 복원
      targetSlot.className = null;
      targetSlot.subject = null;

      AppLogger.exchangeInfo(
        '보강 되돌리기 완료: $targetTeacher($targetDay$targetPeriod교시) → 빈 셀',
      );
      return true;
    } catch (e) {
      AppLogger.exchangeDebug('보강 되돌리기 중 오류 발생: $e');
      return false;
    }
  }

  /// 보강용 교사 목록 (단일 진입점)
  ///
  /// [subjectFilter]가 있으면 해당 교과를 가르치는 교사만 포함합니다.
  /// 공강·교체불가·결강 교사 본인은 항상 제외합니다.
  List<Map<String, dynamic>> getSupplementTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers, {
    String? subjectFilter,
  }) {
    if (_context.selectedTeacher == null ||
        _context.selectedDay == null ||
        _context.selectedPeriod == null) {
      return [];
    }

    _nonExchangeableManager.setTimeSlots(timeSlots);

    final trimmedSubject = subjectFilter?.trim();
    final supplementTeachers = <Map<String, dynamic>>[];

    for (final teacher in teachers) {
      if (!_isTeacherAvailableForSupplement(teacher.name, timeSlots)) {
        continue;
      }

      if (trimmedSubject != null &&
          trimmedSubject.isNotEmpty &&
          !_queryHelper.teacherTeachesSubject(
            teacher.name,
            trimmedSubject,
            timeSlots,
          )) {
        continue;
      }

      supplementTeachers.add({
        'teacherName': teacher.name,
        'day': _context.selectedDay!,
        'period': _context.selectedPeriod!,
        'subject': _queryHelper.getTeacherDisplaySubject(
          teacher.name,
          timeSlots,
        ),
      });
    }

    final filterLabel =
        trimmedSubject == null || trimmedSubject.isEmpty
            ? '전체'
            : trimmedSubject;
    AppLogger.exchangeDebug(
      '보강 가능한 교사 수 ($filterLabel): ${supplementTeachers.length}명',
    );
    return supplementTeachers;
  }

  /// 보강 대상으로 선택 가능한 교사인지 확인
  ///
  /// - 결강 교사 본인 제외
  /// - 해당 교시 수업 중이면 제외
  /// - 해당 교시가 교체불가로 설정되어 있으면 제외
  bool _isTeacherAvailableForSupplement(
    String teacherName,
    List<TimeSlot> timeSlots,
  ) {
    if (_context.selectedTeacher == null ||
        _context.selectedDay == null ||
        _context.selectedPeriod == null) {
      return false;
    }

    if (teacherName == _context.selectedTeacher) {
      return false;
    }

    if (_queryHelper.isTeacherBusyAtSelectedTime(teacherName, timeSlots)) {
      return false;
    }

    return !_nonExchangeableManager.isNonExchangeableTimeSlot(
      teacherName,
      _context.selectedDay!,
      _context.selectedPeriod!,
    );
  }
}
