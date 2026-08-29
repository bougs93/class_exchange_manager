import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/nav_indices.dart';
import '../../models/plan_output_menu.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/plan_output_menu_provider.dart';
import '../../theme/design_tokens.dart';
import '../../ui/widgets/unified_navigation_bar.dart';
import '../../utils/logger.dart';
import 'plan_output/widgets/content_input_grid.dart';
import 'plan_output/widgets/substitution_output/substitution_output_widget.dart';

/// 계획서 출력 화면 (내용 입력 · 결보강 출력)
class PlanOutputScreen extends ConsumerStatefulWidget {
  const PlanOutputScreen({super.key});

  @override
  ConsumerState<PlanOutputScreen> createState() => _PlanOutputScreenState();
}

class _PlanOutputScreenState extends ConsumerState<PlanOutputScreen> {
  // 파일 출력 탭 업데이트용 GlobalKey
  final GlobalKey<SubstitutionOutputWidgetState> _substitutionOutputWidgetKey =
      GlobalKey<SubstitutionOutputWidgetState>();

  // 사이드바 너비 (원하는 값으로 변경 가능)
  static const double _sidebarWidth = 135.0;

  // 결보강 출력 탭을 한 번이라도 열면 위젯을 유지해 준비→교사 동기화 listen이 끊기지 않게 함
  bool _substitutionTabActivated = false;

  /// 결보강 출력 위젯: 결강기간 + 준비 교사 강제 동기화
  void _updateSubstitutionOutputWidget() {
    final widgetState = _substitutionOutputWidgetKey.currentState;
    if (widgetState != null) {
      widgetState.updateAbsencePeriod();
      widgetState.loadDefaultValuesIfEmpty();
      // 빈 칸 채우기와 별도로, 준비 화면 교사를 매번 반영 (2회차 이후 동기화 핵심)
      widgetState.syncPreferredTeacherFromPrepare();
      AppLogger.exchangeDebug('결강기간 업데이트 및 준비 교사 동기화 완료');
    } else {
      AppLogger.warning('⚠️ SubstitutionOutputWidgetState를 찾을 수 없습니다.');
    }
  }

  /// 위젯이 아직 없을 수 있어 다음 프레임·짧은 지연으로 재시도
  void _scheduleSubstitutionSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateSubstitutionOutputWidget();
      }
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _updateSubstitutionOutputWidget();
      }
    });
  }

  /// 메뉴 선택 시 호출
  void _onMenuSelected(PlanOutputMenu menu) {
    final currentMenu = ref.read(planOutputMenuProvider);
    if (currentMenu == menu) {
      return;
    }

    ref.read(planOutputMenuProvider.notifier).state = menu;

    // 파일 출력 탭으로 전환된 경우 결강기간·교사 동기화
    if (menu == PlanOutputMenu.substitutionOutput) {
      AppLogger.exchangeDebug('메뉴 변경 감지: ${menu.displayName}');
      AppLogger.info('📄 파일 출력 메뉴 진입: 결강기간 업데이트 및 준비 교사 동기화 요청');
      setState(() => _substitutionTabActivated = true);
      _scheduleSubstitutionSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenu = ref.watch(planOutputMenuProvider);

    // 사이드바뿐 아니라 '0건 일괄 출력' 등 provider 직접 전환도 동기화
    ref.listen<PlanOutputMenu>(planOutputMenuProvider, (previous, next) {
      if (next != PlanOutputMenu.substitutionOutput) return;
      if (previous == next) return;
      AppLogger.info('결보강 출력 메뉴 진입 → 준비 교사 동기화 요청');
      setState(() => _substitutionTabActivated = true);
      _scheduleSubstitutionSync();
    });

    // 상단 네비에서 계획서 탭으로 들어올 때마다 준비 교사 재동기화
    ref.listen<int>(navigationProvider, (previous, next) {
      if (next != NavIndices.planOutput) return;
      if (ref.read(planOutputMenuProvider) !=
          PlanOutputMenu.substitutionOutput) {
        return;
      }
      AppLogger.info('계획서 탭 재진입 → 준비 교사 동기화 요청');
      _scheduleSubstitutionSync();
    });

    // 결보강 메뉴가 선택되면 캐시 활성화 (첫 진입)
    if (selectedMenu == PlanOutputMenu.substitutionOutput) {
      _substitutionTabActivated = true;
    }

    return Scaffold(
      // AppBar 제거 - StartScreen의 공통 AppBar 사용
      body: Row(
        // 세로 전체 높이 사용 + 각 영역 내용은 상단 정렬 (출력 탭 > 출력 메뉴)
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 왼쪽 사이드바
          _buildSidebar(context, selectedMenu),

          // 오른쪽 컨텐츠 영역 (상단부터 표시)
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              widthFactor: 1.0,
              child: _buildContent(selectedMenu),
            ),
          ),
        ],
      ),
    );
  }

  /// 왼쪽 사이드바 위젯
  Widget _buildSidebar(BuildContext context, PlanOutputMenu selectedMenu) {
    final tokens = context.tokens;
    return Container(
      width: _sidebarWidth, // 사이드바 너비
      decoration: BoxDecoration(
        color: tokens.sectionBackground,
        border: Border(right: BorderSide(color: tokens.cardBorder, width: 1)),
      ),
      alignment: Alignment.topCenter,
      child: Padding(
        // 사이드바 상·하 여백 (다른 탭 콘텐츠와 시각적 균형)
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              PlanOutputMenu.values.map((type) {
                final isSelected = selectedMenu == type;
                // 플랫 모노(monochromeMenuAccents)에서는 메뉴별 색상 대신 틸 단색 사용
                final accent =
                    tokens.monochromeMenuAccents ? tokens.primary : type.color;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onMenuSelected(type),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        // 교체 1차 메뉴(kUnifiedNavBarHeight)와 동일한 높이
                        height: kUnifiedNavBarHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? accent.withValues(alpha: 0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              isSelected
                                  ? Border.all(color: accent, width: 1)
                                  : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              type.icon,
                              size: 18,
                              color: isSelected ? accent : tokens.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                type.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      isSelected
                                          ? accent
                                          : tokens.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// 오른쪽 컨텐츠 영역
  ///
  /// IndexedStack으로 결보강 위젯을 유지해, 내용 입력으로 다녀와도
  /// 준비>교사 listen이 끊기지 않습니다.
  Widget _buildContent(PlanOutputMenu selectedType) {
    final showSubstitution = selectedType == PlanOutputMenu.substitutionOutput;

    return IndexedStack(
      index: showSubstitution ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        // 0: 내용 입력 (항상)
        const ContentInputGrid(),
        // 1: 결보강 출력 (한 번 활성화된 뒤부터 유지)
        if (_substitutionTabActivated)
          SubstitutionOutputWidget(key: _substitutionOutputWidgetKey)
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
