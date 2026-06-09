import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/supplement_exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../utils/logger.dart';
import '../../providers/node_scroll_provider.dart'; // 🆕 노드 스크롤 Provider 추가
import '../../providers/cell_selection_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/exchange_view_provider.dart';
import '../../providers/state_reset_provider.dart';
import 'empty_state_message.dart';
import 'exchange_filter_widget.dart';
import 'timetable_grid/exchange_executor.dart';
import 'timetable_grid/grid_header_widgets.dart';
import 'exchange_sidebar/sidebar_constants.dart';
import 'exchange_sidebar/sidebar_color_scheme.dart';
import 'exchange_sidebar/animated_sidebar_node.dart';
import 'exchange_sidebar/supplement_sidebar_content.dart';

/// 통합 교체 사이드바 위젯
/// 1:1교체와 순환교체 경로를 모두 표시할 수 있는 통합 사이드바
class UnifiedExchangeSidebar extends ConsumerStatefulWidget {
  final double width;
  final List<ExchangePath> paths; // 통합된 경로 리스트
  final List<ExchangePath> filteredPaths; // 필터링된 경로 리스트
  final ExchangePath? selectedPath; // 선택된 경로
  final ExchangePathType mode; // 현재 모드 (1:1 또는 순환교체)
  final bool isLoading;
  final double loadingProgress;
  final String searchQuery;
  final TextEditingController searchController;
  final VoidCallback onToggleSidebar;
  final Function(ExchangePath) onSelectPath; // 통합된 경로 선택 콜백
  final Function(String) onUpdateSearchQuery;
  final VoidCallback onClearSearch;
  final Function(ExchangeNode) getSubjectName;

  // 순환교체 모드에서만 사용되는 단계 필터 관련 매개변수
  final List<int>? availableSteps; // 사용 가능한 단계들 (예: [2, 3, 4])
  final int? selectedStep; // 선택된 단계 (null이면 모든 단계 표시)
  final Function(int?)? onStepChanged; // 단계 변경 콜백

  // 순환교체 모드에서만 사용되는 요일 필터 관련 매개변수
  final String? selectedDay; // 선택된 요일 (null이면 모든 요일 표시)
  final Function(String?)? onDayChanged; // 요일 변경 콜백

  // 보강 모드에서 사용되는 교사 버튼 클릭 콜백
  final Function(String, String, int)? onSupplementTeacherTap; // 교사명, 요일, 교시

  const UnifiedExchangeSidebar({
    super.key,
    required this.width,
    required this.paths,
    required this.filteredPaths,
    required this.selectedPath,
    required this.mode,
    required this.isLoading,
    required this.loadingProgress,
    required this.searchQuery,
    required this.searchController,
    required this.onToggleSidebar,
    required this.onSelectPath,
    required this.onUpdateSearchQuery,
    required this.onClearSearch,
    required this.getSubjectName,
    this.availableSteps,
    this.selectedStep,
    this.onStepChanged,
    // 순환교체 모드에서만 사용되는 요일 필터 매개변수들
    this.selectedDay,
    this.onDayChanged,
    // 보강 모드에서 사용되는 교사 버튼 클릭 콜백
    this.onSupplementTeacherTap,
  });

  @override
  ConsumerState<UnifiedExchangeSidebar> createState() =>
      _UnifiedExchangeSidebarState();
}

