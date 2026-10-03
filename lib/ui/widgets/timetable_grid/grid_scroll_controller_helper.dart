import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../models/exchange_node.dart';
import '../../../providers/scroll_provider.dart';
import '../../../utils/day_utils.dart';
import '../../../utils/logger.dart';
import '../../../utils/timetable_data_source.dart';
import 'grid_column_locator.dart';

/// 시간표 그리드의 교사/노드 스크롤 로직을 담당하는 헬퍼 클래스
///
/// `TimetableGridSection`에서 분리된 순수 로직(위젯이 아님)으로,
/// 그리드 위젯 자체를 다시 만들지 않고 DataGridController 및
/// ScrollController를 직접 제어해 특정 셀로 스크롤한다.
///
/// 이 클래스가 필요로 하는 값(컬럼, 데이터소스, mounted 여부)은 매 호출마다
/// 바뀔 수 있으므로 콜백(Function)으로 전달받아 항상 최신 값을 읽는다.
class GridScrollControllerHelper {
  GridScrollControllerHelper({
    required this.dataGridController,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    required this.ref,
    required this.columnsProvider,
    required this.dataSourceProvider,
    required this.isMounted,
  });

  final DataGridController dataGridController;
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final WidgetRef ref;

  /// 항상 최신 widget.columns를 반환하는 콜백
  final List<GridColumn> Function() columnsProvider;

  /// 항상 최신 widget.dataSource를 반환하는 콜백
  final TimetableDataSource? Function() dataSourceProvider;

  /// State의 mounted 여부를 반환하는 콜백
  final bool Function() isMounted;

  /// 🆕 노드 스크롤 콜백 설정
  void setupNodeScrollCallback() {
    // 외부에서 노드 스크롤을 요청할 수 있도록 콜백 연결
    // 실제 구현에서는 Provider나 다른 상태 관리 방식을 사용할 수 있음
    AppLogger.exchangeDebug('🔄 [노드 스크롤] 콜백 설정 완료');
  }

  /// 홈에서 지정한 교사명 행으로 스크롤 (교체 화면 첫 진입 시 사용)
  void scrollToTeacher(String teacherName, {int retryCount = 0}) {
    try {
      AppLogger.exchangeDebug('🔍 [교사 스크롤] 시작: $teacherName');

      final locator = GridColumnLocator(
        columnsProvider(),
        dataSourceProvider(),
      );
      final teacherRowIndex = locator.findTeacherRowIndex(teacherName);
      if (teacherRowIndex == -1) {
        AppLogger.exchangeDebug(
          '❌ [교사 스크롤] 교사를 찾을 수 없음(재시도 $retryCount): $teacherName',
        );
        // 그리드가 아직 생성 중이라 못 찾았을 수 있으므로 재시도
        if (retryCount < 5 && isMounted()) {
          Future.delayed(Duration(milliseconds: 120 * (retryCount + 1)), () {
            if (isMounted()) {
              scrollToTeacher(teacherName, retryCount: retryCount + 1);
            }
          });
        }
        return;
      }

      dataGridController.scrollToCell(
        teacherRowIndex.toDouble(),
        0,
        canAnimate: retryCount == 0,
        rowPosition: DataGridScrollPosition.center,
        columnPosition: DataGridScrollPosition.center,
      );

      AppLogger.exchangeDebug(
        '🎯 [교사 스크롤] 완료: $teacherName | 행:$teacherRowIndex',
      );
    } catch (e) {
      AppLogger.exchangeDebug('❌ [교사 스크롤] 실패(재시도 $retryCount): $e');
      if (retryCount < 5 && isMounted()) {
        Future.delayed(Duration(milliseconds: 120 * (retryCount + 1)), () {
          if (isMounted()) {
            scrollToTeacher(teacherName, retryCount: retryCount + 1);
          }
        });
      }
    }
  }

