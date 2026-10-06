import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_picker/file_picker.dart';

import '../../config/firebase_app_config.dart';
import '../../constants/login_notice_default.dart';
import '../../models/dated_timetable.dart';
import '../../models/lesson.dart';
import '../../models/web_login_branding.dart';
import '../../providers/timetable_registry_provider.dart';
import '../../providers/web_services_provider.dart';
import '../../providers/timetable_repository_provider.dart';
import '../../services/excel_service.dart';
import '../../services/semester_timetable_generator.dart';
import '../../services/timetable_storage_service.dart';
import '../../services/web_auth_service.dart';
import '../../services/web_branding_service.dart';
import '../../utils/logger.dart';
import '../../utils/snackbar_helper.dart';
import '../widgets/web_login_screen_preview.dart';
import 'timetable_file_register_dialog.dart';
import 'web_admin/web_admin_default_school_name_section.dart';
import 'web_admin/web_admin_guide_button_section.dart';
import 'web_admin/web_admin_login_branding_section.dart';
import 'web_admin/web_admin_password_section.dart';
import 'web_admin/web_admin_publish_section.dart';
import 'web_admin/web_admin_usage_stats_section.dart';
import 'web_login_gate.dart';

/// 관리자용 접속 설정 변경 화면 (웹 전용, 웹 전환 2단계).
///
/// - 접속자 비밀번호 변경 (새 salt 발급 + 해시 저장)
/// - 관리자 비밀번호 변경
/// - 접속 화면 브랜딩 (제목·안내·사용법 버튼·학교 로고·홈페이지)
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
  final _loginNoticeController = TextEditingController();
  final _schoolHomeUrlController = TextEditingController();
  final _guideButtonLabelController = TextEditingController();
  final _guideButtonUrlController = TextEditingController();
  final _defaultSchoolNameController = TextEditingController();

  /// 브랜딩 서비스 — **직접 생성하지 않고 Provider를 거친다.**
  ///
  /// 예전에는 `final _brandingService = WebBrandingService();`였는데, 그
  /// 생성자가 기본값으로 `FirebaseFirestore.instance`를 평가하는 바람에
  /// State가 만들어지는 순간(= `initState`보다 먼저, try/catch 밖) Firebase를
  /// 건드려 **위젯 테스트를 단 하나도 쓸 수 없었다**(2026-10-03).
  /// getter로 두면 실제로 쓸 때까지 생성이 미뤄지고, 테스트는 Provider를
  /// override해 가짜를 넣을 수 있다.
  WebBrandingService get _brandingService =>
      ref.read(webBrandingServiceProvider);

  WebLoginBranding _branding = const WebLoginBranding();

  /// 서버에 저장된 로고 (표시용). 웹에선 network 이미지 대신 이걸 쓴다.
  Uint8List? _storedLogoBytes;

  /// 아직 업로드하지 않은 새로 고른 로고.
  Uint8List? _pendingLogoBytes;
  String _pendingLogoContentType = 'image/png';
  bool _removeLogo = false;
  bool _saving = false;
  bool _publishing = false;
  bool _deleting = false;
  bool _publishFailed = false;
  String? _publishMessage;
  String? _publishResult;
  String? _publishedName;
  bool _viewerVisible = false;
  bool _adminVisible = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMessage();
  }

  /// 현재 로그인 브랜딩·기본 학교명을 입력란에 미리 채운다.
  Future<void> _loadCurrentMessage() async {
    try {
      final branding = await _brandingService.load();
      final logoBytes =
          branding.hasLogo
              ? await _brandingService.resolveLogoBytes(branding)
              : null;
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('public')
          .get()
          .timeout(FirebaseAppConfig.networkTimeout);
      final schoolName = doc.data()?['defaultSchoolName'] as String?;
      if (!mounted) return;
      setState(() {
        _branding = branding;
        _storedLogoBytes = logoBytes;
        _loginMessageController.text = branding.title;
        _loginNoticeController.text = branding.notice;
        _schoolHomeUrlController.text = branding.homeUrl;
        _guideButtonLabelController.text = branding.guideButtonLabel;
        _guideButtonUrlController.text = branding.guideButtonUrl;
        _pendingLogoBytes = null;
        _removeLogo = false;
        if (schoolName != null) _defaultSchoolNameController.text = schoolName;
      });
    } catch (e) {
      // 조회 실패 시 빈칸 유지 — 화면은 열어 두되 원인은 로그로 남긴다.
      // 아무 기록 없이 삼키면 "저장한 설정이 왜 안 보이지?"를 추적할 수 없다.
      AppLogger.warning('접속 설정 조회 실패 — 입력란을 비운 채 표시: $e');
    }
  }

  /// 편집/미리보기에 쓸 로고 바이트 (새 선택 > 저장본).
  Uint8List? get _displayLogoBytes {
    if (_removeLogo) return null;
    return _pendingLogoBytes ?? _storedLogoBytes;
  }

  @override
  void dispose() {
    _viewerPasswordController.dispose();
    _viewerPasswordConfirmController.dispose();
    _adminPasswordController.dispose();
    _adminPasswordConfirmController.dispose();
    _loginMessageController.dispose();
    _loginNoticeController.dispose();
    _schoolHomeUrlController.dispose();
    _guideButtonLabelController.dispose();
    _guideButtonUrlController.dispose();
    _defaultSchoolNameController.dispose();
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

  WebLoginBranding _draftBranding() {
    return _branding.copyWith(
      title: _loginMessageController.text.trim(),
      notice: _loginNoticeController.text.trim(),
      homeUrl: _schoolHomeUrlController.text.trim(),
      guideButtonLabel: _guideButtonLabelController.text.trim(),
      guideButtonUrl: _guideButtonUrlController.text.trim(),
      logoUrl: _removeLogo ? '' : _branding.logoUrl,
      logoBase64: _removeLogo ? '' : _branding.logoBase64,
      logoUpdatedAt: _removeLogo ? 0 : _branding.logoUpdatedAt,
    );
  }

  Future<void> _pickSchoolLogo() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        allowMultiple: false,
        withData: true,
      );
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, '로고 선택 실패: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) SnackBarHelper.showError(context, '로고 파일을 읽을 수 없습니다.');
      return;
    }
    if (bytes.length > WebBrandingService.maxLogoBytes) {
      if (mounted) {
        SnackBarHelper.showError(context, '로고는 2MB 이하만 올릴 수 있습니다.');
      }
      return;
    }
    final name = file.name.toLowerCase();
    final type =
        name.endsWith('.jpg') || name.endsWith('.jpeg')
            ? 'image/jpeg'
            : name.endsWith('.webp')
            ? 'image/webp'
            : name.endsWith('.gif')
            ? 'image/gif'
            : 'image/png';
    setState(() {
      _pendingLogoBytes = bytes;
      _pendingLogoContentType = type;
      _removeLogo = false;
    });
  }

  Future<void> _saveLoginBranding() async {
    final homeUrl = _schoolHomeUrlController.text.trim();
    if (homeUrl.isNotEmpty) {
      final uri = Uri.tryParse(homeUrl);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        SnackBarHelper.showError(
          context,
          '홈페이지 주소는 http:// 또는 https:// 로 시작해야 합니다.',
        );
        return;
      }
    }

    final guideUrl = _guideButtonUrlController.text.trim();
    if (guideUrl.isNotEmpty) {
      final uri = Uri.tryParse(guideUrl);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        SnackBarHelper.showError(
          context,
          '사용법 링크 주소는 http:// 또는 https:// 로 시작해야 합니다.',
        );
        return;
      }
    }

    final pendingBytes = _pendingLogoBytes;
    final error = await _runGuarded(() async {
      var next = _draftBranding();
      if (_removeLogo && _branding.logoUrl.isNotEmpty) {
        next = await _brandingService.clearLogo(next);
      }
      if (pendingBytes != null) {
        next = await _brandingService.uploadLogo(
          bytes: pendingBytes,
          contentType: _pendingLogoContentType,
          current: next,
        );
      } else {
        await _brandingService.saveBranding(next);
      }
      _branding = next;
      if (_removeLogo) {
        _storedLogoBytes = null;
      } else if (pendingBytes != null) {
        // 저장 직후 network URL 대신 방금 올린 바이트를 계속 보여 준다.
        _storedLogoBytes = pendingBytes;
      }
      _pendingLogoBytes = null;
      _removeLogo = false;
    });
    if (!mounted) return;
    if (error == null) {
      setState(() {});
      SnackBarHelper.showSuccess(context, '접속 화면 설정을 저장했습니다.');
    } else {
      SnackBarHelper.showError(context, '저장 실패: $error');
    }
  }

  void _showLoginPreview() {
    final draft = _draftBranding();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('로그인 화면 미리보기'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: WebLoginScreenPreview(
                branding: draft,
                localLogoBytes: _displayLogoBytes,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  /// Dart 상수 기본 안내 문구를 입력란에 넣는다. 저장은 [접속 화면 저장]으로.
  void _applyDefaultLoginNotice() {
    final text = kLoginNoticeDefaultText.replaceAll('\r\n', '\n').trim();
    setState(() => _loginNoticeController.text = text);
    SnackBarHelper.showInfo(context, '기본 안내 문구를 넣었습니다. 저장을 눌러 반영하세요.');
  }

  /// 기본 학교명 저장.
  ///
  /// 교사·학교명은 전역 설정이 아니라 시간표 속성이다(문서 §2) — 이 값은
  /// 그 규칙을 바꾸지 않는다. "준비 > 학교명"과 "계획서 > 결보강 출력 >
  /// 학교명"이 아직 비어 있을 때만 채워 주는 1회성 추천값일 뿐이고, 교사가
  /// 각자 다르게 입력하면 그 값이 그대로 유지된다(2026-10-02 요청).
  Future<void> _saveDefaultSchoolName() async {
    final schoolName = _defaultSchoolNameController.text.trim();
    final error = await _runGuarded(() async {
      await FirebaseFirestore.instance.collection('config').doc('public').set({
        'defaultSchoolName': schoolName,
      }, SetOptions(merge: true));
    });
    if (!mounted) return;
    if (error == null) {
      // `defaultSchoolNameProvider`는 Firestore 문서를 실시간 구독하는
      // StreamProvider라 여기서 따로 무효화하지 않아도 된다 — 이 저장이
      // 끝나는 순간 열려 있는 모든 탭(관리자 포함)에 새 값이 자동으로
      // 푸시된다. (처음엔 한 번만 읽는 FutureProvider였는데, 관리자와
      // 교사가 서로 다른 탭을 쓰면 교사 쪽에 무효화 신호가 닿지 않아
      // 반영되지 않았다 — 2026-10-02 실제 보고로 스트림 방식으로 바꿨다.)
      SnackBarHelper.showSuccess(context, '기본 학교명을 변경했습니다.');
    } else {
      SnackBarHelper.showError(context, '저장 실패: $error');
    }
  }

  /// Firestore 작업을 실행하고, 실패 시 오류 문자열을 반환한다 (성공 시 null).
  Future<String?> _runGuarded(Future<void> Function() task) async {
    if (_saving) return '처리 중입니다. 잠시 후 다시 시도하세요.';
    setState(() => _saving = true);
    try {
      await task();
      return null;
    } catch (e) {
      return '$e';
    } finally {
      if (mounted) setState(() => _saving = false);
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
        actions: [TextButton(onPressed: _logout, child: const Text('로그아웃'))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              WebAdminLoginBrandingSection(
                saving: _saving,
                displayLogoBytes: _displayLogoBytes,
                showRemoveLogoButton:
                    _displayLogoBytes != null ||
                    (!_removeLogo && _branding.logoUrl.isNotEmpty),
                onPickLogo: _pickSchoolLogo,
                onRemoveLogo:
                    () => setState(() {
                      _pendingLogoBytes = null;
                      _removeLogo = true;
                    }),
                schoolHomeUrlController: _schoolHomeUrlController,
                loginMessageController: _loginMessageController,
                loginNoticeController: _loginNoticeController,
                onApplyDefaultNotice: _applyDefaultLoginNotice,
                onShowPreview: _showLoginPreview,
                onSaveBranding: _saveLoginBranding,
              ),
              const Divider(height: 24),
              WebAdminDefaultSchoolNameSection(
                saving: _saving,
                controller: _defaultSchoolNameController,
                onSave: _saveDefaultSchoolName,
              ),
              const Divider(height: 24),
              WebAdminGuideButtonSection(
                saving: _saving,
                labelController: _guideButtonLabelController,
                urlController: _guideButtonUrlController,
                onSave: _saveLoginBranding,
              ),
              const Divider(height: 24),
              WebAdminPublishSection(
                publishing: _publishing,
                publishMessage: _publishMessage,
                publishResult: _publishResult,
                publishFailed: _publishFailed,
                publishedName: _publishedName,
                deleting: _deleting,
                onDelete: _deleteCurrentTimetable,
                onPublish: _publishSharedTimetable,
              ),
              const Divider(height: 24),
              const WebAdminUsageStatsSection(),
              const Divider(height: 24),
              WebAdminPasswordSection(
                saving: _saving,
                viewerPasswordController: _viewerPasswordController,
                viewerPasswordConfirmController:
                    _viewerPasswordConfirmController,
                viewerVisible: _viewerVisible,
                onToggleViewerVisible:
                    () => setState(() => _viewerVisible = !_viewerVisible),
                onSaveViewerPassword: _saveViewerPassword,
                adminPasswordController: _adminPasswordController,
                adminPasswordConfirmController: _adminPasswordConfirmController,
                adminVisible: _adminVisible,
                onToggleAdminVisible:
                    () => setState(() => _adminVisible = !_adminVisible),
                onSaveAdminPassword: _saveAdminPassword,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 현재 시간표를 이 기기와 서버에서 함께 지운다.
  Future<void> _deleteCurrentTimetable() async {
    if (_deleting || _publishing) return;
    final entry = ref.read(activeTimetableEntryProvider);
    if (entry == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('현재 시간표 삭제'),
          content: Text(
            "'${entry.name}'을(를) 삭제할까요?\n"
            '이 기기의 시간표와 서버에 올린 공용 시간표가 함께 지워지며 되돌릴 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref
          .read(sharedTimetableSyncServiceProvider)
          .clearPublishedTimetable();
      final repository = await ref.read(timetableRepositoryProvider.future);
      await repository.deleteTimetable(entry.id);
      final removed = await ref
          .read(timetableRegistryProvider.notifier)
          .removeTimetable(entry.id);
      if (!removed) {
        throw Exception('시간표 삭제에 실패했습니다.');
      }
      if (!mounted) return;
      setState(() {
        _publishedName = null;
        _publishFailed = false;
        _publishResult = '시간표를 삭제했습니다.';
      });
      SnackBarHelper.showSuccess(context, "'${entry.name}' 시간표를 삭제했습니다.");
    } catch (e) {
      AppLogger.error('현재 시간표 삭제 실패: $e', e);
      if (mounted) {
        setState(() {
          _publishFailed = true;
          _publishResult = '삭제 실패: $e';
        });
        SnackBarHelper.showError(context, '삭제 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// 화면이 멈춘 것처럼 보이지 않게, 상태 문구를 그린 뒤 다음 작업으로 넘긴다.
  Future<void> _setPublishMessage(String message) async {
    if (!mounted) return;
    setState(() => _publishMessage = message);
    await Future<void>.delayed(Duration.zero);
  }

  /// 웹 SQLite는 한 번에 넣으면 화면이 길게 멈춘다. 나눠 넣고 진행을 갱신한다.
  Future<void> _insertLessonChunks({
    required Future<void> Function(List<Lesson> lessons) insert,
    required List<Lesson> lessons,
    required String label,
  }) async {
    const chunkSize = 400;
    if (lessons.isEmpty) return;
    for (var start = 0; start < lessons.length; start += chunkSize) {
      final end = min(start + chunkSize, lessons.length);
      await insert(lessons.sublist(start, end));
      if (!mounted) return;
      setState(() => _publishMessage = '$label ($end/${lessons.length})');
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Exception 접두어 없이 사용자용 문구만 남긴다.
  String _publishErrorText(Object error) {
    var text = error.toString();
    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }
    return text.trim().isEmpty ? '알 수 없는 오류가 발생했습니다.' : text;
  }

  /// 게시 실패를 화면에 고정하고, 다음 프레임에 스낵바를 띄운다.
  /// (웹 FilePicker 직후 동기 스낵바가 무시되는 경우 대비)
  void _showPublishFailure(String message) {
    if (!mounted) return;
    setState(() {
      _publishing = false;
      _publishMessage = null;
      _publishFailed = true;
      _publishResult = '게시 실패: $message';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        SnackBarHelper.showError(
          context,
          '게시 실패: $message',
          duration: const Duration(seconds: 6),
        );
      } catch (_) {
        // 스낵바 실패해도 화면의 _publishResult로 안내한다.
      }
    });
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
    if (_publishing) return;

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

    setState(() {
      _publishing = true;
      _publishFailed = false;
      _publishResult = null;
      _publishMessage = '엑셀 파일을 읽는 중…';
    });
    await Future<void>.delayed(Duration.zero);

    var finishedCleanly = false;
    try {
      // 2. 파싱 (동기 작업 전후로 한 프레임씩 양보해 웹 UI가 멈추지 않게 함)
      final excel = await ExcelService.readExcelFromBytes(bytes);
      if (!mounted) return;
      if (excel == null) {
        _showPublishFailure('엑셀 파일을 읽을 수 없습니다.');
        return;
      }

      await _setPublishMessage('시간표를 분석하는 중…');
      final timetableData = await Future(
        () => ExcelService.parseTimetableData(excel),
      );
      if (!mounted) return;
      if (timetableData == null) {
        _showPublishFailure(
          ExcelService.lastParseFailureReason ?? '시간표 데이터를 파싱할 수 없습니다.',
        );
        return;
      }

      // 3. JSON 저장 (바이트 기반)
      await _setPublishMessage('시간표를 저장하는 중…');
      final storage = TimetableStorageService();
      final hashes = await storage.saveTimetableDataForRegistryFromBytes(
        timetableData,
        fileName: fileName,
        bytes: bytes,
      );
      if (!mounted) return;
      if (hashes == null) {
        _showPublishFailure('시간표 저장에 실패했습니다.');
        return;
      }

      // 4. 이름·학기 확인 (기본 이름은 파일명)
      final defaultName = fileName.replaceAll(
        RegExp(r'\.[^.]+$', caseSensitive: false),
        '',
      );
      final registration = await showRegisterTimetableDialog(
        context,
        initialName: defaultName,
      );
      if (registration == null || !mounted) {
        if (mounted) {
          setState(() {
            _publishing = false;
            _publishMessage = null;
          });
        }
        return;
      }
      final timetableName =
          registration.name.isNotEmpty ? registration.name : defaultName;
      _publishedName = timetableName;
      SnackBarHelper.showInfo(context, '\'$timetableName\' 시간표를 올리고 있습니다.');
      await _setPublishMessage('\'$timetableName\' 등록 중…');

      // 5. 레지스트리 등록 (교사·학교명은 기존 활성이 있으면 유지)
      final prevActive = ref.read(activeTimetableEntryProvider);
      final entry = await ref
          .read(timetableRegistryProvider.notifier)
          .registerTimetable(
            name: timetableName,
            fileName: fileName,
            filePath: '',
            hash: hashes.hash,
            contentHash: hashes.contentHash,
            teacherName: prevActive?.teacherName,
            schoolName: prevActive?.schoolName,
            semesterStart: registration.semester.startDate,
            semesterEnd: registration.semester.endDate,
          );
      if (!mounted) return;
      if (entry == null) {
        _showPublishFailure('시간표 등록에 실패했습니다.');
        return;
      }

      // 6. 날짜별 생성·저장 + 활성 전환
      await _setPublishMessage('\'$timetableName\' 수업을 만드는 중…');
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
      await _insertLessonChunks(
        insert: repository.insertLessons,
        lessons: lessons,
        label: '\'$timetableName\' 수업 저장 중',
      );
      if (!mounted) return;
      await _insertLessonChunks(
        insert: repository.insertSnapshot,
        lessons: lessons,
        label: '\'$timetableName\' 원본 저장 중',
      );
      if (!mounted) return;
      await _setPublishMessage('\'$timetableName\' 서버에 올리는 중…');
      await ref.read(timetableRegistryProvider.notifier).switchActive(entry.id);

      // 7. 서버 게시
      final version = await ref
          .read(sharedTimetableSyncServiceProvider)
          .publishTimetable(repo: repository, timetableId: entry.id);
      if (!mounted) return;
      final result = "게시 완료 (버전 $version)";
      setState(() {
        _publishing = false;
        _publishMessage = null;
        _publishFailed = false;
        _publishResult = result;
        _publishedName = entry.name;
      });
      SnackBarHelper.showSuccess(context, "$result · 현재 시간표: '${entry.name}'");
      finishedCleanly = true;
    } catch (e) {
      AppLogger.error('공용 시간표 게시 실패: $e', e);
      _showPublishFailure(_publishErrorText(e));
      finishedCleanly = true;
    } finally {
      // early return / 예외 외 경로에서 스피너가 남지 않게 한다.
      if (!finishedCleanly && mounted && _publishing) {
        setState(() {
          _publishing = false;
          _publishMessage = null;
        });
      }
    }
  }
}
