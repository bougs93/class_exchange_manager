import 'package:flutter/material.dart';
import '../../models/exchange_path.dart';
import '../../models/exchange_node.dart';
import '../../models/circular_exchange_path.dart';
import '../../models/chain_exchange_path.dart';
import '../../models/one_to_one_exchange_path.dart';
import '../../models/supplement_exchange_path.dart';

/// 교체 경로 필터 위젯
/// 순환교체, 연쇄교체, 1:1교체, 보강교체 등 모든 교체 모드에서 공용으로 사용하는 필터 위젯
/// 
/// 주요 기능:
/// - 단계 필터: 순환교체(2~5단계, 경로가 있을 때만), 연쇄교체(필터 불필요), 1:1교체, 보강교체
/// - 요일 필터: 월~금 요일별 필터링
/// - 로딩 상태 처리: 경로 탐색 중에는 단계 필터 숨김
/// - 빈 경로 처리: 교체 가능한 경로가 없을 때는 단계 필터 숨김
/// - 모드별 특화: 순환교체에서만 2~5단계 표시, 연쇄교체는 필터 숨김
class ExchangeFilterWidget extends StatelessWidget {
  final ExchangePathType mode;                    // 현재 모드
  final List<ExchangePath> paths;                 // 전체 경로 리스트
  final String searchQuery;                       // 검색 쿼리
  final bool isLoading;                           // 로딩 상태 (경로 탐색 중인지 여부)
  
  // 단계 필터 관련 매개변수 (순환교체, 연쇄교체에서 사용)
  final List<int>? availableSteps;                // 사용 가능한 단계들
  final int? selectedStep;                        // 선택된 단계
  final Function(int?)? onStepChanged;           // 단계 변경 콜백
  
  // 요일 필터 관련 매개변수
  final String? selectedDay;                      // 선택된 요일
  final Function(String?)? onDayChanged;          // 요일 변경 콜백
  
  // 교사 필터 관련 매개변수 (향후 확장용)
  final List<String>? availableTeachers;          // 사용 가능한 교사들
  final String? selectedTeacher;                 // 선택된 교사
  final Function(String?)? onTeacherChanged;      // 교사 변경 콜백
  
  // 과목 필터 관련 매개변수 (향후 확장용)
  final List<String>? availableSubjects;          // 사용 가능한 과목들
  final String? selectedSubject;                 // 선택된 과목
  final Function(String?)? onSubjectChanged;     // 과목 변경 콜백

