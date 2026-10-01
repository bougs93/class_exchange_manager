import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../config/firebase_app_config.dart';
import '../../providers/timetable_repository_provider.dart';
import '../../services/shared_timetable_sync_service.dart';
import '../../services/web_auth_service.dart';
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';

/// 웹 접속 비밀번호 화면 상태.
enum WebLoginStatus {
  /// 확인 중 (세션·설정 로딩).
  checking,

  /// 비밀번호 입력 대기.
  locked,

  /// 접속자 통과.
  viewerOk,

  /// 관리자 통과.
  adminOk,
}

/// 웹 접속 비밀번호 화면 상태 Provider (웹 전용).
final webLoginStatusProvider =
    StateProvider<WebLoginStatus>((ref) => WebLoginStatus.checking);

/// 웹 전용 접속 게이트 (웹 전환 2단계, 계획서 4.3·4.5절).
///
/// - PC/모바일에서는 사용하지 않는다 (`main.dart`에서 `kIsWeb`일 때만 장착).
/// - 순서: Firebase 설정 확인 → 저장 세션 확인 → 공개 안내문 + 비밀번호 입력.
/// - 평소에는 접속자 비밀번호 입력란만 보이고, "관리자 로그인"을 누르면
///   관리자 비밀번호 입력란 + "비밀번호를 잊으셨나요?" 마스터 폼이 나타난다.
/// - 통과 후 세션을 로컬에 저장해 재방문 시 자동 통과한다.
class WebLoginGate extends ConsumerStatefulWidget {
  final Widget child;

  const WebLoginGate({super.key, required this.child});

  @override
  ConsumerState<WebLoginGate> createState() => _WebLoginGateState();
}

class _WebLoginGateState extends ConsumerState<WebLoginGate> {
  final _passwordController = TextEditingController();
  final _masterIdController = TextEditingController();
  final _masterPasswordController = TextEditingController();
  bool _busy = false;
  bool _showAdmin = false;
  bool _showMasterForm = false;
  String? _loginMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _masterIdController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }

  /// Firebase 초기화 → 익명 로그인 → 세션 확인 → 공개 안내문 로드.
  Future<void> _bootstrap() async {
    if (!FirebaseAppConfig.isConfigured) {
      // 설정 미주입 빌드 — 안내만 보여주고 진행 불가.
      if (mounted) {
        ref.read(webLoginStatusProvider.notifier).state =
            WebLoginStatus.locked;
      }
      return;
    }

    await FirebaseAppConfig.ensureInitialized();
    await WebAuthService.ensureAnonymousSignIn();

    final session = await WebAuthService.loadSession();
    if (!mounted) return;
    if (session.admin) {
      ref.read(webLoginStatusProvider.notifier).state = WebLoginStatus.adminOk;
      unawaited(_syncSharedTimetable());
      return;
    }
    if (session.viewer) {
      ref.read(webLoginStatusProvider.notifier).state =
          WebLoginStatus.viewerOk;
      unawaited(_syncSharedTimetable());
      return;
    }

    String? message;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('config')
              .doc('public')
              .get();
      final data = doc.data();
      // 콘솔에서 필드명 대소문자를 틀리는 실수에 대비해 둘 다 읽는다.
      message =
          (data?['loginMessage'] ?? data?['LoginMessage']) as String?;
    } catch (_) {
      message = null;
    }
    if (!mounted) return;
    setState(() => _loginMessage = message);
    ref.read(webLoginStatusProvider.notifier).state = WebLoginStatus.locked;
  }

  Future<void> _submitViewer() async {
    final input = _passwordController.text;
    if (input.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await WebAuthService.verifyViewerPassword(input);
      if (!mounted) return;
      if (ok) {
        await WebAuthService.saveSession(viewer: true);
        ref.read(webLoginStatusProvider.notifier).state =
            WebLoginStatus.viewerOk;
        unawaited(_syncSharedTimetable());
      } else {
        SnackBarHelper.showError(context, '비밀번호가 맞지 않습니다.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitAdmin() async {
    final input = _passwordController.text;
    if (input.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final ok = await WebAuthService.verifyAdminPassword(input);
      if (!mounted) return;
      if (ok) {
        await WebAuthService.saveSession(viewer: true, admin: true);
        ref.read(webLoginStatusProvider.notifier).state =
            WebLoginStatus.adminOk;
        unawaited(_syncSharedTimetable());
      } else {
        SnackBarHelper.showError(context, '관리자 비밀번호가 맞지 않습니다.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitMaster() {
    final ok = WebAuthService.verifyMaster(
      _masterIdController.text.trim(),
      _masterPasswordController.text,
    );
    if (!mounted) return;
    if (ok) {
      WebAuthService.saveSession(viewer: true, admin: true);
      ref.read(webLoginStatusProvider.notifier).state = WebLoginStatus.adminOk;
      unawaited(_syncSharedTimetable());
      SnackBarHelper.showInfo(context, '마스터 계정으로 진입했습니다. 관리자 비밀번호를 새로 설정하세요.');
    } else {
      SnackBarHelper.showError(context, '마스터 ID 또는 비밀번호가 맞지 않습니다.');
    }
  }

  /// 통과 후 공용 시간표를 백그라운드로 동기화한다.
  ///
  /// 로그인을 막지 않도록 기다리지 않으며(`unawaited`), 실패해도 조용히
  /// 로그만 남긴다 — 다음 접속 때 버전 비교로 다시 시도된다.
  Future<void> _syncSharedTimetable() async {
    try {
      final repo = await ref.read(timetableRepositoryProvider.future);
      final result = await SharedTimetableSyncService().syncSharedTimetable(
        repo: repo,
      );
      AppLogger.info(
        '공용 시간표 동기화: ${result.status.name}, 버전 ${result.version}, ${result.count}건',
      );
    } catch (e) {
      AppLogger.warning('공용 시간표 동기화 실패 (다음 접속 시 재시도): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(webLoginStatusProvider);
    if (status == WebLoginStatus.viewerOk ||
        status == WebLoginStatus.adminOk) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: status == WebLoginStatus.checking
                ? const Center(child: CircularProgressIndicator())
                : _buildLockForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLockForm(BuildContext context) {
    if (!FirebaseAppConfig.isConfigured) {
      return const Text(
        '서버 설정이 아직 준비되지 않았습니다.\n관리자에게 문의하세요.',
        textAlign: TextAlign.center,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loginMessage != null && _loginMessage!.isNotEmpty) ...[
          Text(_loginMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _showAdmin ? '관리자 비밀번호' : '접속 비밀번호',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _showAdmin ? _submitAdmin() : _submitViewer(),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed:
              _busy ? null : (_showAdmin ? _submitAdmin : _submitViewer),
          child:
              _busy
                  ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(_showAdmin ? '관리자로 들어가기' : '들어가기'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              _busy
                  ? null
                  : () => setState(() {
                    _showAdmin = !_showAdmin;
                    _showMasterForm = false;
                  }),
          child: Text(_showAdmin ? '접속자 화면으로' : '관리자 로그인'),
        ),
        if (_showAdmin && !_showMasterForm)
          TextButton(
            onPressed: () => setState(() => _showMasterForm = true),
            child: const Text('비밀번호를 잊으셨나요?'),
          ),
        if (_showAdmin && _showMasterForm) ...[
          const Divider(height: 24),
          const Text('마스터 로그인', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextField(
            controller: _masterIdController,
            decoration: const InputDecoration(
              labelText: '마스터 ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _masterPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '마스터 비밀번호',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submitMaster(),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _submitMaster,
            child: const Text('마스터로 들어가기'),
          ),
        ],
      ],
    );
  }
}
