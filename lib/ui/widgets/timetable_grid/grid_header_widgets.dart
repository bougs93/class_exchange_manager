import 'package:flutter/material.dart';
import '../../../utils/simplified_timetable_theme.dart';

/// 컴팩트 툴바 공통 높이 (모드 선택·실행 도구·줌 컨트롤 공통)
const double kCompactToolbarHeight = 28.0;

/// @deprecated 내부 호환용 — [kCompactToolbarHeight] 사용
const double _kCompactToolbarHeight = kCompactToolbarHeight;

/// 아이콘만 표시 + Tooltip (컴팩트 툴바용)
class CompactToolbarIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double iconSize;

  /// 버튼 정사각형 크기 (기본 28px)
  final double size;

  const CompactToolbarIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    this.iconSize = 16,
    this.size = _kCompactToolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final effectiveBackground =
        isEnabled ? backgroundColor : Colors.grey.shade100;
    final effectiveForeground =
        isEnabled ? foregroundColor : Colors.grey.shade400;
    final effectiveBorder = isEnabled ? borderColor : Colors.grey.shade300;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: effectiveBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: effectiveBorder),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: effectiveForeground),
          ),
        ),
      ),
    );
  }
}

/// 아이콘 + 텍스트 라벨 (컴팩트 툴바용, 교체 실행 버튼 등)
class CompactToolbarLabelButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  /// 최소 버튼 너비 (긴 라벨용, null이면 텍스트 길이에 맞춤)
  final double? minWidth;

  /// 고정 버튼 너비 (동일 폭 버튼 그룹용)
  final double? width;

  /// 버튼 높이 (기본 28px, 사이드바 등 큰 버튼용으로 조절)
  final double height;

  /// 라벨 글자 크기
  final double fontSize;

  /// 아이콘 크기
  final double iconSize;

  const CompactToolbarLabelButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    this.minWidth,
    this.width,
    this.height = _kCompactToolbarHeight,
    this.fontSize = 11,
    this.iconSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    // onPressed가 null이면 비활성(회색) 스타일 적용
    final isEnabled = onPressed != null;
    final effectiveBackground =
        isEnabled ? backgroundColor : Colors.grey.shade100;
    final effectiveForeground =
        isEnabled ? foregroundColor : Colors.grey.shade400;
    final effectiveBorder = isEnabled ? borderColor : Colors.grey.shade300;

    return Tooltip(
      message: isEnabled ? tooltip : '$tooltip (경로를 선택하세요)',
      child: Material(
        color: effectiveBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: effectiveBorder),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: height,
            width: width,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth ?? 0),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (minWidth != null || width != null) ? 10 : 6,
                ),
                child: Row(
                  mainAxisSize:
                      width != null ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: iconSize, color: effectiveForeground),
                    const SizedBox(width: 4),
                    // 고정 폭일 때만 말줄임 — minWidth·자동 폭이면 라벨 전체 표시
                    if (width != null)
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: effectiveForeground,
                          ),
                        ),
                      )
                    else
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: effectiveForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 교체 리스트 전체 초기화 버튼
class ResetExchangeListButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ResetExchangeListButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CompactToolbarIconButton(
      onPressed: onPressed,
      icon: Icons.delete_forever,
      tooltip: '결보강 전체 초기화',
      backgroundColor: Colors.grey.shade100,
      foregroundColor: Colors.grey.shade700,
      borderColor: Colors.grey.shade400,
    );
  }
}

/// 확대/축소 컨트롤 위젯
class ZoomControlWidget extends StatelessWidget {
  final int zoomPercentage;
  final double zoomFactor;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  const ZoomControlWidget({
    super.key,
    required this.zoomPercentage,
    required this.zoomFactor,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kCompactToolbarHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: zoomPercentage != 100 ? onResetZoom : null,
            icon: const Icon(Icons.refresh, size: 15),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 26,
              minHeight: _kCompactToolbarHeight,
            ),
            color:
                zoomPercentage != 100
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
            tooltip: '확대/축소 초기화',
          ),
          IconButton(
            onPressed: zoomFactor > minZoom ? onZoomOut : null,
            icon: const Icon(Icons.zoom_out, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: _kCompactToolbarHeight,
            ),
            color: zoomFactor > minZoom ? Colors.blue : Colors.grey,
            tooltip: '축소',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$zoomPercentage%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          IconButton(
            onPressed: zoomFactor < maxZoom ? onZoomIn : null,
            icon: const Icon(Icons.zoom_in, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: _kCompactToolbarHeight,
            ),
            color: zoomFactor < maxZoom ? Colors.blue : Colors.grey,
            tooltip: '확대',
          ),
        ],
      ),
    );
  }
}