  const ExchangeFilterWidget({
    super.key,
    required this.mode,
    required this.paths,
    required this.searchQuery,
    this.isLoading = false,                        // 기본값 false로 설정
    this.availableSteps,
    this.selectedStep,
    this.onStepChanged,
    this.selectedDay,
    this.onDayChanged,
    this.availableTeachers,
    this.selectedTeacher,
    this.onTeacherChanged,
    this.availableSubjects,
    this.selectedSubject,
    this.onSubjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 필터 그룹 제목
          _buildFilterHeader(),
          const SizedBox(height: 4),
          
          // 단계 필터 (순환교체에서만 2~5단계 표시, 다른 모드는 조건부 표시)
          if (_shouldShowStepFilter()) ...[
            _buildStepFilter(),
            const SizedBox(height: 4),
          ],
          
          // 요일 필터
          _buildDayFilter(),
          
          // 교사 필터 (향후 확장용)
          if (availableTeachers != null && availableTeachers!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildTeacherFilter(),
          ],
          
          // 과목 필터 (향후 확장용)
          if (availableSubjects != null && availableSubjects!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildSubjectFilter(),
          ],
        ],
      ),
    );
  }

  /// 단계 필터 표시 여부 결정
  /// 순환교체에서만 2~5단계 표시, 연쇄교체는 필터 불필요
  bool _shouldShowStepFilter() {
    // 기본 조건: 사용 가능한 단계가 있고 로딩 중이 아니어야 함
    if (availableSteps == null || availableSteps!.isEmpty || isLoading) {
      return false;
    }

    // 순환교체 모드: 경로가 있을 때만 2~5단계 표시
    if (mode == ExchangePathType.circular) {
      return paths.isNotEmpty && _hasCircularPaths();
    }

    // 연쇄교체 모드: 필터 동작 불필요 - 항상 숨김
    if (mode == ExchangePathType.chain) {
      return false;
    }

    // 1:1교체, 보강교체 모드: 경로가 있을 때 표시
    if (mode == ExchangePathType.oneToOne || mode == ExchangePathType.supplement) {
      return paths.isNotEmpty;
    }

    return false;
  }

  /// 순환교체 경로가 있는지 확인
  bool _hasCircularPaths() {
    return paths.any((path) => path is CircularExchangePath);
  }

  /// 필터 헤더 구성
  Widget _buildFilterHeader() {
    return Row(
      children: [
        Icon(
          Icons.filter_list,
          size: 14,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          '검색 필터',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  /// 단계 필터 구성
  Widget _buildStepFilter() {
    return Row(
      children: [
        // 각 단계별 버튼을 Expanded로 감싸서 전체 너비 채우기
        ...availableSteps!.map((step) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: step == availableSteps!.last ? 0 : 2, // 마지막 버튼은 오른쪽 패딩 없음
            ),
            child: _buildStepButton(
              label: _getStepLabel(step),
              step: step,
              isSelected: selectedStep == step,
            ),
          ),
        )),
      ],
    );
  }

  /// 단계 라벨 생성
  String _getStepLabel(int step) {
    switch (mode) {
      case ExchangePathType.circular:
        return '${step-2}단계(${_getStepCount(step)})';
      case ExchangePathType.chain:
        return '$step단계(${_getStepCount(step)})';
      case ExchangePathType.oneToOne:
        return '1:1교체(${_getStepCount(step)})';
      case ExchangePathType.supplement:
        return '보강교체(${_getStepCount(step)})';
    }
  }

  /// 특정 단계의 경로 개수 계산 (검색 및 기타 필터링 반영)
  int _getStepCount(int step) {
    // 단계별 경로를 먼저 필터링 (가장 제한적인 조건)
    final stepPaths = paths.where((path) {
      switch (mode) {
        case ExchangePathType.circular:
          return path is CircularExchangePath && path.nodes.length == step;
        case ExchangePathType.chain:
          return path is ChainExchangePath && path.chainDepth == step;
        case ExchangePathType.oneToOne:
          return path is OneToOneExchangePath; // 1:1 교체는 항상 2개 노드
        case ExchangePathType.supplement:
          return path is SupplementExchangePath; // 보강교체는 항상 2개 노드
      }
    }).toList();
    
    // 필터가 없으면 단계별 경로 수만 반환
    if (selectedDay == null && searchQuery.isEmpty) {
      return stepPaths.length;
    }
    
    // 추가 필터링 적용
    return stepPaths.where((path) {
      if (path.nodes.length < 2) return false;
      
      final targetNode = _getTargetNode(path);
      if (targetNode == null) return false;
      
      // 요일 필터링
      if (selectedDay != null && targetNode.day != selectedDay) {
        return false;
      }
      
      // 검색 필터링
      if (searchQuery.isNotEmpty && !_matchesSearchQuery(targetNode)) {
        return false;
      }
      
      return true;
    }).length;
  }

  /// 경로에서 타겟 노드 추출
  ExchangeNode? _getTargetNode(ExchangePath path) {
    switch (mode) {
      case ExchangePathType.circular:
        if (path is CircularExchangePath && path.nodes.length >= 2) {
          return path.nodes[1]; // 순환교체의 경우 두 번째 노드가 교체 대상
        }
        break;
      case ExchangePathType.chain:
        if (path is ChainExchangePath) {
          return path.nodeB; // 연쇄교체의 경우 마지막 교체 대상
        }
        break;
      case ExchangePathType.oneToOne:
        if (path is OneToOneExchangePath) {
          return path.targetNode; // 1:1 교체의 경우 교체 대상 노드
        }
        break;
      case ExchangePathType.supplement:
        if (path is SupplementExchangePath) {
          return path.targetNode; // 보강교체의 경우 보강 대상 노드
        }
        break;
    }
    return null;
  }

  /// 단계 선택 버튼 구성
  Widget _buildStepButton({
    required String label,
    required int step,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onStepChanged?.call(isSelected ? null : step),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 요일 필터 구성
  Widget _buildDayFilter() {
    final List<String> days = ['월', '화', '수', '목', '금'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 요일 선택 버튼들
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            // 각 요일별 버튼
            ...days.map((day) => _buildDayButton(day)),
          ],
        ),
      ],
    );
  }

  /// 요일 선택 버튼 구성
  Widget _buildDayButton(String day) {
    final bool isSelected = selectedDay == day;
    
    return GestureDetector(
      onTap: () => onDayChanged?.call(isSelected ? null : day),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// 교사 필터 구성 (향후 확장용)
  Widget _buildTeacherFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '교사 필터',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            ...availableTeachers!.map((teacher) => _buildTeacherButton(teacher)),
          ],
        ),
      ],
    );
  }

  /// 교사 선택 버튼 구성 (향후 확장용)
  Widget _buildTeacherButton(String teacher) {
    final bool isSelected = selectedTeacher == teacher;
    
    return GestureDetector(
      onTap: () => onTeacherChanged?.call(isSelected ? null : teacher),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade100 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.purple.shade300 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          teacher,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.purple.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// 과목 필터 구성 (향후 확장용)
  Widget _buildSubjectFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '과목 필터',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            ...availableSubjects!.map((subject) => _buildSubjectButton(subject)),
          ],
        ),
      ],
    );
  }

  /// 과목 선택 버튼 구성 (향후 확장용)
  Widget _buildSubjectButton(String subject) {
    final bool isSelected = selectedSubject == subject;
    
    return GestureDetector(
      onTap: () => onSubjectChanged?.call(isSelected ? null : subject),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade100 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.orange.shade300 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          subject,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.orange.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// 검색 쿼리와 노드가 일치하는지 확인하는 통합 메서드
  bool _matchesSearchQuery(ExchangeNode node) {
    if (searchQuery.isEmpty) return true;
    
    final query = searchQuery.toLowerCase();
    
    // 교사명 검색
    if (node.teacherName.toLowerCase().contains(query)) {
      return true;
    }
    
    // 과목명 검색
    if (node.subjectName.toLowerCase().contains(query)) {
      return true;
    }
    
    // 학급명 검색
    if (node.className.toLowerCase().contains(query)) {
      return true;
    }
    
    // 요일 검색
    if (node.day.toLowerCase().contains(query)) {
      return true;
    }
    
    // 교시 검색
    if (node.period.toString().contains(query)) {
      return true;
    }
    
    return false;
  }
}
