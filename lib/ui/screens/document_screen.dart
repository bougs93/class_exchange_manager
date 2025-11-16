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

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  // 선택된 메뉴 인덱스
  int _selectedIndex = 0;
  
  // 파일 출력 탭 업데이트용 GlobalKey
  final GlobalKey<FileExportWidgetState> _fileExportWidgetKey = GlobalKey<FileExportWidgetState>();
  
  // 사이드바 너비 (원하는 값으로 변경 가능)
  static const double _sidebarWidth = 135.0;

  /// 메뉴 선택 시 호출
  void _onMenuSelected(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      
      // 파일 출력 탭으로 전환된 경우 결강기간 업데이트
      final fileExportIndex = DocumentType.fileExport.index;
      AppLogger.exchangeDebug('메뉴 변경 감지: 인덱스 $index (파일 출력: $fileExportIndex)');
      
      if (index == fileExportIndex) {
        AppLogger.info('📄 파일 출력 메뉴 진입: 결강기간 업데이트 및 입력란 자동 채우기 요청');
        
        // 위젯이 생성될 때까지 대기 (다음 프레임에 실행)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final widgetState = _fileExportWidgetKey.currentState;
            if (widgetState != null) {
              // 결강기간 업데이트
              widgetState.updateAbsencePeriod();
              AppLogger.exchangeDebug('결강기간 업데이트 메서드 호출 완료');
              
              // 입력란이 비어있으면 설정에서 교사명, 학교명 자동 입력
              widgetState.loadDefaultValuesIfEmpty();
              AppLogger.exchangeDebug('입력란 자동 채우기 메서드 호출 완료');
            } else {
              AppLogger.warning('⚠️ FileExportWidgetState가 아직 생성되지 않았습니다. (GlobalKey가 null) - 재시도 예정');
              // 위젯이 생성될 때까지 추가 대기 (100ms 후 재시도)
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  final widgetState = _fileExportWidgetKey.currentState;
                  if (widgetState != null) {
                    // 결강기간 업데이트
                    widgetState.updateAbsencePeriod();
                    AppLogger.exchangeDebug('결강기간 업데이트 메서드 호출 완료 (재시도 성공)');
                    
                    // 입력란이 비어있으면 설정에서 교사명, 학교명 자동 입력
                    widgetState.loadDefaultValuesIfEmpty();
                    AppLogger.exchangeDebug('입력란 자동 채우기 메서드 호출 완료 (재시도 성공)');
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar 제거 - HomeScreen의 공통 AppBar 사용
      body: Row(
        children: [
          // 왼쪽 사이드바
          _buildSidebar(),
          
          // 오른쪽 컨텐츠 영역
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  /// 왼쪽 사이드바 위젯
  Widget _buildSidebar() {
    return Container(
      width: _sidebarWidth, // 사이드바 너비
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: DocumentType.values.asMap().entries.map((entry) {
          final index = entry.key;
          final type = entry.value;
          final isSelected = _selectedIndex == index;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onMenuSelected(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? type.color.withValues(alpha: 0.1) 
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                      ? Border.all(
                          color: type.color,
                          width: 2,
                        )
                      : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type.icon,
                        size: 20,
                        color: isSelected 
                          ? type.color 
                          : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                            color: isSelected 
                              ? type.color 
                              : Colors.grey.shade700,
                          ),
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
    );
  }

  /// 오른쪽 컨텐츠 영역
  Widget _buildContent() {
    final selectedType = DocumentType.values[_selectedIndex];
    return _buildTabContent(selectedType);
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

