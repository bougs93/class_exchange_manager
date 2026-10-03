import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exchange_path.dart';
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
import '../../theme/design_tokens.dart';
import 'timetable_grid/exchange_executor.dart';
import 'exchange_sidebar/sidebar_constants.dart';
import 'instant_tap_ink_well.dart';
import 'exchange_sidebar/sidebar_color_scheme.dart';
import 'exchange_sidebar/supplement_sidebar_content.dart';
import 'exchange_sidebar/path_node_renderer.dart';
import 'exchange_sidebar/sidebar_header.dart';

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

class _UnifiedExchangeSidebarState
    extends ConsumerState<UnifiedExchangeSidebar> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: tokens.surface,
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
          SidebarHeader(
            mode: widget.mode,
            selectedPath: widget.selectedPath,
            isLoading: widget.isLoading,
            onToggleSidebar: widget.onToggleSidebar,
            onExecute: _executeExchangeForPath,
          ),
          // 보강 모드가 아닌 경우에만 검색바 표시
          if (widget.mode != ExchangePathType.supplement) _buildSearchBar(),
          // 순환교체, 1:1 교체, 2중교체 모드에서 검색 필터 그룹 표시
          if (widget.mode == ExchangePathType.circular ||
              widget.mode == ExchangePathType.oneToOne ||
              widget.mode == ExchangePathType.dual)
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
          Expanded(child: _buildContent(tokens)),
        ],
      ),
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
          // 원본을 넘긴다 — dataSource가 든 것은 합성본이라 이중 적용된다(§10.2.1)
          timeSlots: screenState.timetableData!.timeSlots,
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
          ref
              .read(stateResetProvider.notifier)
              .resetExchangeStates(reason: '내부 경로 초기화');
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
  Widget _buildContent(DesignTokens tokens) {
    if (widget.isLoading) {
      return _buildLoadingContent(tokens);
    }

    if (widget.filteredPaths.isEmpty) {
      return _buildEmptyContent();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6), // 12 → 6으로 축소
      itemCount: widget.filteredPaths.length,
      itemBuilder: (context, index) {
        return _buildPathItem(widget.filteredPaths[index], index, tokens);
      },
    );
  }

  /// 로딩 콘텐츠 구성
  Widget _buildLoadingContent(DesignTokens tokens) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: widget.loadingProgress,
            color: tokens.primary,
          ),
          const SizedBox(height: 12),
          Text(
            widget.mode == ExchangePathType.supplement
                ? '보강 준비 중...'
                : '경로 탐색 중...',
            style: TextStyle(
              color: tokens.primary,
              fontSize: SidebarFontSizes.loadingMessage,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(widget.loadingProgress * 100).toInt()}%',
            style: TextStyle(
              color: tokens.primary,
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
      message:
          widget.searchQuery.isNotEmpty ? '검색 결과가 없습니다' : '교체 가능한 경로가 없습니다',
      messageFontSize: SidebarFontSizes.emptyMessage,
    );
  }

  /// 경로 아이템 구성 (공통 디자인, 색상과 화살표만 차별화)
  Widget _buildPathItem(ExchangePath path, int index, DesignTokens tokens) {
    return _buildCommonPathItem(path, index, tokens);
  }

  /// 공통 경로 아이템 구성 (1:1교체와 순환교체 통합)
  Widget _buildCommonPathItem(
    ExchangePath path,
    int index,
    DesignTokens tokens,
  ) {
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
                : tokens.sectionBackground,
        border: Border.all(
          // 선택 상태에 따른 테두리색
          // 선택됨: 각 경로 타입별 색상, 선택안됨: 더 진한 회색으로 통일
          color:
              isSelected
                  ? PathColorScheme.pathBorder(path.type)
                  : tokens.textSecondary,
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
      // InkWell에 onDoubleTap을 함께 주면 단일 탭이 300ms 늦게 실행된다
      // (경로 선택 하이라이트·시간표 반영 지연의 원인) — InstantTapInkWell 참고.
      child: InstantTapInkWell(
        onTap: () => _onPathTap(path, index),
        onDoubleTap: () => _onPathDoubleTap(path, index),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 노드들 표시 (타입별 분기)
              _buildPathNodes(path, index, isSelected, colorScheme, tokens),
            ],
          ),
        ),
      ),
    );
  }

  /// 경로 노드들 구성 (타입별 화살표 차별화) — PathNodeRenderer로 위임
  Widget _buildPathNodes(
    ExchangePath path,
    int index,
    bool isSelected,
    PathColorScheme colorScheme,
    DesignTokens tokens,
  ) {
    return PathNodeRenderer(
      path: path,
      index: index,
      isSelected: isSelected,
      colorScheme: colorScheme,
      tokens: tokens,
      getSubjectName: widget.getSubjectName,
      onNodeTap: _handleNodeTap,
      onNodeDoubleTap: _handleNodeDoubleTap,
    );
  }

  /// 노드 탭 — 경로를 고르고 그 칸으로 스크롤한다.
  void _handleNodeTap(ExchangeNode node, String nodeKey, bool isSelected) {
    if (!isSelected) {
      _selectPathFromNodeKey(nodeKey);
    }
    _requestNodeScroll(node);
  }

  /// 노드 더블 클릭 — 그 경로의 교체를 실행한다.
  void _handleNodeDoubleTap(String nodeKey) {
    final keyParts = nodeKey.split('_');
    if (keyParts.length < 2) return;
    final pathIndex = int.tryParse(keyParts[0]) ?? -1;
    if (pathIndex < 0 || pathIndex >= widget.filteredPaths.length) return;
    _onPathDoubleTap(widget.filteredPaths[pathIndex], pathIndex);
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
}
