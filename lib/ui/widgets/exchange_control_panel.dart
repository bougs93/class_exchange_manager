import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/exchange_mode.dart';
import '../../utils/logger.dart';

/// 교체 제어 패널 위젯
/// 파일 선택 상태 표시와 교체 모드 선택을 담당하는 통합 제어 패널
class ExchangeControlPanel extends StatefulWidget {
  final File? selectedFile;
  final bool isLoading;
  final ExchangeMode currentMode;
  final void Function(ExchangeMode) onModeChanged;

  const ExchangeControlPanel({
    super.key,
    required this.selectedFile,
    required this.isLoading,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  State<ExchangeControlPanel> createState() => _ExchangeControlPanelState();
}

class _ExchangeControlPanelState extends State<ExchangeControlPanel>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
  }
  
  void _initializeTabController() {
    final visibleModes = _getVisibleModes();
    final initialIndex = visibleModes.indexOf(widget.currentMode);
    
    AppLogger.exchangeDebug('initState - TabController 길이: ${visibleModes.length}');
    AppLogger.exchangeDebug('initState - 초기 인덱스: ${initialIndex != -1 ? initialIndex : 0}');
    
    _tabController = TabController(
      length: visibleModes.length,
      initialIndex: initialIndex != -1 ? initialIndex : 0,
      vsync: this,
      animationDuration: Duration.zero, // 애니메이션 지속 시간을 0으로 설정
    );
  }

  @override
  void didUpdateWidget(ExchangeControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // currentMode가 변경되었을 때 TabController 인덱스만 업데이트
    if (oldWidget.currentMode != widget.currentMode && _tabController != null) {
      final visibleModes = _getVisibleModes();
      final newIndex = visibleModes.indexOf(widget.currentMode);
      
      AppLogger.exchangeDebug('didUpdateWidget - 인덱스 업데이트: ${newIndex != -1 ? newIndex : 0}');
      
      // 탭 인덱스 업데이트
      if (newIndex != -1) {
        _tabController!.index = newIndex;
      } else {
        // 모드를 찾을 수 없는 경우 첫 번째 탭으로 설정
        _tabController!.index = 0;
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// 탭 메뉴에 표시할 모드들 반환 (모든 모드 포함)
  List<ExchangeMode> _getVisibleModes() {
    return ExchangeMode.values;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero, // Card의 기본 마진 제거
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0), // 전체 패딩 최소화
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 파일 선택 상태에 따른 UI
            if (widget.selectedFile == null) 
              _buildNoFileSelectedUI()
            else 
              _buildFileSelectedUI(),
            
            const SizedBox(height: 16),
            
            // 교체 모드 TabBar
            _buildModeTabBar(),
          ],
        ),
      ),
    );
  }

  /// 파일이 선택되지 않았을 때의 UI
  Widget _buildNoFileSelectedUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '시간표가 포함된 엑셀 파일(.xlsx, .xls)을 선택하세요.',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 파일이 선택되었을 때의 UI
  Widget _buildFileSelectedUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 선택된 파일 정보 표시
        _buildSelectedFileInfo(),
      ],
    );
  }

  /// 선택된 파일 정보 표시
  Widget _buildSelectedFileInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description,
            color: Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '선택된 파일: ${widget.selectedFile!.path.split('\\').last}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 교체 모드 TabBar 구성
  Widget _buildModeTabBar() {
    final visibleModes = _getVisibleModes();
    
    // TabController가 초기화되지 않은 경우 빈 컨테이너 반환
    if (_tabController == null) {
      return Container(height: 48); // TabBar와 동일한 높이
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 0.0), // 왼쪽 여백 더 최소화
      child: TabBar(
        controller: _tabController!,
        isScrollable: true,
        onTap: (index) {
          widget.onModeChanged(visibleModes[index]);
        },
        tabs: visibleModes.map((mode) => Tab(
          icon: Icon(mode.icon, size: 20),
          text: mode.displayName,
        )).toList(),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        indicator: BoxDecoration(
          color: widget.currentMode.color,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        // indicatorPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // horizontal 패딩 줄임
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabAlignment: TabAlignment.start, // 탭들을 왼쪽 정렬
        dividerColor: Colors.transparent, // 탭 아래 경계선 제거
        dividerHeight: 0, // 탭 아래 경계선 높이 0으로 설정
        // 최대 성능 최적화
        overlayColor: WidgetStateProperty.all(Colors.transparent), // 오버레이 색상 투명화
        splashFactory: NoSplash.splashFactory, // 스플래시 효과 제거
        mouseCursor: SystemMouseCursors.click, // 마우스 커서만 유지
        enableFeedback: false, // 햅틱 피드백 제거
        // physics 제거: 가로폭이 좁을 때 스크롤 가능하도록 함
      ),
    );
  }
}
