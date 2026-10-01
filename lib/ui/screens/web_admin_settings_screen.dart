import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_picker/file_picker.dart';

import '../../models/dated_timetable.dart';
import '../../providers/timetable_registry_provider.dart';
import '../../providers/timetable_repository_provider.dart';
import '../../services/excel_service.dart';
import '../../services/semester_timetable_generator.dart';
import '../../services/shared_timetable_sync_service.dart';
import '../../services/timetable_storage_service.dart';
import '../../services/web_auth_service.dart';
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';
import 'timetable_file_register_dialog.dart';
import 'web_login_gate.dart';

/// 관리자용 접속 설정 변경 화면 (웹 전용, 웹 전환 2단계).
///
/// - 접속자 비밀번호 변경 (새 salt 발급 + 해시 저장)
/// - 관리자 비밀번호 변경
/// - 로그인 안내 메시지 변경 (`config/public`)
/// - 로그아웃 (세션 삭제)
///
/// 관리자 권한(`webLoginStatusProvider == adminOk`)일 때만 진입시킨다.
class WebAdminSettingsScreen extends ConsumerStatefulWidget {
  const WebAdminSettingsScreen({super.key});

  @override
  ConsumerState<WebAdminSettingsScreen> createState() =>
      _WebAdminSettingsScreenState();
}

