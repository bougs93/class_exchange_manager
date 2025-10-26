import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/document_type.dart';
import 'document_screen/widgets/substitution_plan_grid.dart';
import 'document_screen/widgets/class_notice_widget.dart';
import 'document_screen/widgets/teacher_notice_widget.dart';
import 'document_screen/widgets/file_export_widget.dart';

/// 문서 출력 화면
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({super.key});

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;

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
    
    // 탭 변경 시 색상 업데이트를 위한 리스너 추가
    _tabController!.addListener(() {
      if (mounted) {
        setState(() {});
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
        title: const Text('결보강계획서/안내'),
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
        return const FileExportWidget();
    }
  }

}

