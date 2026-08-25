import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exchange_mode.dart';
import '../../providers/app_settings_provider.dart';
import '../../theme/design_tokens.dart';
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

  /// 축약 (👁·🚫 아이콘만, 1:1·2중·순환·보강)
  compact,
}

/// 모드 선택 단독 행 — 전체 라벨(6개 버튼)에 필요한 최소 폭
const double kModeRowFullLabelsMinWidth = 480.0;

/// @deprecated [kModeRowFullLabelsMinWidth] 사용 — 통합 툴바도 모드 영역 폭 기준으로 판단
const double kToolbarFullModeLabelsMinWidth = 880.0;

/// 툴바 [totalWidth] 기준으로 전체/축약 라벨 결정
ExchangeModeLabelStyle resolveModeLabelStyle({required double totalWidth}) {
  return totalWidth >= kModeRowFullLabelsMinWidth
      ? ExchangeModeLabelStyle.full
      : ExchangeModeLabelStyle.compact;
}

/// 툴바 그룹 구분선 실제 점유 폭 (선 1px + 좌우 margin 6px)
const double kToolbarGroupDividerWidth = 13.0;

/// 모드 버튼 사이 간격 ([ExchangeModeSelector]의 padding right)
const double kModeButtonSpacing = 4.0;

/// 통합 툴바 1줄/2줄 및 모드 라벨 스타일 결정 결과
class UnifiedToolbarLayoutDecision {
  final bool useSingleRow;
  final ExchangeModeLabelStyle modeLabelStyle;

  const UnifiedToolbarLayoutDecision({
    required this.useSingleRow,
    required this.modeLabelStyle,
  });
}

/// 가용 폭과 실제 콘텐츠 최소 폭을 비교해 1줄 유지 여부를 결정합니다.
///
/// 전체 라벨이 들어가면 full, 아니면 compact로 1줄을 시도하고
/// 둘 다 불가하면 2줄(모드 단독 행)로 전환합니다.
UnifiedToolbarLayoutDecision resolveUnifiedToolbarLayout({
  required double totalWidth,
  required bool isDualExchangeEnabled,
  required bool showTeacherCount,
  int teacherCount = 0,
}) {
  for (final labelStyle in [
    ExchangeModeLabelStyle.full,
    ExchangeModeLabelStyle.compact,
  ]) {
    final minWidth = estimateUnifiedToolbarMinWidth(
      isDualExchangeEnabled: isDualExchangeEnabled,
      labelStyle: labelStyle,
      showTeacherCount: showTeacherCount,
      teacherCount: teacherCount,
    );
    if (totalWidth >= minWidth) {
      return UnifiedToolbarLayoutDecision(
        useSingleRow: true,
        modeLabelStyle: labelStyle,
      );
    }
  }

  return UnifiedToolbarLayoutDecision(
    useSingleRow: false,
    modeLabelStyle: resolveModeLabelStyle(totalWidth: totalWidth),
  );
}

/// 통합 툴바 1줄 배치에 필요한 최소 가로 폭 (모드·실행도구·줌·교사 수 합산)
double estimateUnifiedToolbarMinWidth({
  required bool isDualExchangeEnabled,
  required ExchangeModeLabelStyle labelStyle,
  required bool showTeacherCount,
  int teacherCount = 0,
  bool withActionButtonLabels = false,
}) {
  const horizontalPadding = 8.0;

  var width = horizontalPadding;
  width += estimateModeSelectorWidth(
    isDualExchangeEnabled: isDualExchangeEnabled,
    labelStyle: labelStyle,
  );
  // 모드 선택 영역과 실행 도구 사이 구분선
  width += kToolbarGroupDividerWidth;
  width += _estimateZoomTeacherActionWidth(
    showTeacherCount: showTeacherCount,
    withButtonLabels: withActionButtonLabels,
    teacherCount: teacherCount,
  );
  width += horizontalPadding;
  return width;
}

/// [줌][교사수][실행 도구] 묶음의 최소 가로 폭
///
/// 1줄/2줄 레이아웃 모두 [_buildZoomTeacherAndActionItems] 위젯을 공유하므로
/// 폭 추정도 이 헬퍼 하나로 통일해 양쪽이 어긋나지 않도록 합니다.
double _estimateZoomTeacherActionWidth({
  required bool showTeacherCount,
  required bool withButtonLabels,
  int teacherCount = 0,
}) {
  const gap = 8.0;

  var width = kZoomControlWidth;
  width += gap;
  if (showTeacherCount) {
    width += estimateTeacherCountWidth(teacherCount);
    width += gap;
  }
  width += estimateActionToolbarItemsWidth(withButtonLabels: withButtonLabels);
  return width;
}

