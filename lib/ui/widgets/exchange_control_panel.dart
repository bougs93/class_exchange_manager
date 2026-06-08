import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exchange_mode.dart';
import '../../providers/app_settings_provider.dart';
import 'timetable_grid/grid_header_widgets.dart';

/// 통합 툴바 공통 높이 (1차 메뉴와 동일하게 맞춤)
const double kExchangeUnifiedToolbarHeight = 40.0;

/// 모드 버튼 글자 크기 — [UnifiedNavigationBar]와 동일
const double kModeButtonFontSize = 12.0;

/// 모드 버튼 아이콘 크기 — 1차 메뉴와 동일
const double kModeButtonIconSize = 18.0;

/// 교체 모드 버튼 고정 폭 (라벨 길이와 무관하게 동일)
const double kExchangeModeButtonWidth = 84.0;

/// 모드 버튼 라벨 표시 방식
enum ExchangeModeLabelStyle {
  /// 전체 이름 (보기, 교체불가, 1:1교체, …)
  full,

  /// 축약 (👁·🚫 아이콘만, 1:1·연쇄·순환·보강)
  compact,
}

/// 모드 선택 단독 행 — 전체 라벨(6개 버튼)에 필요한 최소 폭
const double kModeRowFullLabelsMinWidth = 480.0;

/// @deprecated [kModeRowFullLabelsMinWidth] 사용 — 통합 툴바도 모드 영역 폭 기준으로 판단
const double kToolbarFullModeLabelsMinWidth = 880.0;

/// 툴바 [totalWidth] 기준으로 전체/축약 라벨 결정
ExchangeModeLabelStyle resolveModeLabelStyle({
  required double totalWidth,
}) {
  return totalWidth >= kModeRowFullLabelsMinWidth
      ? ExchangeModeLabelStyle.full
      : ExchangeModeLabelStyle.compact;
}

/// 교체 모드 선택 위젯 (컴팩트 가로 배치)
///
/// [labelStyle]에 따라 전체 라벨 또는 축약 라벨을 표시합니다.
/// 연쇄 교체는 홈>설정에서 활성화한 경우에만 메뉴에 표시됩니다.
class ExchangeModeSelector extends ConsumerWidget {
  final ExchangeMode currentMode;
  final void Function(ExchangeMode) onModeChanged;
  final ExchangeModeLabelStyle labelStyle;

  const ExchangeModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.labelStyle = ExchangeModeLabelStyle.full,
  });

  static const _viewEditModes = [
    ExchangeMode.view,
    ExchangeMode.nonExchangeableEdit,
  ];

  static const _exchangeModes = [
    ExchangeMode.oneToOneExchange,
    ExchangeMode.chainExchange,
    ExchangeMode.circularExchange,
    ExchangeMode.supplementExchange,
  ];

  List<ExchangeMode> _visibleExchangeModes(bool isChainExchangeEnabled) {
    if (isChainExchangeEnabled) {
      return _exchangeModes;
    }

    return _exchangeModes
        .where((mode) => mode != ExchangeMode.chainExchange)
        .toList();
  }

  void _handleModeChanged(
    ExchangeMode mode,
    bool isChainExchangeEnabled,
  ) {
    if (mode == ExchangeMode.chainExchange && !isChainExchangeEnabled) {
      return;
    }

    onModeChanged(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChainExchangeEnabled = ref.watch(chainExchangeEnabledProvider);
    final exchangeModes = _visibleExchangeModes(isChainExchangeEnabled);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._buildModeGroup(_viewEditModes, isChainExchangeEnabled),
        const _ToolbarGroupDivider(),
        ..._buildModeGroup(exchangeModes, isChainExchangeEnabled),
      ],
    );
  }

  List<Widget> _buildModeGroup(
    List<ExchangeMode> modes,
    bool isChainExchangeEnabled,
  ) {
    return modes.map((mode) {
      final isSelected = mode == currentMode;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: _ModeToolbarButton(
          mode: mode,
          isSelected: isSelected,
          labelStyle: labelStyle,
          onPressed: () => _handleModeChanged(mode, isChainExchangeEnabled),
        ),
      );
    }).toList();
  }
}

/// 모드 툴바 버튼 — 공간에 따라 전체/축약 라벨 표시
class _ModeToolbarButton extends StatelessWidget {
  final ExchangeMode mode;
  final bool isSelected;
  final ExchangeModeLabelStyle labelStyle;
  final VoidCallback onPressed;

  const _ModeToolbarButton({
    required this.mode,
    required this.isSelected,
    required this.labelStyle,
    required this.onPressed,
  });

  /// 현재 스타일에 맞는 표시 라벨 (null이면 아이콘만)
  String? get _visibleLabel {
    if (labelStyle == ExchangeModeLabelStyle.full) {
      return mode.displayName;
    }
    return mode.toolbarLabel;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isSelected
            ? mode.color.withValues(alpha: 0.12)
            : Colors.grey.shade100;
    final foregroundColor = isSelected ? mode.color : Colors.grey.shade700;
    final borderColor = isSelected ? mode.color : Colors.grey.shade300;
    final visibleLabel = _visibleLabel;

    // 축약 모드 + 조회/편집: 아이콘만
    if (visibleLabel == null) {
      return Tooltip(
        message: '${mode.displayName}\n${mode.tooltipDescription}',
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: borderColor),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: kExchangeModeButtonWidth,
              height: kExchangeUnifiedToolbarHeight - 8,
              child: Center(
                child: Icon(
                  mode.icon,
                  size: kModeButtonIconSize,
                  color: foregroundColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 전체 라벨: 텍스트 길이에 맞게 폭 확장 / 축약 라벨: 고정 폭 유지
    final useFullLabel = labelStyle == ExchangeModeLabelStyle.full;

    return CompactToolbarLabelButton(
      onPressed: onPressed,
      icon: mode.icon,
      label: visibleLabel,
      tooltip: mode.tooltipDescription,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      width: useFullLabel ? null : kExchangeModeButtonWidth,
      minWidth: useFullLabel ? kExchangeModeButtonWidth : null,
      height: kExchangeUnifiedToolbarHeight - 8,
      fontSize: kModeButtonFontSize,
      iconSize: kModeButtonIconSize,
    );
  }
}

/// 툴바 그룹 구분선 (모드 | 도구 | zoom)
class ToolbarGroupDivider extends StatelessWidget {
  const ToolbarGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.grey.shade500,
    );
  }
}

/// 내부용 — ExchangeModeSelector에서만 사용
class _ToolbarGroupDivider extends ToolbarGroupDivider {
  const _ToolbarGroupDivider();
}

/// 교체 제어 패널 (독립 행으로 사용할 때 — 하위 호환)
class ExchangeControlPanel extends StatelessWidget {
  final ExchangeMode currentMode;
  final void Function(ExchangeMode) onModeChanged;

  const ExchangeControlPanel({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelStyle = resolveModeLabelStyle(
          totalWidth: constraints.maxWidth,
        );

        return Container(
          height: kExchangeUnifiedToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: ExchangeModeSelector(
            currentMode: currentMode,
            onModeChanged: onModeChanged,
            labelStyle: labelStyle,
          ),
        );
      },
    );
  }
}
