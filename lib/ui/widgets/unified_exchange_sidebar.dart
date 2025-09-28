import 'package:flutter/material.dart';
import '../../models/exchange_path.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/exchange_node.dart';

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
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.purple.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.mode == ExchangePathType.oneToOne ? Icons.swap_horiz : Icons.refresh,
            color: Colors.purple.shade600,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mode.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                if (widget.isLoading)
                  Text(
                    '경로 탐색 중...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade500,
                    ),
                  )
                else
                  Text(
                    '${widget.filteredPaths.length}개 경로',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade500,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onToggleSidebar,
            color: Colors.purple.shade600,
          ),
        ],
      ),
    );
  }

  /// 검색바 구성
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: widget.searchController,
        decoration: InputDecoration(
          hintText: '교사명 또는 학급명으로 검색...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: widget.onClearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            color: Colors.purple.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            '경로 탐색 중...',
            style: TextStyle(
              color: Colors.purple.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(widget.loadingProgress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.purple.shade400,
              fontSize: 14,
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
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 경로 아이템 구성 (모드별 분기)
  Widget _buildPathItem(ExchangePath path, int index) {
    switch (path.type) {
      case ExchangePathType.oneToOne:
        return _buildOneToOnePathItem(path as OneToOneExchangePath, index);
      case ExchangePathType.circular:
        return _buildCircularPathItem(path as CircularExchangePath, index);
    }
  }

  /// 1:1교체 경로 아이템 구성
  Widget _buildOneToOnePathItem(OneToOneExchangePath path, int index) {
    bool isSelected = widget.selectedPath == path;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple.shade50 : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.purple.shade300 : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: Colors.purple.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: InkWell(
        onTap: () => widget.onSelectPath(path),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 경로 제목
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '1:1 교체 경로 ${index + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.purple.shade700 : Colors.black87,
                      ),
                    ),
                  ),
                  if (path.isExchangeable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '교체 가능',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 노드들 표시
              _buildOneToOneNodes(path, index, isSelected),
              
              const SizedBox(height: 8),
              
              // 설명
              Text(
                path.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1:1교체 노드들 구성
  Widget _buildOneToOneNodes(OneToOneExchangePath path, int index, bool isSelected) {
    return Column(
      children: [
        // 첫 번째 노드 (선택된 셀)
        _buildNodeContainer(path.nodes[0], '${index}_0', isSelected, true),
        
        // 화살표
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Icon(
            Icons.swap_vert,
            color: Colors.purple.shade400,
            size: 20,
          ),
        ),
        
        // 두 번째 노드 (교체 대상 셀)
        _buildNodeContainer(path.nodes[1], '${index}_1', isSelected, false),
      ],
    );
  }

  /// 순환교체 경로 아이템 구성 (기존 로직 유지)
  Widget _buildCircularPathItem(CircularExchangePath path, int index) {
    bool isSelected = widget.selectedPath == path;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple.shade50 : Colors.white,
        border: Border.all(
          color: isSelected ? Colors.purple.shade300 : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: Colors.purple.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: InkWell(
        onTap: () => widget.onSelectPath(path),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 경로 제목
              Row(
                children: [
                  Icon(
                    Icons.refresh,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '순환교체 경로 ${index + 1} (${path.steps}단계)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.purple.shade700 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 노드들 표시
              _buildCircularNodes(path, index, isSelected),
            ],
          ),
        ),
      ),
    );
  }

  /// 순환교체 노드들 구성
  Widget _buildCircularNodes(CircularExchangePath path, int index, bool isSelected) {
    List<Widget> nodeWidgets = [];
    
    // 시작점 표시 (첫 번째 화살표 위에)
    nodeWidgets.add(_buildNodeContainer(path.nodes[0], '${index}_0', isSelected, true));
    
    // 중간 노드들과 화살표들
    for (int i = 1; i < path.nodes.length - 1; i++) {
      // 화살표
      nodeWidgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Icon(
            Icons.arrow_downward,
            color: Colors.purple.shade400,
            size: 16,
          ),
        ),
      );
      
      // 노드
      nodeWidgets.add(_buildNodeContainer(path.nodes[i], '${index}_$i', isSelected, false));
    }
    
    return Column(children: nodeWidgets);
  }

  /// 노드 컨테이너 구성 (공통)
  Widget _buildNodeContainer(ExchangeNode node, String nodeKey, bool isSelected, bool isStartNode) {
    return GestureDetector(
      onTap: () {
        // 경로가 선택되지 않은 상태라면 경로만 선택
        if (!isSelected) {
          // 해당 경로 찾기
          ExchangePath? targetPath;
          for (var path in widget.filteredPaths) {
            if (path.nodes.contains(node)) {
              targetPath = path;
              break;
            }
          }
          if (targetPath != null) {
            widget.onSelectPath(targetPath);
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? (isStartNode ? Colors.purple.shade100 : Colors.purple.shade50)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected 
                      ? (isStartNode ? Colors.purple.shade600 : Colors.purple.shade500)
                      : Colors.purple.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: Colors.purple.shade200,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.teacherName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.purple.shade700 : Colors.black87,
                    ),
                  ),
                  Text(
                    '${node.day}${node.period}교시',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.purple.shade600 : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    node.className,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.purple.shade600 : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    widget.getSubjectName(node),
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected ? Colors.purple.shade500 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
