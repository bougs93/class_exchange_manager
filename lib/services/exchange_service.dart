import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../models/teacher.dart';
import '../models/exchange_node.dart';
import '../utils/exchange_algorithm.dart';
import '../utils/timetable_data_source.dart';
import '../utils/non_exchangeable_manager.dart';
import 'base_exchange_service.dart';
import 'exchange/circular_exchange_handler.dart';
import 'exchange/exchange_query_helper.dart';
import 'exchange/one_to_one_exchange_handler.dart';
import 'exchange/supplement_exchange_handler.dart';
import '../models/exchange_result.dart';

// ExchangeResult는 2026-10-03에 models로 옮겼다. 기존 import 경로
// (`exchange_service.dart`)를 쓰던 호출부가 깨지지 않도록 다시 export 한다.
export '../models/exchange_result.dart' show ExchangeResult;

/// 1:1 교체 서비스 클래스
/// 교체 관련 비즈니스 로직을 담당
///
/// 2026-10-03 리팩토링: 실제 로직은 `lib/services/exchange/` 하위의 핸들러
/// 클래스들(1:1/보강/순환/조회·상태)로 옮겼고, 이 클래스는 기존 호출부가
/// 그대로 동작하도록 각 핸들러에 위임하는 퍼사드(facade)로 남긴다.
class ExchangeService extends BaseExchangeService {
  // 싱글톤 인스턴스
  static final ExchangeService _instance = ExchangeService._internal();

  // 싱글톤 생성자
  factory ExchangeService() => _instance;

  // 내부 생성자
  ExchangeService._internal() {
    _queryHelper = ExchangeQueryHelper(this);
    _oneToOne = OneToOneExchangeHandler(
      this,
      _nonExchangeableManager,
      _queryHelper,
    );
    _supplement = SupplementExchangeHandler(
      this,
      _nonExchangeableManager,
      _queryHelper,
    );
    _circular = CircularExchangeHandler(this);
  }

  // 교체 불가 관리자
  final NonExchangeableManager _nonExchangeableManager =
      NonExchangeableManager();

  // 분리된 핸들러들 (생성자에서 초기화)
  late final ExchangeQueryHelper _queryHelper;
  late final OneToOneExchangeHandler _oneToOne;
  late final SupplementExchangeHandler _supplement;
  late final CircularExchangeHandler _circular;

  // Getters
  String? get targetTeacher => _queryHelper.targetTeacher;
  String? get targetDay => _queryHelper.targetDay;
  int? get targetPeriod => _queryHelper.targetPeriod;
  List<ExchangeOption> get exchangeOptions => _oneToOne.exchangeOptions;

  /// 1:1 교체 처리 시작
  /// 교체 모드에서 셀을 클릭했을 때 호출되는 메인 함수
  ExchangeResult startOneToOneExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
  ) => _oneToOne.startOneToOneExchange(details, dataSource);

  /// 교체 가능한 시간 업데이트
  /// 선택된 셀에 대해 교체 가능한 시간들을 탐색하고 반환
  List<ExchangeOption> updateExchangeableTimes(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) => _oneToOne.updateExchangeableTimes(timeSlots, teachers);

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
  ) => _oneToOne.performOneToOneExchange(
    timeSlots,
    teacher1,
    day1,
    period1,
    teacher2,
    day2,
    period2,
  );

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
  ) => _supplement.performSupplementExchange(
    timeSlots,
    sourceTeacher,
    sourceDay,
    sourcePeriod,
    targetTeacher,
    targetDay,
    targetPeriod,
  );

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
  ) => _supplement.undoSupplementExchange(
    timeSlots,
    targetTeacher,
    targetDay,
    targetPeriod,
  );

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
  ) => _circular.performCircularExchange(timeSlots, nodes);

  /// 교체 가능한 교사 정보 가져오기
  List<Map<String, dynamic>> getCurrentExchangeableTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers,
  ) => _oneToOne.getCurrentExchangeableTeachers(timeSlots, teachers);

  /// 보강용 교사 목록 (단일 진입점)
  ///
  /// [subjectFilter]가 있으면 해당 교과를 가르치는 교사만 포함합니다.
  /// 공강·교체불가·결강 교사 본인은 항상 제외합니다.
  List<Map<String, dynamic>> getSupplementTeachers(
    List<TimeSlot> timeSlots,
    List<Teacher> teachers, {
    String? subjectFilter,
  }) => _supplement.getSupplementTeachers(
    timeSlots,
    teachers,
    subjectFilter: subjectFilter,
  );

  /// 시간표 어디든 해당 교과를 가르치는지 확인
  bool teacherTeachesSubject(
    String teacherName,
    String subject,
    List<TimeSlot> timeSlots,
  ) => _queryHelper.teacherTeachesSubject(teacherName, subject, timeSlots);

  /// 교체 가능한 교사 정보 로그 출력
  void logExchangeableInfo(List<Map<String, dynamic>> exchangeableTeachers) =>
      _queryHelper.logExchangeableInfo(exchangeableTeachers);

  /// 타겟 셀 설정 (교체 대상의 같은 행 셀)
  /// 교체 대상이 월1교시라면, 선택된 셀의 같은 행의 월1교시를 타겟으로 설정
  void setTargetCell(
    String targetTeacher,
    String targetDay,
    int targetPeriod,
  ) => _queryHelper.setTargetCell(targetTeacher, targetDay, targetPeriod);

  /// 타겟 셀 상태만 업데이트 (UI 핸들러용)
  void updateTargetCellState(String? teacher, String? day, int? period) =>
      _queryHelper.updateTargetCellState(teacher, day, period);

  /// 타겟 셀이 설정되어 있는지 확인
  bool hasTargetCell() => _queryHelper.hasTargetCell();

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    clearCellSelection();
    _queryHelper.clearTargetCell();
    _oneToOne.clearExchangeOptions();
  }
}
