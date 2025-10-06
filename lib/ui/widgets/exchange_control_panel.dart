import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/exchange_mode.dart';

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
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: ExchangeMode.values.length,
      vsync: this,
      initialIndex: widget.currentMode.index,
    );
  }

  @override
  void didUpdateWidget(ExchangeControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // currentMode가 변경되었을 때 TabController 업데이트
    if (oldWidget.currentMode != widget.currentMode) {
      _tabController.animateTo(widget.currentMode.index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero, // Card의 기본 마진 제거
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0), // 하단 패딩 제거
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
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      onTap: (index) {
        widget.onModeChanged(ExchangeMode.values[index]);
      },
      tabs: ExchangeMode.values.map((mode) => Tab(
        icon: Icon(mode.icon, size: 18),
        text: mode.displayName,
      )).toList(),
      labelColor: Colors.white, // 선택된 탭의 텍스트 색상 (흰색으로 변경)
      unselectedLabelColor: Colors.grey.shade600,
      indicator: BoxDecoration(
        color: widget.currentMode.color, // 선택된 탭의 배경색 (현재 모드의 색상 사용)
        borderRadius: BorderRadius.circular(8), // 둥근 모서리
      ),
      indicatorSize: TabBarIndicatorSize.tab, // 탭 전체 크기에 맞춤
      indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // 패딩 추가
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      // 애니메이션 효과 제거 - overlayColor만 사용
      overlayColor: WidgetStateProperty.all(Colors.transparent), // 오버레이 색상 투명화
    );
  }
}
