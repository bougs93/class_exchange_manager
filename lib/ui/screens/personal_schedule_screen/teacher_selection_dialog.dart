import 'package:flutter/material.dart';
import 'personal_schedule_constants.dart';

/// 교사 선택 다이얼로그 위젯
///
/// 전체 교사 목록을 리스트 형태로 표시하고 선택할 수 있는 다이얼로그입니다.
class TeacherSelectionDialog extends StatefulWidget {
  /// 선택 가능한 교사명 목록
  final List<String> teacherNames;

  /// 현재 선택된 교사명 (없으면 null)
  final String? currentTeacherName;

  const TeacherSelectionDialog({
    super.key,
    required this.teacherNames,
    this.currentTeacherName,
  });

  @override
  State<TeacherSelectionDialog> createState() => _TeacherSelectionDialogState();
}

class _TeacherSelectionDialogState extends State<TeacherSelectionDialog> {
  /// 검색어 필터링용
  String _searchQuery = '';

  /// 검색어로 필터링된 교사명 목록
  List<String> get _filteredTeacherNames {
    if (_searchQuery.isEmpty) {
      return widget.teacherNames;
    }

    // 검색어가 포함된 교사명만 필터링 (대소문자 구분 없음)
    return widget.teacherNames
        .where((name) => name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: PersonalScheduleConstants.teacherSelectionDialogWidth,
        height: PersonalScheduleConstants.teacherSelectionDialogHeight,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 헤더
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '교사 선택',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '닫기',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 검색 필드
            TextField(
              decoration: InputDecoration(
                hintText: '교사명 검색...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // 교사 목록
            Expanded(
              child: _filteredTeacherNames.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? '교사 목록이 비어있습니다'
                                : '검색 결과가 없습니다',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTeacherNames.length,
                      itemBuilder: (context, index) {
                        final teacherName = _filteredTeacherNames[index];
                        final isSelected = teacherName == widget.currentTeacherName;

                        return ListTile(
                          // 현재 선택된 교사는 체크 아이콘 표시
                          leading: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                )
                              : const Icon(Icons.person_outline),
                          title: Text(teacherName),
                          // 현재 선택된 교사는 배경색 변경
                          tileColor: isSelected
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                              : null,
                          onTap: () {
                            // 선택한 교사명 반환하고 다이얼로그 닫기
                            Navigator.of(context).pop(teacherName);
                          },
                        );
                      },
                    ),
            ),

            // 하단 정보
            if (widget.teacherNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '총 ${widget.teacherNames.length}명의 교사',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
