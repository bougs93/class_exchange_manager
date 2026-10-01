import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/timetable_registry_provider.dart';
import '../../providers/timetable_repository_provider.dart';
import '../../services/shared_timetable_sync_service.dart';
import '../../services/web_auth_service.dart';
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';
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
  ConsumerState< WebAdminSettingsScreen> createState() =>
      _WebAdminSettingsScreenState();
}

class _WebAdminSettingsScreenState
    extends ConsumerState<WebAdminSettingsScreen> {
  final _viewerPasswordController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _loginMessageController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _viewerPasswordController.dispose();
    _adminPasswordController.dispose();
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
      SnackBarHelper.showSuccess(context, '관리자 비밀번호를 변경했습니다.');
    } else {
      SnackBarHelper.showError(context, '저장 실패: $error');
    }
  }

  Future<void> _saveLoginMessage() async {    final message = _loginMessageController.text.trim();
    final error = await _runGuarded(() async {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('public')
          .set({'loginMessage': message}, SetOptions(merge: true));
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('접속자 비밀번호 변경'),
          const SizedBox(height: 8),
          TextField(
            controller: _viewerPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '새 접속자 비밀번호 (4자 이상)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _saveViewerPassword,
            child: const Text('접속자 비밀번호 저장'),
          ),
          const Divider(height: 32),
          const Text('관리자 비밀번호 변경'),
          const SizedBox(height: 8),
          TextField(
            controller: _adminPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '새 관리자 비밀번호 (4자 이상)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _saveAdminPassword,
            child: const Text('관리자 비밀번호 저장'),
          ),
          const Divider(height: 32),
          const Text('로그인 안내 메시지 변경'),
          const SizedBox(height: 8),
          TextField(
            controller: _loginMessageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '접속 화면에 보여줄 문구',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _saveLoginMessage,
            child: const Text('안내 메시지 저장'),
          ),
          const Divider(height: 32),
          const Text('공용 시간표 올리기'),
          const SizedBox(height: 8),
          const Text(
            '현재 선택된 시간표 전체를 공용 시간표로 게시합니다. '
            '버전부터 올린 뒤 파일을 전송하므로, 실패해도 접속자는 구버전을 유지합니다.',
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _publishSharedTimetable,
            child: const Text('공용 시간표 게시'),
          ),
        ],
      ),
    );
  }

  /// 현재 활성 시간표를 공용으로 게시한다 (웹·관리자 전용).
  Future<void> _publishSharedTimetable() async {
    if (!kIsWeb) {
      SnackBarHelper.showInfo(context, '공용 게시는 웹에서만 할 수 있습니다.');
      return;
    }
    final entry = ref.read(activeTimetableEntryProvider);
    if (entry == null) {
      SnackBarHelper.showError(context, '게시할 시간표를 먼저 선택하세요.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(timetableRepositoryProvider.future);
      final service = SharedTimetableSyncService();
      final version = await service.publishTimetable(
        repo: repo,
        timetableId: entry.id,
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(context, '공용 시간표 게시 완료 (버전 $version)');
    } catch (e) {
      AppLogger.error('공용 시간표 게시 실패: $e', e);
      if (mounted) SnackBarHelper.showError(context, '게시 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
