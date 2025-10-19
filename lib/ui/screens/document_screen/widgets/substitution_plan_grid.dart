import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../../providers/services_provider.dart';
import '../../../../utils/logger.dart';
import '../../../../models/exchange_path.dart';

/// 여백 및 스타일 상수
class _Spacing {
  // 패딩 - 최소화
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0);
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0);
  
  // 간격 - 최소화
  static const double smallSpacing = 4.0;
  static const double mediumSpacing = 8.0; // 16.0에서 8.0으로 줄임
  
  // 폰트 크기
  static const double headerFontSize = 12.0; // 14.0에서 12.0으로 줄임
  static const double cellFontSize = 11.0; // 12.0에서 11.0으로 줄임
}

/// 보강계획서 데이터 모델
class SubstitutionPlanData {
  final String exchangeId;      // 교체 식별자 (고유 키)
  final String absenceDate;      // 결강일
  final String absenceDay;       // 결강 요일
  final String period;           // 교시
  final String grade;           // 학년
  final String className;       // 반
  final String subject;         // 과목
  final String teacher;         // 교사
  final String supplementSubject; // 보강/수업변경 과목
  final String supplementTeacher; // 보강/수업변경 교사 성명
  final String substitutionDate; // 교체일
  final String substitutionDay;  // 교체 요일
  final String substitutionPeriod; // 교체 교시
  final String substitutionSubject; // 교체 과목
  final String substitutionTeacher; // 교체 교사 성명
  final String remarks;         // 비고

  SubstitutionPlanData({
    required this.exchangeId,
    required this.absenceDate,
    required this.absenceDay,
    required this.period,
    required this.grade,
    required this.className,
    required this.subject,
    required this.teacher,
    required this.supplementSubject,
    required this.supplementTeacher,
    required this.substitutionDate,
    required this.substitutionDay,
    required this.substitutionPeriod,
    required this.substitutionSubject,
    required this.substitutionTeacher,
    required this.remarks,
  });
}

/// 보강계획서 데이터 소스
class SubstitutionPlanDataSource extends DataGridSource {
  final List<SubstitutionPlanData> _data;
  final Function(DataGridCell, DataGridRow)? onDateCellTap;

  SubstitutionPlanDataSource(this._data, {this.onDateCellTap});

