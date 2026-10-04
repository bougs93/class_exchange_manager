import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/exchange_algorithm.dart';
import '../utils/timetable_data_source.dart';
import 'base_exchange_service.dart';
import 'search/circular_search.dart';

/// 순환교체 서비스 클래스
/// 여러 교사 간의 순환 교체 비즈니스 로직을 담당
class CircularExchangeService extends BaseExchangeService with CircularSearch {
  // 싱글톤 인스턴스
  static final CircularExchangeService _instance =
      CircularExchangeService._internal();

  // 싱글톤 생성자
  factory CircularExchangeService() => _instance;

  // 내부 생성자
  CircularExchangeService._internal();

  // ==================== 상수 정의 ====================

  /// 기본 최대 단계 수 (순환 교체에서 최대 몇 단계까지 탐색할지)
  static const int defaultMaxSteps = 3;

  /// 기본 단계 검사 방식 (false: 해당 단계까지, true: 정확히 해당 단계만)
  static const bool defaultExactSteps = false;

  // ==================== 성능 최적화 ====================
  // 캐시 로직 제거됨 - 복잡도 감소를 위해 매번 새로 계산

  /// 순환교체 경로 디버그 콘솔 출력 여부
  static const bool enablePathDebugLogging = false;

  // ==================== 인스턴스 변수 ====================

  // 교체 가능한 시간 관련 변수들
  final List<ExchangeOption> _exchangeOptions = []; // 교체 가능한 시간 옵션들

  // Getters
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
    // 교사명 열 클릭은 교사 이름 선택 기능으로 처리
    if (details.column.columnName == 'teacher') {
      return CircularExchangeResult.noAction(); // 교사 이름 선택은 별도 처리
    }

    // 컬럼명에서 요일과 교시 추출 (예: "월_1", "화_2")
    List<String> parts = details.column.columnName.split('_');
    if (parts.length != 2) {
      return CircularExchangeResult.noAction();
    }

    String day = parts[0];
    int period = int.tryParse(parts[1]) ?? 0;

    // 교체할 셀의 교사명 찾기 (베이스 클래스 메서드 사용)
    String teacherName = getTeacherNameFromCell(details, dataSource);

    // 동일한 셀을 다시 클릭했는지 확인 (베이스 클래스 메서드 사용)
    if (isSameCell(teacherName, day, period)) {
      // 동일한 셀 클릭 시 교체 대상 해제
      clearCellSelection();
      return CircularExchangeResult.deselected();
    } else {
      // 새로운 교체 대상 선택
      selectCell(teacherName, day, period);
      return CircularExchangeResult.selected(teacherName, day, period);
    }
  }

  /// 모든 선택 상태 초기화
  void clearAllSelections() {
    clearCellSelection();
    _exchangeOptions.clear();
    // 캐시 로직 제거됨
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
  factory CircularExchangeResult.selected(
    String teacherName,
    String day,
    int period,
  ) {
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
