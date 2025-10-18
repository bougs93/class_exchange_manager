import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/document_type.dart';
import 'document_screen/widgets/substitution_plan_grid.dart';

/// 문서 출력 화면
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({super.key});

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: DocumentType.values.length,
      vsync: this,
      animationDuration: Duration.zero,
    );
    
    // 탭 변경 시 색상 업데이트를 위한 리스너 추가
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 현재 선택된 탭의 색상 가져오기
  Color get _currentTabColor {
    final currentIndex = _tabController.index;
    if (currentIndex >= 0 && currentIndex < DocumentType.values.length) {
      return DocumentType.values[currentIndex].color;
    }
    return Colors.grey; // 기본 색상
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문서 출력'),
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
        return _buildNoticeTab(
          title: type.displayName,
          description: '학급별 교체 안내문을 생성합니다.',
          icon: Icons.class_outlined,
          color: type.color,
          featureTitle: '학급안내 기능',
          featureDescription: '학급별 수업 교체 안내문 생성',
        );
      case DocumentType.teacherNotice:
        return _buildNoticeTab(
          title: type.displayName,
          description: '교사별 교체 안내문을 생성합니다.',
          icon: Icons.person_outline,
          color: type.color,
          featureTitle: '교사안내 기능',
          featureDescription: '교사별 교체 안내문 및 QR코드 생성',
        );
    }
  }

  /// 공통 안내 탭 UI 생성
  Widget _buildNoticeTab({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String featureTitle,
    required String featureDescription,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 64,
                    color: color.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    featureTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    featureDescription,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