  @override
  List<DataGridRow> get rows => _data.map<DataGridRow>((data) {
    return DataGridRow(cells: [
      DataGridCell<String>(columnName: 'absenceDate', value: data.absenceDate),
      DataGridCell<String>(columnName: 'absenceDay', value: data.absenceDay),
      DataGridCell<String>(columnName: 'period', value: data.period),
      DataGridCell<String>(columnName: 'grade', value: data.grade),
      DataGridCell<String>(columnName: 'className', value: data.className),
      DataGridCell<String>(columnName: 'subject', value: data.subject),
      DataGridCell<String>(columnName: 'teacher', value: data.teacher),
      DataGridCell<String>(columnName: 'supplementSubject', value: data.supplementSubject),
      DataGridCell<String>(columnName: 'supplementTeacher', value: data.supplementTeacher),
      DataGridCell<String>(columnName: 'substitutionDate', value: data.substitutionDate),
      DataGridCell<String>(columnName: 'substitutionDay', value: data.substitutionDay),
      DataGridCell<String>(columnName: 'substitutionPeriod', value: data.substitutionPeriod),
      DataGridCell<String>(columnName: 'substitutionSubject', value: data.substitutionSubject),
      DataGridCell<String>(columnName: 'substitutionTeacher', value: data.substitutionTeacher),
      DataGridCell<String>(columnName: 'remarks', value: data.remarks),
    ]);
  }).toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        
        // 날짜 셀인 경우 클릭 가능한 위젯으로 표시
        if (dataGridCell.columnName == 'absenceDate' || dataGridCell.columnName == 'substitutionDate') {
          final isSelectable = dataGridCell.value == '선택';
          final displayText = isSelectable ? '선택' : (dataGridCell.value?.toString() ?? '');
          
          
          return GestureDetector(
            onTap: () {
              AppLogger.exchangeDebug('날짜 셀 클릭됨 - 컬럼: ${dataGridCell.columnName}, 값: ${dataGridCell.value}');
              if (onDateCellTap != null) {
                onDateCellTap!(dataGridCell, row);
              }
            },
            child: Container(
              alignment: Alignment.center,
              padding: _Spacing.cellPadding,
              decoration: BoxDecoration(
                color: isSelectable ? Colors.blue.shade50 : Colors.transparent,
                border: isSelectable ? Border.all(color: Colors.blue.shade200) : null,
                borderRadius: isSelectable ? BorderRadius.circular(4) : null,
              ),
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: _Spacing.cellFontSize,
                  height: 1.0,
                  color: isSelectable ? Colors.blue.shade700 : Colors.black87,
                  fontWeight: isSelectable ? FontWeight.w500 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        
        // 다른 컬럼들은 기본 텍스트 표시
        return Container(
          alignment: Alignment.center,
          padding: _Spacing.cellPadding, // 최소화된 패딩 사용
          child: Text(
            dataGridCell.value?.toString() ?? '',
            style: const TextStyle(
              fontSize: _Spacing.cellFontSize,
              height: 1.0, // 줄 간격 최소화
            ),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }
}

/// 보강계획서 그리드 위젯
class SubstitutionPlanGrid extends ConsumerStatefulWidget {
  const SubstitutionPlanGrid({super.key});

  @override
  ConsumerState<SubstitutionPlanGrid> createState() => _SubstitutionPlanGridState();
}

class _SubstitutionPlanGridState extends ConsumerState<SubstitutionPlanGrid> {
  late SubstitutionPlanDataSource _dataSource;
  List<SubstitutionPlanData> _planData = [];
  
  // 사용자가 입력한 날짜 정보를 저장하는 맵
  // 키: "교체식별자_컬럼명" (예: "문유란_월5_absenceDate"), 값: 날짜 문자열
  final Map<String, String> _savedDates = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadPlanData();
  }

  /// 교체 항목의 고유 식별자 생성
  String _generateExchangeId(String teacher, String day, String period, String subject) {
    return '${teacher}_$day${period}_$subject';
  }
  
  /// 수업 조건 키 생성 (요일, 교시, 학년, 반, 과목, 교사)
  String _generateClassConditionKey(String day, String period, String grade, String className, String subject, String teacher) {
    return '$day|$period|$grade|$className|$subject|$teacher';
  }
  
  /// 사용자가 입력한 날짜 정보를 저장
  void _saveDate(String exchangeId, String columnName, String date) {
    final key = '${exchangeId}_$columnName';
    _savedDates[key] = date;
    AppLogger.exchangeDebug('날짜 저장: $key = $date');
  }
  
  /// 저장된 날짜 정보를 복원
  String _getSavedDate(String exchangeId, String columnName) {
    final key = '${exchangeId}_$columnName';
    final savedDate = _savedDates[key];
    AppLogger.exchangeDebug('날짜 복원: $key = $savedDate');
    return savedDate ?? '선택';
  }
  
  /// 동일한 수업 조건을 가진 항목들의 날짜를 연동 업데이트
  void _updateLinkedDates(String day, String period, String grade, String className, String subject, String teacher, String newDate, String columnName) {
    final classConditionKey = _generateClassConditionKey(day, period, grade, className, subject, teacher);
    AppLogger.exchangeDebug('연동 업데이트 시작 - 수업 조건: $classConditionKey, 새 날짜: $newDate, 컬럼: $columnName');
    
    List<int> updateIndices = [];
    
    // 모든 계획 데이터를 순회하며 동일한 수업 조건을 가진 항목 찾기
    for (int i = 0; i < _planData.length; i++) {
      final planData = _planData[i];
      bool shouldUpdateAbsence = false;
      bool shouldUpdateSubstitution = false;
      
      // 결강일 섹션의 수업 조건 검사
      final absenceKey = _generateClassConditionKey(
        planData.absenceDay, 
        planData.period, 
        planData.grade, 
        planData.className, 
        planData.subject, 
        planData.teacher
      );
      
      if (absenceKey == classConditionKey) {
        shouldUpdateAbsence = true;
        AppLogger.exchangeDebug('결강일 연동 발견 - 행 $i: ${planData.absenceDay}|${planData.period}|${planData.grade}|${planData.className}|${planData.subject}|${planData.teacher}');
      }
      
      // 교체일 섹션의 수업 조건 검사
      final substitutionKey = _generateClassConditionKey(
        planData.substitutionDay, 
        planData.substitutionPeriod, 
        planData.grade, 
        planData.className, 
        planData.substitutionSubject, 
        planData.substitutionTeacher
      );
      
      if (substitutionKey == classConditionKey) {
        shouldUpdateSubstitution = true;
        AppLogger.exchangeDebug('교체일 연동 발견 - 행 $i: ${planData.substitutionDay}|${planData.substitutionPeriod}|${planData.grade}|${planData.className}|${planData.substitutionSubject}|${planData.substitutionTeacher}');
      }
      
      // 업데이트가 필요한 경우 인덱스와 업데이트 타입 저장
      if (shouldUpdateAbsence || shouldUpdateSubstitution) {
        updateIndices.add(i);
        AppLogger.exchangeDebug('연동 대상 추가 - 행 $i (결강일: $shouldUpdateAbsence, 교체일: $shouldUpdateSubstitution)');
      }
    }
    
    // 실제 업데이트 수행
    for (int index in updateIndices) {
      final planData = _planData[index];
      
      // 결강일과 교체일 섹션 모두에서 동일한 수업 조건 확인
      final absenceKey = _generateClassConditionKey(
        planData.absenceDay, 
        planData.period, 
        planData.grade, 
        planData.className, 
        planData.subject, 
        planData.teacher
      );
      
      final substitutionKey = _generateClassConditionKey(
        planData.substitutionDay, 
        planData.substitutionPeriod, 
        planData.grade, 
        planData.className, 
        planData.substitutionSubject, 
        planData.substitutionTeacher
      );
      
      bool updateAbsence = (absenceKey == classConditionKey);
      bool updateSubstitution = (substitutionKey == classConditionKey);
      
      // 교체 식별자로 날짜 정보 저장
      if (updateAbsence) {
        _saveDate(planData.exchangeId, 'absenceDate', newDate);
      }
      if (updateSubstitution) {
        _saveDate(planData.exchangeId, 'substitutionDate', newDate);
      }
      
      // 계획 데이터 업데이트
      _planData[index] = SubstitutionPlanData(
        exchangeId: planData.exchangeId,
        absenceDate: updateAbsence ? newDate : planData.absenceDate,
        absenceDay: planData.absenceDay,
        period: planData.period,
        grade: planData.grade,
        className: planData.className,
        subject: planData.subject,
        teacher: planData.teacher,
        supplementSubject: planData.supplementSubject,
        supplementTeacher: planData.supplementTeacher,
        substitutionDate: updateSubstitution ? newDate : planData.substitutionDate,
        substitutionDay: planData.substitutionDay,
        substitutionPeriod: planData.substitutionPeriod,
        substitutionSubject: planData.substitutionSubject,
        substitutionTeacher: planData.substitutionTeacher,
        remarks: planData.remarks,
      );
      
      String updateInfo = '';
      if (updateAbsence) updateInfo += '결강일 ';
      if (updateSubstitution) updateInfo += '교체일 ';
      AppLogger.exchangeDebug('연동 업데이트 완료 - 행 $index, $updateInfo: $newDate');
    }
    
    if (updateIndices.isNotEmpty) {
      AppLogger.exchangeDebug('총 ${updateIndices.length}개 항목이 연동 업데이트되었습니다.');
      
      // 연동 업데이트된 항목들의 상세 정보 출력
      for (int index in updateIndices) {
        final updatedData = _planData[index];
        AppLogger.exchangeDebug('  연동 완료 - 행 $index: ${columnName == 'absenceDate' ? '결강일' : '교체일'}=${columnName == 'absenceDate' ? updatedData.absenceDate : updatedData.substitutionDate}');
      }
    } else {
      AppLogger.exchangeDebug('연동할 항목이 없습니다.');
      AppLogger.exchangeDebug('검색 조건: $classConditionKey');
      AppLogger.exchangeDebug('현재 데이터 개수: ${_planData.length}');
    }
  }
  
  /// 교체 히스토리에서 보강계획서 데이터 로드
  void _loadPlanData() {
    final historyService = ref.read(exchangeHistoryServiceProvider);
    final exchangeList = historyService.getExchangeList();
    
    // 디버그: 교체 히스토리 개수 출력
    AppLogger.exchangeDebug('교체 히스토리 개수: ${exchangeList.length}');
    
    // 교체 히스토리가 있는 경우에만 데이터 로드
    if (exchangeList.isNotEmpty) {
      _planData = [];
      
      for (final item in exchangeList) {
        final nodes = item.originalPath.nodes;
        
        // 디버그: 각 교체 항목의 노드 정보 출력
        AppLogger.exchangeDebug('교체 항목 - 노드 개수: ${nodes.length}');
        for (int i = 0; i < nodes.length; i++) {
          final node = nodes[i];
          AppLogger.exchangeDebug('노드 $i: ${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}');
        }
        
        // ExchangePathType에 따른 분류 처리
        final exchangeType = item.type;
        
        AppLogger.exchangeDebug('교체 타입 처리: ${exchangeType.displayName}');
        
        switch (exchangeType) {
          case ExchangePathType.oneToOne:
            // 1:1 교체 처리
            if (nodes.length < 2) {
              AppLogger.exchangeDebug('1:1 교체: 노드가 부족합니다 (${nodes.length}개)');
              break;
            }
            
            final sourceNode = nodes[0];  // 결강할 셀
            final targetNode = nodes[1];  // 교체할 셀
            
            // 교체 식별자 생성
            final exchangeId = _generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName);
            
            final planData = SubstitutionPlanData(
              exchangeId: exchangeId,
              // 결강 정보 (sourceNode)
              absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
              absenceDay: sourceNode.day,
              period: sourceNode.period.toString(),
              grade: _extractGradeFromClassName(sourceNode.className),
              className: _extractClassNumberFromClassName(sourceNode.className),
              subject: sourceNode.subjectName,
              teacher: sourceNode.teacherName,
              
              // 보강/수업변경 정보 - 비워둠 (사용자 입력용)
              supplementSubject: '',
              supplementTeacher: '',
              
              // 교체 정보 (targetNode)
              substitutionDate: _getSavedDate(exchangeId, 'substitutionDate'),
              substitutionDay: targetNode.day,
              substitutionPeriod: targetNode.period.toString(),
              substitutionSubject: targetNode.subjectName,
              substitutionTeacher: targetNode.teacherName,
              
              remarks: item.notes ?? '',
            );
            
            _planData.add(planData);
            
            // 디버그: 생성된 계획 데이터 출력
            AppLogger.exchangeDebug('1:1 교체 처리 완료:');
            AppLogger.exchangeDebug('  결강: ${planData.absenceDay}|${planData.period}|${planData.grade}|${planData.className}|${planData.subject}|${planData.teacher}');
            AppLogger.exchangeDebug('  교체: ${planData.substitutionDay}|${planData.substitutionPeriod}|${planData.substitutionSubject}|${planData.substitutionTeacher}');
            break;
            
          case ExchangePathType.circular:
            // 순환교체 처리
            if (nodes.length < 3) {
              AppLogger.exchangeDebug('순환교체: 노드가 부족합니다 (${nodes.length}개)');
              break;
            }
            
            // 3개 노드인 경우: 첫 번째 쌍만 표시 (A→B)
            if (nodes.length == 3) {
              AppLogger.exchangeDebug('순환교체 3개 노드: 첫 번째 쌍만 표시');
              
              final sourceNode = nodes[0];  // 첫 번째 노드 (결강할 셀)
              final targetNode = nodes[1]; // 두 번째 노드 (교체할 셀)
              
              // 교체 식별자 생성
              final exchangeId = '${_generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName)}_순환';
              
              final planData = SubstitutionPlanData(
                exchangeId: exchangeId,
                // 결강 정보 (sourceNode)
                absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
                absenceDay: sourceNode.day,
                period: sourceNode.period.toString(),
                grade: _extractGradeFromClassName(sourceNode.className),
                className: _extractClassNumberFromClassName(sourceNode.className),
                subject: sourceNode.subjectName,
                teacher: sourceNode.teacherName,
                
                // 보강/수업변경 정보 - 비워둠 (사용자 입력용)
                supplementSubject: '',
                supplementTeacher: '',
                
                // 교체 정보 (targetNode)
                substitutionDate: _getSavedDate(exchangeId, 'substitutionDate'),
                substitutionDay: targetNode.day,
                substitutionPeriod: targetNode.period.toString(),
                substitutionSubject: targetNode.subjectName,
                substitutionTeacher: targetNode.teacherName,
                
                remarks: '',
              );
              
              _planData.add(planData);
              
              // 디버그: 생성된 계획 데이터 출력
              AppLogger.exchangeDebug('순환교체 처리 완료 (첫 번째 쌍만 표시):');
              AppLogger.exchangeDebug('  결강: ${planData.absenceDay}|${planData.period}|${planData.grade}|${planData.className}|${planData.subject}|${planData.teacher}');
              AppLogger.exchangeDebug('  교체: ${planData.substitutionDay}|${planData.substitutionPeriod}|${planData.substitutionSubject}|${planData.substitutionTeacher}');
            } else {
              // 4개 이상 노드인 경우: 모든 교체 쌍 표시 (기존 로직 유지)
              AppLogger.exchangeDebug('순환교체 4개 이상 노드: 모든 교체 쌍 표시');
              
              // 순환교체: [A, B, C, D, A] 형태에서 A→B, B→C, C→D 교체 쌍 생성 (마지막 A는 제외)
              for (int i = 0; i < nodes.length - 1; i++) {
                final sourceNode = nodes[i];
                final targetNode = nodes[i + 1];
                
                // 교체 식별자 생성 (순환교체는 순서 번호 포함)
                final exchangeId = '${_generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName)}_순환${i + 1}';
                
                final planData = SubstitutionPlanData(
                  exchangeId: exchangeId,
                  // 결강 정보 (sourceNode)
                  absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
                  absenceDay: sourceNode.day,
                  period: sourceNode.period.toString(),
                  grade: _extractGradeFromClassName(sourceNode.className),
                  className: _extractClassNumberFromClassName(sourceNode.className),
                  subject: sourceNode.subjectName,
                  teacher: sourceNode.teacherName,
                  
                  // 보강/수업변경 정보 - 비워둠 (사용자 입력용)
                  supplementSubject: '',
                  supplementTeacher: '',
                  
                  // 교체 정보 (targetNode)
                  substitutionDate: _getSavedDate(exchangeId, 'substitutionDate'),
                  substitutionDay: targetNode.day,
                  substitutionPeriod: targetNode.period.toString(),
                  substitutionSubject: targetNode.subjectName,
                  substitutionTeacher: targetNode.teacherName,
                  
                  remarks: i == nodes.length - 2 ? '(삭제가능)' : '순환교체${i + 1}',
                );
                
                _planData.add(planData);
                
                // 디버그: 생성된 계획 데이터 출력
                AppLogger.exchangeDebug('순환교체 쌍 ${i + 1}:');
                AppLogger.exchangeDebug('  결강: ${planData.absenceDay}|${planData.period}|${planData.grade}|${planData.className}|${planData.subject}|${planData.teacher}');
                AppLogger.exchangeDebug('  교체: ${planData.substitutionDay}|${planData.substitutionPeriod}|${planData.substitutionSubject}|${planData.substitutionTeacher}');
              }
            }
            break;
            
          case ExchangePathType.chain:
            // 연쇄교체 처리
            if (nodes.length < 4) {
              AppLogger.exchangeDebug('연쇄교체: 노드가 부족합니다 (${nodes.length}개)');
              break;
            }
            
            // 연쇄교체 구조 분석: [결강수업, 대체수업, 중간교체1, 중간교체2]
            // 실제 교체 쌍: 결강수업 ↔ 대체수업, 중간교체1 ↔ 중간교체2
            final absentNode = nodes[0];    // 결강 수업 (목표)
            final substituteNode = nodes[1]; // 대체 수업 (최종 목표)
            final intermediateNode1 = nodes[2]; // 중간 교체 1
            final intermediateNode2 = nodes[3]; // 중간 교체 2
            
            // 첫 번째 교체 쌍: 대체수업 ↔ 결강수업 (최종 목표) - 순서 바꿈
            final finalExchangeId = '${_generateExchangeId(substituteNode.teacherName, substituteNode.day, substituteNode.period.toString(), substituteNode.subjectName)}_연쇄최종';
            final finalExchangePlanData = SubstitutionPlanData(
              exchangeId: finalExchangeId,
              absenceDate: _getSavedDate(finalExchangeId, 'absenceDate'),
              absenceDay: substituteNode.day,
              period: substituteNode.period.toString(),
              grade: _extractGradeFromClassName(substituteNode.className),
              className: _extractClassNumberFromClassName(substituteNode.className),
              subject: substituteNode.subjectName,
              teacher: substituteNode.teacherName,
              
              supplementSubject: '',
              supplementTeacher: '',
              
              substitutionDate: _getSavedDate(finalExchangeId, 'substitutionDate'),
              substitutionDay: absentNode.day,
              substitutionPeriod: absentNode.period.toString(),
              substitutionSubject: absentNode.subjectName,
              substitutionTeacher: absentNode.teacherName,
              
              remarks: '연쇄교체(중간)',
            );
            
            // 두 번째 교체 쌍: 중간교체1 ↔ 중간교체2 (중간 단계) - 순서 바꿈
            final intermediateExchangeId = '${_generateExchangeId(intermediateNode1.teacherName, intermediateNode1.day, intermediateNode1.period.toString(), intermediateNode1.subjectName)}_연쇄중간';
            final intermediateExchangePlanData = SubstitutionPlanData(
              exchangeId: intermediateExchangeId,
              absenceDate: _getSavedDate(intermediateExchangeId, 'absenceDate'),
              absenceDay: intermediateNode1.day,
              period: intermediateNode1.period.toString(),
              grade: _extractGradeFromClassName(intermediateNode1.className),
              className: _extractClassNumberFromClassName(intermediateNode1.className),
              subject: intermediateNode1.subjectName,
              teacher: intermediateNode1.teacherName,
              
              supplementSubject: '',
              supplementTeacher: '',
              
              substitutionDate: _getSavedDate(intermediateExchangeId, 'substitutionDate'),
              substitutionDay: intermediateNode2.day,
              substitutionPeriod: intermediateNode2.period.toString(),
              substitutionSubject: intermediateNode2.subjectName,
              substitutionTeacher: intermediateNode2.teacherName,
              
              remarks: '연쇄교체(최종)',
            );
            
            _planData.addAll([finalExchangePlanData, intermediateExchangePlanData]);
            
            // 디버그: 생성된 계획 데이터 출력
            AppLogger.exchangeDebug('연쇄교체 처리 완료:');
            AppLogger.exchangeDebug('최종교체: ${substituteNode.teacherName} ${substituteNode.day}${substituteNode.period} ↔ ${absentNode.teacherName} ${absentNode.day}${absentNode.period}');
            AppLogger.exchangeDebug('중간교체: ${intermediateNode1.teacherName} ${intermediateNode1.day}${intermediateNode1.period} ↔ ${intermediateNode2.teacherName} ${intermediateNode2.day}${intermediateNode2.period}');
            break;
            
          case ExchangePathType.supplement:
            // 보강교체 처리
            if (nodes.length < 2) {
              AppLogger.exchangeDebug('보강교체: 노드가 부족합니다 (${nodes.length}개)');
              break;
            }
            
            final sourceNode = nodes[0];  // 보강할 셀
            final targetNode = nodes[1];  // 보강할 교사
            
            // 교체 식별자 생성
            final exchangeId = '${_generateExchangeId(sourceNode.teacherName, sourceNode.day, sourceNode.period.toString(), sourceNode.subjectName)}_보강';
            
            final planData = SubstitutionPlanData(
              exchangeId: exchangeId,
              // 결강 정보 (sourceNode - 보강할 셀)
              absenceDate: _getSavedDate(exchangeId, 'absenceDate'),
              absenceDay: sourceNode.day,
              period: sourceNode.period.toString(),
              grade: _extractGradeFromClassName(sourceNode.className),
              className: _extractClassNumberFromClassName(sourceNode.className),
              subject: sourceNode.subjectName,
              teacher: sourceNode.teacherName,
              
              // 보강/수업변경 정보 - 보강할 교사 정보 (과목은 비우고 성명만 표시)
              supplementSubject: '',
              supplementTeacher: targetNode.teacherName,
              
              // 교체 정보 - 보강교체는 직접 교체가 아닌 보강이므로 비워둠
              substitutionDate: '',
              substitutionDay: '',
              substitutionPeriod: '',
              substitutionSubject: '',
              substitutionTeacher: '',
              
              remarks: '보강',
            );
            
            _planData.add(planData);
            
            // 디버그: 생성된 계획 데이터 출력
            AppLogger.exchangeDebug('보강교체 처리 완료:');
            AppLogger.exchangeDebug('  보강할 셀: ${planData.absenceDay}|${planData.period}|${planData.grade}|${planData.className}|${planData.subject}|${planData.teacher}');
            AppLogger.exchangeDebug('  보강할 교사: ${planData.supplementTeacher}');
            break;
        }
      }
    } else {
      // 교체 히스토리가 없는 경우 빈 리스트
      _planData = [];
      AppLogger.exchangeDebug('교체 히스토리가 없어서 빈 리스트로 설정');
    }

    // 디버그: 최종 데이터 개수 출력
    AppLogger.exchangeDebug('최종 _planData 개수: ${_planData.length}');
    
    // UI 업데이트를 위해 setState 호출
    if (mounted) {
      setState(() {
        // 데이터 소스는 항상 초기화 (빈 데이터여도 안정적으로 작동)
        _dataSource = SubstitutionPlanDataSource(_planData, onDateCellTap: _showDatePicker);
      });
    }
    
    // 디버그: 데이터 소스 행 개수 출력
    AppLogger.exchangeDebug('데이터 소스 행 개수: ${_dataSource.rows.length}');
  }

  /// 학급명에서 학년 추출
  String _extractGradeFromClassName(String className) {
    try {
      className = className.trim();
      
      // 1. 3자리 숫자 형태 처리 (예: "103" -> "1", "203" -> "2")
      if (className.length == 3 && RegExp(r'^\d{3}$').hasMatch(className)) {
        return className[0]; // 첫 번째 자리: 학년
      }
      
      // 2. 하이픈 형태 처리 (예: "1-1" -> "1")
      final gradeMatch = RegExp(r'(\d+)[-학년]').firstMatch(className);
      if (gradeMatch != null) {
        return gradeMatch.group(1) ?? '';
      }
      
      // 3. 학년 포함 형태 처리 (예: "1학년 3반" -> "1", "2학년 10반" -> "2")
      final gradeYearMatch = RegExp(r'(\d+)학년').firstMatch(className);
      if (gradeYearMatch != null) {
        return gradeYearMatch.group(1) ?? '';
      }
      
      return '';
    } catch (e) {
      AppLogger.exchangeDebug('학년 추출 중 오류 발생: $e');
      return '';
    }
  }

  /// 학급명에서 반 번호만 추출
  String _extractClassNumberFromClassName(String className) {
    try {
      className = className.trim();
      
      // 1. 3자리 숫자 형태 처리 (예: "103" -> "3", "110" -> "10")
      if (className.length == 3 && RegExp(r'^\d{3}$').hasMatch(className)) {
        String classNum = className.substring(1); // 나머지: 반
        // 반 번호가 한 자리인 경우 앞의 0 제거
        if (classNum.startsWith('0') && classNum.length > 1) {
          classNum = classNum.substring(1);
        }
        return classNum;
      }
      
      // 2. 하이픈 형태 처리 (예: "1-3" -> "3", "2-10" -> "10")
      if (className.contains('-')) {
        final parts = className.split('-');
        if (parts.length >= 2) {
          return parts[1].trim();
        }
      }
      
      // 3. 학년 포함 형태 처리 (예: "1학년 3반" -> "3", "2학년 10반" -> "10")
      final classMatch = RegExp(r'학년\s*(\d+)반').firstMatch(className);
      if (classMatch != null) {
        return classMatch.group(1) ?? '';
      }
      
      return '';
    } catch (e) {
      AppLogger.exchangeDebug('반 번호 추출 중 오류 발생: $e');
      return '';
    }
  }

  /// 날짜 포맷팅 (월.일 형태)
  String _formatDate(DateTime date) {
    return '${date.month}.${date.day}';
  }

  /// 특정 요일에 해당하는 날짜인지 확인
  bool _isTargetWeekday(DateTime date, String targetWeekday) {
    // 한글 요일을 숫자로 변환 (일요일=0, 월요일=1, ..., 토요일=6)
    final weekdayMap = {
      '일': 0,
      '월': 1,
      '화': 2,
      '수': 3,
      '목': 4,
      '금': 5,
      '토': 6,
    };
    
    final targetWeekdayNumber = weekdayMap[targetWeekday];
    if (targetWeekdayNumber == null) {
      AppLogger.exchangeDebug('알 수 없는 요일: $targetWeekday');
      return true; // 요일을 알 수 없으면 모든 날짜 선택 가능
    }
    
    // DateTime.weekday는 월요일=1, 화요일=2, ..., 일요일=7
    // 따라서 일요일 처리를 위해 변환 필요
    final dateWeekday = date.weekday == 7 ? 0 : date.weekday;
    
    final isMatch = dateWeekday == targetWeekdayNumber;
    
    return isMatch;
  }


  /// 날짜 선택기 표시 (calendar_date_picker2 사용)
  Future<void> _showDatePicker(DataGridCell dataGridCell, DataGridRow row) async {
    AppLogger.exchangeDebug('날짜 선택기 시작 - 컬럼: ${dataGridCell.columnName}, 현재 값: ${dataGridCell.value}');
    
    // 해당 행에서 요일 정보 추출
    String targetWeekday = '';
    if (dataGridCell.columnName == 'absenceDate') {
      // 결강일인 경우 결강 요일 가져오기
      final absenceDayCell = row.getCells().firstWhere(
        (cell) => cell.columnName == 'absenceDay',
        orElse: () => DataGridCell<String>(columnName: '', value: ''),
      );
      targetWeekday = absenceDayCell.value?.toString() ?? '';
    } else if (dataGridCell.columnName == 'substitutionDate') {
      // 교체일인 경우 교체 요일 가져오기
      final substitutionDayCell = row.getCells().firstWhere(
        (cell) => cell.columnName == 'substitutionDay',
        orElse: () => DataGridCell<String>(columnName: '', value: ''),
      );
      targetWeekday = substitutionDayCell.value?.toString() ?? '';
    }
    
    AppLogger.exchangeDebug('대상 요일: $targetWeekday');
    
    // 오늘 날짜를 초기값으로 설정
    DateTime initialDate = DateTime.now();
    AppLogger.exchangeDebug('초기 날짜 설정: ${initialDate.toString()}');
    
    // calendar_date_picker2를 사용한 날짜 선택기
    final List<DateTime?>? selectedDates = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        weekdayLabels: ['일', '월', '화', '수', '목', '금', '토'], // 한글 요일
        weekdayLabelTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _Spacing.headerFontSize,
        ),
        selectedDayTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16, // 선택된 날짜 숫자 크기
        ),
        selectedDayHighlightColor: Colors.blue.shade600,
        todayTextStyle: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 16, // 오늘 날짜 숫자 크기
        ),
        dayTextStyle: const TextStyle(
          fontSize: _Spacing.headerFontSize, // 일반 날짜 숫자 크기
          color: Colors.black87,
        ),
        // 요일 필터링을 위한 선택 가능한 날짜 제한
        selectableDayPredicate: targetWeekday.isNotEmpty 
            ? (DateTime date) => _isTargetWeekday(date, targetWeekday)
            : null,
        cancelButtonTextStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 16,
        ),
        okButtonTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        okButton: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('확인'),
        ),
        cancelButton: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
        ),
      ),
      dialogSize: const Size(350, 360),
      borderRadius: BorderRadius.circular(5),
      value: [initialDate],
    );
    
    AppLogger.exchangeDebug('날짜 선택기 결과: $selectedDates');
    
    final DateTime? selectedDate = selectedDates?.isNotEmpty == true ? selectedDates!.first : null;
    AppLogger.exchangeDebug('선택된 날짜: $selectedDate');

    if (selectedDate != null) {
      // 요일 검증 수행
      if (targetWeekday.isNotEmpty && !_isTargetWeekday(selectedDate, targetWeekday)) {
        AppLogger.exchangeDebug('선택된 날짜($selectedDate)가 대상 요일($targetWeekday)과 일치하지 않음');
        
        // 스낵바로 알림 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$targetWeekday요일이 아닌 날짜는 선택할 수 없습니다.'),
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        return; // 함수 종료하여 데이터 업데이트 방지
      }
      
      // 선택된 날짜를 포맷팅
      final formattedDate = _formatDate(selectedDate);
      AppLogger.exchangeDebug('포맷팅된 날짜: $formattedDate');
      
      // 데이터 업데이트 - 행 인덱스를 다른 방법으로 찾기
      int rowIndex = -1;
      
      // 방법 1: _dataSource.rows에서 찾기
      try {
        rowIndex = _dataSource.rows.indexOf(row);
        AppLogger.exchangeDebug('방법 1 - _dataSource.rows.indexOf: $rowIndex');
      } catch (e) {
        AppLogger.exchangeDebug('방법 1 실패: $e');
      }
      
      // 방법 2: row의 첫 번째 셀 값으로 찾기
      if (rowIndex == -1) {
        try {
          final firstCell = row.getCells().first;
          AppLogger.exchangeDebug('첫 번째 셀 값: ${firstCell.value}');
          
          // _planData에서 해당 값과 일치하는 행 찾기
          for (int i = 0; i < _planData.length; i++) {
            final planData = _planData[i];
            // 교사명으로 매칭 시도
            if (planData.teacher == firstCell.value.toString()) {
              rowIndex = i;
              AppLogger.exchangeDebug('방법 2 - 교사명으로 매칭: $rowIndex');
              break;
            }
          }
        } catch (e) {
          AppLogger.exchangeDebug('방법 2 실패: $e');
        }
      }
      
      // 방법 3: 클릭된 셀의 컬럼명과 값으로 찾기
      if (rowIndex == -1) {
        try {
          AppLogger.exchangeDebug('방법 3 - 클릭된 셀 정보: 컬럼=${dataGridCell.columnName}, 값=${dataGridCell.value}');
          
          // 모든 행을 순회하면서 해당 컬럼의 값이 일치하는지 확인
          for (int i = 0; i < _planData.length; i++) {
            final planData = _planData[i];
            String cellValue = '';
            
            if (dataGridCell.columnName == 'absenceDate') {
              cellValue = planData.absenceDate;
            } else if (dataGridCell.columnName == 'substitutionDate') {
              cellValue = planData.substitutionDate;
            }
            
            if (cellValue == dataGridCell.value.toString()) {
              rowIndex = i;
              AppLogger.exchangeDebug('방법 3 - 셀 값으로 매칭: $rowIndex');
              break;
            }
          }
        } catch (e) {
          AppLogger.exchangeDebug('방법 3 실패: $e');
        }
      }
      
      AppLogger.exchangeDebug('최종 행 인덱스: $rowIndex, 전체 데이터 개수: ${_planData.length}');
      
      if (rowIndex >= 0 && rowIndex < _planData.length) {
        // 어떤 날짜 컬럼인지에 따라 업데이트
        if (dataGridCell.columnName == 'absenceDate') {
          AppLogger.exchangeDebug('결강일 업데이트 - 이전 값: ${_planData[rowIndex].absenceDate} -> 새 값: $formattedDate');
          
          // 교체 식별자로 날짜 정보 저장
          _saveDate(_planData[rowIndex].exchangeId, 'absenceDate', formattedDate);
          
          // 동일한 수업 조건을 가진 항목들의 날짜 연동 업데이트
          _updateLinkedDates(
            _planData[rowIndex].absenceDay,
            _planData[rowIndex].period,
            _planData[rowIndex].grade,
            _planData[rowIndex].className,
            _planData[rowIndex].subject,
            _planData[rowIndex].teacher,
            formattedDate,
            'absenceDate'
          );
          
          setState(() {
            _planData[rowIndex] = SubstitutionPlanData(
              exchangeId: _planData[rowIndex].exchangeId,
              absenceDate: formattedDate,
              absenceDay: _planData[rowIndex].absenceDay,
              period: _planData[rowIndex].period,
              grade: _planData[rowIndex].grade,
              className: _planData[rowIndex].className,
              subject: _planData[rowIndex].subject,
              teacher: _planData[rowIndex].teacher,
              supplementSubject: _planData[rowIndex].supplementSubject,
              supplementTeacher: _planData[rowIndex].supplementTeacher,
              substitutionDate: _planData[rowIndex].substitutionDate,
              substitutionDay: _planData[rowIndex].substitutionDay,
              substitutionPeriod: _planData[rowIndex].substitutionPeriod,
              substitutionSubject: _planData[rowIndex].substitutionSubject,
              substitutionTeacher: _planData[rowIndex].substitutionTeacher,
              remarks: _planData[rowIndex].remarks,
            );
          });
        } else if (dataGridCell.columnName == 'substitutionDate') {
          AppLogger.exchangeDebug('교체일 업데이트 - 이전 값: ${_planData[rowIndex].substitutionDate} -> 새 값: $formattedDate');
          
          // 교체 식별자로 날짜 정보 저장
          _saveDate(_planData[rowIndex].exchangeId, 'substitutionDate', formattedDate);
          
          // 동일한 수업 조건을 가진 항목들의 날짜 연동 업데이트
          _updateLinkedDates(
            _planData[rowIndex].substitutionDay,
            _planData[rowIndex].substitutionPeriod,
            _planData[rowIndex].grade,
            _planData[rowIndex].className,
            _planData[rowIndex].substitutionSubject,
            _planData[rowIndex].substitutionTeacher,
            formattedDate,
            'substitutionDate'
          );
          
          setState(() {
            _planData[rowIndex] = SubstitutionPlanData(
              exchangeId: _planData[rowIndex].exchangeId,
              absenceDate: _planData[rowIndex].absenceDate,
              absenceDay: _planData[rowIndex].absenceDay,
              period: _planData[rowIndex].period,
              grade: _planData[rowIndex].grade,
              className: _planData[rowIndex].className,
              subject: _planData[rowIndex].subject,
              teacher: _planData[rowIndex].teacher,
              supplementSubject: _planData[rowIndex].supplementSubject,
              supplementTeacher: _planData[rowIndex].supplementTeacher,
              substitutionDate: formattedDate,
              substitutionDay: _planData[rowIndex].substitutionDay,
              substitutionPeriod: _planData[rowIndex].substitutionPeriod,
              substitutionSubject: _planData[rowIndex].substitutionSubject,
              substitutionTeacher: _planData[rowIndex].substitutionTeacher,
              remarks: _planData[rowIndex].remarks,
            );
          });
        }
        
        // 연동 업데이트 후 전체 UI 새로고침
        setState(() {
          _dataSource = SubstitutionPlanDataSource(_planData, onDateCellTap: _showDatePicker);
        });
        AppLogger.exchangeDebug('데이터 소스 새로고침 완료 - 새로운 데이터 소스 행 개수: ${_dataSource.rows.length}');
        
        // 업데이트된 데이터 확인
        final updatedRow = _dataSource.rows[rowIndex];
        final updatedCell = updatedRow.getCells().firstWhere(
          (cell) => cell.columnName == dataGridCell.columnName,
          orElse: () => DataGridCell<String>(columnName: '', value: ''),
        );
        AppLogger.exchangeDebug('업데이트된 셀 값 확인: ${updatedCell.value}');
        
        // 전체 _planData 상태 확인
        AppLogger.exchangeDebug('전체 _planData 상태:');
        for (int i = 0; i < _planData.length; i++) {
          AppLogger.exchangeDebug('  행 $i: absenceDate=${_planData[i].absenceDate}, substitutionDate=${_planData[i].substitutionDate}');
        }
      } else {
        AppLogger.exchangeDebug('행 인덱스가 유효하지 않음: $rowIndex');
      }
    } else {
      AppLogger.exchangeDebug('날짜 선택이 취소되었거나 실패함');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 버튼들을 SingleChildScrollView로 감싸서 가로 스크롤 가능하게 함
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadPlanData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('새로고침'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: _Spacing.smallSpacing),
                  ElevatedButton.icon(
                    onPressed: _clearAllDates,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('날짜 지우기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: _Spacing.smallSpacing),
                  ElevatedButton.icon(
                    onPressed: _exportToPDF,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF 출력'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _Spacing.mediumSpacing),
            // 데이터가 있을 때는 그리드 표시, 없을 때는 안내 메시지 표시
            SizedBox(
              height: 500, // 고정 높이로 설정
              child: _planData.isNotEmpty
                  ? SfDataGrid(
                      source: _dataSource,
                      columns: _buildColumns(),
                      stackedHeaderRows: _buildStackedHeaders(),
                      allowColumnsResizing: true,
                      columnResizeMode: ColumnResizeMode.onResize,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      selectionMode: SelectionMode.single,
                      headerRowHeight: 35, // 50에서 35로 줄임
                      rowHeight: 28, // 40에서 28로 줄임
                      allowEditing: false, // 편집 비활성화
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '교체 기록이 없습니다',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '교체를 실행하면 여기에 기록이 표시됩니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 라벨 생성 헬퍼 메서드
  Widget _buildHeaderLabel(String text) {
    return Container(
      padding: _Spacing.headerPadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: _Spacing.cellFontSize,
          height: 1.0, // 줄 간격 최소화
        ),
      ),
    );
  }

  /// 컬럼 정의
  List<GridColumn> _buildColumns() {
    return [
      // 결강 섹션 (7개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'absenceDate',
        label: _buildHeaderLabel('결강일'),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'absenceDay',
        label: _buildHeaderLabel('요일'),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'period',
        label: _buildHeaderLabel('교시'),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'grade',
        label: _buildHeaderLabel('학년'),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'className',
        label: _buildHeaderLabel('반'),
        width: 55, // 60에서 55로 줄임
      ),
      GridColumn(
        columnName: 'subject',
        label: _buildHeaderLabel('과목'),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'teacher',
        label: _buildHeaderLabel('교사'),
        width: 70, // 80에서 70으로 줄임
      ),
      // 보강/수업변경 섹션 (2개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'supplementSubject',
        label: _buildHeaderLabel('과목'),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'supplementTeacher',
        label: _buildHeaderLabel('성명'),
        width: 90, // 100에서 90으로 줄임
      ),
      // 수업 교체 섹션 (5개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'substitutionDate',
        label: _buildHeaderLabel('교체일'),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'substitutionDay',
        label: _buildHeaderLabel('요일'),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'substitutionPeriod',
        label: _buildHeaderLabel('교시'),
        width: 45, // 50에서 45로 줄임
      ),
      GridColumn(
        columnName: 'substitutionSubject',
        label: _buildHeaderLabel('과목'),
        width: 70, // 80에서 70으로 줄임
      ),
      GridColumn(
        columnName: 'substitutionTeacher',
        label: _buildHeaderLabel('교사'),
        width: 90, // 100에서 90으로 줄임
      ),
      // 비고 섹션 (1개 컬럼) - 너비 최소화
      GridColumn(
        columnName: 'remarks',
        label: _buildHeaderLabel('비고'),
        width: 100, // 120에서 100으로 줄임
      ),
    ];
  }

  /// 스택 헤더 정의
  List<StackedHeaderRow> _buildStackedHeaders() {
    return [
      // 첫 번째 헤더 행 (주요 카테고리)
      StackedHeaderRow(
        cells: [
          // 결강 섹션 (7개 컬럼)
          StackedHeaderCell(
            columnNames: ['absenceDate', 'absenceDay', 'period', 'grade', 'className', 'subject', 'teacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '결강',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 보강/수업변경 섹션 (2개 컬럼)
          StackedHeaderCell(
            columnNames: ['supplementSubject', 'supplementTeacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '보강/수업변경',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 수업 교체 섹션 (5개 컬럼)
          StackedHeaderCell(
            columnNames: ['substitutionDate', 'substitutionDay', 'substitutionPeriod', 'substitutionSubject', 'substitutionTeacher'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '수업 교체',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
          // 비고 섹션 (2행 병합)
          StackedHeaderCell(
            columnNames: ['remarks'],
            child: Container(
              padding: _Spacing.headerPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: const Text(
                '비고',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _Spacing.headerFontSize,
                  height: 1.0, // 줄 간격 최소화
                ),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// 모든 날짜 정보 지우기
  void _clearAllDates() {
    AppLogger.exchangeDebug('모든 날짜 정보 지우기 시작');
    
    // 확인 다이얼로그 표시
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('날짜 지우기'),
          content: const Text('입력한 모든 날짜 정보를 지우시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: Text(
                '취소',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                _performClearAllDates(); // 실제 지우기 작업 수행
              },
              child: Text(
                '지우기',
                style: TextStyle(color: Colors.red.shade600),
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// 실제 날짜 지우기 작업 수행
  void _performClearAllDates() {
    AppLogger.exchangeDebug('실제 날짜 지우기 작업 수행');
    
    // 저장된 날짜 정보 모두 지우기
    _savedDates.clear();
    AppLogger.exchangeDebug('저장된 날짜 정보 개수: ${_savedDates.length}');
    
    // 모든 계획 데이터의 날짜 필드를 '선택'으로 초기화
    for (int i = 0; i < _planData.length; i++) {
      final planData = _planData[i];
      _planData[i] = SubstitutionPlanData(
        exchangeId: planData.exchangeId,
        absenceDate: '선택',
        absenceDay: planData.absenceDay,
        period: planData.period,
        grade: planData.grade,
        className: planData.className,
        subject: planData.subject,
        teacher: planData.teacher,
        supplementSubject: planData.supplementSubject,
        supplementTeacher: planData.supplementTeacher,
        substitutionDate: '선택',
        substitutionDay: planData.substitutionDay,
        substitutionPeriod: planData.substitutionPeriod,
        substitutionSubject: planData.substitutionSubject,
        substitutionTeacher: planData.substitutionTeacher,
        remarks: planData.remarks,
      );
    }
    
    // UI 업데이트
    setState(() {
      _dataSource = SubstitutionPlanDataSource(_planData, onDateCellTap: _showDatePicker);
    });
    
    // 성공 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('모든 날짜 정보가 지워졌습니다.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    AppLogger.exchangeDebug('날짜 지우기 작업 완료');
  }

  /// PDF 출력 기능
  void _exportToPDF() {
    // TODO: PDF 출력 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF 출력 기능은 추후 구현 예정입니다.'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
