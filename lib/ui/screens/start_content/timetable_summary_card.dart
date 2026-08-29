import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/print_profile.dart';
import '../../../models/timetable_registry.dart';
import '../../../providers/print_profile_provider.dart';
import '../../../providers/timetable_registry_provider.dart';
import '../../../providers/timetable_summary_provider.dart';
import '../../../providers/timetable_teachers_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/logger.dart';
import '../../widgets/app_content_card.dart';

/// 홈 화면의 시간표 카드
///
/// 시간표 → 교사 → 계획서 계층을 중첩 레이아웃으로 표현합니다.
/// 교사·학교명은 전역 설정이 아니라 **활성 시간표의 속성**이므로 이 카드 안쪽에
/// 들여쓰기해 배치하며, 시간표를 전환하면 그 아래가 통째로 바뀝니다(문서 §3②).
class TimetableSummaryCard extends ConsumerStatefulWidget {
  const TimetableSummaryCard({
    super.key,
    required this.onAddTimetable,
    required this.onOpenManager,
    required this.onOpenProfiles,
    this.errorSection,
  });

  /// [＋ 시간표 추가] — 엑셀 선택 → 등록 흐름
  final Future<void> Function() onAddTimetable;

  /// [시간표 관리 >] — 관리 화면 열기
  final Future<void> Function() onOpenManager;

  /// [관리 >] — 계획서 편집 화면(문서 출력 탭)으로 이동
  final VoidCallback onOpenProfiles;

  /// 파일 로드 오류 배너 (없으면 null)
  final Widget? errorSection;

  @override
  ConsumerState<TimetableSummaryCard> createState() =>
      _TimetableSummaryCardState();
}

class _TimetableSummaryCardState extends ConsumerState<TimetableSummaryCard> {
  /// 라벨 칼럼 폭
  ///
  /// 아이콘(16) + 간격(6) + 한글 3자(약 38) = 60px 이상이 필요하다.
  /// 좁으면 '학교명'·'계획서' 라벨에서 RenderFlex 오버플로가 발생한다.
  static const double _labelWidth = 76;

  /// 입력란 아래 보조 문구의 들여쓰기 (라벨 폭 + 라벨/필드 간격)
  static const double _hintIndent = _labelWidth + 8;

  final TextEditingController _schoolController = TextEditingController();
  final FocusNode _schoolFocus = FocusNode();

  /// 컨트롤러에 반영된 시간표 ID (전환 감지용)
  String? _syncedEntryId;

  @override
  void initState() {
    super.initState();
    // 포커스를 잃을 때 자동 저장 — 별도 [저장] 버튼을 두지 않는다
    _schoolFocus.addListener(() {
      if (!_schoolFocus.hasFocus) _saveSchoolName();
    });
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _schoolFocus.dispose();
    super.dispose();
  }

  /// 활성 시간표가 바뀌면 학교명 입력란을 그 시간표 값으로 교체
  void _syncSchoolField(TimetableRegistryEntry? entry) {
    if (entry?.id == _syncedEntryId) return;
    _syncedEntryId = entry?.id;
    _schoolController.text = entry?.schoolName ?? '';
  }

  /// 실제로 선택 가능한 교사 (엑셀 교사 목록에 없으면 null)
  ///
  /// 원본 파일이 바뀌어 교사가 사라졌는데 레지스트리에는 남아 있을 수 있다.
  /// 이때 목록에 없는 이름을 선택된 것처럼 보여주면 안 된다.
  String? _resolvedTeacher(TimetableRegistryEntry entry) {
    final teachers = ref.read(activeTimetableTeachersProvider);
    final name = entry.teacherName;
    if (name == null || !teachers.contains(name)) return null;
    return name;
  }

  /// 학교명 저장 (변경이 없으면 아무것도 하지 않음)
  Future<void> _saveSchoolName() async {
    final entry = ref.read(activeTimetableEntryProvider);
    if (entry == null) return;

    final value = _schoolController.text.trim();
    if (value == (entry.schoolName ?? '')) return;

    await ref
        .read(timetableRegistryProvider.notifier)
        .updateTeacherAndSchool(entry.id, schoolName: value);
    AppLogger.info('학교명 저장: ${entry.name} -> $value');
  }

  /// 교사 선택 (드롭다운 — 엑셀 교사 목록에서만 고를 수 있다)
  Future<void> _selectTeacher(String? teacher) async {
    final entry = ref.read(activeTimetableEntryProvider);
    if (entry == null || teacher == null) return;

    await ref
        .read(timetableRegistryProvider.notifier)
        .updateTeacherAndSchool(entry.id, teacherName: teacher);
  }

