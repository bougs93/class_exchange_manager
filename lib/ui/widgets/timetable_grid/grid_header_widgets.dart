import 'package:flutter/material.dart';

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
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 초기화 버튼
          IconButton(
            onPressed: zoomPercentage != 100 ? onResetZoom : null,
            icon: const Icon(Icons.refresh, size: 16),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            color: zoomPercentage != 100 ? Colors.grey.shade600 : Colors.grey.shade400,
            tooltip: '확대/축소 초기화',
          ),
          // 축소 버튼
          IconButton(
            onPressed: zoomFactor > minZoom ? onZoomOut : null,
            icon: const Icon(Icons.zoom_out, size: 18),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            color: zoomFactor > minZoom ? Colors.blue : Colors.grey,
            tooltip: '축소',
          ),
          // 현재 확대 비율 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$zoomPercentage%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          // 확대 버튼
          IconButton(
            onPressed: zoomFactor < maxZoom ? onZoomIn : null,
            icon: const Icon(Icons.zoom_in, size: 18),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            color: zoomFactor < maxZoom ? Colors.blue : Colors.grey,
            tooltip: '확대',
          ),
        ],
      ),
    );
  }
}

/// 교사 수 표시 위젯
class TeacherCountWidget extends StatelessWidget {
  final int teacherCount;

  const TeacherCountWidget({
    super.key,
    required this.teacherCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        '교사 $teacherCount명',
        style: TextStyle(
          fontSize: 12,
          color: Colors.green.shade700,
          fontWeight: FontWeight.w500,
        ),
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
        // 타겟 셀 예시
        _buildLegendItem(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255), // 흰색
          borderColor: const Color(0xFFFF0000), // 빨간색
          borderWidth: 2.5,
          label: '교체후 수업',
        ),
        const SizedBox(width: 8),
        
        // 교체된 소스 셀 예시
        _buildLegendItem(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255), // 흰색
          borderColor: const Color(0xFF2196F3), // 파란색
          borderWidth: 2.0,
          label: '비워진 수업',
        ),
        const SizedBox(width: 8),
        
        // 교체된 목적지 셀 예시
        _buildLegendItem(
          backgroundColor: const Color.fromARGB(255, 144, 199, 245), // 연한 파란색
          borderColor: Colors.transparent,
          borderWidth: 0,
          label: '채워진 수업 ',
        ),
        const SizedBox(width: 8),
        
        // 교체불가 셀 예시
        _buildLegendItem(
          backgroundColor: const Color(0xFFFFCDD2), // 연한 빨간색
          borderColor: Colors.transparent,
          borderWidth: 0,
          label: '교체불가 수업',
        ),
      ],
    );
  }

  /// 개별 범례 아이템 생성
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
            border: borderWidth > 0 
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

/// 교체 뷰 스위치 위젯
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 0.8,
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
          Text(
            '교체 뷰',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isEnabled ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 교체 작업 버튼 그룹 위젯
class ExchangeActionButtons extends StatelessWidget {
  final VoidCallback onUndo;
  final VoidCallback onRepeat;
  final Future<void> Function()? onDelete;
  final VoidCallback? onExchange;
  final bool showDeleteButton;
  final bool showExchangeButton;

  const ExchangeActionButtons({
    super.key,
    required this.onUndo,
    required this.onRepeat,
    this.onDelete,
    this.onExchange,
    required this.showDeleteButton,
    required this.showExchangeButton,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 되돌리기 버튼
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: onUndo,
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade100,
              foregroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(50, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: BorderSide(color: Colors.orange.shade300),
              ),
            ),
          ),
        ),

        // 다시 반복 버튼
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: onRepeat,
            icon: const Icon(Icons.redo, size: 16),
            label: const Text('', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade100,
              foregroundColor: Colors.purple.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(50, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: BorderSide(color: Colors.purple.shade300),
              ),
            ),
          ),
        ),

        // 삭제 버튼
        if (showDeleteButton && onDelete != null) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () async => await onDelete!(),
              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade700),
              label: Text('삭제', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(60, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
          ),
        ],

        // 교체 버튼
        if (showExchangeButton) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: onExchange,
              icon: Icon(
                Icons.swap_horiz,
                size: 16,
                color: onExchange != null ? Colors.blue.shade700 : Colors.grey.shade400,
              ),
              label: Text(
                '교체',
                style: TextStyle(
                  fontSize: 12,
                  color: onExchange != null ? Colors.blue.shade700 : Colors.grey.shade400,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: onExchange != null ? Colors.blue.shade100 : Colors.grey.shade100,
                foregroundColor: onExchange != null ? Colors.blue.shade700 : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(60, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                  side: BorderSide(
                    color: onExchange != null ? Colors.blue.shade300 : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
