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

class _ExchangeControlPanelState extends State<ExchangeControlPanel> {
  /// 탭 메뉴에 표시할 모드들 (상수로 캐싱)
  static final _visibleModes = ExchangeMode.values;

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

            // 교체 모드 ToggleButtons
            _buildModeToggleButtons(),
          ],
        ),
      ),
    );
  }

  /// 파일이 선택되지 않았을 때의 UI
  Widget _buildNoFileSelectedUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '시간표가 포함된 엑셀 파일(.xlsx, .xls, .xlsm)을 선택하세요.',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
          Icon(Icons.description, color: Colors.blue.shade600, size: 20),
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

  /// 교체 모드 ToggleButtons 구성
  ///
  /// 버튼 그룹 스타일로 디자인하여 상단 네비게이션 바와 명확히 구분합니다.
  Widget _buildModeToggleButtons() {
    final selectedIndex = _visibleModes.indexOf(widget.currentMode);
    final selectedIndices = selectedIndex >= 0 ? {selectedIndex} : <int>{};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: ToggleButtons(
        isSelected: List.generate(
          _visibleModes.length,
          (index) => selectedIndices.contains(index),
        ),
        onPressed: (index) {
          widget.onModeChanged(_visibleModes[index]);
        },
        borderRadius: BorderRadius.circular(8),
        borderWidth: 1,
        borderColor: Colors.grey.shade300,
        selectedBorderColor:
            _visibleModes[selectedIndex >= 0 ? selectedIndex : 0].color,
        fillColor: widget.currentMode.color.withValues(alpha: 0.1),
        selectedColor: widget.currentMode.color,
        color: Colors.grey.shade600,
        constraints: const BoxConstraints(minHeight: 42, minWidth: 55),
        children:
            _visibleModes.map((mode) {
              final isSelected = mode == widget.currentMode;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mode.icon, size: 18),
                    const SizedBox(height: 2),
                    Text(
                      mode.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}