  /// 시간표 전환
  Future<void> _switchTo(String id) async {
    final ok = await ref
        .read(timetableRegistryProvider.notifier)
        .switchActive(id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시간표 전환에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(activeTimetableEntryProvider);
    _syncSchoolField(entry);

    return AppContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry == null)
            _buildEmptyState()
          else
            ..._buildActiveState(entry),
          if (widget.errorSection != null) widget.errorSection!,
        ],
      ),
    );
  }

  // ===== 빈 상태 =====

  /// 등록된 시간표가 없을 때
  ///
  /// 교사·학교명·계획서 영역은 아예 그리지 않는다 — 시간표가 없으면 교사 목록
  /// 자체가 존재하지 않으므로 빈 입력란을 보여주는 것은 거짓 정보다.
  Widget _buildEmptyState() {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined, size: 40, color: tokens.textMuted),
          const SizedBox(height: 12),
          Text(
            '등록된 시간표가 없습니다',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '엑셀 시간표 파일을 등록하면 교체 관리를 시작합니다',
            style: TextStyle(fontSize: 12.5, color: tokens.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => widget.onAddTimetable(),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('시간표 파일 등록'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 활성 상태 =====

  List<Widget> _buildActiveState(TimetableRegistryEntry entry) {
    return [
      _buildHeader(entry),
      const SizedBox(height: 12),
      _buildNestedDetails(entry),
    ];
  }

  /// 헤더: 시간표 이름 + 전환 드롭다운 + 원본 파일 요약
  Widget _buildHeader(TimetableRegistryEntry entry) {
    final tokens = context.tokens;
    final teacherCount = ref.watch(activeTimetableTeachersProvider).length;

    final subtitleParts = <String>[
      if (entry.fileName.isNotEmpty) entry.fileName,
      if (teacherCount > 0) '교사 $teacherCount명',
      '${entry.registeredAt.month}/${entry.registeredAt.day} 등록',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.event_note, size: 20, color: tokens.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tokens.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitleParts.join(' · '),
                style: TextStyle(fontSize: 12, color: tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildSwitchMenu(entry),
        const SizedBox(width: 4),
        _buildFooterActions(),
      ],
    );
  }

  /// 전환 메뉴 — 시간표 진입점을 이 하나로 통합한다
  ///
  /// 각 행에 그 시간표의 교사·계획서 수를 함께 보여줘, 전환하면 무엇이 따라오는지
  /// 고르기 전에 알 수 있게 한다.
  Widget _buildSwitchMenu(TimetableRegistryEntry active) {
    final tokens = context.tokens;
    final registry = ref.watch(timetableRegistryProvider).valueOrNull;
    final entries = registry?.timetables ?? const <TimetableRegistryEntry>[];

    return PopupMenuButton<String>(
      tooltip: '시간표 전환',
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        if (value == '__add__') {
          await widget.onAddTimetable();
        } else if (value == '__manage__') {
          await widget.onOpenManager();
        } else {
          await _switchTo(value);
        }
      },
      itemBuilder:
          (context) => [
            for (final e in entries)
              PopupMenuItem<String>(
                value: e.id,
                child: _buildSwitchMenuRow(e, isActive: e.id == active.id),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: '__add__',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.add, size: 18),
                title: Text('시간표 추가…', style: TextStyle(fontSize: 13)),
              ),
            ),
            const PopupMenuItem<String>(
              value: '__manage__',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.settings_outlined, size: 18),
                title: Text('시간표 관리…', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '전환',
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: tokens.textSecondary),
          ],
        ),
      ),
    );
  }

  /// 전환 메뉴 행 한 줄 (이름 + 교사·계획서 요약)
  Widget _buildSwitchMenuRow(
    TimetableRegistryEntry entry, {
    required bool isActive,
  }) {
    final tokens = context.tokens;
    final summary = ref.watch(timetableSummaryProvider(entry.id)).valueOrNull;

    final detail = StringBuffer(
      entry.hasTeacher ? entry.teacherName! : '교사 미지정',
    );
    if (summary != null) {
      detail.write(' · 계획서 ${summary.profileCount}');
      if (summary.exchangeCount > 0) {
        detail.write(' · 교체 ${summary.exchangeCount}건');
      }
    }

    return Row(
      children: [
        SizedBox(
          width: 22,
          child:
              isActive
                  ? Icon(Icons.check, size: 16, color: tokens.primary)
                  : const SizedBox.shrink(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? tokens.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                detail.toString(),
                style: TextStyle(
                  fontSize: 11.5,
                  color: entry.hasTeacher ? tokens.textMuted : Colors.orange,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 시간표에 종속된 항목들 (교사 · 학교명 · 계획서)
  ///
  /// 들여쓰기된 박스로 감싸 "시간표 아래"라는 계층을 시각적으로 드러낸다.
  Widget _buildNestedDetails(TimetableRegistryEntry entry) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeacherRow(entry),
          const SizedBox(height: 10),
          _buildSchoolRow(),
          const SizedBox(height: 10),
          _buildProfileRow(entry),
        ],
      ),
    );
  }

  /// 교사 선택 행 — 자유 입력이 아닌 드롭다운
  Widget _buildTeacherRow(TimetableRegistryEntry entry) {
    final tokens = context.tokens;
    final teachers = ref.watch(activeTimetableTeachersProvider);

    final current = _resolvedTeacher(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledField(
          icon: Icons.person_outline,
          label: '교사',
          child: DropdownButtonFormField<String>(
            // 레지스트리 교사명이 바뀌면 FormField를 새로 만들어 표시값을 맞춤
            // (initialValue는 첫 빌드에만 쓰이므로 Key로 강제 재생성)
            key: ValueKey('prepare-teacher-${current ?? 'none'}'),
            initialValue: current,
            isExpanded: true,
            decoration: _fieldDecoration(
              hint: teachers.isEmpty ? '시간표를 불러오는 중…' : '교사를 선택하세요',
            ),
            style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
            items: [
              for (final name in teachers)
                DropdownMenuItem<String>(
                  value: name,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: teachers.isEmpty ? null : _selectTeacher,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: _hintIndent),
          child:
              current == null
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          '선택하면 교체 화면에서 내 시간표 행이 강조되고, 계획서 교사명이 자동 입력됩니다',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  )
                  : Text(
                    '이 시간표의 교사 목록에서 선택',
                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  ),
        ),
      ],
    );
  }

  /// 학교명 입력 행 — 포커스 이탈 시 자동 저장
  Widget _buildSchoolRow() {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledField(
          icon: Icons.school_outlined,
          label: '학교명',
          child: TextField(
            controller: _schoolController,
            focusNode: _schoolFocus,
            style: const TextStyle(fontSize: 13.5),
            decoration: _fieldDecoration(hint: '예: 월계중학교'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveSchoolName(),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: _hintIndent),
          child: Text(
            '계획서 인쇄에 사용됩니다',
            style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
          ),
        ),
      ],
    );
  }

  /// 계획서 요약 행 — 교사가 선택돼야 사용할 수 있다
  ///
  /// 저장된 교사가 엑셀 교사 목록에 더 이상 없으면(원본 파일이 바뀐 경우)
  /// 드롭다운과 동일하게 미선택으로 취급한다 — 한쪽만 활성이면 상태가 어긋나 보인다.
  Widget _buildProfileRow(TimetableRegistryEntry entry) {
    final tokens = context.tokens;
    final store = ref.watch(printProfileStoreProvider);
    final teacher = _resolvedTeacher(entry);
    final enabled = teacher != null;
    final profiles =
        enabled ? store.byTeacher(teacher) : const <PrintProfile>[];

    final String summaryText;
    if (!enabled) {
      summaryText = '교사 선택 후 사용 가능';
    } else if (profiles.isEmpty) {
      summaryText = '계획서 없음 — 문서 출력 탭에서 만들 수 있습니다';
    } else {
      summaryText = profiles.map((p) => p.name).join(' · ');
    }

    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: enabled ? tokens.textSecondary : tokens.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '계획서',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: enabled ? tokens.textSecondary : tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            summaryText,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? tokens.textPrimary : tokens.textMuted,
              fontStyle: enabled ? FontStyle.normal : FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: enabled ? widget.onOpenProfiles : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('관리 >', style: TextStyle(fontSize: 12.5)),
        ),
      ],
    );
  }

  /// 하단 액션 (추가 · 관리)
  Widget _buildFooterActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => widget.onAddTimetable(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('시간표 추가', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => widget.onOpenManager(),
          child: const Text('시간표 관리 >', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  // ===== 공통 조각 =====

  /// 아이콘 + 라벨 + 입력 위젯 한 줄
  Widget _labeledField({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final tokens = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Row(
            children: [
              Icon(icon, size: 16, color: tokens.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    final tokens = context.tokens;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: tokens.textMuted),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: tokens.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.primary),
      ),
    );
  }
}
