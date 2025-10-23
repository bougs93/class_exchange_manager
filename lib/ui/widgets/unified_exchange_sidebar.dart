import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../models/time_slot.dart';
import '../../utils/logger.dart';
import '../../utils/day_utils.dart';
import '../../providers/node_scroll_provider.dart'; // 🆕 노드 스크롤 Provider 추가
import '../../providers/cell_selection_provider.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/services_provider.dart';
import 'exchange_filter_widget.dart';

/// 사이드바 폰트 사이즈 상수
class SidebarFontSizes {
  // 헤더 영역
  static const double headerText = 12.0;          // 경로 개수 텍스트
  
  // 검색바 영역
  static const double searchHint = 12.0;          // 힌트 텍스트
  static const double searchInput = 12.0;         // 입력 텍스트
  
  // 로딩 영역
  static const double loadingMessage = 14.0;      // 로딩 메시지
  static const double loadingProgress = 12.0;     // 진행률 텍스트
  
  // 빈 콘텐츠 영역
  static const double emptyMessage = 16.0;        // 안내 메시지
  
  // 경로 아이템
  static const double nodeText = 12.0;            // 노드 텍스트 (메인)
}

/// 경로 타입별 색상 시스템
class PathColorScheme {
  final Color primary;              // 메인 색상 (화살표, 강조)
  final Color nodeBackground;       // 노드 배경색 (선택된 상태)
  final Color nodeBackgroundUnselected; // 노드 배경색 (선택되지 않은 상태)
  final Color nodeBorder;           // 노드 테두리색 (선택된 상태)
  final Color nodeBorderUnselected; // 노드 테두리색 (선택되지 않은 상태)
  final Color nodeText;             // 노드 텍스트 색상 (선택된 상태)
  final Color nodeTextUnselected;   // 노드 텍스트 색상 (선택되지 않은 상태)
  final Color shadow;               // 그림자 색상
  
  const PathColorScheme({
    required this.primary,
    required this.nodeBackground,
    required this.nodeBackgroundUnselected,
    required this.nodeBorder,
    required this.nodeBorderUnselected,
    required this.nodeText,
    required this.nodeTextUnselected,
    required this.shadow,
  });
  
  /// 1:1교체 색상 스키마 (초록색 계열)
  static const oneToOne = PathColorScheme(
    primary: Color(0xFF4CAF50),                    // 초록색 화살표
    nodeBackground: Color(0xFFE8F5E8),             // 연한 초록색 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF8FFF8),   // 매우 연한 초록색 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF4CAF50),                 // 초록색 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFC8E6C9),       // 연한 초록색 노드 테두리 (선택안됨)
    nodeText: Color(0xFF2E7D32),                   // 진한 초록색 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF4CAF50),         // 초록색 노드 텍스트 (선택안됨)
    shadow: Color(0xFFC8E6C9),                     // 초록색 그림자
  );
  
  /// 순환교체 색상 스키마 (보라색 계열)
  static const circular = PathColorScheme(
    primary: Color(0xFF9C27B0),                    // 보라색 화살표
    nodeBackground: Color(0xFFF3E5F5),             // 연한 보라색 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF8FFF8),   // 매우 연한 보라색 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF9C27B0),                 // 보라색 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFE1BEE7),       // 연한 보라색 노드 테두리 (선택안됨)
    nodeText: Color(0xFF6A1B9A),                   // 진한 보라색 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF9C27B0),         // 보라색 노드 텍스트 (선택안됨)
    shadow: Color(0xFFE1BEE7),                     // 보라색 그림자
  );

  /// 연쇄교체 색상 스키마 (주황색 계열)
  static const chain = PathColorScheme(
    primary: Color(0xFFFF5722),                    // 주황색 화살표
    nodeBackground: Color(0xFFFBE9E7),             // 연한 주황색 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFFFF8F8),   // 매우 연한 주황색 노드 배경 (선택안됨)
    nodeBorder: Color(0xFFFF5722),                 // 주황색 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFFFCCBC),       // 연한 주황색 노드 테두리 (선택안됨)
    nodeText: Color(0xFFD84315),                   // 진한 주황색 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFFFF5722),         // 주황색 노드 텍스트 (선택안됨)
    shadow: Color(0xFFFFCCBC),                     // 주황색 그림자
  );

