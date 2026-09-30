import 'package:flutter/foundation.dart';
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
  }) : _rows = rows,
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
    final nextExchange = exchangeInfoList ?? _exchangeInfoList;
    final nextEnabled = isExchangeViewEnabled ?? _isExchangeViewEnabled;
    // 내용이 같으면 SfDataGrid를 다시 그리지 않습니다.
    if (identical(_rows, newRows) &&
        _isExchangeViewEnabled == nextEnabled &&
        listEquals(_exchangeInfoList, nextExchange)) {
      return;
    }
    _rows = newRows;
    _exchangeInfoList = nextExchange;
    _isExchangeViewEnabled = nextEnabled;
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells:
          row.getCells().asMap().entries.map<Widget>((entry) {
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

            // columnName 파싱: "월_5_2026.06.10" (요일_교시_YYYY.MM.DD)
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
            final date = columnNameParts[2];

            // 교체 정보와 매칭하여 테마 결정 (날짜+교시 — 해당 날짜 열에만 표시)
            //
            // 2중·순환 교체에서는 같은 칸이 "한 단계에서는 빠져나가는 자리
            // (결강)"이면서 동시에 "다른 단계에서는 새로 들어오는 자리(수업)"일
            // 수 있다 — 예: 이숙희의 월4교시가 (중간 단계) 그의 원래 수업이
            // 빠지는 자리이면서, (최종 단계) 다른 교사의 수업이 새로 들어오는
            // 자리인 경우. 첫 매칭 후 break하면 둘 중 하나만 반영돼 X·O 중
            // 하나만 표시되고 도착 과목이 안 보이는 문제가 있었다(2026-09-30
            // 실 앱 테스트로 발견) — 이제 두 매칭을 모두 모은 뒤 반영한다.
            ExchangeCellInfo? absenceMatch;
            ExchangeCellInfo? destinationMatch;
            for (final exchangeInfo in _exchangeInfoList) {
              if (exchangeInfo.period == period && exchangeInfo.date == date) {
                if (exchangeInfo.isAbsence) {
                  absenceMatch ??= exchangeInfo;
                } else {
                  destinationMatch ??= exchangeInfo;
                }
              }
            }

            final matched = absenceMatch != null || destinationMatch != null;
            final isExchangedSourceCell = absenceMatch != null;
            final isExchangedDestinationCell = destinationMatch != null;
            String content = timeSlot?.displayText ?? '';

            if (destinationMatch != null) {
              // 도착 정보가 있으면(결강만 있을 때와 달리) 실제로 지금 이
              // 칸에서 수업하는 내용이 있다는 뜻이므로, 결강 표시와 함께
              // 있어도 항상 도착 과목을 보여준다.
              if (DebugConfig.enableCellThemeDebugLogs) {
                AppLogger.info(
                  '[셀 테마] 수업 셀 발견 - $date $day $period교시 (원본: "$content")',
                );
              }
              if (_isExchangeViewEnabled) {
                content = destinationMatch.displayText;
                if (DebugConfig.enableCellThemeDebugLogs) {
                  AppLogger.info('[셀 테마] 교체 뷰 활성화 - 내용 변경: "$content"');
                }
              }
            } else if (absenceMatch != null) {
              if (DebugConfig.enableCellThemeDebugLogs) {
                AppLogger.info(
                  '[셀 테마] 결강 셀 발견 - $date $day $period교시 (원본: "$content")',
                );
              }
              if (_isExchangeViewEnabled) {
                content = '';
                if (DebugConfig.enableCellThemeDebugLogs) {
                  AppLogger.info('[셀 테마] 교체 뷰 활성화 - 내용 삭제됨');
                }
              }
            }

            // 매칭 실패 시 디버그 로그 (첫 번째 셀에 대해서만, 조건부)
            if (DebugConfig.enableCellMatchingDebugLogs &&
                !matched &&
                _exchangeInfoList.isNotEmpty &&
                columnName.contains('월') &&
                period == 1) {
              AppLogger.info(
                '[셀 매칭] 실패 - columnName: $columnName, 파싱: day=$day, period=$period, date=$date',
              );
              AppLogger.info('[셀 매칭] 교체 정보 리스트:');
              for (final info in _exchangeInfoList) {
                AppLogger.info(
                  '  - day=${info.day}, period=${info.period}, date=${info.date}',
                );
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
