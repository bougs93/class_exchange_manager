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
      appBar: AppBar(
        title: const Text('결보강계획서'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 교체 제어 패널과 동일한 스타일의 탭바
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: _currentTabColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: DocumentType.values.map((type) => Tab(
                      text: type.displayName,
                      icon: Icon(type.icon, size: 18),
                    )).toList(),
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

