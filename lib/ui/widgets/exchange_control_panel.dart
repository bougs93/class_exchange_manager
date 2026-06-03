import 'package:flutter/material.dart';
import '../../models/exchange_mode.dart';

/// 교체 제어 패널 위젯
///
/// 교체 모드 선택만 담당합니다. 엑셀 파일 표시는 홈 화면에서 합니다.
class ExchangeControlPanel extends StatefulWidget {
  final ExchangeMode currentMode;
  final void Function(ExchangeMode) onModeChanged;

  const ExchangeControlPanel({
    super.key,
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
            // 교체 모드 ToggleButtons
            _buildModeToggleButtons(),
          ],
        ),
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