  /// 보강교체 색상 스키마 (틸 색상 계열)
  static const supplement = PathColorScheme(
    primary: Color(0xFF20B2AA),                    // 틸 색상 화살표
    nodeBackground: Color(0xFFE0F2F1),             // 연한 틸 색상 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF0FFFF),   // 매우 연한 틸 색상 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF20B2AA),                 // 틸 색상 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFB2DFDB),        // 연한 틸 색상 노드 테두리 (선택안됨)
    nodeText: Color(0xFF00695C),                   // 진한 틸 색상 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF20B2AA),         // 틸 색상 노드 텍스트 (선택안됨)
    shadow: Color(0xFFB2DFDB),                     // 틸 색상 그림자
  );

  /// 경로 타입에 따른 색상 스키마 반환
  static PathColorScheme getScheme(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return oneToOne;
      case ExchangePathType.circular:
        return circular;
      case ExchangePathType.chain:
        return chain;
      case ExchangePathType.supplement:
        return supplement;
    }
  }
}

/// 통합 교체 사이드바 위젯
/// 1:1교체와 순환교체 경로를 모두 표시할 수 있는 통합 사이드바
class UnifiedExchangeSidebar extends ConsumerStatefulWidget {
  final double width;
  final List<ExchangePath> paths;                    // 통합된 경로 리스트
  final List<ExchangePath> filteredPaths;           // 필터링된 경로 리스트
  final ExchangePath? selectedPath;                 // 선택된 경로
  final ExchangePathType mode;                      // 현재 모드 (1:1 또는 순환교체)
  final bool isLoading;
  final double loadingProgress;
  final String searchQuery;
  final TextEditingController searchController;
  final VoidCallback onToggleSidebar;
  final Function(ExchangePath) onSelectPath;        // 통합된 경로 선택 콜백
  final Function(String) onUpdateSearchQuery;
  final VoidCallback onClearSearch;
  final Function(ExchangeNode) getSubjectName;
  
  // 순환교체 모드에서만 사용되는 단계 필터 관련 매개변수
  final List<int>? availableSteps;                    // 사용 가능한 단계들 (예: [2, 3, 4])
  final int? selectedStep;                           // 선택된 단계 (null이면 모든 단계 표시)
  final Function(int?)? onStepChanged;               // 단계 변경 콜백
  
  // 순환교체 모드에서만 사용되는 요일 필터 관련 매개변수
  final String? selectedDay;                          // 선택된 요일 (null이면 모든 요일 표시)
  final Function(String?)? onDayChanged;              // 요일 변경 콜백
  
  // 보강교체 모드에서 사용되는 교사 버튼 클릭 콜백
  final Function(String, String, int)? onSupplementTeacherTap;  // 교사명, 요일, 교시

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
    // 보강교체 모드에서 사용되는 교사 버튼 클릭 콜백
    this.onSupplementTeacherTap,
  });

  @override
  ConsumerState<UnifiedExchangeSidebar> createState() => _UnifiedExchangeSidebarState();
}

