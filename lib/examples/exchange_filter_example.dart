import 'package:flutter/material.dart';
import '../ui/widgets/exchange_filter_widget.dart';
import '../models/exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/chain_exchange_path.dart';
import '../models/exchange_node.dart';

/// 교체 필터 위젯 사용 예시
/// 순환교체, 연쇄교체 등 다양한 모드에서 공용 필터 위젯 사용법을 보여줍니다
class ExchangeFilterExample extends StatefulWidget {
  const ExchangeFilterExample({super.key});

  @override
  State<ExchangeFilterExample> createState() => _ExchangeFilterExampleState();
}

class _ExchangeFilterExampleState extends State<ExchangeFilterExample> {
  // 예시 데이터
  List<ExchangePath> _paths = [];
  String _searchQuery = '';
  
  // 순환교체 필터 상태
  List<int>? _availableSteps;
  int? _selectedStep;
  String? _selectedDay;
  
  // 연쇄교체 필터 상태
  List<int>? _chainAvailableSteps;
  int? _chainSelectedStep;
  
  // 현재 모드
  ExchangePathType _currentMode = ExchangePathType.circular;

  @override
  void initState() {
    super.initState();
    _initializeExampleData();
  }

  /// 예시 데이터 초기화
  void _initializeExampleData() {
    // 순환교체 예시 경로들
    List<ExchangeNode> circularNodes1 = [
      ExchangeNode(teacherName: 'A교사', day: '월', period: 1, className: '1학년 1반', subjectName: '수학'),
      ExchangeNode(teacherName: 'B교사', day: '화', period: 2, className: '1학년 2반', subjectName: '영어'),
      ExchangeNode(teacherName: 'A교사', day: '월', period: 1, className: '1학년 1반', subjectName: '수학'),
    ];
    
    List<ExchangeNode> circularNodes2 = [
      ExchangeNode(teacherName: 'C교사', day: '수', period: 3, className: '2학년 1반', subjectName: '과학'),
      ExchangeNode(teacherName: 'D교사', day: '목', period: 4, className: '2학년 2반', subjectName: '사회'),
      ExchangeNode(teacherName: 'E교사', day: '금', period: 5, className: '2학년 3반', subjectName: '국어'),
      ExchangeNode(teacherName: 'C교사', day: '수', period: 3, className: '2학년 1반', subjectName: '과학'),
    ];
    
    _paths = [
      CircularExchangePath.fromNodes(circularNodes1),
      CircularExchangePath.fromNodes(circularNodes2),
    ];
    
    // 사용 가능한 단계들 설정
    _availableSteps = [3, 4]; // 3단계, 4단계 순환교체
    _selectedStep = 3; // 기본적으로 3단계 선택
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교체 필터 위젯 예시'),
        actions: [
          // 모드 전환 버튼
          PopupMenuButton<ExchangePathType>(
            onSelected: (mode) {
              setState(() {
                _currentMode = mode;
                _updateModeData();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ExchangePathType.circular,
                child: Text('순환교체 모드'),
              ),
              const PopupMenuItem(
                value: ExchangePathType.chain,
                child: Text('연쇄교체 모드'),
              ),
            ],
            child: Text(_getModeText(_currentMode)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '검색어 입력',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // 공용 필터 위젯
          ExchangeFilterWidget(
            mode: _currentMode,
            paths: _paths,
            searchQuery: _searchQuery,
            availableSteps: _currentMode == ExchangePathType.circular 
                ? _availableSteps 
                : _chainAvailableSteps,
            selectedStep: _currentMode == ExchangePathType.circular 
                ? _selectedStep 
                : _chainSelectedStep,
            onStepChanged: (step) {
              setState(() {
                if (_currentMode == ExchangePathType.circular) {
                  _selectedStep = step;
                } else {
                  _chainSelectedStep = step;
                }
              });
            },
            selectedDay: _selectedDay,
            onDayChanged: (day) {
              setState(() {
                _selectedDay = day;
              });
            },
          ),
          
          // 필터 결과 표시
          Expanded(
            child: _buildFilterResults(),
          ),
        ],
      ),
    );
  }

  /// 모드별 데이터 업데이트
  void _updateModeData() {
    if (_currentMode == ExchangePathType.chain) {
      // 연쇄교체 모드로 전환
      _chainAvailableSteps = [2]; // 연쇄교체는 2단계만
      _chainSelectedStep = 2;
    } else {
      // 순환교체 모드로 전환
      _availableSteps = [3, 4];
      _selectedStep = 3;
    }
  }

  /// 모드 텍스트 반환
  String _getModeText(ExchangePathType mode) {
    switch (mode) {
      case ExchangePathType.circular:
        return '순환교체';
      case ExchangePathType.chain:
        return '연쇄교체';
      default:
        return '알 수 없음';
    }
  }

  /// 필터 결과 표시
  Widget _buildFilterResults() {
    List<ExchangePath> filteredPaths = _paths.where((path) {
      // 단계 필터링
      int? currentStep = _currentMode == ExchangePathType.circular 
          ? _selectedStep 
          : _chainSelectedStep;
      
      if (currentStep != null) {
        if (_currentMode == ExchangePathType.circular) {
          if (path is CircularExchangePath && path.nodes.length != currentStep) {
            return false;
          }
        } else if (_currentMode == ExchangePathType.chain) {
          if (path is ChainExchangePath && path.chainDepth != currentStep) {
            return false;
          }
        }
      }
      
      // 요일 필터링
      if (_selectedDay != null) {
        ExchangeNode? targetNode = _getTargetNode(path);
        if (targetNode == null || targetNode.day != _selectedDay) {
          return false;
        }
      }
      
      // 검색 필터링
      if (_searchQuery.isNotEmpty) {
        ExchangeNode? targetNode = _getTargetNode(path);
        if (targetNode == null || !_matchesSearchQuery(targetNode)) {
          return false;
        }
      }
      
      return true;
    }).toList();

    return ListView.builder(
      itemCount: filteredPaths.length,
      itemBuilder: (context, index) {
        final path = filteredPaths[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(path.displayTitle),
            subtitle: Text(path.description),
            trailing: Text('${path.nodes.length}개 노드'),
          ),
        );
      },
    );
  }

  /// 경로에서 타겟 노드 추출
  ExchangeNode? _getTargetNode(ExchangePath path) {
    switch (_currentMode) {
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
      default:
        break;
    }
    return null;
  }

  /// 검색 쿼리와 노드가 일치하는지 확인
  bool _matchesSearchQuery(ExchangeNode node) {
    if (_searchQuery.isEmpty) return true;
    
    final query = _searchQuery.toLowerCase();
    
    return node.teacherName.toLowerCase().contains(query) ||
           node.subjectName.toLowerCase().contains(query) ||
           node.className.toLowerCase().contains(query) ||
           node.day.toLowerCase().contains(query) ||
           node.period.toString().contains(query);
  }
}
