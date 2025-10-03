import '../models/circular_exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/chain_exchange_path.dart';

/// 셀 상태 관리 클래스
class CellStateManager {
  // 셀 선택 관련 변수들
  String? _selectedTeacher;
  String? _selectedDay;
  int? _selectedPeriod;
  
  // 타겟 셀 관련 변수들 (교체 대상의 같은 행 셀)
  String? _targetTeacher;
  String? _targetDay;
  int? _targetPeriod;
  
  // 교체 가능한 교사 정보 (교사명, 요일, 교시)
  List<Map<String, dynamic>> _exchangeableTeachers = [];
  
  // 선택된 경로들
  CircularExchangePath? _selectedCircularPath;
  OneToOneExchangePath? _selectedOneToOnePath;
  ChainExchangePath? _selectedChainPath;

  /// 선택 상태 업데이트
  void updateSelection(String? teacher, String? day, int? period) {
    _selectedTeacher = teacher;
    _selectedDay = day;
    _selectedPeriod = period;
  }
  
  /// 타겟 셀 상태 업데이트
  void updateTargetCell(String? teacher, String? day, int? period) {
    _targetTeacher = teacher;
    _targetDay = day;
    _targetPeriod = period;
  }
  
  /// 교체 가능한 교사 정보 업데이트
  void updateExchangeableTeachers(List<Map<String, dynamic>> exchangeableTeachers) {
    _exchangeableTeachers = exchangeableTeachers;
  }
  
  /// 선택된 순환교체 경로 업데이트
  void updateSelectedCircularPath(CircularExchangePath? path) {
    _selectedCircularPath = path;
  }
  
  /// 선택된 1:1 교체 경로 업데이트
  void updateSelectedOneToOnePath(OneToOneExchangePath? path) {
    _selectedOneToOnePath = path;
  }
  
  /// 선택된 연쇄교체 경로 업데이트
  void updateSelectedChainPath(ChainExchangePath? path) {
    _selectedChainPath = path;
  }

  /// 특정 셀이 선택된 상태인지 확인
  bool isCellSelected(String teacherName, String day, int period) {
    return _selectedTeacher == teacherName && 
           _selectedDay == day && 
           _selectedPeriod == period;
  }
  
  /// 특정 셀이 타겟 셀인지 확인
  bool isCellTarget(String teacherName, String day, int period) {
    return _targetTeacher == teacherName && 
           _targetDay == day && 
           _targetPeriod == period;
  }
  
  /// 특정 교사가 선택된 상태인지 확인
  bool isTeacherSelected(String teacherName) {
    return _selectedTeacher == teacherName;
  }

  /// 교체 가능한 교사인지 확인 (교사명, 요일, 교시 기준)
  bool isExchangeableTeacher(String teacherName, String day, int period) {
    return _exchangeableTeachers.any((teacher) => 
      teacher['teacherName'] == teacherName &&
      teacher['day'] == day &&
      teacher['period'] == period
    );
  }
  
  /// 교체 가능한 교사인지 확인 (교사명만 기준)
  bool isExchangeableTeacherForTeacher(String teacherName) {
    return _exchangeableTeachers.any((teacher) => 
      teacher['teacherName'] == teacherName
    );
  }

  /// 순환교체 경로에 포함된 셀인지 확인
  bool isInCircularPath(String teacherName, String day, int period) {
    if (_selectedCircularPath == null) return false;
    
    return _selectedCircularPath!.nodes.any((node) => 
      node.teacherName == teacherName &&
      node.day == day &&
      node.period == period
    );
  }
  
  /// 순환교체 경로에서 해당 셀의 단계 번호 가져오기
  int? getCircularPathStep(String teacherName, String day, int period) {
    if (_selectedCircularPath == null) return null;
    
    for (int i = 0; i < _selectedCircularPath!.nodes.length; i++) {
      final node = _selectedCircularPath!.nodes[i];
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        // 첫 번째 노드(시작점)는 오버레이 표시하지 않음 (null 반환)
        if (i == 0) {
          return null;
        }
        // 두 번째 노드부터는 1, 2, 3... 순서로 표시
        return i;
      }
    }
    
    return null;
  }
  
  /// 순환교체 경로에 포함된 교사인지 확인
  bool isTeacherInCircularPath(String teacherName) {
    if (_selectedCircularPath == null) return false;
    
    return _selectedCircularPath!.nodes.any((node) => 
      node.teacherName == teacherName
    );
  }

  /// 선택된 1:1 경로에 포함된 셀인지 확인
  bool isInSelectedOneToOnePath(String teacherName, {String? day, int? period}) {
    if (_selectedOneToOnePath == null) return false;
    
    return _selectedOneToOnePath!.nodes.any((node) {
      if (day != null && period != null) {
        // 데이터 셀: 교사명, 요일, 교시 모두 확인
        return node.teacherName == teacherName && 
               node.day == day && 
               node.period == period;
      } else {
        // 교사명 열: 교사명만 확인
        return node.teacherName == teacherName;
      }
    });
  }

  /// 연쇄교체 경로에 포함된 셀인지 확인
  bool isInChainPath(String teacherName, String day, int period) {
    if (_selectedChainPath == null) return false;
    
    return _selectedChainPath!.nodes.any((node) => 
      node.teacherName == teacherName &&
      node.day == day &&
      node.period == period
    );
  }
  
  /// 연쇄교체 경로에서 해당 셀의 단계 번호 가져오기
  int? getChainPathStep(String teacherName, String day, int period) {
    if (_selectedChainPath == null) return null;
    
    // 연쇄교체의 노드 순서: [node1, node2, nodeA, nodeB]
    for (int i = 0; i < _selectedChainPath!.nodes.length; i++) {
      final node = _selectedChainPath!.nodes[i];
      if (node.teacherName == teacherName &&
          node.day == day &&
          node.period == period) {
        // node1, node2는 1단계, nodeA, nodeB는 2단계
        if (i < 2) {
          return 1; // 1단계
        } else {
          return 2; // 2단계
        }
      }
    }
    
    return null;
  }
  
  /// 연쇄교체 경로에 포함된 교사인지 확인
  bool isTeacherInChainPath(String teacherName) {
    if (_selectedChainPath == null) return false;
    
    return _selectedChainPath!.nodes.any((node) => 
      node.teacherName == teacherName
    );
  }
}