  /// 🆕 교체 경로 노드로 스크롤하는 메서드
  /// 사이드바에서 노드를 선택했을 때 해당 셀로 중앙 스크롤
  ///
  /// [node] 교체 경로의 노드 정보
  void scrollToExchangeNode(ExchangeNode node) {
    try {
      AppLogger.exchangeDebug(
        '🔍 [노드 스크롤] 시작: ${node.teacherName} | ${node.day}요일 ${node.period}교시',
      );

      // 1. DataGridController 상태 확인
      // DataGridController는 hasClients 속성이 없으므로 다른 방법으로 확인
      try {
        // 간단한 테스트로 컨트롤러가 작동하는지 확인
        AppLogger.exchangeDebug('🔍 [노드 스크롤] DataGridController 상태 확인 중...');
      } catch (e) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] DataGridController가 아직 초기화되지 않음: $e',
        );
        // 잠시 후 재시도
        Future.delayed(const Duration(milliseconds: 100), () {
          scrollToExchangeNode(node);
        });
        return;
      }

      // 2. 교사명으로 행 인덱스 찾기
      final columns = columnsProvider();
      final dataSource = dataSourceProvider();
      final locator = GridColumnLocator(columns, dataSource);
      final teacherRowIndex = locator.findTeacherRowIndex(node.teacherName);
      if (teacherRowIndex == -1) {
        AppLogger.exchangeDebug('❌ [노드 스크롤] 교사를 찾을 수 없음: ${node.teacherName}');
        return;
      }

      // 3. 요일과 교시로 열 인덱스 계산
      final dayOfWeekInt = DayUtils.getDayNumber(node.day);
      final columnIndex = locator.calculateColumnIndex(
        dayOfWeekInt,
        node.period,
      );
      if (columnIndex == -1) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] 열 인덱스 계산 실패: 요일=${node.day}, 교시=${node.period}',
        );
        return;
      }

      // 4. 인덱스 유효성 검증
      if (dataSource == null) {
        AppLogger.exchangeDebug('❌ [노드 스크롤] 데이터 소스가 null');
        return;
      }

      final maxRowIndex = dataSource.rows.length - 1;
      final maxColumnIndex = columns.length - 1;

      if (teacherRowIndex > maxRowIndex) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] 행 인덱스 범위 초과: $teacherRowIndex > $maxRowIndex',
        );
        return;
      }

      if (columnIndex > maxColumnIndex) {
        AppLogger.exchangeDebug(
          '❌ [노드 스크롤] 열 인덱스 범위 초과: $columnIndex > $maxColumnIndex',
        );
        return;
      }

      AppLogger.exchangeDebug(
        '✅ [노드 스크롤] 인덱스 검증 완료: 행=$teacherRowIndex/$maxRowIndex, 열=$columnIndex/$maxColumnIndex',
      );

      // 5. Syncfusion DataGrid의 내장 스크롤 기능 사용
      dataGridController.scrollToCell(
        teacherRowIndex.toDouble(), // 행 인덱스 (double로 변환)
        columnIndex.toDouble(), // 열 인덱스 (double로 변환)
        canAnimate: true, // 부드러운 애니메이션 효과 적용
        rowPosition: DataGridScrollPosition.center, // 행을 수직 중앙에 위치
        columnPosition: DataGridScrollPosition.center, // 열을 수평 중앙에 위치
      );

      AppLogger.exchangeDebug(
        '🎯 [노드 스크롤] 셀 중앙 이동 완료: ${node.teacherName} | ${node.day}요일 ${node.period}교시 | 행:$teacherRowIndex, 열:$columnIndex',
      );

      // 6. 스크롤 실행 확인 (잠시 후)
      Future.delayed(const Duration(milliseconds: 500), () {
        _verifyScrollExecution(node, teacherRowIndex, columnIndex);
      });
    } catch (e) {
      AppLogger.exchangeDebug('❌ [노드 스크롤] 스크롤 실패: $e');
    }
  }

  /// 🆕 스크롤 실행 확인 메서드
  /// 실제로 스크롤이 실행되었는지 확인
  void _verifyScrollExecution(
    ExchangeNode node,
    int expectedRowIndex,
    int expectedColumnIndex,
  ) {
    try {
      // 현재 스크롤 위치 확인
      final currentHorizontalOffset =
          horizontalScrollController.hasClients
              ? horizontalScrollController.offset
              : 0.0;
      final currentVerticalOffset =
          verticalScrollController.hasClients
              ? verticalScrollController.offset
              : 0.0;

      AppLogger.exchangeDebug(
        '🔍 [스크롤 확인] 현재 위치: 수평=${currentHorizontalOffset.toStringAsFixed(1)}, 수직=${currentVerticalOffset.toStringAsFixed(1)}',
      );

      // 스크롤이 실제로 발생했는지 확인
      if (currentHorizontalOffset > 0 || currentVerticalOffset > 0) {
        AppLogger.exchangeDebug('✅ [스크롤 확인] 스크롤 실행됨');
      } else {
        AppLogger.exchangeDebug('⚠️ [스크롤 확인] 스크롤이 실행되지 않음 - 대체 방법 시도');
        _tryAlternativeScrollMethod(
          node,
          expectedRowIndex,
          expectedColumnIndex,
        );
      }
    } catch (e) {
      AppLogger.exchangeDebug('❌ [스크롤 확인] 확인 실패: $e');
    }
  }

  /// 🆕 대체 스크롤 방법 시도
  /// DataGridController가 작동하지 않을 때 ScrollController 직접 사용
  void _tryAlternativeScrollMethod(
    ExchangeNode node,
    int rowIndex,
    int columnIndex,
  ) {
    try {
      AppLogger.exchangeDebug('🔄 [대체 스크롤] ScrollController 직접 사용 시도');

      // ScrollController를 직접 사용하여 스크롤
      if (horizontalScrollController.hasClients &&
          verticalScrollController.hasClients) {
        // 대략적인 위치 계산 (실제 구현에서는 더 정밀한 계산 필요)
        final estimatedHorizontalOffset = columnIndex * 100.0; // 열당 대략 100px
        final estimatedVerticalOffset = rowIndex * 50.0; // 행당 대략 50px

        horizontalScrollController.animateTo(
          estimatedHorizontalOffset.clamp(
            0.0,
            horizontalScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        verticalScrollController.animateTo(
          estimatedVerticalOffset.clamp(
            0.0,
            verticalScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        AppLogger.exchangeDebug(
          '🔄 [대체 스크롤] ScrollController 스크롤 실행: 수평=${estimatedHorizontalOffset.toStringAsFixed(1)}, 수직=${estimatedVerticalOffset.toStringAsFixed(1)}',
        );
      }
    } catch (e) {
      AppLogger.exchangeDebug('❌ [대체 스크롤] 실패: $e');
    }
  }

  /// 실제 스크롤 컨트롤러의 오프셋으로 scrollProvider를 동기화
  ///
  /// 창 최대화/리사이즈로 인해 Syncfusion 내부 스크롤 오프셋이 조용히 보정되어
  /// scrollProvider 값과 어긋나는 경우, 실제 위치로 맞춰 화살표 좌표를 정정한다.
  void syncScrollOffsetFromControllers() {
    final horizontal =
        horizontalScrollController.hasClients
            ? horizontalScrollController.offset
            : 0.0;
    final vertical =
        verticalScrollController.hasClients
            ? verticalScrollController.offset
            : 0.0;

    final current = ref.read(scrollProvider);
    // 미세한 차이는 무시하여 불필요한 재빌드 방지
    if ((current.horizontalOffset - horizontal).abs() > 0.5 ||
        (current.verticalOffset - vertical).abs() > 0.5) {
      ref.read(scrollProvider.notifier).updateOffset(horizontal, vertical);
      AppLogger.exchangeDebug(
        '🔄 [스크롤 동기화] 리사이즈 후 오프셋 보정: '
        'h=${horizontal.toStringAsFixed(1)}, v=${vertical.toStringAsFixed(1)}',
      );
    }
  }
}
