import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/plan_output_menu.dart';
import '../../providers/plan_output_menu_provider.dart';
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

  /// 파일 출력 위젯 업데이트 헬퍼 메서드
  void _updateSubstitutionOutputWidget() {
    final widgetState = _substitutionOutputWidgetKey.currentState;
    if (widgetState != null) {
      widgetState.updateAbsencePeriod();
      widgetState.loadDefaultValuesIfEmpty();
      AppLogger.exchangeDebug('결강기간 업데이트 및 입력란 자동 채우기 완료');
    } else {
      AppLogger.warning('⚠️ SubstitutionOutputWidgetState를 찾을 수 없습니다.');
    }
  }

  /// 메뉴 선택 시 호출
  void _onMenuSelected(PlanOutputMenu menu) {
    final currentMenu = ref.read(planOutputMenuProvider);
    if (currentMenu == menu) {
      return;
    }

    ref.read(planOutputMenuProvider.notifier).state = menu;

    // 파일 출력 탭으로 전환된 경우 결강기간 업데이트
    if (menu == PlanOutputMenu.substitutionOutput) {
      AppLogger.exchangeDebug(
        '메뉴 변경 감지: ${menu.displayName}',
      );
      AppLogger.info('📄 파일 출력 메뉴 진입: 결강기간 업데이트 및 입력란 자동 채우기 요청');

      // 위젯이 생성될 때까지 대기 (다음 프레임에 실행)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateSubstitutionOutputWidget();
        }
      });

      // 100ms 후 재시도 (위젯이 아직 생성되지 않은 경우 대비)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _updateSubstitutionOutputWidget();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenu = ref.watch(planOutputMenuProvider);

    return Scaffold(
      // AppBar 제거 - StartScreen의 공통 AppBar 사용
      body: Row(
        // 세로 전체 높이 사용 + 각 영역 내용은 상단 정렬 (출력 탭 > 출력 메뉴)
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 왼쪽 사이드바
          _buildSidebar(selectedMenu),

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
  Widget _buildSidebar(PlanOutputMenu selectedMenu) {
    return Container(
      width: _sidebarWidth, // 사이드바 너비
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
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
                                  ? type.color.withValues(alpha: 0.1)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              isSelected
                                  ? Border.all(color: type.color, width: 1)
                                  : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              type.icon,
                              size: 18,
                              color:
                                  isSelected
                                      ? type.color
                                      : Colors.grey.shade600,
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
                                          ? type.color
                                          : Colors.grey.shade700,
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
  Widget _buildContent(PlanOutputMenu selectedType) {
    return _buildTabContent(selectedType);
  }

  /// 문서 타입에 따른 탭 컨텐츠 생성
  Widget _buildTabContent(PlanOutputMenu type) {
    switch (type) {
      case PlanOutputMenu.contentInput:
        return const ContentInputGrid();
      case PlanOutputMenu.substitutionOutput:
        return SubstitutionOutputWidget(key: _substitutionOutputWidgetKey);
    }
  }
}