class _WebAdminSettingsScreenState
    extends ConsumerState<WebAdminSettingsScreen> {
  final _viewerPasswordController = TextEditingController();
  final _viewerPasswordConfirmController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminPasswordConfirmController = TextEditingController();
  final _loginMessageController = TextEditingController();
  bool _busy = false;
  bool _viewerVisible = false;
  bool _adminVisible = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMessage();
  }

  /// 현재 로그인 안내 메시지를 입력란에 미리 채운다.
  Future<void> _loadCurrentMessage() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('config')
              .doc('public')
              .get();
      final data = doc.data();
      final message =
          (data?['loginMessage'] ?? data?['LoginMessage']) as String?;
      if (!mounted || message == null) return;
      setState(() => _loginMessageController.text = message);
    } catch (_) {
      // 조회 실패 시 빈칸 유지
    }
  }

  @override
  void dispose() {
    _viewerPasswordController.dispose();
    _viewerPasswordConfirmController.dispose();
    _adminPasswordController.dispose();
    _adminPasswordConfirmController.dispose();
    _loginMessageController.dispose();
    super.dispose();
  }

  /// 16바이트 난수 salt (hex).
  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _saveViewerPassword() async {
    final password = _viewerPasswordController.text;
    if (password.length < 4) {
      SnackBarHelper.showError(context, '접속자 비밀번호는 4자 이상으로 정하세요.');
      return;
    }
    if (password != _viewerPasswordConfirmController.text) {
      SnackBarHelper.showError(context, '접속자 비밀번호가 서로 다릅니다.');
      return;
    }
    final error = await _runGuarded(() async {
      final salt = _newSalt();
      await FirebaseFirestore.instance.collection('config').doc('auth').set({
        'viewerSalt': salt,
        'viewerPasswordHash': WebAuthService.hashPassword(password, salt),
      }, SetOptions(merge: true));
    });
    if (!mounted) return;
    if (error == null) {
      _viewerPasswordController.clear();
      _viewerPasswordConfirmController.clear();
      setState(() => _viewerVisible = false);
      SnackBarHelper.showSuccess(context, '접속자 비밀번호를 변경했습니다.');
    } else {
      SnackBarHelper.showError(context, '저장 실패: $error');
    }
  }

  Future<void> _saveAdminPassword() async {
    final password = _adminPasswordController.text;
    if (password.length < 4) {
      SnackBarHelper.showError(context, '관리자 비밀번호는 4자 이상으로 정하세요.');
      return;
    }
    if (password != _adminPasswordConfirmController.text) {
      SnackBarHelper.showError(context, '관리자 비밀번호가 서로 다릅니다.');
      return;
    }
    final error = await _runGuarded(() async {
      final salt = _newSalt();
      await FirebaseFirestore.instance.collection('config').doc('auth').set({
        'adminSalt': salt,
        'adminPasswordHash': WebAuthService.hashPassword(password, salt),
      }, SetOptions(merge: true));
    });
    if (!mounted) return;
    if (error == null) {
      _adminPasswordController.clear();
      _adminPasswordConfirmController.clear();
      setState(() => _adminVisible = false);
      SnackBarHelper.showSuccess(context, '관리자 비밀번호를 변경했습니다.');
    } else {
      SnackBarHelper.showError(context, '저장 실패: $error');
    }
  }

  Future<void> _saveLoginMessage() async {
    final message = _loginMessageController.text.trim();
    final error = await _runGuarded(() async {
      await FirebaseFirestore.instance.collection('config').doc('public').set({
        'loginMessage': message,
      }, SetOptions(merge: true));
    });
    if (!mounted) return;
    if (error == null) {
      SnackBarHelper.showSuccess(context, '안내 메시지를 변경했습니다.');
    } else {
      SnackBarHelper.showError(context, '저장 실패: $error');
    }
  }

  /// Firestore 작업을 실행하고, 실패 시 오류 문자열을 반환한다 (성공 시 null).
  Future<String?> _runGuarded(Future<void> Function() task) async {
    if (_busy) return '처리 중입니다. 잠시 후 다시 시도하세요.';
    setState(() => _busy = true);
    try {
      await task();
      return null;
    } catch (e) {
      return '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await WebAuthService.clearSession();
    if (!mounted) return;
    ref.read(webLoginStatusProvider.notifier).state = WebLoginStatus.locked;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('접속 설정 (관리자)'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _logout,
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              const Text(
                '접속자 비밀번호 변경',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _buildPasswordField(
                controller: _viewerPasswordController,
                label: '새 접속자 비밀번호 (4자 이상)',
                visible: _viewerVisible,
                onToggle:
                    () => setState(() => _viewerVisible = !_viewerVisible),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _viewerPasswordConfirmController,
                label: '새 접속자 비밀번호 확인',
                visible: _viewerVisible,
                onToggle:
                    () => setState(() => _viewerVisible = !_viewerVisible),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _busy ? null : _saveViewerPassword,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('접속자 비밀번호 저장'),
                ),
              ),
              const Divider(height: 24),
              const Text(
                '관리자 비밀번호 변경',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _adminPasswordController,
                label: '새 관리자 비밀번호 (4자 이상)',
                visible: _adminVisible,
                onToggle: () => setState(() => _adminVisible = !_adminVisible),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _adminPasswordConfirmController,
                label: '새 관리자 비밀번호 확인',
                visible: _adminVisible,
                onToggle: () => setState(() => _adminVisible = !_adminVisible),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _busy ? null : _saveAdminPassword,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('관리자 비밀번호 저장'),
                ),
              ),
              const Divider(height: 24),
              const Text(
                '로그인 안내 메시지 변경',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _loginMessageController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '접속 화면에 보여줄 문구',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _busy ? null : _saveLoginMessage,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('안내 메시지 저장'),
                ),
              ),
              const Divider(height: 24),
              const Text(
                '공용 시간표 올리기',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                '엑셀 파일을 고르면 등록부터 서버 게시까지 한 번에 처리합니다. '
                '버전부터 올린 뒤 파일을 전송하므로, 실패해도 접속자는 구버전을 유지합니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _busy ? null : _publishSharedTimetable,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('공용 시간표 게시'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 보기/숨기기 토글이 달린 비밀번호 입력란.
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          tooltip: visible ? '숨기기' : '보기',
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  /// 공용 시간표 원스텝 게시 (웹·관리자 전용).
  ///
  /// 엑셀 선택 → 파싱 → 저장 → 이름·학기 확인 → 등록 → 날짜별 생성 →
  /// 서버 게시를 한 번에 처리한다. 준비 화면의 등록 과정을 거치지 않아도 된다.
  Future<void> _publishSharedTimetable() async {
    if (!kIsWeb) {
      SnackBarHelper.showInfo(context, '공용 게시는 웹에서만 할 수 있습니다.');
      return;
    }
    if (_busy) return;

    // 1. 엑셀 파일 선택 (바이트 직접 수신)
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'xlsm'],
        allowMultiple: false,
        withData: true,
      );
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, '파일 선택 실패: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    final fileName = picked.name;
    if (bytes == null) {
      if (mounted) {
        SnackBarHelper.showError(context, '파일을 읽을 수 없습니다.');
      }
      return;
    }

    setState(() => _busy = true);
    try {
      // 2. 파싱
      final excel = await ExcelService.readExcelFromBytes(bytes);
      if (excel == null) {
        throw Exception('엑셀 파일을 읽을 수 없습니다.');
      }
      final timetableData = ExcelService.parseTimetableData(excel);
      if (timetableData == null) {
        throw Exception('시간표 데이터를 파싱할 수 없습니다.');
      }

      // 3. JSON 저장 (바이트 기반)
      final storage = TimetableStorageService();
      final hashes = await storage.saveTimetableDataForRegistryFromBytes(
        timetableData,
        fileName: fileName,
        bytes: bytes,
      );
      if (hashes == null) {
        throw Exception('시간표 저장에 실패했습니다.');
      }
      if (!mounted) return;

      // 4. 이름·학기 확인 (기본 이름은 파일명)
      final defaultName = fileName.replaceAll(
        RegExp(r'\.[^.]+$', caseSensitive: false),
        '',
      );
      final registration = await showRegisterTimetableDialog(
        context,
        initialName: defaultName,
      );
      if (registration == null || !mounted) return;

      // 5. 레지스트리 등록 (교사·학교명은 기존 활성이 있으면 유지)
      final prevActive = ref.read(activeTimetableEntryProvider);
      final entry = await ref
          .read(timetableRegistryProvider.notifier)
          .registerTimetable(
            name:
                registration.name.isNotEmpty ? registration.name : defaultName,
            fileName: fileName,
            filePath: '',
            hash: hashes.hash,
            contentHash: hashes.contentHash,
            teacherName: prevActive?.teacherName,
            schoolName: prevActive?.schoolName,
            semesterStart: registration.semester.startDate,
            semesterEnd: registration.semester.endDate,
          );
      if (entry == null) {
        throw Exception('시간표 등록에 실패했습니다.');
      }
      if (!mounted) return;

      // 6. 날짜별 생성·저장 + 활성 전환
      final repository = await ref.read(timetableRepositoryProvider.future);
      final lessons = SemesterTimetableGenerator.generate(
        timetableId: entry.id,
        timeSlots: timetableData.timeSlots,
        semester: registration.semester,
      );
      await repository.insertTimetable(
        DatedTimetable(
          id: entry.id,
          name: entry.name,
          semester: registration.semester,
          teacherName: entry.teacherName,
          schoolName: entry.schoolName,
          registeredAt: entry.registeredAt,
        ),
      );
      await repository.insertLessons(lessons);
      await repository.insertSnapshot(lessons);
      await ref.read(timetableRegistryProvider.notifier).switchActive(entry.id);

      // 7. 서버 게시
      final version = await SharedTimetableSyncService().publishTimetable(
        repo: repository,
        timetableId: entry.id,
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        "공용 시간표 게시 완료 (버전 $version, '${entry.name}')",
      );
    } catch (e) {
      AppLogger.error('공용 시간표 게시 실패: $e', e);
      if (mounted) SnackBarHelper.showError(context, '게시 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