/// 실행 도구 2번째 행(줌·교사수·원본·초기화 등)만의 최소 가로 폭
double estimateActionToolbarRowMinWidth({
  required bool showTeacherCount,
  required bool withButtonLabels,
  int teacherCount = 0,
}) {
  // 행 좌우 패딩(SizedBox 8px × 2)
  const horizontalPadding = 16.0;

  return horizontalPadding +
      _estimateZoomTeacherActionWidth(
        showTeacherCount: showTeacherCount,
        withButtonLabels: withButtonLabels,
        teacherCount: teacherCount,
      );
}

/// 실행 도구 버튼에 라벨을 표시할지 결정
///
/// - 2줄 레이아웃: 실행 도구 행만 전체 폭을 쓰므로 해당 행 기준으로 판단
/// - 1줄 레이아웃: 모드 선택 + 실행 도구 전체 폭 기준으로 판단
bool shouldShowActionButtonLabels({
  required double totalWidth,
  required bool useSingleRow,
  required bool isDualExchangeEnabled,
  required bool showTeacherCount,
  required ExchangeModeLabelStyle modeLabelStyle,
  int teacherCount = 0,
}) {
  if (!useSingleRow) {
    return totalWidth >=
        estimateActionToolbarRowMinWidth(
          showTeacherCount: showTeacherCount,
          withButtonLabels: true,
          teacherCount: teacherCount,
        );
  }

  return totalWidth >=
      estimateUnifiedToolbarMinWidth(
        isDualExchangeEnabled: isDualExchangeEnabled,
        labelStyle: modeLabelStyle,
        showTeacherCount: showTeacherCount,
        teacherCount: teacherCount,
        withActionButtonLabels: true,
      );
}

/// [ExchangeModeSelector] 최소 폭 (내부 그룹 구분선 포함)
double estimateModeSelectorWidth({
  required bool isDualExchangeEnabled,
  required ExchangeModeLabelStyle labelStyle,
}) {
  const viewEditModes = [ExchangeMode.view, ExchangeMode.nonExchangeableEdit];
  final exchangeModes =
      isDualExchangeEnabled
          ? const [
            ExchangeMode.oneToOneExchange,
            ExchangeMode.dualExchange,
            ExchangeMode.circularExchange,
            ExchangeMode.supplementExchange,
          ]
          : const [
            ExchangeMode.oneToOneExchange,
            ExchangeMode.circularExchange,
            ExchangeMode.supplementExchange,
          ];

  double groupWidth(List<ExchangeMode> modes) {
    return modes
        .map(
          (mode) => estimateModeButtonWidth(mode: mode, labelStyle: labelStyle),
        )
        .fold(0.0, (sum, itemWidth) => sum + itemWidth);
  }

  return groupWidth(viewEditModes) +
      kToolbarGroupDividerWidth +
      groupWidth(exchangeModes);
}

/// 모드 버튼 1개 폭 (오른쪽 [kModeButtonSpacing] 포함)
double estimateModeButtonWidth({
  required ExchangeMode mode,
  required ExchangeModeLabelStyle labelStyle,
}) {
  if (labelStyle == ExchangeModeLabelStyle.compact) {
    return kExchangeModeButtonWidth + kModeButtonSpacing;
  }

  final label = mode.displayName;
  final textWidth = _measureToolbarTextWidth(
    label,
    fontSize: kModeButtonFontSize,
    fontWeight: FontWeight.w600,
  );
  // 아이콘 + 간격 + 텍스트 + 좌우 패딩(10px × 2), 최소 폭 84px
  final innerWidth = (kModeButtonIconSize + 4 + textWidth + 20).clamp(
    kExchangeModeButtonWidth,
    double.infinity,
  );
  return innerWidth + kModeButtonSpacing;
}

