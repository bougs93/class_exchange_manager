import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../utils/timetable_data_source.dart';
import '../../../utils/day_utils.dart';
import '../../../utils/logger.dart';

/// 시간표 그리드의 행·열 위치 계산기
///
/// 교사명 → 행 인덱스, (요일·교시) → 열 인덱스 변환을 담당한다.
/// 그리드 컬럼 구조(요일별 교시 수)를 분석해 인덱스를 산출하며,
/// 기본 계산이 실패하면 단계적으로 대안 계산을 시도한다.
///
/// 위젯 상태에 의존하지 않으므로(컬럼·데이터소스 스냅샷만 사용)
/// 필요한 시점에 생성해 사용한다.
class GridColumnLocator {
  final List<GridColumn> columns;
  final TimetableDataSource? dataSource;

  const GridColumnLocator(this.columns, this.dataSource);

  /// 교사명이 포함된 행 인덱스 (없으면 -1)
  int findTeacherRowIndex(String teacherName) {
    final source = dataSource;
    if (source == null) return -1;

    final target = teacherName.trim();
    if (target.isEmpty) return -1;

    for (int i = 0; i < source.rows.length; i++) {
      final cells = source.rows[i].getCells();
      if (cells.isEmpty) continue;

      final cellValue = cells.first.value?.toString() ?? '';
      if (_isTeacherNameMatch(cellValue, target)) {
        return i;
      }
    }
    return -1;
  }

  /// 홈 기본 교사명과 그리드 교사명 비교 (괄호 번호 등 형식 차이 허용)
  bool _isTeacherNameMatch(String cellValue, String targetName) {
    final cell = cellValue.trim();
    final target = targetName.trim();
    if (cell.isEmpty || target.isEmpty) return false;
    if (cell == target) return true;
    if (cell.contains(target) || target.contains(cell)) return true;

    final cellBase = cell.split('(').first.trim();
    final targetBase = target.split('(').first.trim();
    return cellBase.isNotEmpty && cellBase == targetBase;
  }

  /// 요일·교시로 열 인덱스 계산
  ///
  /// [dayOfWeek] 요일 (1-5), [period] 교시 (1-8)
  /// Returns 열 인덱스 (0부터 시작, 실패 시 -1)
  int calculateColumnIndex(int dayOfWeek, int period) {
    try {
      AppLogger.exchangeDebug('🔍 [열 계산] 시작: 요일=$dayOfWeek, 교시=$period');
      AppLogger.exchangeDebug('🔍 [열 계산] 전체 열 개수: ${columns.length}');

      // 첫 번째 열이 교사명 열이면 그 다음부터 데이터 열이 시작된다
      final startColumnIndex = _hasTeacherColumn() ? 1 : 0;

      final actualDataColumns = columns.length - startColumnIndex;
      final periodsPerDay = actualDataColumns ~/ 5; // 5요일로 나누기
      AppLogger.exchangeDebug(
        '🔍 [열 계산] 데이터 열=$actualDataColumns, 요일당 교시=$periodsPerDay',
      );

      int columnIndex;
      if (periodsPerDay > 0) {
        // 일반적인 경우: 요일별로 일정한 교시 수
        columnIndex =
            startColumnIndex + (dayOfWeek - 1) * periodsPerDay + (period - 1);
      } else {
        // 특수한 경우: 실제 열 구조를 분석
        AppLogger.exchangeDebug('🔍 [열 계산] 특수 구조 감지 - 실제 열 분석 시작');
        columnIndex = _analyzeActualColumnStructure(
          dayOfWeek,
          period,
          startColumnIndex,
        );
      }

      // 범위 초과 시 대안 계산 시도
      if (columnIndex < 0 || columnIndex >= columns.length) {
        AppLogger.exchangeDebug('🔄 [열 계산] 범위 초과($columnIndex) - 대안 계산 시도');
        columnIndex = _tryAlternativeColumnCalculation(
          dayOfWeek,
          period,
          startColumnIndex,
          columns.length,
        );
        if (columnIndex == -1) {
          AppLogger.exchangeDebug('❌ [열 계산] 모든 계산 방법 실패');
          return -1;
        }
      }

      AppLogger.exchangeDebug('✅ [열 계산] 성공: $columnIndex');
      return columnIndex;
    } catch (e) {
      AppLogger.exchangeDebug('❌ [열 계산] 오류: $e');
      return -1;
    }
  }

  /// 첫 번째 열이 교사명 열인지 여부
  bool _hasTeacherColumn() {
    if (columns.isEmpty) return false;
    final name = columns.first.columnName;
    return name.contains('교사') ||
        name.contains('선생님') ||
        name.toLowerCase().contains('teacher');
  }

  /// 실제 열 구조를 분석하여 정확한 열 인덱스 계산
  int _analyzeActualColumnStructure(
    int dayOfWeek,
    int period,
    int startColumnIndex,
  ) {
    try {
      // 요일별로 열 인덱스를 그룹화
      final Map<String, List<int>> dayGroups = {};
      for (int i = startColumnIndex; i < columns.length; i++) {
        final dayName = _extractDayFromColumnName(columns[i].columnName);
        if (dayName != null) {
          dayGroups.putIfAbsent(dayName, () => []).add(i);
        }
      }
      AppLogger.exchangeDebug('🔍 [구조 분석] 요일별 그룹: $dayGroups');

      final dayColumns = dayGroups[DayUtils.getDayName(dayOfWeek)] ?? [];
      if (dayColumns.isNotEmpty && period <= dayColumns.length) {
        return dayColumns[period - 1];
      }

      AppLogger.exchangeDebug('❌ [구조 분석] 해당 요일/교시를 찾을 수 없음');
      return -1;
    } catch (e) {
      AppLogger.exchangeDebug('❌ [구조 분석] 오류: $e');
      return -1;
    }
  }

  /// 열 이름에서 요일 추출 (없으면 null)
  String? _extractDayFromColumnName(String columnName) {
    for (final day in const ['월', '화', '수', '목', '금']) {
      if (columnName.contains(day)) return day;
    }
    return null;
  }

  /// 기본 계산이 실패했을 때 시도하는 대안 계산
  int _tryAlternativeColumnCalculation(
    int dayOfWeek,
    int period,
    int startColumnIndex,
    int totalColumns,
  ) {
    try {
      // 방법 1: 단순 선형 계산 (요일별 8교시 가정)
      final linearIndex = startColumnIndex + (dayOfWeek - 1) * 8 + (period - 1);
      if (linearIndex < totalColumns) {
        AppLogger.exchangeDebug('✅ [대안 계산] 선형 계산 성공: $linearIndex');
        return linearIndex;
      }

      // 방법 2: 교시 중심 계산 (요일별로 교시가 연속 배치)
      final periodBasedIndex =
          startColumnIndex + (period - 1) * 5 + (dayOfWeek - 1);
      if (periodBasedIndex < totalColumns) {
        AppLogger.exchangeDebug('✅ [대안 계산] 교시 중심 계산 성공: $periodBasedIndex');
        return periodBasedIndex;
      }

      // 방법 3: 최소한의 안전한 인덱스 반환
      final safeIndex = (startColumnIndex + (dayOfWeek - 1) * 6 + (period - 1))
          .clamp(startColumnIndex, totalColumns - 1);
      AppLogger.exchangeDebug('⚠️ [대안 계산] 안전한 인덱스 사용: $safeIndex');
      return safeIndex;
    } catch (e) {
      AppLogger.exchangeDebug('❌ [대안 계산] 오류: $e');
      return -1;
    }
  }
}
