import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/nav_indices.dart';
import '../../models/plan_output_menu.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/plan_output_menu_provider.dart';
import '../../theme/design_tokens.dart';
import '../widgets/app_branding_header.dart';
import '../widgets/app_content_card.dart';
import 'start_content/start_settings_card.dart';
import 'start_content/timetable_summary_card.dart';
import 'handlers/exchange_ui_builder.dart';
import 'timetable_file_screen.dart';

/// 시작 화면 콘텐츠
///
/// 시간표 카드(시간표 → 교사 → 계획서 계층)와 설정을 표시합니다.
///
/// 교사명·학교명은 전역 설정이 아니라 활성 시간표의 속성이므로 별도 '기본 정보'
/// 카드를 두지 않고 시간표 카드 안에서 편집합니다(문서 §3②).
class StartContentScreen extends ConsumerStatefulWidget {
  const StartContentScreen({super.key});

  @override
  ConsumerState<StartContentScreen> createState() => _StartContentScreenState();
}

class _StartContentScreenState extends ConsumerState<StartContentScreen>
    with ExchangeUIBuilder {
  /// 파일 로드 오류 메시지 닫기
  void _clearFileError() {
    ref.read(exchangeScreenProvider.notifier).setErrorMessage(null);
  }

  /// 시간표 관리 화면 열기
  ///
  /// [autoStartAdd]가 true면 진입 즉시 파일 선택 대화상자를 띄웁니다.
  /// 시간표 추가·전환은 레지스트리 스코프가 적용된 관리 화면에서만 수행합니다
  /// (홈에서 직접 로드하면 활성 시간표 스코프와 불일치가 발생하므로 우회를 막음).
  Future<void> _openTimetableManager({bool autoStartAdd = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimetableFileScreen(autoStartAdd: autoStartAdd),
      ),
    );
    if (mounted) {
      setState(() {}); // 복귀 시 카드 정보 갱신
    }
  }

  /// 계획서 관리 화면(계획서 탭 > 결보강 출력)으로 이동
  void _openProfileManager() {
    ref.read(planOutputMenuProvider.notifier).state =
        PlanOutputMenu.substitutionOutput;
    ref.read(navigationProvider.notifier).state = NavIndices.planOutput;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final errorMessage = ref.watch(
      exchangeScreenProvider.select((state) => state.errorMessage),
    );

    return Container(
      color: tokens.sectionBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 앱 아이콘 + 프로그램명 + 버전·이용 기간 (도움말 > 프로그램 정보와 동일)
            const AppContentCard(
              child: AppBrandingHeader(showVersionAndPeriod: true),
            ),
            const SizedBox(height: 16),

            // 시간표 카드 (시간표 → 교사 → 계획서)
            TimetableSummaryCard(
              onAddTimetable: () => _openTimetableManager(autoStartAdd: true),
              onOpenManager: _openTimetableManager,
              onOpenProfiles: _openProfileManager,
              errorSection: buildPaddedErrorMessageSection(
                errorMessage,
                _clearFileError,
              ),
            ),

            const SizedBox(height: 24),

            // 설정 카드 (접을 수 있음) — 언어·색상·초기화 등은 카드가 자체 관리
            const StartSettingsCard(),
          ],
        ),
      ),
    );
  }
}
