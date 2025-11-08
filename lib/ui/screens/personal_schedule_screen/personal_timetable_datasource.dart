import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../models/time_slot.dart';
import '../../../utils/personal_exchange_info_extractor.dart';
import '../../../utils/logger.dart';
import '../../../config/debug_config.dart';
import '../../widgets/simplified_timetable_cell.dart';

/// 개인 시간표용 DataSource
///
/// 교시가 행이고 요일이 열인 구조를 위한 DataSource
class PersonalTimetableDataSource extends DataGridSource {
  PersonalTimetableDataSource({
    required List<DataGridRow> rows,
    List<ExchangeCellInfo>? exchangeInfoList,
    bool isExchangeViewEnabled = false,
  })  : _rows = rows,
        _exchangeInfoList = exchangeInfoList ?? [],
        _isExchangeViewEnabled = isExchangeViewEnabled;

  List<DataGridRow> _rows;
  List<ExchangeCellInfo> _exchangeInfoList;
  bool _isExchangeViewEnabled;

  void updateRows(
    List<DataGridRow> newRows, {
    List<ExchangeCellInfo>? exchangeInfoList,
    bool? isExchangeViewEnabled,
  }) {
    _rows = newRows;
    if (exchangeInfoList != null) {
      _exchangeInfoList = exchangeInfoList;
    }
    if (isExchangeViewEnabled != null) {
      _isExchangeViewEnabled = isExchangeViewEnabled;
    }
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().asMap().entries.map<Widget>((entry) {
        final dataGridCell = entry.value;
        final isPeriodColumn = dataGridCell.columnName == 'period';

        // 교시 헤더 열인 경우
        if (isPeriodColumn) {
          return SimplifiedTimetableCell(
            content: dataGridCell.value.toString(),
            isTeacherColumn: true,
            isSelected: false,
            isExchangeable: false,
            isLastColumnOfDay: false,
            isFirstColumnOfDay: false,
            isHeader: true,
          );
        }

        // 시간표 셀
        final timeSlot = dataGridCell.value as TimeSlot?;
        final columnName = dataGridCell.columnName;

        // columnName 파싱: "월_5_2025.11.10" 형식
        final columnNameParts = columnName.split('_');
        if (columnNameParts.length < 3) {
          // 형식이 맞지 않으면 기본 처리 (교시 헤더 열인 경우)
          if (columnName == 'period') {
            // 교시 헤더는 이미 위에서 처리됨
          } else {
            // 날짜가 없는 구형식인 경우 (조건부 로그)
            if (DebugConfig.enableCellThemeDebugLogs) {
              AppLogger.info('[셀 파싱] 날짜 없는 형식: $columnName');
            }
          }
          final content = timeSlot?.displayText ?? '';
          return SimplifiedTimetableCell(
            content: content,
            isTeacherColumn: false,
            isSelected: false,
            isExchangeable: false,
            isLastColumnOfDay: false,
            isFirstColumnOfDay: false,
            isHeader: false,
          );
        }

        final day = columnNameParts[0];
        final period = int.tryParse(columnNameParts[1]) ?? 0;
        // 날짜 부분: "월_5_2025.11.10" 형식에서 세 번째 요소가 날짜 (YYYY.MM.DD)
        final date = columnNameParts.length >= 3 ? columnNameParts[2] : '';

        // 교체 정보와 매칭하여 테마 결정
        bool isExchangedSourceCell = false;
        bool isExchangedDestinationCell = false;
        String content = timeSlot?.displayText ?? '';

        // 교체 정보 리스트에서 매칭되는 항목 찾기
        bool matched = false;
        for (final exchangeInfo in _exchangeInfoList) {
          if (exchangeInfo.day == day &&
              exchangeInfo.period == period &&
              exchangeInfo.date == date) {
            matched = true;
            if (exchangeInfo.isAbsence) {
              // 결강 셀
              isExchangedSourceCell = true;
              if (DebugConfig.enableCellThemeDebugLogs) {
                AppLogger.info('[셀 테마] 결강 셀 발견 - $date $day $period교시 (원본: "$content")');
              }
              // 교체 뷰 활성화 시 내용 삭제
              if (_isExchangeViewEnabled) {
                content = '';
                if (DebugConfig.enableCellThemeDebugLogs) {
                  AppLogger.info('[셀 테마] 교체 뷰 활성화 - 내용 삭제됨');
                }
              }
            } else {
              // 수업 셀
              isExchangedDestinationCell = true;
              final newContent = '${exchangeInfo.subject ?? ''} ${exchangeInfo.className ?? ''}'.trim();
              if (DebugConfig.enableCellThemeDebugLogs) {
                AppLogger.info('[셀 테마] 수업 셀 발견 - $date $day $period교시 (원본: "$content")');
              }
              // 교체 뷰 활성화 시 수업 내용 표시
              if (_isExchangeViewEnabled) {
                content = newContent;
                if (DebugConfig.enableCellThemeDebugLogs) {
                  AppLogger.info('[셀 테마] 교체 뷰 활성화 - 내용 변경: "$newContent"');
                }
              }
            }
            break; // 첫 번째 매칭 항목만 사용
          }
        }

        // 매칭 실패 시 디버그 로그 (첫 번째 셀에 대해서만, 조건부)
        if (DebugConfig.enableCellMatchingDebugLogs && !matched && _exchangeInfoList.isNotEmpty && columnName.contains('월') && period == 1) {
          AppLogger.info('[셀 매칭] 실패 - columnName: $columnName, 파싱: day=$day, period=$period, date=$date');
          AppLogger.info('[셀 매칭] 교체 정보 리스트:');
          for (final info in _exchangeInfoList) {
            AppLogger.info('  - day=${info.day}, period=${info.period}, date=${info.date}');
          }
        }

        return SimplifiedTimetableCell(
          content: content,
          isTeacherColumn: false,
          isSelected: false,
          isExchangeable: false,
          isExchangedSourceCell: isExchangedSourceCell,
          isExchangedDestinationCell: isExchangedDestinationCell,
          isLastColumnOfDay: false,
          isFirstColumnOfDay: false,
          isHeader: false,
        );
      }).toList(),
    );
  }
}
