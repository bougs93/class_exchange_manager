import 'package:flutter/material.dart';
import '../../models/exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/exchange_node.dart';

/// 사이드바 폰트 사이즈 상수
class _SidebarFontSizes {
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
class _PathColorScheme {
  final Color primary;              // 메인 색상 (화살표, 강조)
  final Color nodeBackground;       // 노드 배경색 (선택된 상태)
  final Color nodeBackgroundUnselected; // 노드 배경색 (선택되지 않은 상태)
  final Color nodeBorder;           // 노드 테두리색 (선택된 상태)
  final Color nodeBorderUnselected; // 노드 테두리색 (선택되지 않은 상태)
  final Color nodeText;             // 노드 텍스트 색상 (선택된 상태)
  final Color nodeTextUnselected;   // 노드 텍스트 색상 (선택되지 않은 상태)
  final Color shadow;               // 그림자 색상
  
  const _PathColorScheme({
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
  static const oneToOne = _PathColorScheme(
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
  static const circular = _PathColorScheme(
    primary: Color(0xFF9C27B0),                    // 보라색 화살표
    nodeBackground: Color(0xFFF3E5F5),             // 연한 보라색 노드 배경 (선택됨)
    nodeBackgroundUnselected: Color(0xFFF8FFF8),   // 매우 연한 보라색 노드 배경 (선택안됨)
    nodeBorder: Color(0xFF9C27B0),                 // 보라색 노드 테두리 (선택됨)
    nodeBorderUnselected: Color(0xFFE1BEE7),       // 연한 보라색 노드 테두리 (선택안됨)
    nodeText: Color(0xFF6A1B9A),                   // 진한 보라색 노드 텍스트 (선택됨)
    nodeTextUnselected: Color(0xFF9C27B0),         // 보라색 노드 텍스트 (선택안됨)
    shadow: Color(0xFFE1BEE7),                     // 보라색 그림자
  );
  
  /// 경로 타입에 따른 색상 스키마 반환
  static _PathColorScheme getScheme(ExchangePathType type) {
    switch (type) {
      case ExchangePathType.oneToOne:
        return oneToOne;
      case ExchangePathType.circular:
        return circular;
    }
  }
}

/// 통합 교체 사이드바 위젯
/// 1:1교체와 순환교체 경로를 모두 표시할 수 있는 통합 사이드바
class UnifiedExchangeSidebar extends StatefulWidget {
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
  final Function(String teacherName, String day, int period)? onScrollToCell;
  
  // 순환교체 모드에서만 사용되는 단계 필터 관련 매개변수
  final List<int>? availableSteps;                    // 사용 가능한 단계들 (예: [2, 3, 4])
  final int? selectedStep;                           // 선택된 단계 (null이면 모든 단계 표시)
  final Function(int?)? onStepChanged;               // 단계 변경 콜백

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
    this.onScrollToCell,
    this.availableSteps,
    this.selectedStep,
    this.onStepChanged,
  });

  @override
  State<UnifiedExchangeSidebar> createState() => _UnifiedExchangeSidebarState();
}

class _UnifiedExchangeSidebarState extends State<UnifiedExchangeSidebar> 
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
          _buildSearchBar(),
          // 순환교체 모드에서만 단계 필터 표시
          if (widget.mode == ExchangePathType.circular && widget.availableSteps != null)
            _buildStepFilter(),
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
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isLoading)
                  Text(
                    '경로 탐색 중...',
                    style: TextStyle(
                      fontSize: _SidebarFontSizes.headerText,
                      color: Colors.blue.shade500,
                    ),
                  )
                else
                  Text(
                    '${widget.filteredPaths.length}개 경로',
                    style: TextStyle(
                      fontSize: _SidebarFontSizes.headerText,
                      color: Colors.blue.shade500,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onToggleSidebar,
            color: Colors.blue.shade600,
            iconSize: 18,
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
           hintStyle: TextStyle(fontSize: _SidebarFontSizes.searchHint),
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
          fontSize: _SidebarFontSizes.searchInput,
          height: 3, // 줄 높이 조정으로 텍스트 영역 축소
        ),
        onChanged: widget.onUpdateSearchQuery,
      ),
    );
  }

  /// 단계 필터 구성 (순환교체 모드에서만 표시)
  Widget _buildStepFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 필터 제목

          const SizedBox(height: 4),
          // 단계 선택 버튼들
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              // 각 단계별 버튼
              ...widget.availableSteps!.map((step) => _buildStepButton(
                label: '${step-2}단계(${_getStepCount(step)})',
                step: step,
                isSelected: widget.selectedStep == step,
              )),
            ],
          ),
        ],
      ),
    );
  }

  /// 특정 단계의 경로 개수 계산
  int _getStepCount(int step) {
    if (widget.mode != ExchangePathType.circular) return 0;
    
    return widget.paths.where((path) {
      if (path is CircularExchangePath) {
        return path.nodes.length == step;
      }
      return false;
    }).length;
  }

  /// 단계 선택 버튼 구성
  Widget _buildStepButton({
    required String label,
    required int? step,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => widget.onStepChanged?.call(step),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade100 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.purple.shade300 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.purple.shade700 : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
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
              fontSize: _SidebarFontSizes.loadingMessage,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(widget.loadingProgress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.blue.shade400,
              fontSize: _SidebarFontSizes.loadingProgress,
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 콘텐츠 구성
  Widget _buildEmptyContent() {
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
              fontSize: _SidebarFontSizes.emptyMessage,
            ),
          ),
        ],
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
    _PathColorScheme colorScheme = _PathColorScheme.getScheme(path.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        // 선택 상태에 따른 배경색
        // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
        color: isSelected 
            ? (path.type == ExchangePathType.oneToOne 
                ? Colors.green.shade50 
                : Colors.purple.shade50)
            : Colors.grey.shade50,
        border: Border.all(
          // 선택 상태에 따른 테두리색
          // 선택됨: 각 경로 타입별 색상, 선택안됨: 더 진한 회색으로 통일
          color: isSelected 
              ? (path.type == ExchangePathType.oneToOne 
                  ? Colors.green.shade400 
                  : Colors.purple.shade400)
              : Colors.grey.shade600,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              // 선택된 상태에서 각 경로 타입별 그림자 색상
              color: path.type == ExchangePathType.oneToOne 
                  ? Colors.green.shade200 
                  : Colors.purple.shade200,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: InkWell(
        onTap: () {
          String pathTypeName = path.type == ExchangePathType.oneToOne ? '1:1교체' : '순환교체';
          print('사이드바에서 $pathTypeName 경로 클릭: 인덱스=$index, 경로ID=${path.id}');
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
  Widget _buildPathNodes(ExchangePath path, int index, bool isSelected, _PathColorScheme colorScheme) {
    if (path.type == ExchangePathType.oneToOne) {
      return _buildOneToOneNodes(path as OneToOneExchangePath, index, isSelected, colorScheme);
    } else {
      return _buildCircularNodes(path as CircularExchangePath, index, isSelected, colorScheme);
    }
  }

  /// 1:1교체 노드들 구성
  Widget _buildOneToOneNodes(OneToOneExchangePath path, int index, bool isSelected, _PathColorScheme colorScheme) {
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
        
        // 두 번째 노드 (교체 대상 셀)
        _buildNodeContainer(path.nodes[1], '${index}_1', isSelected, false, colorScheme),
      ],
    );
  }

  // 기존 _buildCircularPathItem 메서드 제거 (공통 메서드로 통합됨)

  /// 순환교체 노드들 구성
  Widget _buildCircularNodes(CircularExchangePath path, int index, bool isSelected, _PathColorScheme colorScheme) {
    List<Widget> nodeWidgets = [];
    
    // 시작점 표시 (첫 번째 화살표 위에)
    nodeWidgets.add(_buildNodeContainer(path.nodes[0], '${index}_0', isSelected, true, colorScheme));
    
    // 중간 노드들과 화살표들
    for (int i = 1; i < path.nodes.length - 1; i++) {
      // 단방향 화살표 (순환교체 특징)
      // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
      nodeWidgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          child: Icon(
            Icons.arrow_downward,
            color: isSelected ? colorScheme.primary : Colors.grey.shade500,
            size: 12,
          ),
        ),
      );
      
      // 노드
      nodeWidgets.add(_buildNodeContainer(path.nodes[i], '${index}_$i', isSelected, false, colorScheme));
    }
    
    return Column(children: nodeWidgets);
  }

  /// 노드 컨테이너 구성 (공통)
  Widget _buildNodeContainer(ExchangeNode node, String nodeKey, bool isSelected, bool isStartNode, _PathColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        // 경로가 선택되지 않은 상태라면 경로만 선택
        if (!isSelected) {
          // nodeKey에서 경로 인덱스 추출 (형태: '${pathIndex}_${nodeIndex}')
          List<String> keyParts = nodeKey.split('_');
          if (keyParts.length >= 2) {
            int pathIndex = int.tryParse(keyParts[0]) ?? -1;
            if (pathIndex >= 0 && pathIndex < widget.filteredPaths.length) {
              ExchangePath targetPath = widget.filteredPaths[pathIndex];
              print('노드 클릭으로 경로 선택: 인덱스=$pathIndex, 경로ID=${targetPath.id}');
              widget.onSelectPath(targetPath);
            }
          }
          return; // 경로 선택만 하고 스크롤은 하지 않음
        }

        // 이미 선택된 경로의 노드를 클릭한 경우에만 물결 효과와 스크롤 실행
        _triggerRippleEffect(nodeKey);

        // 해당 셀로 스크롤
        if (widget.onScrollToCell != null) {
          widget.onScrollToCell!(
            node.teacherName,
            node.day,
            node.period,
          );
        }
      },
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
                 // 선택 상태에 따른 노드 배경색
                 // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
                 color: isSelected 
                     ? colorScheme.nodeBackground
                     : Colors.grey.shade100,
                 borderRadius: BorderRadius.circular(3),
                 border: Border.all(
                   // 선택 상태에 따른 노드 테두리색
                   // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
                   color: isSelected 
                       ? colorScheme.nodeBorder
                       : Colors.grey.shade400,
                   width: isSelected ? 2 : 1,
                 ),
                 boxShadow: [
                   if (isSelected)
                     BoxShadow(
                       color: colorScheme.shadow,
                       blurRadius: 1,
                       offset: const Offset(0, 1),
                     ),
                 ],
               ),
              child: Text(
                '${node.day}${node.period} | ${node.teacherName} | ${widget.getSubjectName(node)}',
                style: TextStyle(
                  fontSize: _SidebarFontSizes.nodeText,
                  fontWeight: FontWeight.w500,
                  // 선택 상태에 따른 노드 텍스트 색상
                  // 선택됨: 각 경로 타입별 색상, 선택안됨: 회색으로 통일
                  color: isSelected 
                      ? colorScheme.nodeText 
                      : Colors.grey.shade600,
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
