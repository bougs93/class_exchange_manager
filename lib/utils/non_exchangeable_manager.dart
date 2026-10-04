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

  /// `교사|요일번호|교시` → TimeSlot 색인
  ///
  /// 그리드 셀 하나를 그릴 때마다 `_timeSlots`를 선형 탐색하면
  /// (보이는 셀 수 × 전체 TimeSlot 수)만큼 비교가 일어나 웹에서 수 초가 걸린다.
  /// 시간표가 바뀔 때 한 번만 색인을 만들어 O(1) 조회로 바꾼다.
  final Map<String, TimeSlot> _slotIndex = {};

  /// TimeSlot 리스트 설정
  void setTimeSlots(List<TimeSlot> timeSlots) {
    _timeSlots = timeSlots;
    _rebuildIndex();
  }

  void _rebuildIndex() {
    _slotIndex.clear();
    for (final slot in _timeSlots) {
      final teacher = slot.teacher;
      final dayOfWeek = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || dayOfWeek == null || period == null) continue;
      // 중복 키는 기존 firstWhere와 동일하게 먼저 나온 것을 유지한다.
      _slotIndex.putIfAbsent('$teacher|$dayOfWeek|$period', () => slot);
    }
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
    return _slotIndex['$teacherName|$dayNumber|$period'];
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
    List<TimeSlot> teacherSlots =
        _timeSlots.where((slot) => slot.teacher == teacherName).toList();

    if (teacherSlots.isEmpty) {
      AppLogger.exchangeDebug('교사 "$teacherName"의 시간표가 없습니다.');
      return;
    }

    // 현재 상태 확인 (모두 교체불가인지)
    bool allNonExchangeable = teacherSlots.every(
      (slot) => !slot.isExchangeable && slot.exchangeReason == '교체불가',
    );

    // 토글 동작
    if (allNonExchangeable) {
      // 모두 교체불가 -> 모두 교체가능으로
      for (var slot in teacherSlots) {
        slot.isExchangeable = true;
        slot.exchangeReason = null;
      }
      AppLogger.exchangeDebug(
        '교사 "$teacherName"의 모든 시간을 교체 가능으로 설정 (${teacherSlots.length}개 TimeSlot)',
      );
    } else {
      // 일부 또는 전체가 교체가능 -> 모두 교체불가로
      int modifiedCount = 0;
      for (var slot in teacherSlots) {
        slot.isExchangeable = false;
        slot.exchangeReason = '교체불가';
        modifiedCount++;

        // 검증 로그 (처음 3개만)
        if (modifiedCount <= 3) {
          AppLogger.exchangeDebug(
            '  ✓ TimeSlot 설정: teacher=${slot.teacher}, dayOfWeek=${slot.dayOfWeek}, period=${slot.period}, isExchangeable=${slot.isExchangeable}, exchangeReason=${slot.exchangeReason}',
          );
        }
      }
      AppLogger.exchangeDebug(
        '교사 "$teacherName"의 모든 시간을 교체 불가능으로 설정 ($modifiedCount개 TimeSlot, isExchangeable=false 확인됨)',
      );
    }
  }

  /// 특정 셀을 교체불가로 설정 또는 해제 (토글 방식, 빈 셀 포함)
  void setCellAsNonExchangeable(String teacherName, String day, int period) {
    // 공통 헬퍼 메서드 사용 (중복 로직 제거)
    final existingTimeSlot = _findTimeSlot(teacherName, day, period);

    if (existingTimeSlot != null) {
      // 기존 TimeSlot이 있는 경우 토글 방식으로 처리
      if (!existingTimeSlot.isExchangeable &&
          existingTimeSlot.exchangeReason == '교체불가') {
        // 교체불가 상태인 경우 -> 교체 가능으로 되돌리기
        existingTimeSlot.isExchangeable = true;
        existingTimeSlot.exchangeReason = null;
        AppLogger.exchangeDebug(
          '교체불가 해제: $teacherName $day $period교시 (${existingTimeSlot.subject ?? "빈 셀"})',
        );
      } else {
        // 교체 가능 상태인 경우 -> 교체불가로 설정
        existingTimeSlot.isExchangeable = false;
        existingTimeSlot.exchangeReason = '교체불가';
        AppLogger.exchangeDebug(
          '교체불가 설정: $teacherName $day $period교시 (${existingTimeSlot.subject ?? "빈 셀"})',
        );
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
      _slotIndex['$teacherName|$dayOfWeek|$period'] = newTimeSlot;
      AppLogger.exchangeDebug(
        '새로운 TimeSlot 생성 (교체불가): $teacherName $day $period교시',
      );
    }
  }

  /// 그리드(복사본)에서 바뀐 교체불가 상태를 원본 시간표에 반영한다.
  ///
  /// 그리드는 원본의 복사본(교체 뷰 합성본 포함)을 들고 있어서, 교체불가를
  /// 토글해도 경로 탐색이 쓰는 원본(`resolvedTimetableProvider`의 입력)에는
  /// 반영되지 않았다 — 재시작 전까지 교체불가 칸이 탐색 후보로 계속 나왔다.
  ///
  /// [source] 중 [where]에 맞는 칸만 `isExchangeable`/`exchangeReason`을
  /// 같은 키(교사·요일·교시)의 [base] 칸에 복사한다. 과목·학급은 건드리지 않는다.
  /// [base]에 없는 칸이 교체불가면 빈 교체불가 TimeSlot을 추가한다
  /// (`start_screen.dart`의 시작 시 적용과 같은 규칙).
  static void syncToBase(
    List<TimeSlot> base,
    List<TimeSlot> source, {
    bool Function(TimeSlot slot)? where,
  }) {
    final baseIndex = <String, TimeSlot>{};
    for (final slot in base) {
      final teacher = slot.teacher;
      final day = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || day == null || period == null) continue;
      baseIndex.putIfAbsent('$teacher|$day|$period', () => slot);
    }

    for (final slot in source) {
      final teacher = slot.teacher;
      final day = slot.dayOfWeek;
      final period = slot.period;
      if (teacher == null || day == null || period == null) continue;
      if (where != null && !where(slot)) continue;

      final key = '$teacher|$day|$period';
      final isNonExchangeable =
          !slot.isExchangeable && slot.exchangeReason == '교체불가';
      final target = baseIndex[key];

      if (target != null) {
        if (isNonExchangeable) {
          target.isExchangeable = false;
          target.exchangeReason = '교체불가';
        } else if (!target.isExchangeable &&
            target.exchangeReason == '교체불가') {
          target.isExchangeable = true;
          target.exchangeReason = null;
        }
      } else if (isNonExchangeable) {
        final newSlot = TimeSlot(
          teacher: teacher,
          dayOfWeek: day,
          period: period,
          isExchangeable: false,
          exchangeReason: '교체불가',
        );
        base.add(newSlot);
        baseIndex[key] = newSlot;
      }
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
