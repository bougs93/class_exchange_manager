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
            
            const SizedBox(height: 8),
            
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '파일: ${widget.selectedFile!.path.split('\\').last}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 교체 모드 TabBar 구성 (컴팩트 버전)
  /// 
  /// 아이콘과 텍스트를 모두 표시하되, 패딩과 크기를 최소화하여
  /// 공간을 효율적으로 사용합니다.
  Widget _buildModeTabBar() {
    final visibleModes = _getVisibleModes();
    
    // TabController가 초기화되지 않은 경우 빈 컨테이너 반환
    if (_tabController == null) {
      return Container(height: 50); // 높이를 50으로 설정 (오버플로우 방지)
    }
    
    return Container(
      height: 50, // 전체 높이 제한 (2px 오버플로우 방지를 위해 48에서 50으로 증가)
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0), // 패딩 최소화
      child: TabBar(
        controller: _tabController!,
        isScrollable: true,
        onTap: (index) {
          widget.onModeChanged(visibleModes[index]);
        },
        tabs: visibleModes.map((mode) {
          return SizedBox(
            width: 55, // 모든 탭 버튼의 폭을 90px로 고정
            child: Tab(
              height: 46, // 탭 높이를 46으로 설정 (오버플로우 방지)
              icon: SizedBox(
                width: 18, // 아이콘 너비 고정
                height: 18, // 아이콘 높이 고정
                child: Icon(
                  mode.icon,
                  size: 18, // 아이콘 크기를 18로 고정 (모든 아이콘 동일)
                ),
              ),
              text: mode.displayName,
              iconMargin: const EdgeInsets.only(bottom: 2), // 아이콘과 텍스트 간격 조정
            ),
          );
        }).toList(),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        indicator: BoxDecoration(
          color: widget.currentMode.color,
          borderRadius: BorderRadius.circular(6), // 모서리 둥글기 감소
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontSize: 12, // 폰트 크기를 12px로 설정
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12, // 폰트 크기를 12px로 설정
        ),
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        // 성능 최적화
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        mouseCursor: SystemMouseCursors.click,
        enableFeedback: false,
        // 탭 간격 최소화
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // vertical 패딩을 4에서 3으로 조정
      ),
    );
  }
}