class _UnifiedExchangeSidebarState extends ConsumerState<UnifiedExchangeSidebar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          // 보강 모드가 아닌 경우에만 검색바 표시
          if (widget.mode != ExchangePathType.supplement) _buildSearchBar(),
          // 순환교체, 1:1 교체, 연쇄교체 모드에서 검색 필터 그룹 표시
          if (widget.mode == ExchangePathType.circular ||
              widget.mode == ExchangePathType.oneToOne ||
              widget.mode == ExchangePathType.chain)
            ExchangeFilterWidget(
              mode: widget.mode,
              paths: widget.paths,
              searchQuery: widget.searchQuery,
              isLoading: widget.isLoading,
              filteredPathCount: widget.filteredPaths.length,
              availableSteps: widget.availableSteps,
              selectedStep: widget.selectedStep,
              onStepChanged: widget.onStepChanged,
              selectedDay: widget.selectedDay,
              onDayChanged: widget.onDayChanged,
            ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  /// 헤더 구성 — [교체 실행] | [닫기]  (경로 개수는 검색 필터 헤더에 표시)
  Widget _buildHeader() {
    // 보강: 경로 미선택 시 안내, 선택 시 다른 모드와 동일하게 [교체 실행] 표시
    if (widget.mode == ExchangePathType.supplement &&
        widget.selectedPath == null) {
      final headerText =
          widget.isLoading ? '보강 준비 중...' : '보강 선택';
      return _buildHeaderContainer(
        child: Row(
          children: [
            Expanded(
              child: Text(
                headerText,
                style: TextStyle(
                  fontSize: SidebarFontSizes.headerText,
                  color: Colors.blue.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _buildCloseButton(),
          ],
        ),
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final cellState = ref.watch(cellSelectionProvider);

        // 사이드바에서 사용자가 클릭하여 선택한 경로만 사용
        // (cellSelectionProvider 잔여값으로 잘못 활성화되는 것 방지)
        final selectedPath = widget.selectedPath;
        final isFromExchangedCell = cellState.isFromExchangedCell;

        // 경로를 명시적으로 선택했고, 교체된 셀 조회가 아니며, 로딩 중이 아닐 때만 활성화
        final canExchange =
            selectedPath != null && !isFromExchangedCell && !widget.isLoading;

        VoidCallback? onExchange;
        if (canExchange) {
          onExchange = () => _executeExchangeForPath(selectedPath);
        }

        // 보강 모드는 '보강 실행', 그 외는 '교체 실행'
        final executeLabel =
            widget.mode == ExchangePathType.supplement ? '보강 실행' : '교체 실행';

        return _buildHeaderContainer(
          child: Row(
            children: [
              CompactToolbarLabelButton(
                onPressed: onExchange,
                icon: Icons.swap_horiz,
                label: executeLabel,
                tooltip: executeLabel,
                minWidth: 140,
                height: 33,
                fontSize: 12,
                iconSize: 18,
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade700,
                borderColor: Colors.blue.shade300,
              ),
              const Spacer(),
              _buildCloseButton(),
            ],
          ),
        );
      },
    );
  }

  /// 헤더 공통 컨테이너
  Widget _buildHeaderContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: child,
    );
  }

  /// 사이드바 닫기 버튼
  Widget _buildCloseButton() {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: widget.onToggleSidebar,
      color: Colors.blue.shade600,
      iconSize: 16,
      padding: const EdgeInsets.all(3),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    );
  }

  /// 교체 실행 후 교체 뷰 활성화
  void _enableExchangeView(WidgetRef ref) {
    final screenState = ref.read(exchangeScreenProvider);
    if (screenState.timetableData == null || screenState.dataSource == null) {
      return;
    }
    ref
        .read(exchangeViewProvider.notifier)
        .enableExchangeView(
          timeSlots: screenState.dataSource!.timeSlots,
          teachers: screenState.timetableData!.teachers,
          dataSource: screenState.dataSource!,
        );
  }

  /// 교체 실행 (헤더 버튼·경로 더블클릭 공통)
  void _executeExchangeForPath(ExchangePath path) {
    if (widget.isLoading) {
      return;
    }

    final cellState = ref.read(cellSelectionProvider);
    if (cellState.isFromExchangedCell) {
      return;
    }

    final screenState = ref.read(exchangeScreenProvider);
    final executor = ExchangeExecutor(
      ref: ref,
      dataSource: screenState.dataSource,
      onEnableExchangeView: () => _enableExchangeView(ref),
    );

    if (path is SupplementExchangePath) {
      executor.executeSupplementExchange(
        path.sourceNode.teacherName,
        path.sourceNode.day,
        path.sourceNode.period,
        path.targetNode.teacherName,
        path.sourceNode.className,
        path.sourceNode.subjectName,
        context,
        () {
          ref.read(stateResetProvider.notifier).resetExchangeStates(
                reason: '내부 경로 초기화',
              );
        },
      );
      ref.read(exchangeScreenProvider.notifier).disableTeacherNameSelection();
      ref.read(cellSelectionProvider.notifier).selectTeacherName(null);
      return;
    }

    executor.executeExchange(path, context, () {
      ref
          .read(stateResetProvider.notifier)
          .resetExchangeStates(reason: '내부 경로 초기화');
    });
  }

  /// 경로 단일 클릭 — 선택만
  void _onPathTap(ExchangePath path, int index) {
    final pathTypeName = path.type.displayName;
    AppLogger.exchangeDebug(
      '사이드바에서 $pathTypeName 경로 클릭: 인덱스=$index, 경로ID=${path.id}',
    );
    widget.onSelectPath(path);
  }

  /// 경로 더블 클릭 — 선택 후 교체 실행
  void _onPathDoubleTap(ExchangePath path, int index) {
    final pathTypeName = path.type.displayName;
    AppLogger.exchangeDebug(
      '사이드바에서 $pathTypeName 경로 더블클릭: 인덱스=$index, 경로ID=${path.id}',
    );
    widget.onSelectPath(path);
    _executeExchangeForPath(path);
  }

  /// 보강 실행 가능 여부 (헤더 [보강 실행] 버튼·경로 더블클릭 공통)
  bool _canExecuteSupplement() {
    if (widget.selectedPath is! SupplementExchangePath || widget.isLoading) {
      return false;
    }
    return !ref.read(cellSelectionProvider).isFromExchangedCell;
  }

  /// 보강 경로 박스 더블 클릭 — 헤더 [보강 실행] 버튼과 동일
  void _onSupplementPathDoubleTap() {
    final path = widget.selectedPath;
    if (!_canExecuteSupplement() || path is! SupplementExchangePath) {
      return;
    }

    AppLogger.exchangeDebug('보강 경로 더블클릭: 경로ID=${path.id}');
    _executeExchangeForPath(path);
  }

  /// 검색바 구성
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(6.0), // 8 → 6으로 축소
      child: TextField(
        controller: widget.searchController,
        decoration: InputDecoration(
          hintText: '요일,교사,학급,과목 검색...',
          hintStyle: TextStyle(fontSize: SidebarFontSizes.searchHint),
          isDense: true, // 조밀한 레이아웃 적용
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 6, right: 2), // 아이콘 여백 조정
            child: const Icon(Icons.search, size: 15),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 22,
            minHeight: 22,
          ), // 24 → 22로 더 축소
          suffixIcon:
              widget.searchQuery.isNotEmpty
                  ? Padding(
                    padding: const EdgeInsets.only(right: 2), // 지우기 아이콘 여백 조정
                    child: IconButton(
                      icon: const Icon(Icons.clear, size: 12),
                      onPressed: widget.onClearSearch,
                      padding: const EdgeInsets.all(2), // 버튼 패딩 축소
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ), // 20 → 18로 더 축소
                    ),
                  )
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 4,
          ), // 2 → 0으로 최소화
        ),
        style: TextStyle(
          fontSize: SidebarFontSizes.searchInput,
          height: 3, // 줄 높이 조정으로 텍스트 영역 축소
        ),
        onChanged: widget.onUpdateSearchQuery,
      ),
    );
  }

  /// 메인 콘텐츠 구성
  Widget _buildContent() {
    if (widget.isLoading) {
      return _buildLoadingContent();
    }

    if (widget.filteredPaths.isEmpty) {
      return _buildEmptyContent();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6), // 12 → 6으로 축소
      itemCount: widget.filteredPaths.length,
      itemBuilder: (context, index) {
        return _buildPathItem(widget.filteredPaths[index], index);
      },
    );
  }

  /// 로딩 콘텐츠 구성
  Widget _buildLoadingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: widget.loadingProgress,
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            widget.mode == ExchangePathType.supplement
                ? '보강 준비 중...'
                : '경로 탐색 중...',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: SidebarFontSizes.loadingMessage,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(widget.loadingProgress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.blue.shade400,
              fontSize: SidebarFontSizes.loadingProgress,
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 콘텐츠 구성
  Widget _buildEmptyContent() {
    // 보강 모드인 경우 특별한 안내 메시지 표시
    if (widget.mode == ExchangePathType.supplement) {
      return SupplementSidebarContent(
        mode: widget.mode,
        selectedPath: widget.selectedPath,
        isLoading: widget.isLoading,
        getSubjectName: widget.getSubjectName,
        onSupplementTeacherTap: widget.onSupplementTeacherTap,
        onExecuteSupplement: _onSupplementPathDoubleTap,
        onSourceNodeTap: _requestNodeScroll,
      );
    }

    // 다른 모드에서는 기존 로직 유지
    return EmptyStateMessage(
      icon: Icons.search_off,
      message: widget.searchQuery.isNotEmpty ? '검색 결과가 없습니다' : '교체 가능한 경로가 없습니다',
      messageFontSize: SidebarFontSizes.emptyMessage,
    );
  }

  /// 경로 아이템 구성 (공통 디자인, 색상과 화살표만 차별화)
  Widget _buildPathItem(ExchangePath path, int index) {
    return _buildCommonPathItem(path, index);
  }

  /// 공통 경로 아이템 구성 (1:1교체와 순환교체 통합)
  Widget _buildCommonPathItem(ExchangePath path, int index) {
    bool isSelected = widget.selectedPath == path;

    // 경로 타입별 색상 스키마 가져오기
    PathColorScheme colorScheme = PathColorScheme.getScheme(path.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        // 선택 상태에 따른 배경색
        // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
        color:
            isSelected
                ? PathColorScheme.pathBackground(path.type)
                : Colors.grey.shade50,
        border: Border.all(
          // 선택 상태에 따른 테두리색
          // 선택됨: 각 경로 타입별 색상, 선택안됨: 더 진한 회색으로 통일
          color:
              isSelected
                  ? PathColorScheme.pathBorder(path.type)
                  : Colors.grey.shade600,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              // 선택된 상태에서 각 경로 타입별 그림자 색상
              color: PathColorScheme.pathShadow(path.type),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: InkWell(
        onTap: () => _onPathTap(path, index),
        onDoubleTap: () => _onPathDoubleTap(path, index),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 노드들 표시 (타입별 분기)
              _buildPathNodes(path, index, isSelected, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  /// 경로 노드들 구성 (타입별 화살표 차별화)
  Widget _buildPathNodes(
    ExchangePath path,
    int index,
    bool isSelected,
    PathColorScheme colorScheme,
  ) {
    if (path.type == ExchangePathType.oneToOne) {
      return _buildOneToOneNodes(
        path as OneToOneExchangePath,
        index,
        isSelected,
        colorScheme,
      );
    } else if (path.type == ExchangePathType.circular) {
      return _buildCircularNodes(
        path as CircularExchangePath,
        index,
        isSelected,
        colorScheme,
      );
    } else {
      return _buildChainNodes(
        path as ChainExchangePath,
        index,
        isSelected,
        colorScheme,
      );
    }
  }

  /// 화살표 + 단계 숫자 배지 (연쇄·순환교체 공통)
  ///
  /// [arrow] 방향 아이콘(연쇄: swap_vert, 순환: arrow_downward),
  /// [badgeColor] 선택 시 배지 색상(연쇄: 빨강, 순환: 경로색),
  /// [arrowColor] 선택 시 화살표 색상(연쇄는 배지와 달리 경로색을 쓰므로 분리).
  ///   생략 시 [badgeColor]와 동일. [number] 단계 번호. 미선택 시 회색으로 통일된다.
  Widget _buildArrowWithBadge({
    required IconData arrow,
    required double arrowSize,
    required String number,
    required Color badgeColor,
    required bool isSelected,
    Color? arrowColor,
    EdgeInsets margin = const EdgeInsets.symmetric(vertical: 2),
  }) {
    final effectiveBadgeColor = isSelected ? badgeColor : Colors.grey.shade500;
    final effectiveArrowColor =
        isSelected ? (arrowColor ?? badgeColor) : Colors.grey.shade500;

    return Container(
      margin: margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(arrow, color: effectiveArrowColor, size: arrowSize),
          const SizedBox(width: 4),
          Container(
            width: 20,
            height: 16,
            decoration: BoxDecoration(
              color: effectiveBadgeColor,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: effectiveBadgeColor, width: 1),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 1:1교체 노드들 구성
  Widget _buildOneToOneNodes(
    OneToOneExchangePath path,
    int index,
    bool isSelected,
    PathColorScheme colorScheme,
  ) {
    return Column(
      children: [
        // 첫 번째 노드 (선택된 셀)
        _buildNodeContainer(
          path.nodes[0],
          '${index}_0',
          isSelected,
          true,
          colorScheme,
        ),

        // 양방향 화살표 (1:1교체 특징)
        // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Icon(
            Icons.swap_vert,
            color: isSelected ? colorScheme.primary : Colors.grey.shade500,
            size: 14,
          ),
        ),

        // 두 번째 노드 (교체 대상 셀, 진한 색상 적용)
        _buildNodeContainer(
          path.nodes[1],
          '${index}_1',
          isSelected,
          false,
          colorScheme,
          isSecondNode: true,
        ),
      ],
    );
  }

  // 기존 _buildCircularPathItem 메서드 제거 (공통 메서드로 통합됨)

  /// 연쇄교체 노드들 구성
  Widget _buildChainNodes(
    ChainExchangePath path,
    int index,
    bool isSelected,
    PathColorScheme colorScheme,
  ) {
    List<Widget> nodeWidgets = [];

    // 연쇄교체 단계별 표시:
    // 1단계: node1 ↔ node2
    // 2단계: nodeA ↔ nodeB

    // 1단계: node2 ↔ node1 (순서 수정)
    nodeWidgets.add(
      _buildNodeContainer(
        path.node2,
        '${index}_2',
        isSelected,
        false,
        colorScheme,
      ),
    );

    // 1단계 양방향 화살표와 빨간색 숫자 박스
    nodeWidgets.add(
      _buildArrowWithBadge(
        arrow: Icons.swap_vert,
        arrowSize: 14,
        number: '1',
        badgeColor: Colors.red,
        arrowColor: colorScheme.primary,
        isSelected: isSelected,
      ),
    );

    nodeWidgets.add(
      _buildNodeContainer(
        path.node1,
        '${index}_1',
        isSelected,
        false,
        colorScheme,
      ),
    );

    // 단계 간 구분선 (선택사항)
    nodeWidgets.add(
      Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 1,
        color: Colors.grey.shade300,
      ),
    );

    // 2단계: nodeA ↔ nodeB
    nodeWidgets.add(
      _buildNodeContainer(
        path.nodeA,
        '${index}_A',
        isSelected,
        false,
        colorScheme,
      ),
    );

    // 2단계 양방향 화살표와 빨간색 숫자 박스
    nodeWidgets.add(
      _buildArrowWithBadge(
        arrow: Icons.swap_vert,
        arrowSize: 14,
        number: '2',
        badgeColor: Colors.red,
        arrowColor: colorScheme.primary,
        isSelected: isSelected,
      ),
    );

    nodeWidgets.add(
      _buildNodeContainer(
        path.nodeB,
        '${index}_B',
        isSelected,
        false,
        colorScheme,
        isSecondNode: true,
      ),
    );

    return Column(children: nodeWidgets);
  }

  /// 순환교체 노드들 구성
  Widget _buildCircularNodes(
    CircularExchangePath path,
    int index,
    bool isSelected,
    PathColorScheme colorScheme,
  ) {
    List<Widget> nodeWidgets = [];

    // 시작점 표시 (첫 번째 노드)
    nodeWidgets.add(
      _buildNodeContainer(
        path.nodes[0],
        '${index}_0',
        isSelected,
        true,
        colorScheme,
      ),
    );

    // 노드 길이가 3인 경우: 1번째와 2번째 노드 사이를 상하 화살표로 (3번째 노드는 숨김)
    if (path.nodes.length == 3) {
      // 상하 화살표만 표시 (숫자 박스 제거)
      nodeWidgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swap_vert, // 상하 화살표
                color: isSelected ? colorScheme.primary : Colors.grey.shade500,
                size: 14,
              ),
            ],
          ),
        ),
      );

      // 두 번째 노드 (마지막으로 표시되는 노드, 진한 색상 적용)
      nodeWidgets.add(
        _buildNodeContainer(
          path.nodes[1],
          '${index}_1',
          isSelected,
          false,
          colorScheme,
          isSecondNode: true,
        ),
      );

      // 3번째 노드는 표시하지 않음 (숨김)
    } else {
      // 노드 길이가 4 이상인 경우: 각 화살표에 단계별 숫자 추가
      for (int i = 1; i < path.nodes.length - 1; i++) {
        // 단방향 화살표와 숫자 (순환교체 특징)
        nodeWidgets.add(
          _buildArrowWithBadge(
            arrow: Icons.arrow_downward,
            arrowSize: 12,
            number: '$i',
            badgeColor: colorScheme.primary,
            isSelected: isSelected,
            margin: const EdgeInsets.symmetric(vertical: 1),
          ),
        );

        // 노드 (2번째 노드인 경우 진한 색상 적용)
        bool isSecondNode = (i == 1); // 인덱스 1이 2번째 노드
        nodeWidgets.add(
          _buildNodeContainer(
            path.nodes[i],
            '${index}_$i',
            isSelected,
            false,
            colorScheme,
            isSecondNode: isSecondNode,
          ),
        );
      }

      // 마지막 노드 추가 (4개 이상인 경우)
      if (path.nodes.length > 3) {
        // 마지막 화살표와 숫자
        nodeWidgets.add(
          _buildArrowWithBadge(
            arrow: Icons.arrow_downward,
            arrowSize: 12,
            number: '${path.nodes.length - 1}',
            badgeColor: colorScheme.primary,
            isSelected: isSelected,
            margin: const EdgeInsets.symmetric(vertical: 1),
          ),
        );

        // 마지막 노드 (연하게 표시)
        nodeWidgets.add(
          _buildNodeContainer(
            path.nodes.last,
            '${index}_${path.nodes.length - 1}',
            isSelected,
            false,
            colorScheme,
            isLastNode: true,
          ),
        );
      }
    }

    return Column(children: nodeWidgets);
  }

  /// 노드 탭 처리 (경로 선택 또는 스크롤)
  void _handleNodeTap(ExchangeNode node, String nodeKey, bool isSelected) {
    // 경로가 선택되지 않은 상태라면 경로만 선택
    if (!isSelected) {
      _selectPathFromNodeKey(nodeKey);
      return; // 경로 선택만 하고 스크롤은 하지 않음
    }

    // 이미 선택된 경로의 노드를 클릭한 경우 해당 셀로 스크롤
    // (물결 효과는 AnimatedSidebarNode가 자체적으로 재생)
    _requestNodeScroll(node);
  }

  /// 🆕 노드 스크롤 요청
  /// 선택된 경로의 노드를 클릭했을 때 해당 셀로 스크롤 요청
  void _requestNodeScroll(ExchangeNode node) {
    try {
      AppLogger.exchangeDebug(
        '🎯 [사이드바] 노드 스크롤 요청: ${node.teacherName} | ${node.day}요일 ${node.period}교시',
      );

      // 🆕 노드 스크롤 Provider를 통해 스크롤 요청
      ref.read(nodeScrollProvider.notifier).requestScrollToNode(node);

      AppLogger.exchangeDebug('✅ [사이드바] 노드 스크롤 요청 전송 완료');
    } catch (e) {
      AppLogger.exchangeDebug('❌ [사이드바] 노드 스크롤 요청 실패: $e');
    }
  }

  /// nodeKey에서 경로 인덱스를 추출하여 경로 선택
  void _selectPathFromNodeKey(String nodeKey) {
    // nodeKey에서 경로 인덱스 추출 (형태: '${pathIndex}_${nodeIndex}')
    List<String> keyParts = nodeKey.split('_');
    if (keyParts.length >= 2) {
      int pathIndex = int.tryParse(keyParts[0]) ?? -1;
      if (pathIndex >= 0 && pathIndex < widget.filteredPaths.length) {
        ExchangePath targetPath = widget.filteredPaths[pathIndex];
        AppLogger.exchangeDebug(
          '노드 클릭으로 경로 선택: 인덱스=$pathIndex, 경로ID=${targetPath.id}',
        );
        widget.onSelectPath(targetPath);
      }
    }
  }

  /// 노드 컨테이너 구성 (공통) — 물결 효과를 가진 AnimatedSidebarNode로 위임
  ///
  /// [isStartNode]는 호출부 호환을 위해 유지하나 표시에는 사용하지 않는다.
  Widget _buildNodeContainer(
    ExchangeNode node,
    String nodeKey,
    bool isSelected,
    bool isStartNode,
    PathColorScheme colorScheme, {
    bool isLastNode = false,
    bool isSecondNode = false,
    String? labelOverride,
  }) {
    return AnimatedSidebarNode(
      node: node,
      isSelected: isSelected,
      colorScheme: colorScheme,
      isLastNode: isLastNode,
      isSecondNode: isSecondNode,
      label: labelOverride ??
          '${node.day}${node.period}|${node.className}|${node.teacherName}|${widget.getSubjectName(node)}',
      onTap: () => _handleNodeTap(node, nodeKey, isSelected),
    );
  }
}
