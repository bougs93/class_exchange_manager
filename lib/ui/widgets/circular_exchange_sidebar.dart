import 'package:flutter/material.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/exchange_node.dart';

/// 순환교체 사이드바 위젯
/// 순환교체 경로 목록을 표시하고 선택할 수 있는 사이드바
class CircularExchangeSidebar extends StatefulWidget {
  final double width;
  final List<CircularExchangePath> circularPaths;
  final List<CircularExchangePath> filteredCircularPaths;
  final CircularExchangePath? selectedCircularPath;
  final bool isLoading;
  final double loadingProgress;
  final String searchQuery;
  final TextEditingController searchController;
  final VoidCallback onToggleSidebar;
  final Function(CircularExchangePath) onSelectPath;
  final Function(String) onUpdateSearchQuery;
  final VoidCallback onClearSearch;
  final Function(ExchangeNode) getSubjectName;
  final Function(String teacherName, String day, int period)? onScrollToCell; // 셀 스크롤 콜백 추가

  const CircularExchangeSidebar({
    super.key,
    required this.width,
    required this.circularPaths,
    required this.filteredCircularPaths,
    required this.selectedCircularPath,
    required this.isLoading,
    required this.loadingProgress,
    required this.searchQuery,
    required this.searchController,
    required this.onToggleSidebar,
    required this.onSelectPath,
    required this.onUpdateSearchQuery,
    required this.onClearSearch,
    required this.getSubjectName,
    this.onScrollToCell, // 선택적 매개변수로 추가
  });

  @override
  State<CircularExchangeSidebar> createState() => _CircularExchangeSidebarState();
}

