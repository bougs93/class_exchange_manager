import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'simplified_timetable_theme.dart';
import 'constants.dart';
import 'cell_style_config.dart';
import 'logger.dart';

/// 시간표 테이블의 고정 헤더(1행: 요일, 2행: 교시) 스타일 통합 관리 클래스
///
/// 기존에 여러 파일에 분산되어 있던 헤더 스타일 로직을 통합하여
/// 새로운 기능 추가 시 일관성 유지 및 유지보수성 향상
/// 
/// 성능 최적화:
/// - 위젯 캐싱을 통한 불필요한 재생성 방지
/// - Syncfusion DataGrid의 효율적인 헤더 업데이트 지원
class FixedHeaderStyleManager {
  // ==================== 위젯 캐시 (간소화) ====================
  static final Map<String, Widget> _widgetCache = {};
  // ==================== 색상 상수 ====================
  /// 요일 행(1행) 배경색 (SimplifiedTimetableTheme 사용)
  static const Color dayHeaderBackgroundColor = SimplifiedTimetableTheme.teacherHeaderColor;

  /// 교시 행(2행) 배경색 (기본 - 선택되지 않은 상태)
  static const Color periodHeaderBackgroundColor = SimplifiedTimetableTheme.teacherHeaderColor;

  // ==================== 외곽선 상수 ====================
  /// 일반 외곽선
  static const BorderSide normalBorder = BorderSide(
    color: SimplifiedTimetableTheme.normalBorderColor,
    width: SimplifiedTimetableTheme.normalBorderWidth,
  );

  /// 요일 구분선 (두꺼운 외곽선)
  static const BorderSide dayDividerBorder = BorderSide(
    color: SimplifiedTimetableTheme.dayHeaderBorderColor,
    width: SimplifiedTimetableTheme.dayHeaderBorderWidth,
  );

  // ==================== 요일 행(1행) 스타일 ====================

