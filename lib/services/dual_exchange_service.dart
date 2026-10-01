import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/time_slot.dart';
import '../utils/timetable_data_source.dart';
import '../utils/logger.dart';
import 'base_exchange_service.dart';
import 'search/dual_search.dart';

/// 2중교체 서비스 클래스
///
/// 2중교체는 결강한 수업(A)을 다른 교사(B)가 대체하려고 할 때,
/// A 교사가 B 시간에 다른 수업이 있어 직접 교체가 불가능한 경우,
/// A 교사의 해당 시간 수업을 먼저 다른 교사와 교체하여 빈 시간을 만든 후
/// 최종 교체를 완성하는 방식입니다.
class DualExchangeService extends BaseExchangeService with DualSearch {
  // 싱글톤 인스턴스
  static final DualExchangeService _instance = DualExchangeService._internal();

  // 싱글톤 생성자
  factory DualExchangeService() => _instance;

  // 내부 생성자
  DualExchangeService._internal();

  // ==================== 상수 정의 ====================

  /// 2중교체 경로 디버그 콘솔 출력 여부
  static const bool enablePathDebugLogging = false;

  // ==================== 인스턴스 변수 ====================

  /// 2중교체 모드에서 셀 탭 처리
  ///
  /// 매개변수:
  /// - `details`: 셀 탭 상세 정보
  /// - `dataSource`: 데이터 소스
  ///
  /// 반환값:
  /// - `DualExchangeResult`: 처리 결과
  DualExchangeResult startDualExchange(
    DataGridCellTapDetails details,
    TimetableDataSource dataSource,
    List<TimeSlot> timeSlots,
  ) {
    // 교사명 열 클릭은 교사 이름 선택 기능으로 처리
    if (details.column.columnName == 'teacher') {
      return DualExchangeResult.noAction(); // 교사 이름 선택은 별도 처리
    }

    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      return DualExchangeResult.noAction();
    }

    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;

    // 교체할 셀의 교사명 찾기 (베이스 클래스 메서드 사용)
    String teacherName = getTeacherNameFromCell(details, dataSource);

    // 해당 시간의 학급 정보 찾기 (베이스 클래스 메서드 사용)
    String className = getClassNameFromTimeSlot(
      teacherName,
      day,
      period,
      timeSlots,
    );

    // 동일한 셀을 다시 클릭했는지 확인 (베이스 클래스 메서드 사용)
    if (isSameCell(teacherName, day, period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      clearAllSelections();
      return DualExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      selectCell(teacherName, day, period, className: className);

      AppLogger.exchangeInfo(
        '2중교체: A 위치 선택 - $teacherName $day $period교시 $className',
      );

      return DualExchangeResult.selected(teacherName, day, period);
    }
  }
}

/// 2중교체 처리 결과를 나타내는 클래스
class DualExchangeResult {
  final bool isSelected; // 교체 대상이 선택됨
  final bool isDeselected; // 교체 대상이 해제됨
  final bool isNoAction; // 아무 동작하지 않음
  final String? teacherName; // 교사명
  final String? day; // 요일
  final int? period; // 교시

  DualExchangeResult._({
    required this.isSelected,
    required this.isDeselected,
    required this.isNoAction,
    this.teacherName,
    this.day,
    this.period,
  });

  /// 교체 대상이 선택됨
  factory DualExchangeResult.selected(
    String teacherName,
    String day,
    int period,
  ) {
    return DualExchangeResult._(
      isSelected: true,
      isDeselected: false,
      isNoAction: false,
      teacherName: teacherName,
      day: day,
      period: period,
    );
  }

  /// 교체 대상이 해제됨
  factory DualExchangeResult.deselected() {
    return DualExchangeResult._(
      isSelected: false,
      isDeselected: true,
      isNoAction: false,
    );
  }

  /// 아무 동작하지 않음
  factory DualExchangeResult.noAction() {
    return DualExchangeResult._(
      isSelected: false,
      isDeselected: false,
      isNoAction: true,
    );
  }
}