class _CircularExchangeSidebarState extends State<CircularExchangeSidebar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 사이드바 헤더
          _buildSidebarHeader(),
          
          // 경로 리스트
          Expanded(
            child: _buildCircularPathsList(),
          ),
        ],
      ),
    );
  }

  /// 사이드바 헤더 구성
  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 헤더 상단 (제목과 닫기 버튼)
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
                  _getSearchResultText(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade600,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onToggleSidebar,
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '사이드바 닫기',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 검색 입력 필드
          _buildSearchField(),
        ],
      ),
    );
  }

  /// 검색 입력 필드 구성
  Widget _buildSearchField() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: TextField(
        controller: widget.searchController,
        onChanged: widget.onUpdateSearchQuery,
        decoration: InputDecoration(
          hintText: '요일, 교사명, 과목 검색...',
          hintStyle: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 16,
            color: Colors.grey.shade500,
          ),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: widget.onClearSearch,
                  icon: Icon(
                    Icons.clear,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// 순환교체 경로 리스트 구성
  Widget _buildCircularPathsList() {
    // 로딩 중인 경우 진행률 표시
    if (widget.isLoading) {
      return _buildLoadingIndicator();
    }
    
    // 필터링된 경로가 비어있는 경우 처리
    if (widget.filteredCircularPaths.isEmpty) {
      return _buildEmptyState();
    }

    // 단계별로 분류 (필터링된 경로 사용)
    Map<int, List<CircularExchangePath>> pathsByStep = {};
    for (var path in widget.filteredCircularPaths) {
      pathsByStep.putIfAbsent(path.steps, () => []).add(path);
    }

    List<int> steps = pathsByStep.keys.toList()..sort();

    return DefaultTabController(
      length: steps.length,
      child: Column(
        children: [
          // 사이드바용 탭바
          _buildTabBar(steps, pathsByStep),
          
          // 탭별 내용
          Expanded(
            child: TabBarView(
              children: steps.map((step) => _buildPathListForStep(pathsByStep[step]!)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 로딩 인디케이터 구성
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 원형 진행률 표시기
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: widget.loadingProgress,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
                ),
              ),
              Text(
                '${(widget.loadingProgress * 100).round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 로딩 상태 텍스트
          Text(
            '순환교체 경로 탐색 중...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.purple.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 진행률에 따른 상세 메시지
          Text(
            _getLoadingMessage(widget.loadingProgress),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 선형 진행률 표시기
          Container(
            width: 140,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.grey.shade300,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: widget.loadingProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 화면 구성
  Widget _buildEmptyState() {
    if (widget.circularPaths.isEmpty) {
      // 경로가 전혀 없는 경우
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '순환교체 경로가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '시간표에서 셀을 선택하면\n순환교체 경로를 찾을 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    } else {
      // 검색 결과가 없는 경우
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${widget.searchQuery}"에 대한\n검색 결과를 찾을 수 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 탭바 구성
  Widget _buildTabBar(List<int> steps, Map<int, List<CircularExchangePath>> pathsByStep) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        isScrollable: true,
        indicator: BoxDecoration(
          color: Colors.purple.shade600,
          borderRadius: BorderRadius.circular(4),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: steps.map((step) => Tab(
          text: '$step단계 (${pathsByStep[step]!.length})',
          height: 32,
        )).toList(),
      ),
    );
  }

  /// 특정 단계의 경로 리스트 구성
  Widget _buildPathListForStep(List<CircularExchangePath> paths) {
    return ListView.builder(
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        return _buildPathItem(path, index);
      },
    );
  }

  /// 경로 아이템 구성
  Widget _buildPathItem(CircularExchangePath path, int index) {
    // 선택된 경로인지 확인 (노드 비교를 통해 동일한 경로인지 판단)
    bool isSelected = widget.selectedCircularPath != null && 
                     widget.selectedCircularPath!.nodes.length == path.nodes.length &&
                     widget.selectedCircularPath!.nodes.asMap().entries.every((entry) {
                       int idx = entry.key;
                       var selectedNode = entry.value;
                       var pathNode = path.nodes[idx];
                       return selectedNode.teacherName == pathNode.teacherName &&
                              selectedNode.day == pathNode.day &&
                              selectedNode.period == pathNode.period &&
                              selectedNode.className == pathNode.className;
                     });
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Card(
        elevation: isSelected ? 4 : 1, // 선택된 경로는 더 높은 그림자
        color: isSelected ? Colors.purple.shade50 : Colors.white, // 선택된 경로는 배경색 변경
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.purple.shade600 : Colors.grey.shade300,
            width: isSelected ? 2 : 1, // 선택된 경로는 테두리 두께 증가
          ),
        ),
        child: InkWell(
          onTap: () => widget.onSelectPath(path),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 시작점과 다음 경로들 표시
                Column(
                  children: [
                    // 시작점 표시 (첫 번째 화살표 위에) - 클릭 가능
                    GestureDetector(
                      onTap: () {
                        // 해당 셀로 스크롤
                        if (widget.onScrollToCell != null) {
                          widget.onScrollToCell!(
                            path.nodes[0].teacherName,
                            path.nodes[0].day,
                            path.nodes[0].period,
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.purple.shade100 : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? Colors.purple.shade600 : Colors.purple.shade400,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isSelected ? 0.1 : 0.05),
                              blurRadius: isSelected ? 3 : 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${path.nodes[0].day}${path.nodes[0].period} | ${path.nodes[0].teacherName} | ${widget.getSubjectName(path.nodes[0])}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.purple.shade800 : Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ),
                    
                    // 다음 경로들
                    for (int i = 1; i < path.nodes.length - 1; i++) ...[
                      // 모든 경로 앞에 화살표 표시
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Icon(
                          Icons.arrow_downward,
                          size: 14,
                          color: isSelected ? Colors.purple.shade600 : Colors.purple.shade400,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // 해당 셀로 스크롤
                          if (widget.onScrollToCell != null) {
                            widget.onScrollToCell!(
                              path.nodes[i].teacherName,
                              path.nodes[i].day,
                              path.nodes[i].period,
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.purple.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? Colors.purple.shade500 : Colors.purple.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isSelected ? 0.1 : 0.05),
                                blurRadius: isSelected ? 3 : 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '${path.nodes[i].day}${path.nodes[i].period} | ${path.nodes[i].teacherName} | ${widget.getSubjectName(path.nodes[i])}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.purple.shade800 : Colors.purple.shade700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 검색 결과 통계 텍스트 반환
  String _getSearchResultText() {
    if (widget.searchQuery.isEmpty) {
      return '순환교체 ${widget.circularPaths.length}개';
    } else {
      return '검색 결과 ${widget.filteredCircularPaths.length}개 / 전체 ${widget.circularPaths.length}개';
    }
  }
  
  /// 진행률에 따른 로딩 메시지 반환
  String _getLoadingMessage(double progress) {
    if (progress < 0.2) {
      return '초기화 중...';
    } else if (progress < 0.4) {
      return '교사 정보 수집 중...';
    } else if (progress < 0.8) {
      return '시간표 분석 중...';
    } else if (progress < 0.9) {
      return 'DFS 경로 탐색 중...';
    } else if (progress < 1.0) {
      return '결과 처리 중...';
    } else {
      return '완료!';
    }
  }
}