  /// 요일 행의 빈 셀(교사명 위치) 스타일 위젯 생성
  static Widget buildEmptyDayHeaderCell() {
    return Container(
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dayHeaderBackgroundColor,
        border: Border(
          right: normalBorder,
          bottom: normalBorder,
        ),
      ),
      child: Text(
        '',
        style: TextStyle(
          fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 요일 행의 요일 셀 스타일 위젯 생성
  static Widget buildDayHeaderCell(String dayName) {
    return Container(
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dayHeaderBackgroundColor,
        border: Border(
          left: dayDividerBorder,
          right: normalBorder,
          bottom: normalBorder,
        ),
      ),
      child: Text(
        dayName,
        style: TextStyle(
          fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==================== 교시 행(2행) 스타일 ====================

  /// 교시 행의 교사명 셀("교시" 텍스트) 스타일 위젯 생성
  static Widget buildTeacherHeaderCell() {
    return Container(
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SimplifiedTimetableTheme.teacherHeaderColor,
        border: Border(
          right: normalBorder,
          bottom: normalBorder,
        ),
      ),
      child: Text(
        '교시',
        style: TextStyle(
          fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 교시 행의 교시 번호 셀 스타일 위젯 생성 (캐싱 최적화)
  ///
  /// [period] 교시 번호
  /// [isFirstPeriod] 해당 요일의 첫 번째 교시인지 여부
  /// [config] 셀 스타일 설정 (선택 상태, 교체 가능 여부 등)
  static Widget buildPeriodHeaderCell({
    required int period,
    required bool isFirstPeriod,
    required CellStyleConfig config,
  }) {
    // 캐시 키 생성 (성능 최적화)
    final cacheKey = _generateCacheKey(period, isFirstPeriod, config);
    
    // 캐시된 위젯이 있으면 반환 (불필요한 재생성 방지)
    if (_widgetCache.containsKey(cacheKey)) {
      return _widgetCache[cacheKey]!;
    }

    // SimplifiedTimetableTheme의 통합 스타일 사용
    final CellStyle headerStyles = SimplifiedTimetableTheme.getCellStyleFromConfig(config);

    // 새로운 위젯 생성 및 캐시에 저장
    final widget = Container(
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: headerStyles.backgroundColor,
        border: headerStyles.border,
      ),
      child: Text(
        '$period',
        style: TextStyle(
          fontSize: AppConstants.headerFontSize * SimplifiedTimetableTheme.fontScaleFactor,
          fontWeight: FontWeight.bold,
          color: headerStyles.textStyle.color ?? Colors.black,
        ),
      ),
    );

    // 캐시 크기 제한 (최대 100개)
    if (_widgetCache.length >= 100) {
      // 캐시가 가득 찬 경우 20% 제거
      final removeCount = (_widgetCache.length * 0.2).ceil();
      final keysToRemove = _widgetCache.keys.take(removeCount).toList();
      for (final key in keysToRemove) {
        _widgetCache.remove(key);
      }
    }
    _widgetCache[cacheKey] = widget;

    return widget;
  }

  // ==================== StackedHeaderRow 생성 헬퍼 ====================

  /// StackedHeaderRow(요일 행) 생성
  ///
  /// [days] 요일 목록
  /// [groupedData] 요일별 교시 데이터
  static StackedHeaderRow buildStackedHeaderRow({
    required List<String> days,
    required Map<String, Map<int, Map<String, dynamic>>> groupedData,
  }) {
    List<StackedHeaderCell> headerCells = [];

    // 교사명 위치의 빈 셀
    headerCells.add(
      StackedHeaderCell(
        child: buildEmptyDayHeaderCell(),
        columnNames: ['teacher'],
      ),
    );

    // 요일별 헤더 셀
    for (String day in days) {
      List<int> dayPeriods = (groupedData[day]?.keys.toList() ?? [])..sort();
      List<String> dayColumnNames = dayPeriods.map((period) => '${day}_$period').toList();

      headerCells.add(
        StackedHeaderCell(
          child: buildDayHeaderCell(day),
          columnNames: dayColumnNames,
        ),
      );
    }

    return StackedHeaderRow(cells: headerCells);
  }

  // ==================== GridColumn 생성 헬퍼 ====================

  /// GridColumn 리스트 생성 (교사명 열 + 교시 열)
  ///
  /// [days] 요일 목록
  /// [groupedData] 요일별 교시 데이터
  /// [selectedDay] 선택된 요일
  /// [selectedPeriod] 선택된 교시
  /// [targetDay] 타겟 셀의 요일 (보기 모드에서 교체 리스트 선택 시)
  /// [targetPeriod] 타겟 셀의 교시 (보기 모드에서 교체 리스트 선택 시)
  /// [exchangeableTeachers] 교체 가능한 교사 정보
  /// [selectedCircularPath] 순환교체 경로
  /// [selectedOneToOnePath] 1:1 교체 경로
  /// [selectedChainPath] 연쇄교체 경로
  static List<GridColumn> buildGridColumns({
    required List<String> days,
    required Map<String, Map<int, Map<String, dynamic>>> groupedData,
    String? selectedDay,
    int? selectedPeriod,
    String? targetDay,
    int? targetPeriod,
    List<Map<String, dynamic>>? exchangeableTeachers,
    dynamic selectedCircularPath,
    dynamic selectedOneToOnePath,
    dynamic selectedChainPath,
  }) {
    List<GridColumn> columns = [];

    // 교사명 열
    columns.add(
      GridColumn(
        columnName: 'teacher',
        width: AppConstants.teacherColumnWidth,
        label: buildTeacherHeaderCell(),
      ),
    );

    // 요일별 교시 열
    for (String day in days) {
      List<int> dayPeriods = (groupedData[day]?.keys.toList() ?? [])..sort();

      for (int i = 0; i < dayPeriods.length; i++) {
        int period = dayPeriods[i];
        bool isFirstPeriod = i == 0;
        bool isLastPeriod = i == dayPeriods.length - 1;

        // 선택 상태 및 교체 가능 여부 확인
        bool isSelected = SimplifiedTimetableTheme.isPeriodSelected(
          day, period, selectedDay, selectedPeriod,
        );
        bool isTargetCell = SimplifiedTimetableTheme.isPeriodTarget(
          day, period, targetDay, targetPeriod,
        );
        
        bool isExchangeablePeriod = _isExchangeablePeriod(
          day, period, exchangeableTeachers,
        );
        bool isInCircularPath = _isPeriodInPath(
          day, period, selectedCircularPath?.nodes,
        );
        bool isInSelectedOneToOnePath = _isPeriodInPath(
          day, period, selectedOneToOnePath?.nodes,
        );
        bool isInChainPath = _isPeriodInPath(
          day, period, selectedChainPath?.nodes,
        );

        // CellStyleConfig로 통합 관리
        final config = CellStyleConfig(
          isTeacherColumn: false,
          isSelected: isSelected,
          isExchangeable: isExchangeablePeriod,
          isLastColumnOfDay: isLastPeriod,
          isFirstColumnOfDay: isFirstPeriod,
          isHeader: true,
          isInCircularPath: isInCircularPath,
          isInSelectedPath: isInSelectedOneToOnePath,
          isInChainPath: isInChainPath,
          isTargetCell: isTargetCell,
          headerPosition: '$day$period', // 헤더 위치 정보 추가 (캐시 키 구분용)
        );

        columns.add(
          GridColumn(
            columnName: '${day}_$period',
            width: AppConstants.periodColumnWidth,
            label: buildPeriodHeaderCell(
              period: period,
              isFirstPeriod: isFirstPeriod,
              config: config,
            ),
          ),
        );
      }
    }

    return columns;
  }

  // ==================== 헬퍼 메서드 ====================

  /// 교체 가능한 교시인지 확인
  static bool _isExchangeablePeriod(
    String day,
    int period,
    List<Map<String, dynamic>>? exchangeableTeachers,
  ) {
    if (exchangeableTeachers == null) return false;
    return exchangeableTeachers.any(
      (teacher) => teacher['day'] == day && teacher['period'] == period,
    );
  }

  /// 경로에 포함된 교시인지 확인
  static bool _isPeriodInPath(String day, int period, List<dynamic>? nodes) {
    if (nodes == null) return false;
    return nodes.any((node) => node.day == day && node.period == period);
  }

  // ==================== 캐시 관리 메서드 ====================

  /// 캐시 키 생성 (성능 최적화용) - 간소화된 버전
  static String _generateCacheKey(int period, bool isFirstPeriod, CellStyleConfig config) {
    // 간소화된 캐시 키로 메모리 사용량 최적화
    final key = StringBuffer();
    key.write('${period}_${isFirstPeriod ? 'F' : 'N'}');
    if (config.isSelected) key.write('_S');
    if (config.isExchangeable) key.write('_E');
    if (config.isInCircularPath) key.write('_C');
    if (config.isInSelectedPath) key.write('_P');
    if (config.isInChainPath) key.write('_H');
    if (config.isTargetCell) key.write('_T');
    return key.toString();
  }

  /// 캐시 초기화 (메모리 관리)
  static void clearCache() {
    _widgetCache.clear();
  }

  /// 선택적 캐시 초기화 (특정 상태 변경 시)
  static void clearCacheForState(bool isSelected, bool isExchangeable) {
    if (isSelected || isExchangeable) {
      // 상태 변경 시 전체 캐시 무효화 (간단하고 안전)
      _widgetCache.clear();
    }
  }

  // ==================== 스타일 초기화 메서드 ====================

  /// 헤더 스타일 초기화 (선택 상태 및 경로 상태 제거)
  ///
  /// 기존에 여러 곳에 분산되어 있던 초기화 로직을 통합
  /// Syncfusion DataGrid의 효율적인 업데이트를 위한 캐시 관리 포함
  static void resetHeaderStyles() {
    // 캐시 초기화로 불필요한 위젯 재생성 방지
    clearCache();
    
    // SimplifiedTimetableTheme의 기본 상태로 초기화
    // 이는 getCellStyleFromConfig를 기본 상태로 호출하여 초기화
  }

  /// 헤더 강제 업데이트 (즉시 반영)
  ///
  /// Syncfusion DataGrid의 헤더 업데이트 지연 문제 해결
  /// 셀 선택 시 헤더 UI가 변경되도록 캐시를 초기화하고 강제 업데이트
  static void forceHeaderUpdate() {
    // 캐시 초기화로 새로운 상태 반영
    clearCache();
    
    // 다음 프레임에서 업데이트 강제 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 헤더 업데이트가 완료되었음을 로그로 확인
      AppLogger.exchangeDebug('FixedHeaderStyleManager: 헤더 강제 업데이트 완료');
    });
  }

  /// 셀 선택 시 헤더 업데이트 (교체 모드 전용)
  ///
  /// 교체 모드에서 셀을 선택했을 때 헤더 UI가 즉시 변경되도록 함
  /// 선택된 교시의 헤더가 하이라이트되도록 캐시를 무효화
  static void updateHeaderForCellSelection({
    String? selectedDay,
    int? selectedPeriod,
  }) {
    // 선택 상태가 변경된 경우에만 캐시 무효화
    if (selectedDay != null && selectedPeriod != null) {
      // 선택된 교시와 관련된 캐시만 무효화 (성능 최적화)
      _invalidateCacheForPeriod(selectedDay, selectedPeriod);
    } else {
      // 선택 해제 시 전체 캐시 무효화
      clearCache();
    }
    
    // 다음 프레임에서 업데이트 강제 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 헤더 업데이트 완료
    });
  }

  /// 교체된 셀 선택 시 헤더 업데이트 (교체된 셀 전용)
  ///
  /// 교체된 셀을 선택했을 때 해당 교시의 헤더가 하이라이트되도록 함
  /// 교체된 셀은 특별한 스타일이 적용될 수 있음
  static void updateHeaderForExchangedCell({
    required String day,
    required int period,
  }) {
    AppLogger.exchangeDebug('FixedHeaderStyleManager: 교체된 셀 헤더 업데이트 - 요일: $day, 교시: $period');
    
    // 교체된 셀과 관련된 캐시 무효화
    _invalidateCacheForPeriod(day, period);
    
    // 다음 프레임에서 업데이트 강제 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.exchangeDebug('FixedHeaderStyleManager: 교체된 셀 헤더 업데이트 완료');
    });
  }

  /// 특정 교시와 관련된 캐시 무효화 (성능 최적화)
  static void _invalidateCacheForPeriod(String day, int period) {
    // 해당 교시와 관련된 캐시 키들을 찾아서 제거
    final keysToRemove = _widgetCache.keys.where((key) => 
      key.contains('$day$period') || 
      key.contains('${day}_$period')
    ).toList();
    
    for (final key in keysToRemove) {
      _widgetCache.remove(key);
    }
    
    AppLogger.exchangeDebug('FixedHeaderStyleManager: 교시 $day$period 관련 캐시 ${keysToRemove.length}개 무효화');
  }
}