class _UnifiedExchangeSidebarState extends ConsumerState<UnifiedExchangeSidebar> 
    with TickerProviderStateMixin {
  
  // 물결 효과를 위한 애니메이션 컨트롤러들
  final Map<String, AnimationController> _flashControllers = {};
  final Map<String, Animation<double>> _flashAnimations = {};
  
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
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.elasticOut, // 탄성 있는 물결 효과
    ));
    
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
          // 보강교체 모드가 아닌 경우에만 검색바 표시
          if (widget.mode != ExchangePathType.supplement)
            _buildSearchBar(),
          // 순환교체, 1:1 교체, 연쇄교체 모드에서 검색 필터 그룹 표시
          if (widget.mode == ExchangePathType.circular || 
              widget.mode == ExchangePathType.oneToOne || 
              widget.mode == ExchangePathType.chain)
            ExchangeFilterWidget(
              mode: widget.mode,
              paths: widget.paths,
              searchQuery: widget.searchQuery,
              isLoading: widget.isLoading,              // 로딩 상태 전달
              availableSteps: widget.availableSteps,
              selectedStep: widget.selectedStep,
              onStepChanged: widget.onStepChanged,
              selectedDay: widget.selectedDay,
              onDayChanged: widget.onDayChanged,
            ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  /// 헤더 구성
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.isLoading 
                ? '경로 탐색 중...'
                : widget.mode == ExchangePathType.supplement
                  ? '보강교체 안내'
                  : '${widget.filteredPaths.length}개 경로',
              style: TextStyle(
                fontSize: SidebarFontSizes.headerText,
                color: Colors.blue.shade500,
              ),
              textAlign: TextAlign.center, // 가운데 정렬 추가
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onToggleSidebar,
            color: Colors.blue.shade600,
            iconSize: 16,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
          ),
        ],
      ),
    );
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
          prefixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 22), // 24 → 22로 더 축소
          suffixIcon: widget.searchQuery.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 2), // 지우기 아이콘 여백 조정
                  child: IconButton(
                    icon: const Icon(Icons.clear, size: 12),
                    onPressed: widget.onClearSearch,
                    padding: const EdgeInsets.all(2), // 버튼 패딩 축소
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18), // 20 → 18로 더 축소
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4), // 2 → 0으로 최소화
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
            '경로 탐색 중...',
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
    // 보강교체 모드인 경우 특별한 안내 메시지 표시
    if (widget.mode == ExchangePathType.supplement) {
      return _buildSupplementContent();
    }
    
    // 다른 모드에서는 기존 로직 유지
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            widget.searchQuery.isNotEmpty
                ? '검색 결과가 없습니다'
                : '교체 가능한 경로가 없습니다',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: SidebarFontSizes.emptyMessage,
            ),
          ),
        ],
      ),
    );
  }

  /// 보강교체 모드 콘텐츠 구성
  Widget _buildSupplementContent() {
    return Consumer(
      builder: (context, ref, child) {
        // 선택된 셀 정보 가져오기
        final cellSelectionState = ref.watch(cellSelectionProvider);
        final hasSelectedCell = cellSelectionState.selectedTeacher != null &&
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
                
                const SizedBox(height: 16),
                
                // 보강 가능한 교사 버튼 섹션
                Expanded(
                  child: _buildSupplementTeacherButtons(cellSelectionState),
                ),
              ],
            ),
          );
        } else {
          // 선택된 셀이 없는 경우: 안내 메시지 표시 (상단 간격 추가)
          return Padding(
            padding: const EdgeInsets.only(top: 16.0), // 헤더와 안내 메시지 사이 간격
            child: _buildSupplementGuide(),
          );
        }
      },
    );
  }

  /// 보강교체 안내 메시지
  Widget _buildSupplementGuide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Colors.blue.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '보강교체를 위해 빈 셀을 선택하거나\n교사명을 클릭해주세요',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          // 2개 노드를 감싸는 박스 (1:1 교체와 동일한 구조)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: PathColorScheme.getScheme(ExchangePathType.supplement).primary,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: PathColorScheme.getScheme(ExchangePathType.supplement).shadow,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  // 1번째 노드 (선택된 셀) - 1:1 교체와 동일한 디자인
                  _buildSupplementNode1(cellSelectionState),
                  
                  // 화살표 (보강교체 특징: 단방향)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: PathColorScheme.getScheme(ExchangePathType.supplement).primary,
                      size: 14,
                    ),
                  ),
                  
                  // 2번째 노드 (빈 박스) - 보강받을 셀
                  _buildSupplementNode2(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),

        ],
      ),
    );
  }

  /// 1번째 노드 (선택된 셀) - 1:1 교체와 동일한 디자인
  Widget _buildSupplementNode1(CellSelectionState cellSelectionState) {
    return Consumer(
      builder: (context, ref, child) {
        // 시간표 데이터에서 선택된 셀의 상세 정보 가져오기
        final timetableData = ref.watch(exchangeScreenProvider).timetableData;
        
        if (timetableData == null) {
          return _buildEmptyNode('시간표 데이터 없음');
        }

        // 선택된 셀의 TimeSlot 찾기
        final selectedSlot = timetableData.timeSlots.firstWhere(
          (slot) => slot.teacher == cellSelectionState.selectedTeacher &&
                   slot.dayOfWeek == DayUtils.getDayNumber(cellSelectionState.selectedDay!) &&
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

        // 1:1 교체와 동일한 노드 컨테이너 사용
        return _buildNodeContainer(
          node, 
          'supplement_0', 
          true, // 선택된 상태
          true, // 시작 노드
          PathColorScheme.getScheme(ExchangePathType.supplement),
        );
      },
    );
  }

  /// 2번째 노드 (빈 박스) - 보강받을 셀
  Widget _buildSupplementNode2() {
    // 빈 노드 컨테이너 (회색 스타일)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Text(
        '빈 수업 선택 대기',
        style: TextStyle(
          fontSize: SidebarFontSizes.nodeText,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
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

        // 보강 가능한 교사 목록 가져오기
        final exchangeableTeachers = exchangeService.getSupplementExchangeableTeachers(
          timetableData.timeSlots,
          timetableData.teachers,
        );

        if (exchangeableTeachers.isEmpty) {
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
                itemCount: exchangeableTeachers.length,
                itemBuilder: (context, index) {
                  final teacher = exchangeableTeachers[index];
                  return _buildTeacherButton(teacher, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 교사 버튼 구성
  Widget _buildTeacherButton(Map<String, dynamic> teacher, int index) {
    final teacherName = teacher['teacherName'] as String;
    final day = teacher['day'] as String;
    final period = teacher['period'] as int;
    final subject = teacher['subject'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _onTeacherButtonTap(teacherName, day, period),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.teal.shade300,
              width: 1,
            ),
            boxShadow: [
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
                    color: Colors.teal.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // 구분선
              Container(
                width: 1,
                height: 16,
                color: Colors.teal.shade200,
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
                    color: Colors.teal.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // 구분선
              Container(
                width: 1,
                height: 16,
                color: Colors.teal.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
              
              // 과목 정보
              Expanded(
                flex: 2,
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: SidebarFontSizes.nodeText - 1,
                    color: Colors.teal.shade600,
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
    AppLogger.exchangeDebug('보강 가능한 교사 버튼 클릭: $teacherName ($day $period교시)');
    
    // 보강교체 모드이고 콜백이 제공된 경우 보강교체 실행
    if (widget.mode == ExchangePathType.supplement && widget.onSupplementTeacherTap != null) {
      widget.onSupplementTeacherTap!(teacherName, day, period);
    }
  }

  /// 데이터 없음 메시지
  Widget _buildNoDataMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
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
          Icon(
            Icons.person_off,
            size: 48,
            color: Colors.grey.shade400,
          ),
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
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
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
        color: isSelected
            ? _getPathBackgroundColor(path.type)
            : Colors.grey.shade50,
        border: Border.all(
          // 선택 상태에 따른 테두리색
          // 선택됨: 각 경로 타입별 색상, 선택안됨: 더 진한 회색으로 통일
          color: isSelected
              ? _getPathBorderColor(path.type)
              : Colors.grey.shade600,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              // 선택된 상태에서 각 경로 타입별 그림자 색상
              color: _getPathShadowColor(path.type),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: InkWell(
        onTap: () {
          String pathTypeName = _getPathTypeName(path.type);
          AppLogger.exchangeDebug('사이드바에서 $pathTypeName 경로 클릭: 인덱스=$index, 경로ID=${path.id}');
          widget.onSelectPath(path);
        },
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
  Widget _buildPathNodes(ExchangePath path, int index, bool isSelected, PathColorScheme colorScheme) {
    if (path.type == ExchangePathType.oneToOne) {
      return _buildOneToOneNodes(path as OneToOneExchangePath, index, isSelected, colorScheme);
    } else if (path.type == ExchangePathType.circular) {
      return _buildCircularNodes(path as CircularExchangePath, index, isSelected, colorScheme);
    } else {
      return _buildChainNodes(path as ChainExchangePath, index, isSelected, colorScheme);
    }
  }

  /// 1:1교체 노드들 구성
  Widget _buildOneToOneNodes(OneToOneExchangePath path, int index, bool isSelected, PathColorScheme colorScheme) {
    return Column(
      children: [
        // 첫 번째 노드 (선택된 셀)
        _buildNodeContainer(path.nodes[0], '${index}_0', isSelected, true, colorScheme),
        
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
        _buildNodeContainer(path.nodes[1], '${index}_1', isSelected, false, colorScheme, isSecondNode: true),
      ],
    );
  }

  // 기존 _buildCircularPathItem 메서드 제거 (공통 메서드로 통합됨)

  /// 연쇄교체 노드들 구성
  Widget _buildChainNodes(ChainExchangePath path, int index, bool isSelected, PathColorScheme colorScheme) {
    List<Widget> nodeWidgets = [];
    
    // 연쇄교체 단계별 표시:
    // 1단계: node1 ↔ node2
    // 2단계: nodeA ↔ nodeB
    
    // 1단계: node2 ↔ node1 (순서 수정)
    nodeWidgets.add(_buildNodeContainer(path.node2, '${index}_2', isSelected, false, colorScheme));
    
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
                  width: 1
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
    
    nodeWidgets.add(_buildNodeContainer(path.node1, '${index}_1', isSelected, false, colorScheme));
    
    // 단계 간 구분선 (선택사항)
    nodeWidgets.add(
      Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 1,
        color: Colors.grey.shade300,
      ),
    );
    
    // 2단계: nodeA ↔ nodeB
    nodeWidgets.add(_buildNodeContainer(path.nodeA, '${index}_A', isSelected, false, colorScheme));
    
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
                  width: 1
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
    
    nodeWidgets.add(_buildNodeContainer(path.nodeB, '${index}_B', isSelected, false, colorScheme, isSecondNode: true));
    
    return Column(children: nodeWidgets);
  }

  /// 순환교체 노드들 구성
  Widget _buildCircularNodes(CircularExchangePath path, int index, bool isSelected, PathColorScheme colorScheme) {
    List<Widget> nodeWidgets = [];
    
    // 시작점 표시 (첫 번째 노드)
    nodeWidgets.add(_buildNodeContainer(path.nodes[0], '${index}_0', isSelected, true, colorScheme));
    
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
                Icons.swap_vert,  // 상하 화살표
                color: isSelected ? colorScheme.primary : Colors.grey.shade500,
                size: 14,
              ),
            ],
          ),
        ),
      );
      
      // 두 번째 노드 (마지막으로 표시되는 노드, 진한 색상 적용)
      nodeWidgets.add(_buildNodeContainer(path.nodes[1], '${index}_1', isSelected, false, colorScheme, isSecondNode: true));
      
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
                  color: isSelected ? colorScheme.primary : Colors.grey.shade500,
                  size: 12,
                ),
                const SizedBox(width: 4),
                // 숫자 박스 (선택 상태에 따라 색상 변경)
                Container(
                  width: 20,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : Colors.grey.shade500, 
                      width: 1
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
        bool isSecondNode = (i == 1);  // 인덱스 1이 2번째 노드
        nodeWidgets.add(_buildNodeContainer(path.nodes[i], '${index}_$i', isSelected, false, colorScheme, isSecondNode: isSecondNode));
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
                  color: isSelected ? colorScheme.primary : Colors.grey.shade500,
                  size: 12,
                ),
                const SizedBox(width: 4),
                // 마지막 숫자 박스 (선택 상태에 따라 색상 변경)
                Container(
                  width: 20,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : Colors.grey.shade500, 
                      width: 1
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
        nodeWidgets.add(_buildNodeContainer(path.nodes.last, '${index}_${path.nodes.length - 1}', isSelected, false, colorScheme, isLastNode: true));
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
        '🎯 [사이드바] 노드 스크롤 요청: ${node.teacherName} | ${node.day}요일 ${node.period}교시'
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
        AppLogger.exchangeDebug('노드 클릭으로 경로 선택: 인덱스=$pathIndex, 경로ID=${targetPath.id}');
        widget.onSelectPath(targetPath);
      }
    }
  }

  /// 노드 배경색 계산
  Color _getNodeBackgroundColor(bool isSelected, bool isLastNode, bool isSecondNode, PathColorScheme colorScheme) {
    if (isLastNode) {
      return isSelected
          ? colorScheme.nodeBackground.withValues(alpha: 0.3)
          : Colors.grey.shade50;
    }

    if (isSecondNode) {
      return isSelected
          ? _getDarkerColor(colorScheme.nodeBackground)
          : Colors.grey.shade300;
    }

    return isSelected
        ? colorScheme.nodeBackground
        : Colors.grey.shade100;
  }

  /// 노드 테두리색 계산
  Color _getNodeBorderColor(bool isSelected, bool isLastNode, bool isSecondNode, PathColorScheme colorScheme) {
    if (isLastNode) {
      return isSelected
          ? colorScheme.nodeBorder.withValues(alpha: 0.3)
          : Colors.grey.shade300;
    }

    if (isSecondNode) {
      return isSelected
          ? _getDarkerColor(colorScheme.nodeBorder)
          : Colors.grey.shade500;
    }

    return isSelected
        ? colorScheme.nodeBorder
        : Colors.grey.shade400;
  }

  /// 노드 텍스트 색상 계산
  Color _getNodeTextColor(bool isSelected, bool isLastNode, bool isSecondNode, PathColorScheme colorScheme) {
    if (isLastNode) {
      return isSelected
          ? colorScheme.nodeText.withValues(alpha: 0.4)
          : Colors.grey.shade400;
    }

    if (isSecondNode) {
      return isSelected
          ? _getDarkerColor(colorScheme.nodeText)
          : Colors.grey.shade800;
    }

    return isSelected
        ? colorScheme.nodeText
        : Colors.grey.shade600;
  }

  /// 노드 컨테이너 구성 (공통)
  Widget _buildNodeContainer(ExchangeNode node, String nodeKey, bool isSelected, bool isStartNode, PathColorScheme colorScheme, {bool isLastNode = false, bool isSecondNode = false}) {
    return GestureDetector(
      onTap: () => _handleNodeTap(node, nodeKey, isSelected),
      child: AnimatedBuilder(
        animation: _flashAnimations[nodeKey] ??
                  const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          final scale = _flashAnimations[nodeKey]?.value ?? 1.0;
          
          return Transform.scale(
            scale: scale,
             child: Container(
               width: double.infinity,
               padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), // 4,2 → 3,1로 축소
               decoration: BoxDecoration(
                 // 노드 타입별 배경색 적용
                 color: _getNodeBackgroundColor(isSelected, isLastNode, isSecondNode, colorScheme),
                 borderRadius: BorderRadius.circular(3),
                 border: Border.all(
                   // 노드 타입별 테두리색 적용
                   color: _getNodeBorderColor(isSelected, isLastNode, isSecondNode, colorScheme),
                   width: isSelected ? 2 : 1,
                 ),
                 boxShadow: [
                   if (isSelected && !isLastNode)  // 마지막 노드는 그림자 제거
                     BoxShadow(
                       color: colorScheme.shadow,
                       blurRadius: 1,
                       offset: const Offset(0, 1),
                     ),
                 ],
               ),
              child: Text(
                '${node.day}${node.period}|${node.className}|${node.teacherName}|${widget.getSubjectName(node)}',
                style: TextStyle(
                  fontSize: SidebarFontSizes.nodeText,
                  fontWeight: FontWeight.w500,
                   // 노드 타입별 텍스트 색상 적용
                   color: _getNodeTextColor(isSelected, isLastNode, isSecondNode, colorScheme),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
  
  
  /// 색상을 진하게 만드는 헬퍼 메서드 (투명도 변경 없이)
  Color _getDarkerColor(Color originalColor) {
    // HSL 색상 공간에서 명도(Lightness)를 낮춰서 진하게 만듦 (0.7 → 0.85로 조정하여 덜 진하게)
    HSLColor hsl = HSLColor.fromColor(originalColor);
    return hsl.withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0)).toColor();
  }

  /// 경로 타입별 배경색 반환
  Color _getPathBackgroundColor(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return Colors.green.shade50;
      case ExchangePathType.circular:
        return Colors.purple.shade50;
      case ExchangePathType.chain:
        return Colors.deepOrange.shade50;
      case ExchangePathType.supplement:
        return Colors.teal.shade50;
    }
  }

  /// 경로 타입별 테두리색 반환
  Color _getPathBorderColor(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return Colors.green.shade400;
      case ExchangePathType.circular:
        return Colors.purple.shade400;
      case ExchangePathType.chain:
        return Colors.deepOrange.shade400;
      case ExchangePathType.supplement:
        return Colors.teal.shade400;
    }
  }

  /// 경로 타입별 그림자 색상 반환
  Color _getPathShadowColor(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return Colors.green.shade200;
      case ExchangePathType.circular:
        return Colors.purple.shade200;
      case ExchangePathType.chain:
        return Colors.deepOrange.shade200;
      case ExchangePathType.supplement:
        return Colors.teal.shade200;
    }
  }

  /// 경로 타입별 이름 반환
  String _getPathTypeName(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return '1:1교체';
      case ExchangePathType.circular:
        return '순환교체';
      case ExchangePathType.chain:
        return '연쇄교체';
      case ExchangePathType.supplement:
        return '보강교체';
    }
  }
}
