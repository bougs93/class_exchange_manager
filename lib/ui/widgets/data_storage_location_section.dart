import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/storage_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/logger.dart';

/// 데이터 JSON 저장 폴더 경로를 표시하는 공통 위젯
///
/// 기본적으로 접혀 있으며, 탭하면 경로·설명·복사 버튼을 표시합니다.
class DataStorageLocationSection extends StatefulWidget {
  const DataStorageLocationSection({super.key, this.compact = false});

  /// true: 홈 화면용 작은 글꼴·여백
  final bool compact;

  @override
  State<DataStorageLocationSection> createState() =>
      DataStorageLocationSectionState();
}

class DataStorageLocationSectionState
    extends State<DataStorageLocationSection> {
  String? _dataDirectoryPath;
  String _dataLocationDescription = '';
  bool _isLoading = false;
  bool _hasLoaded = false;

  /// 외부에서 경로 새로고침 (데이터 삭제 후 등)
  Future<void> reload() async {
    await _loadPath();
  }

  Future<void> _loadPath() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final storageService = StorageService();
      final path = await storageService.getDataDirectoryPath();
      final description = storageService.getDataLocationDescription();

      if (mounted) {
        setState(() {
          _dataDirectoryPath = path;
          _dataLocationDescription = description;
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      AppLogger.error('데이터 저장 경로 로드 중 오류: $e', e);
      if (mounted) {
        setState(() {
          _dataDirectoryPath = null;
          _dataLocationDescription = '저장 경로를 불러올 수 없습니다.';
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    }
  }

  void _onExpansionChanged(bool expanded) {
    if (expanded && !_hasLoaded && !_isLoading) {
      _loadPath();
    }
  }

  Future<void> _copyPath() async {
    final path = _dataDirectoryPath;
    if (path == null || path.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('저장 경로가 클립보드에 복사되었습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final titleSize = widget.compact ? 12.0 : 16.0;
    final bodySize = widget.compact ? 11.0 : 14.0;
    final pathSize = widget.compact ? 11.0 : 13.0;

    return Container(
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          // ExpansionTile 내부 ListTile이 배경색 있는 Container에 가려지지 않도록
          // 잉크를 그릴 자체 Material 제공 (Flutter 디버그 assertion 요구)
          color: Colors.transparent,
          child: ExpansionTile(
            initiallyExpanded: false,
            onExpansionChanged: _onExpansionChanged,
            tilePadding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: widget.compact ? 0 : 4,
            ),
            childrenPadding: EdgeInsets.fromLTRB(
              widget.compact ? 8 : 16,
              0,
              widget.compact ? 8 : 16,
              widget.compact ? 8 : 12,
            ),
            leading: Icon(
              Icons.folder_outlined,
              size: widget.compact ? 18 : 22,
              color: tokens.primary,
            ),
            title: Text(
              '데이터 저장 위치',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle:
                widget.compact
                    ? Text(
                      '탭하여 경로 확인',
                      style: TextStyle(
                        fontSize: 10,
                        color: tokens.textSecondary,
                      ),
                    )
                    : Text(
                      '탭하여 JSON 저장 폴더 경로 확인',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
            children: [_buildExpandedContent(bodySize, pathSize)],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(double bodySize, double pathSize) {
    final tokens = context.tokens;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final path = _dataDirectoryPath ?? '(경로를 불러오지 못했습니다)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _dataLocationDescription,
                style: TextStyle(
                  fontSize: bodySize,
                  color: tokens.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              tooltip: '경로 새로고침',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: reload,
              icon: Icon(Icons.refresh, size: widget.compact ? 18 : 22),
            ),
          ],
        ),
        SizedBox(height: widget.compact ? 6 : 10),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(widget.compact ? 8 : 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(color: tokens.cardBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            path,
            style: TextStyle(fontSize: pathSize, height: 1.35),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _dataDirectoryPath != null ? _copyPath : null,
            icon: Icon(Icons.copy, size: widget.compact ? 16 : 18),
            label: Text(
              '경로 복사',
              style: TextStyle(fontSize: widget.compact ? 12 : 14),
            ),
          ),
        ),
      ],
    );
  }
}
