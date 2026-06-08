import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/supplement_exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../models/time_slot.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';
import '../../providers/node_scroll_provider.dart'; // 🆕 노드 스크롤 Provider 추가
import '../../providers/cell_selection_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/exchange_view_provider.dart';
import '../../providers/services_provider.dart';
import '../../providers/state_reset_provider.dart';
import 'exchange_filter_widget.dart';
import 'timetable_grid/exchange_executor.dart';
import 'timetable_grid/grid_header_widgets.dart';
import 'exchange_sidebar/sidebar_constants.dart';
import 'exchange_sidebar/sidebar_color_scheme.dart';

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

class _UnifiedExchangeSidebarState extends ConsumerState<UnifiedExchangeSidebar>
    with TickerProviderStateMixin {
  // 물결 효과를 위한 애니메이션 컨트롤러들
  final Map<String, AnimationController> _flashControllers = {};
  final Map<String, Animation<double>> _flashAnimations = {};

  /// 보강 동일 교과목 필터 활성 여부 (토글, 셀 변경 시에도 유지)
  bool _supplementSubjectFilterEnabled = false;

  @override
  void dispose() {
    // 모든 애니메이션 컨트롤러 정리
    for (var controller in _flashControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 특정 노드에 대한 물결 효과 실행
  void _triggerRippleEffect(String nodeKey) {
    // 기존 컨트롤러가 있으면 정리
    _flashControllers[nodeKey]?.dispose();

    // 새로운 애니메이션 컨트롤러 생성 (더 빠른 물결 효과)
    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 물결 효과를 위한 스케일 애니메이션 (크기 변화)
    final scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05, // 5% 확대로 줄임 (기존 15%에서 감소)
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut, // 탄성 있는 물결 효과
      ),
    );

    _flashControllers[nodeKey] = controller;
    _flashAnimations[nodeKey] = scaleAnimation;

    // 물결 애니메이션 실행 (확대 후 원래 크기로)
    controller.forward().then((_) {
      controller.reverse().then((_) {
        // 애니메이션 완료 후 정리
        setState(() {
          _flashControllers.remove(nodeKey);
          _flashAnimations.remove(nodeKey);
        });
        controller.dispose();
      });
    });

    setState(() {});
  }

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
      return _buildSupplementContent();
    }

    // 다른 모드에서는 기존 로직 유지
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            widget.searchQuery.isNotEmpty ? '검색 결과가 없습니다' : '교체 가능한 경로가 없습니다',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: SidebarFontSizes.emptyMessage,
            ),
          ),
        ],
      ),
    );
  }

  /// 보강 모드 콘텐츠 구성
  Widget _buildSupplementContent() {
    return Consumer(
      builder: (context, ref, child) {
        // 선택된 셀 정보 가져오기
        final cellSelectionState = ref.watch(cellSelectionProvider);
        final hasSelectedCell =
            cellSelectionState.selectedTeacher != null &&
            cellSelectionState.selectedDay != null &&
            cellSelectionState.selectedPeriod != null;

        if (hasSelectedCell) {
          // 선택된 셀이 있는 경우: 셀 정보와 보강 가능한 교사 버튼 표시
          return Padding(
            padding: const EdgeInsets.only(top: 16.0), // 헤더와 노드 사각형 사이 간격
            child: Column(
              children: [
                // 선택된 셀 정보
                _buildSelectedCellInfo(cellSelectionState),

                const SizedBox(height: 8),

                // 동일 교과목 필터 (보강 가능한 교사 목록 위)
                _buildSupplementSubjectFilter(cellSelectionState),

                const SizedBox(height: 8),

                // 보강 가능한 교사 버튼 섹션
                Expanded(
                  child: _buildSupplementTeacherButtons(cellSelectionState),
                ),
              ],
            ),
          );
        } else {
          // 셀 선택이 해제된 경우에만 필터 상태 초기화
          _supplementSubjectFilterEnabled = false;

          // 선택된 셀이 없는 경우: 안내 메시지 표시 (상단 간격 추가)
          return Padding(
            padding: const EdgeInsets.only(top: 16.0), // 헤더와 안내 메시지 사이 간격
            child: _buildSupplementGuide(),
          );
        }
      },
    );
  }

  /// 보강 선택 안내 메시지
  Widget _buildSupplementGuide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 64, color: Colors.blue.shade400),
          const SizedBox(height: 16),
          Text(
            '보강을 위해 빈 셀을 선택하거나\n교사명을 클릭해주세요',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: SidebarFontSizes.emptyMessage,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 선택된 셀 정보 표시 (1:1 교체와 동일한 디자인)
  Widget _buildSelectedCellInfo(CellSelectionState cellSelectionState) {
    final canExecute = _canExecuteSupplement();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          // 2개 노드를 감싸는 박스 — 더블클릭 시 [보강 실행]과 동일
          // (다른 교체 경로와 동일하게 onTap + onDoubleTap 병행)
          InkWell(
            onTap: () {},
            onDoubleTap: canExecute ? _onSupplementPathDoubleTap : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      PathColorScheme.getScheme(
                        ExchangePathType.supplement,
                      ).primary,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        PathColorScheme.getScheme(
                          ExchangePathType.supplement,
                        ).shadow,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    // 상단: 보강할 교사(빈 수업) 또는 대기 문구
                    _buildSupplementTopNode(),

                    // 화살표 (순환교체와 동일한 아래 방향, 단계 번호 없음)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      child: Icon(
                        Icons.arrow_downward,
                        color:
                            widget.selectedPath is SupplementExchangePath
                                ? PathColorScheme.getScheme(
                                  ExchangePathType.supplement,
                                ).primary
                                : Colors.grey.shade500,
                        size: 12,
                      ),
                    ),

                    // 하단: 결강(보강 대상) 수업 셀
                    _buildSupplementBottomNode(cellSelectionState),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// 보강 상단 노드 — 보강할 교사(빈수업) 또는 [빈 수업 대기]
  Widget _buildSupplementTopNode() {
    final path = widget.selectedPath;
    final colorScheme = PathColorScheme.getScheme(ExchangePathType.supplement);

    if (path is SupplementExchangePath) {
      return Consumer(
        builder: (context, ref, child) {
          final timetableData =
              ref.watch(exchangeScreenProvider).timetableData;
          final target = path.targetNode;
          final label = _formatSupplementNodeLabel(
            target,
            isSubstituteSlot: true,
            subject: _getSupplementTeacherDisplaySubject(
              target,
              timetableData?.timeSlots ?? [],
            ),
          );

          return _buildSupplementTextBox(
            label,
            colorScheme: colorScheme,
            isSelected: true,
            isHighlighted: true,
          );
        },
      );
    }

    return _buildSupplementTextBox(
      '빈 수업 대기',
      colorScheme: colorScheme,
      isPlaceholder: true,
    );
  }

  /// 보강 하단 노드 — 결강(보강 대상) 수업 셀
  Widget _buildSupplementBottomNode(CellSelectionState cellSelectionState) {
    return Consumer(
      builder: (context, ref, child) {
        // 시간표 데이터에서 선택된 셀의 상세 정보 가져오기
        final timetableData = ref.watch(exchangeScreenProvider).timetableData;

        if (timetableData == null) {
          return _buildEmptyNode('시간표 데이터 없음');
        }

        // 선택된 셀의 TimeSlot 찾기
        final selectedSlot = timetableData.timeSlots.firstWhere(
          (slot) =>
              slot.teacher == cellSelectionState.selectedTeacher &&
              slot.dayOfWeek ==
                  DayUtils.getDayNumber(cellSelectionState.selectedDay!) &&
              slot.period == cellSelectionState.selectedPeriod &&
              slot.isNotEmpty,
          orElse: () => TimeSlot(),
        );

        // ExchangeNode 생성 (1:1 교체와 동일한 형식)
        final node = ExchangeNode(
          teacherName: cellSelectionState.selectedTeacher!,
          day: cellSelectionState.selectedDay!,
          period: cellSelectionState.selectedPeriod!,
          className: selectedSlot.className ?? '',
          subjectName: selectedSlot.subject ?? '',
        );

        final colorScheme =
            PathColorScheme.getScheme(ExchangePathType.supplement);

        return _buildNodeContainer(
          node,
          'supplement_source',
          true,
          true,
          colorScheme,
          labelOverride: _formatSupplementNodeLabel(
            node,
            isSubstituteSlot: false,
            subject: node.subjectName.isNotEmpty
                ? node.subjectName
                : widget.getSubjectName(node),
          ),
        );
      },
    );
  }

  /// 보강 교사 표시용 과목명 (해당 교시가 비어 있어도 담당 과목 표시)
  String _getSupplementTeacherDisplaySubject(
    ExchangeNode node,
    List<TimeSlot> timeSlots,
  ) {
    for (final slot in timeSlots) {
      if (slot.teacher == node.teacherName &&
          slot.isNotEmpty &&
          slot.subject != null &&
          slot.subject!.isNotEmpty) {
        return slot.subject!;
      }
    }
    return widget.getSubjectName(node);
  }

  /// 보강 노드 라벨: 요일교시|학급|교사|과목
  String _formatSupplementNodeLabel(
    ExchangeNode node, {
    required bool isSubstituteSlot,
    String? subject,
  }) {
    final classLabel =
        isSubstituteSlot && node.className.isEmpty ? '빈수업' : node.className;
    final subjectLabel = subject ?? widget.getSubjectName(node);
    return '${node.day}${node.period}|$classLabel|${node.teacherName}|$subjectLabel';
  }

  /// 보강 전용 텍스트 박스 (대기 문구·보강 교사 라벨)
  Widget _buildSupplementTextBox(
    String label, {
    required PathColorScheme colorScheme,
    bool isSelected = false,
    bool isHighlighted = false,
    bool isPlaceholder = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isPlaceholder
            ? Colors.grey.shade100
            : colorScheme.backgroundFor(isSelected, false, isHighlighted),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isPlaceholder
              ? Colors.grey.shade300
              : colorScheme.borderFor(isSelected, false, isHighlighted),
          width: isSelected && !isPlaceholder ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected && !isPlaceholder)
            BoxShadow(
              color: colorScheme.shadow,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: SidebarFontSizes.nodeText,
          fontWeight: FontWeight.w500,
          color: isPlaceholder
              ? Colors.grey.shade600
              : colorScheme.textFor(isSelected, false, isHighlighted),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 선택된 결강 셀의 교과목 (없으면 null)
  String? _getSelectedCellSubject(
    CellSelectionState state,
    List<TimeSlot> timeSlots,
  ) {
    if (state.selectedTeacher == null ||
        state.selectedDay == null ||
        state.selectedPeriod == null) {
      return null;
    }

    TimeSlot? selectedSlot;
    for (final slot in timeSlots) {
      if (slot.teacher == state.selectedTeacher &&
          slot.dayOfWeek == DayUtils.getDayNumber(state.selectedDay!) &&
          slot.period == state.selectedPeriod &&
          slot.isNotEmpty) {
        selectedSlot = slot;
        break;
      }
    }

    if (selectedSlot == null) return null;

    final subject = selectedSlot.subject?.trim();
    if (subject == null || subject.isEmpty) return null;
    return subject;
  }

  /// 보강 동일 교과목 필터 버튼 — ExchangeFilterWidget 요일/단계 버튼과 동일한 칩 형태
  Widget _buildSupplementSubjectFilterButton({
    required String label,
    required bool isEnabled,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final scheme = PathColorScheme.getScheme(ExchangePathType.supplement);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: !isEnabled
              ? Colors.grey.shade100
              : isSelected
                  ? scheme.nodeBackground
                  : Colors.grey.shade100,
          border: Border.all(
            color: !isEnabled
                ? Colors.grey.shade300
                : isSelected
                    ? scheme.nodeBorder
                    : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: !isEnabled
                ? Colors.grey.shade400
                : isSelected
                    ? scheme.nodeText
                    : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// 동일 교과목 필터 — 다른 교체 모드 검색 필터 헤더와 동일한 1줄 레이아웃
  /// [아이콘] [필터] [기가 (1명) 버튼]
  Widget _buildSupplementSubjectFilter(CellSelectionState cellSelectionState) {
    return Consumer(
      builder: (context, ref, child) {
        final timetableData = ref.watch(exchangeScreenProvider).timetableData;
        if (timetableData == null) {
          return const SizedBox.shrink();
        }

        final exchangeService = ref.watch(exchangeServiceProvider);

        final subject = _getSelectedCellSubject(
          cellSelectionState,
          timetableData.timeSlots,
        );
        final isEnabled = subject != null;

        final matchCount = subject == null
            ? 0
            : exchangeService
                .getSupplementTeachers(
                  timetableData.timeSlots,
                  timetableData.teachers,
                  subjectFilter: subject,
                )
                .length;

        // 필터 ON 상태는 셀 변경 후에도 유지 (과목 없는 셀에서는 비활성 표시만)
        final isFilterActive = _supplementSubjectFilterEnabled && isEnabled;
        final subjectBadge = isEnabled
            ? '$subject ($matchCount명)'
            : '과목 없음';

        // ExchangeFilterWidget 헤더와 동일한 컨테이너 스타일
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_list,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                '필터',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              // 동일 교과목 필터 토글 버튼
              _buildSupplementSubjectFilterButton(
                label: subjectBadge,
                isEnabled: isEnabled,
                isSelected: isFilterActive,
                onTap: isEnabled
                    ? () {
                        setState(() {
                          _supplementSubjectFilterEnabled =
                              !_supplementSubjectFilterEnabled;
                        });
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 보강 가능한 교사 버튼 섹션
  Widget _buildSupplementTeacherButtons(CellSelectionState cellSelectionState) {
    return Consumer(
      builder: (context, ref, child) {
        // ExchangeService에서 보강 가능한 교사 목록 가져오기
        final exchangeService = ref.watch(exchangeServiceProvider);
        final timetableData = ref.watch(exchangeScreenProvider).timetableData;

        if (timetableData == null) {
          return _buildNoDataMessage();
        }

        final subject = _getSelectedCellSubject(
          cellSelectionState,
          timetableData.timeSlots,
        );

        // 보강 가능 교사 목록 (필터 ON 상태는 셀 변경 후에도 유지)
        final teachersToShow = exchangeService.getSupplementTeachers(
          timetableData.timeSlots,
          timetableData.teachers,
          subjectFilter:
              _supplementSubjectFilterEnabled ? subject : null,
        );

        if (teachersToShow.isEmpty) {
          return _buildNoAvailableTeachersMessage();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 헤더
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                '보강 가능한 교사',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            // 교사 버튼 목록
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: teachersToShow.length,
                itemBuilder: (context, index) {
                  final teacher = teachersToShow[index];
                  return _buildTeacherButton(teacher, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 보강 경로의 대상 교사 버튼인지 확인
  bool _isSupplementTeacherButtonSelected(
    String teacherName,
    String day,
    int period,
  ) {
    final path = widget.selectedPath;
    if (path is! SupplementExchangePath) return false;
    final target = path.targetNode;
    return target.teacherName == teacherName &&
        target.day == day &&
        target.period == period;
  }

  /// 교사 버튼 구성
  Widget _buildTeacherButton(Map<String, dynamic> teacher, int index) {
    final teacherName = teacher['teacherName'] as String;
    final day = teacher['day'] as String;
    final period = teacher['period'] as int;
    final subject = teacher['subject'] as String;
    final isSelected = _isSupplementTeacherButtonSelected(
      teacherName,
      day,
      period,
    );
    final accentColor = isSelected ? Colors.teal.shade700 : Colors.teal.shade600;
    final nameColor = isSelected ? Colors.teal.shade800 : Colors.teal.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _onTeacherButtonTap(teacherName, day, period),
        onDoubleTap:
            isSelected && _canExecuteSupplement()
                ? _onSupplementPathDoubleTap
                : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? PathColorScheme.pathBackground(ExchangePathType.supplement)
                    : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  isSelected
                      ? PathColorScheme.pathBorder(ExchangePathType.supplement)
                      : Colors.teal.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: PathColorScheme.pathShadow(ExchangePathType.supplement),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                )
              else
                BoxShadow(
                  color: Colors.teal.shade100,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            children: [
              // 시간 정보 (월1)
              Expanded(
                flex: 1,
                child: Text(
                  '$day$period',
                  style: TextStyle(
                    fontSize: SidebarFontSizes.nodeText - 1,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 구분선
              Container(
                width: 1,
                height: 16,
                color: isSelected ? Colors.teal.shade300 : Colors.teal.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),

              // 교사 이름 (강조)
              Expanded(
                flex: 2,
                child: Text(
                  teacherName,
                  style: TextStyle(
                    fontSize: SidebarFontSizes.nodeText,
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 구분선
              Container(
                width: 1,
                height: 16,
                color: isSelected ? Colors.teal.shade300 : Colors.teal.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),

              // 과목 정보
              Expanded(
                flex: 2,
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: SidebarFontSizes.nodeText - 1,
                    color: accentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 교사 버튼 탭 처리
  void _onTeacherButtonTap(String teacherName, String day, int period) {
    // 이미 선택된 교사 재클릭 무시 (더블클릭 시 onTap 2회 방지)
    if (_isSupplementTeacherButtonSelected(teacherName, day, period)) {
      return;
    }

    AppLogger.exchangeDebug('보강 가능한 교사 버튼 클릭: $teacherName ($day $period교시)');

    // 보강 모드이고 콜백이 제공된 경우 경로 미리보기
    if (widget.mode == ExchangePathType.supplement &&
        widget.onSupplementTeacherTap != null) {
      widget.onSupplementTeacherTap!(teacherName, day, period);
    }
  }

  /// 데이터 없음 메시지
  Widget _buildNoDataMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            '시간표 데이터가 없습니다',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: SidebarFontSizes.emptyMessage - 2,
            ),
          ),
        ],
      ),
    );
  }

  /// 보강 가능한 교사 없음 메시지
  Widget _buildNoAvailableTeachersMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            '보강 가능한 교사가 없습니다',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: SidebarFontSizes.emptyMessage - 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '같은 반을 가르치는 교사 중\n빈 시간이 있는 교사가 없습니다',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: SidebarFontSizes.emptyMessage - 4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 빈 노드 생성 (에러 처리용)
  Widget _buildEmptyNode(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: SidebarFontSizes.nodeText,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
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
      Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_vert,
              color: isSelected ? colorScheme.primary : Colors.grey.shade500,
              size: 14,
            ),
            const SizedBox(width: 4),
            // 숫자 1 박스 (선택 상태에 따라 색상 변경)
            Container(
              width: 20,
              height: 16,
              decoration: BoxDecoration(
                color: isSelected ? Colors.red : Colors.grey.shade500,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.grey.shade500,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
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
      Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_vert,
              color: isSelected ? colorScheme.primary : Colors.grey.shade500,
              size: 14,
            ),
            const SizedBox(width: 4),
            // 숫자 2 박스 (선택 상태에 따라 색상 변경)
            Container(
              width: 20,
              height: 16,
              decoration: BoxDecoration(
                color: isSelected ? Colors.red : Colors.grey.shade500,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.grey.shade500,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '2',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward,
                  color:
                      isSelected ? colorScheme.primary : Colors.grey.shade500,
                  size: 12,
                ),
                const SizedBox(width: 4),
                // 숫자 박스 (선택 상태에 따라 색상 변경)
                Container(
                  width: 20,
                  height: 16,
                  decoration: BoxDecoration(
                    color:
                        isSelected ? colorScheme.primary : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color:
                          isSelected
                              ? colorScheme.primary
                              : Colors.grey.shade500,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward,
                  color:
                      isSelected ? colorScheme.primary : Colors.grey.shade500,
                  size: 12,
                ),
                const SizedBox(width: 4),
                // 마지막 숫자 박스 (선택 상태에 따라 색상 변경)
                Container(
                  width: 20,
                  height: 16,
                  decoration: BoxDecoration(
                    color:
                        isSelected ? colorScheme.primary : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color:
                          isSelected
                              ? colorScheme.primary
                              : Colors.grey.shade500,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${path.nodes.length - 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

    // 이미 선택된 경로의 노드를 클릭한 경우에만 물결 효과와 스크롤 실행
    _triggerRippleEffect(nodeKey);

    // 🆕 선택된 경로의 노드 클릭 시 해당 셀로 스크롤
    _requestNodeScroll(node);

    // 노드 클릭 시 선택 처리
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

  /// 노드 컨테이너 구성 (공통)
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
    return GestureDetector(
      onTap: () => _handleNodeTap(node, nodeKey, isSelected),
      child: AnimatedBuilder(
        animation:
            _flashAnimations[nodeKey] ?? const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          final scale = _flashAnimations[nodeKey]?.value ?? 1.0;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 3,
                vertical: 1,
              ), // 4,2 → 3,1로 축소
              decoration: BoxDecoration(
                // 노드 타입별 배경색 적용
                color: colorScheme.backgroundFor(
                  isSelected,
                  isLastNode,
                  isSecondNode,
                ),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  // 노드 타입별 테두리색 적용
                  color: colorScheme.borderFor(
                    isSelected,
                    isLastNode,
                    isSecondNode,
                  ),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  if (isSelected && !isLastNode) // 마지막 노드는 그림자 제거
                    BoxShadow(
                      color: colorScheme.shadow,
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Text(
                labelOverride ??
                    '${node.day}${node.period}|${node.className}|${node.teacherName}|${widget.getSubjectName(node)}',
                style: TextStyle(
                  fontSize: SidebarFontSizes.nodeText,
                  fontWeight: FontWeight.w500,
                  // 노드 타입별 텍스트 색상 적용
                  color: colorScheme.textFor(
                    isSelected,
                    isLastNode,
                    isSecondNode,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

}
