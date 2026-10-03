import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/firebase_app_config.dart';
import '../../constants/app_info.dart';
import '../../models/web_login_branding.dart';
import '../../providers/timetable_repository_provider.dart';
import '../../providers/timetable_registry_provider.dart';
import '../../services/shared_timetable_sync_service.dart';
import '../../services/web_auth_service.dart';
import '../../services/web_branding_service.dart';
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/web_login_branding_block.dart';
import 'web_admin_settings_screen.dart';

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
final webLoginStatusProvider = StateProvider<WebLoginStatus>(
  (ref) => WebLoginStatus.checking,
);

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
  WebLoginBranding _branding = const WebLoginBranding();
  Uint8List? _logoBytes;

  /// 지금 진행 중인 동기화 단계 (진행 화면 안내문)
  String? _syncStage;

  /// 다운로드 진행률 (0.0~1.0). null이면 진행률을 알 수 없어 비확정 막대.
  double? _downloadProgress;

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
  ///
  /// 이 구간에서는 아직 시간표를 받지 않는다. 예전에는 화면에 계속
  /// "시간표를 불러오는 중…"이 떠서, 비밀번호 입력 전인데도 시간표를 받는 줄
  /// 알게 했다(2026-10-02). 단계마다 실제로 하는 일을 적는다.
  void _setStage(String stage) {
    if (mounted) setState(() => _syncStage = stage);
  }

  Future<void> _bootstrap() async {
    if (!FirebaseAppConfig.isConfigured) {
      // 설정 미주입 빌드 — 안내만 보여주고 진행 불가.
      if (mounted) {
        ref.read(webLoginStatusProvider.notifier).state = WebLoginStatus.locked;
      }
      return;
    }

    _setStage('서버 연결 준비 중');
    await FirebaseAppConfig.ensureInitialized();
    await WebAuthService.ensureAnonymousSignIn();

    _setStage('접속 정보 확인 중');
    final session = await WebAuthService.loadSession();
    if (!mounted) return;
    if (session.admin) {
      await _enterSession(admin: true);
      return;
    }
    if (session.viewer) {
      await _enterSession(admin: false);
      return;
    }

    _setStage('접속 화면 준비 중');
    final brandingService = WebBrandingService();
    final branding = await brandingService.load();
    // base64가 있으면 바로 쓰고, 없으면 Storage/URL에서 받는다.
    final logoBytes =
        branding.hasLogo
            ? await brandingService.resolveLogoBytes(branding)
            : null;
    if (!mounted) return;
    setState(() {
      _branding = branding;
      _logoBytes = logoBytes;
    });
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
        await _enterSession(admin: false);
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
        await _enterSession(admin: true);
      } else {
        SnackBarHelper.showError(context, '관리자 비밀번호가 맞지 않습니다.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitMaster() async {
    final ok = WebAuthService.verifyMaster(
      _masterIdController.text.trim(),
      _masterPasswordController.text,
    );
    if (!mounted) return;
    if (ok) {
      await WebAuthService.saveSession(viewer: true, admin: true);
      await _enterSession(admin: true);
      if (!mounted) return;
      SnackBarHelper.showInfo(context, '마스터 계정으로 진입했습니다. 관리자 비밀번호를 새로 설정하세요.');
    } else {
      SnackBarHelper.showError(context, '마스터 ID 또는 비밀번호가 맞지 않습니다.');
    }
  }

  /// 새 브라우저에서는 공용 시간표 등록을 마친 뒤 메인 화면을 연다.
  ///
  /// 공용 시간표 동기화가 실패해도 앱 진입 자체는 막지 않는다 — 예전에는
  /// 실패 시 "다시 시도/계속/로그아웃" 중 하나를 고르게 하는 화면을
  /// 띄웠는데, 공용 시간표는 앱 기능 중 하나일 뿐 전체가 거기 의존하진
  /// 않으므로 굳이 물어볼 필요가 없다(2026-10-02 요청). 실패 원인은 로그로만
  /// 남기고 평소처럼 들여보낸다 — 로컬에 캐시된 이전 버전이 있으면 그게
  /// 계속 보이고, 받은 적이 없으면 공용 시간표 없이 시작한다. 이후 접속
  /// 때마다 다시 시도되므로 서버가 복구되면 저절로 받아진다.
  Future<void> _enterSession({required bool admin}) async {
    if (!mounted) return;
    setState(() {
      _syncStage = '시간표 준비 중';
      _downloadProgress = null;
    });
    ref.read(webLoginStatusProvider.notifier).state = WebLoginStatus.checking;
    var stage = '브라우저 저장소 초기화';
    try {
      // FutureProvider는 실패한 결과도 보관하므로 재시도 전에 초기화한다.
      if (ref.read(timetableDatabaseProvider).hasError) {
        ref.invalidate(timetableDatabaseProvider);
      }
      if (ref.read(timetableRepositoryProvider).hasError) {
        ref.invalidate(timetableRepositoryProvider);
      }
      final repo = await ref.read(timetableRepositoryProvider.future);
      await SharedTimetableSyncService().syncSharedTimetable(
        repo: repo,
        onStage: (value) {
          stage = value;
          if (mounted) setState(() => _syncStage = value);
        },
        onDownloadProgress: (value) {
          if (mounted) setState(() => _downloadProgress = value);
        },
      );
      if (!mounted) return;
      ref.invalidate(timetableRegistryProvider);
    } catch (e, st) {
      AppLogger.error('공용 시간표 동기화 실패 — 캐시된 시간표로 계속 진행 ($stage)', e, st);
    }
    if (!mounted) return;
    ref.read(webLoginStatusProvider.notifier).state =
        admin ? WebLoginStatus.adminOk : WebLoginStatus.viewerOk;
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(webLoginStatusProvider);
    if (status == WebLoginStatus.viewerOk) {
      // 접속자: 우측 상단에 로그아웃 버튼을 띄운다.
      return Stack(
        children: [
          widget.child,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: FloatingActionButton.small(
              heroTag: 'webViewerLogout',
              tooltip: '로그아웃',
              onPressed: () async {
                await WebAuthService.clearSession();
                ref.read(webLoginStatusProvider.notifier).state =
                    WebLoginStatus.locked;
              },
              child: const Icon(Icons.logout_outlined),
            ),
          ),
        ],
      );
    }
    // 관리자 통과 시: 앱 위에 접속 설정 진입 버튼을 띄운다.
    if (status == WebLoginStatus.adminOk) {
      return Stack(
        children: [
          widget.child,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: FloatingActionButton.small(
              heroTag: 'webAdminSettings',
              tooltip: '접속 설정 (관리자)',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WebAdminSettingsScreen(),
                  ),
                );
              },
              child: const Icon(Icons.admin_panel_settings_outlined),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                status == WebLoginStatus.checking
                    ? _buildSyncProgress()
                    : _buildLockForm(context),
          ),
        ),
      ),
    );
  }

  /// 동기화 진행 화면 — 단계 안내 + 다운로드 진행 막대
  ///
  /// 다운로드 중에는 실제 수신 바이트 기준으로 막대가 찬다. 그 외 단계
  /// (DB 저장 등)는 남은 양을 알 수 없어 비확정 막대로 돈다.
  Widget _buildSyncProgress() {
    final progress = _downloadProgress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          child: LinearProgressIndicator(value: progress, minHeight: 6),
        ),
        const SizedBox(height: 14),
        Text(_syncStage ?? '접속 준비 중…'),
        if (progress != null) ...[
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildLockForm(BuildContext context) {
    if (!FirebaseAppConfig.isConfigured) {
      return const Text(
        '서버 설정이 아직 준비되지 않았습니다.\n관리자에게 문의하세요.',
        textAlign: TextAlign.center,
      );
    }

    // 관리자 모드는 인디고 계열로 구분한다.
    final adminBg = Colors.indigo.shade100;
    final adminFg = Colors.indigo.shade900;
    final adminBorder = Colors.indigo.shade300;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'lib/assets/images/app_icon.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => const Icon(
                    Icons.swap_horiz_rounded,
                    size: 72,
                    color: Colors.teal,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            AppInfo.programName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Version : ${AppInfo.versionLabel}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        WebLoginBrandingBlock(
          branding: _branding,
          localLogoBytes: _logoBytes,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _showAdmin ? '관리자 비밀번호' : '선생님 접속 비밀번호',
            border: const OutlineInputBorder(),
            focusedBorder:
                _showAdmin
                    ? OutlineInputBorder(
                      borderSide: BorderSide(color: adminBorder, width: 2),
                    )
                    : null,
            floatingLabelStyle: _showAdmin ? TextStyle(color: adminFg) : null,
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _passwordController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: '지우기',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _passwordController.clear(),
                );
              },
            ),
          ),
          onSubmitted: (_) => _showAdmin ? _submitAdmin() : _submitViewer(),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _busy ? null : (_showAdmin ? _submitAdmin : _submitViewer),
          style:
              _showAdmin
                  ? ElevatedButton.styleFrom(
                    backgroundColor: adminBg,
                    foregroundColor: adminFg,
                  )
                  : null,
          child:
              _busy
                  ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(_showAdmin ? '관리자로 들어가기' : '선생님 들어가기'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              _busy
                  ? null
                  : () => setState(() {
                    _showAdmin = !_showAdmin;
                    _showMasterForm = false;
                    // 모드 전환 시 이전 입력값이 남지 않도록 비운다.
                    _passwordController.clear();
                  }),
          style:
              _showAdmin
                  ? TextButton.styleFrom(foregroundColor: adminFg)
                  : null,
          // 모드 전환 링크는 원래(선생님) 색 유지, 마스터 안내는 관리자 색.
          child: Text(_showAdmin ? '선생님 접속화면으로' : '관리자 로그인'),
        ),
        if (_showAdmin && !_showMasterForm)
          TextButton(
            onPressed: () => setState(() => _showMasterForm = true),
            style: TextButton.styleFrom(foregroundColor: adminFg),
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
