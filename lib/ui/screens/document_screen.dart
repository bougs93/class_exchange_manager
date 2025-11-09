import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/document_type.dart';
import '../../utils/logger.dart';
import 'document_screen/widgets/substitution_plan_grid.dart';
import 'document_screen/widgets/class_notice_widget.dart';
import 'document_screen/widgets/teacher_notice_widget.dart';
import 'document_screen/widgets/file_export/file_export_widget.dart';

/// 문서 출력 화면
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({super.key});

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  // 파일 출력 탭 업데이트용 GlobalKey
  final GlobalKey<FileExportWidgetState> _fileExportWidgetKey = GlobalKey<FileExportWidgetState>();

  @override
  void initState() {
    super.initState();
    _initializeTabController();
  }

  /// TabController 초기화
  void _initializeTabController() {
    // 기존 컨트롤러가 있으면 해제
    _tabController?.dispose();
    
    // 새로운 컨트롤러 생성
    _tabController = TabController(
      length: DocumentType.values.length,
      vsync: this,
      animationDuration: Duration.zero,
    );
    
    // 탭 변경 시 색상 업데이트 및 파일 출력 탭 업데이트
    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
        
        // 파일 출력 탭으로 전환된 경우 결강기간 업데이트
        final currentIndex = _tabController!.index;
        final fileExportIndex = DocumentType.fileExport.index;
        AppLogger.exchangeDebug('탭 변경 감지: 인덱스 $currentIndex (파일 출력: $fileExportIndex)');
        
        if (currentIndex == fileExportIndex) {
          AppLogger.info('📄 파일 출력 탭 진입: 결강기간 업데이트 요청');
          
          // 위젯이 생성될 때까지 대기 (다음 프레임에 실행)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final widgetState = _fileExportWidgetKey.currentState;
              if (widgetState != null) {
                widgetState.updateAbsencePeriod();
                AppLogger.exchangeDebug('결강기간 업데이트 메서드 호출 완료');
              } else {
                AppLogger.warning('⚠️ FileExportWidgetState가 아직 생성되지 않았습니다. (GlobalKey가 null) - 재시도 예정');
                // 위젯이 생성될 때까지 추가 대기 (100ms 후 재시도)
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    final widgetState = _fileExportWidgetKey.currentState;
                    if (widgetState != null) {
                      widgetState.updateAbsencePeriod();
                      AppLogger.exchangeDebug('결강기간 업데이트 메서드 호출 완료 (재시도 성공)');
                    } else {
                      AppLogger.warning('⚠️ FileExportWidgetState를 찾을 수 없습니다. (재시도 실패)');
                    }
                  }
                });
              }
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // null-safe 호출: _tabController가 null이 아닐 때만 dispose 호출
    _tabController?.dispose();
    super.dispose();
  }

  /// 현재 선택된 탭의 색상 가져오기
  Color get _currentTabColor {
    // null-safe 접근: _tabController가 null일 경우 기본 색상 반환
    final currentIndex = _tabController?.index ?? 0;
    if (currentIndex >= 0 && currentIndex < DocumentType.values.length) {
      return DocumentType.values[currentIndex].color;
    }
    return Colors.grey; // 기본 색상
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar 제거 - HomeScreen의 공통 AppBar 사용
      body: Column(
        children: [
          // 교체 제어 패널과 동일한 스타일의 탭바
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft, // 왼쪽 정렬 명시
                    child: Container(
                      height: 50, // 전체 높이 제한
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0), // 패딩 최소화
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true, // 스크롤 가능 (TabAlignment.start 사용을 위해 필요)
                        tabs: DocumentType.values.map((type) {
                          return SizedBox(
                            width: 82, // 모든 탭 버튼의 폭을 70px로 고정
                            child: Tab(
                              height: 46, // 탭 높이를 46으로 설정 (오버플로우 방지)
                              icon: SizedBox(
                                width: 18, // 아이콘 너비 고정
                                height: 18, // 아이콘 높이 고정
                                child: Icon(
                                  type.icon,
                                  size: 18, // 아이콘 크기를 18로 고정 (모든 아이콘 동일)
                                ),
                              ),
                              text: type.displayName,
                              iconMargin: const EdgeInsets.only(bottom: 2), // 아이콘과 텍스트 간격 조정
                            ),
                          );
                        }).toList(),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicator: BoxDecoration(
                          color: _currentTabColor,
                          borderRadius: BorderRadius.circular(6), // 모서리 둥글기
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(
                          fontSize: 12, // 폰트 크기를 12px로 설정
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 12, // 폰트 크기를 12px로 설정
                        ),
                        tabAlignment: TabAlignment.start, // 왼쪽 정렬
                        dividerColor: Colors.transparent,
                        dividerHeight: 0,
                        // 성능 최적화
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        splashFactory: NoSplash.splashFactory,
                        mouseCursor: SystemMouseCursors.click,
                        enableFeedback: false,
                        // 탭 간격 최소화
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 탭 컨텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: DocumentType.values.map((type) => _buildTabContent(type)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 문서 타입에 따른 탭 컨텐츠 생성
  Widget _buildTabContent(DocumentType type) {
    switch (type) {
      case DocumentType.substitutionPlan:
        return const SubstitutionPlanGrid();
      case DocumentType.classNotice:
        return const ClassNoticeWidget();
      case DocumentType.teacherNotice:
        return const TeacherNoticeWidget();
      case DocumentType.fileExport:
        return FileExportWidget(key: _fileExportWidgetKey);
    }
  }

}