/// 원본 스위치 + 전체삭제 + undo/redo 그룹 최소 폭
double estimateActionToolbarItemsWidth({bool withButtonLabels = false}) {
  final switchLabelWidth = _measureToolbarTextWidth(
    '교체',
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  const switchAreaWidth = 34.0;
  const labelToSwitchGap = 4.0;
  const checkboxToDeleteGap = 6.0;
  const compactButtonSize = kCompactToolbarHeight;
  const buttonGap = 4.0;

  final switchPart =
      switchLabelWidth +
      labelToSwitchGap +
      switchAreaWidth +
      checkboxToDeleteGap;

  if (!withButtonLabels) {
    return switchPart +
        compactButtonSize + // 전체 초기화
        buttonGap +
        compactButtonSize + // 되돌리기
        buttonGap +
        compactButtonSize + // 다시실행
        buttonGap +
        compactButtonSize; // 선택교체 삭제
  }

  double labeledButtonWidth(String label) {
    final textWidth = _measureToolbarTextWidth(
      label,
      fontSize: kAdaptiveActionButtonFontSize,
      fontWeight: FontWeight.w600,
    );
    // 아이콘 + 간격 + 텍스트 + 좌우 패딩 (위젯 실제 레이아웃과 동일 상수 사용)
    return (kAdaptiveActionButtonIconSize +
            kAdaptiveActionButtonIconLabelGap +
            textWidth +
            kAdaptiveActionButtonHPadding)
        .clamp(compactButtonSize, double.infinity);
  }

  return switchPart +
      labeledButtonWidth('전체 초기화') +
      buttonGap +
      labeledButtonWidth('되돌리기') +
      buttonGap +
      labeledButtonWidth('다시실행') +
      buttonGap +
      labeledButtonWidth('선택교체 삭제');
}

/// 줌 컨트롤 ([ZoomControlWidget] IconButton constraints 합산)
const double kZoomControlWidth = 110.0;

/// 교사 수 표시 ([TeacherCountWidget]) 최소 폭
double estimateTeacherCountWidth(int teacherCount) {
  final textWidth = _measureToolbarTextWidth(
    '$teacherCount',
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
  return 14 + 2 + textWidth;
}

double _measureToolbarTextWidth(
  String text, {
  required double fontSize,
  required FontWeight fontWeight,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// 교체 모드 선택 위젯 (컴팩트 가로 배치)
///
/// [labelStyle]에 따라 전체 라벨 또는 축약 라벨을 표시합니다.
/// 2중 교체는 홈>설정에서 활성화한 경우에만 메뉴에 표시됩니다.
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
    ExchangeMode.dualExchange,
    ExchangeMode.circularExchange,
    ExchangeMode.supplementExchange,
  ];

  List<ExchangeMode> _visibleExchangeModes(
    bool isDualExchangeEnabled,
    bool isCircularExchangeEnabled,
  ) {
    return _exchangeModes.where((mode) {
      if (mode == ExchangeMode.dualExchange && !isDualExchangeEnabled) {
        return false;
      }
      if (mode == ExchangeMode.circularExchange && !isCircularExchangeEnabled) {
        return false;
      }
      return true;
    }).toList();
  }

  void _handleModeChanged(
    ExchangeMode mode,
    bool isDualExchangeEnabled,
    bool isCircularExchangeEnabled,
  ) {
    if (mode == ExchangeMode.dualExchange && !isDualExchangeEnabled) {
      return;
    }
    if (mode == ExchangeMode.circularExchange && !isCircularExchangeEnabled) {
      return;
    }

    onModeChanged(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDualExchangeEnabled = ref.watch(dualExchangeEnabledProvider);
    final isCircularExchangeEnabled = ref.watch(
      circularExchangeEnabledProvider,
    );
    final exchangeModes = _visibleExchangeModes(
      isDualExchangeEnabled,
      isCircularExchangeEnabled,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._buildModeGroup(
          _viewEditModes,
          isDualExchangeEnabled,
          isCircularExchangeEnabled,
        ),
        const _ToolbarGroupDivider(),
        ..._buildModeGroup(
          exchangeModes,
          isDualExchangeEnabled,
          isCircularExchangeEnabled,
        ),
      ],
    );
  }

  List<Widget> _buildModeGroup(
    List<ExchangeMode> modes,
    bool isDualExchangeEnabled,
    bool isCircularExchangeEnabled,
  ) {
    return modes.map((mode) {
      final isSelected = mode == currentMode;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: _ModeToolbarButton(
          mode: mode,
          isSelected: isSelected,
          labelStyle: labelStyle,
          onPressed:
              () => _handleModeChanged(
                mode,
                isDualExchangeEnabled,
                isCircularExchangeEnabled,
              ),
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
    final tokens = context.tokens;
    final backgroundColor =
        isSelected
            ? mode.color.withValues(alpha: 0.12)
            : tokens.sectionBackground;
    final foregroundColor = isSelected ? mode.color : tokens.textSecondary;
    final borderColor = isSelected ? mode.color : tokens.cardBorder;
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
    final tokens = context.tokens;
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: tokens.textMuted,
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
        final tokens = context.tokens;

        return Container(
          height: kExchangeUnifiedToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(
              bottom: BorderSide(color: tokens.cardBorder, width: 1),
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