/// 교사 수 표시 (아이콘 + 숫자, Tooltip으로 전체 설명)
class TeacherCountWidget extends StatelessWidget {
  final int teacherCount;

  const TeacherCountWidget({super.key, required this.teacherCount});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '교사 $teacherCount명',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 2),
          Text(
            '$teacherCount',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 셀 테마 예시 위젯
class CellThemeLegend extends StatelessWidget {
  const CellThemeLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem(
          backgroundColor: SimplifiedTimetableTheme.selectedColorLight,
          borderColor: SimplifiedTimetableTheme.selectedCellBorderColor,
          borderWidth: SimplifiedTimetableTheme.selectedCellBorderWidth,
          label: '선택한 수업',
        ),
        const SizedBox(width: 8),
        _buildLegendItem(
          backgroundColor: SimplifiedTimetableTheme.defaultColor,
          borderColor:
              SimplifiedTimetableTheme.selectedTeacherDestinationBorderColor,
          borderWidth:
              SimplifiedTimetableTheme.selectedTeacherDestinationBorderWidth,
          label: '교체후 수업',
        ),
        const SizedBox(width: 8),
        _buildLegendItem(
          backgroundColor: SimplifiedTimetableTheme.defaultColor,
          borderColor: SimplifiedTimetableTheme.exchangedSourceCellBorderColor,
          borderWidth: SimplifiedTimetableTheme.exchangedSourceCellBorderWidth,
          label: '비워진 수업',
        ),
        const SizedBox(width: 8),
        _buildLegendItem(
          backgroundColor:
              SimplifiedTimetableTheme.exchangedDestinationCellBackgroundColor,
          borderColor: Colors.transparent,
          borderWidth: 0,
          label: '채워진 수업 ',
        ),
        const SizedBox(width: 8),
        _buildLegendItem(
          backgroundColor: SimplifiedTimetableTheme.nonExchangeableColor,
          borderColor: Colors.transparent,
          borderWidth: 0,
          label: '교체불가 수업',
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color backgroundColor,
    required Color borderColor,
    required double borderWidth,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: backgroundColor,
            border:
                borderWidth > 0
                    ? Border.all(color: borderColor, width: borderWidth)
                    : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

/// 교체 적용 스위치 위젯
class ExchangeViewCheckbox extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool?> onChanged;

  const ExchangeViewCheckbox({
    super.key,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 스위치 OFF → 원본 시간표, ON → 교체된 시간표
    final label = isEnabled ? '교체' : '원본';

    return Tooltip(
      message: isEnabled ? '교체된 시간표' : '원본 시간표',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isEnabled ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 4),
          // scale(0.6) 적용 시 Switch 기본 레이아웃 폭(~52px)이 남아 간격이 벌어지므로
          // OverflowBox로 시각 크기만큼만 공간을 차지하게 합니다.
          SizedBox(
            width: 34,
            height: 22,
            child: OverflowBox(
              maxWidth: 52,
              maxHeight: 32,
              alignment: Alignment.centerLeft,
              child: Transform.scale(
                scale: 0.6,
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: isEnabled,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeThumbColor: Colors.blue.shade600,
                  activeTrackColor: Colors.blue.shade200,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 교체 작업 버튼 그룹 (되돌리기·다시 실행 — 교체 버튼은 사이드바 헤더로 이동)
class ExchangeActionButtons extends StatelessWidget {
  final VoidCallback? onUndo;
  final VoidCallback? onRepeat;
  final Future<void> Function()? onDelete;
  final bool showDeleteButton;

  const ExchangeActionButtons({
    super.key,
    required this.onUndo,
    required this.onRepeat,
    this.onDelete,
    required this.showDeleteButton,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactToolbarIconButton(
          onPressed: onUndo,
          icon: Icons.undo,
          tooltip: onUndo != null ? '되돌리기' : '되돌리기 (불가)',
          backgroundColor: Colors.orange.shade100,
          foregroundColor: Colors.orange.shade700,
          borderColor: Colors.orange.shade300,
        ),
        const SizedBox(width: 4),
        CompactToolbarIconButton(
          onPressed: onRepeat,
          icon: Icons.redo,
          tooltip: onRepeat != null ? '다시 실행' : '다시 실행 (불가)',
          backgroundColor: Colors.purple.shade100,
          foregroundColor: Colors.purple.shade700,
          borderColor: Colors.purple.shade300,
        ),
        const SizedBox(width: 4),
        if (showDeleteButton && onDelete != null)
          CompactToolbarIconButton(
            onPressed: () async => await onDelete!(),
            icon: Icons.delete_outline,
            tooltip: '선택 교체 삭제',
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red.shade700,
            borderColor: Colors.red.shade300,
          ),
      ],
    );
  }
}
