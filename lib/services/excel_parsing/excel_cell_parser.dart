import 'dart:developer' as developer;
import '../../models/teacher.dart';
import '../../models/time_slot.dart';
import '../excel_service.dart';
import 'excel_parsing_utils.dart';

/// 엑셀 셀 파싱 관련 클래스
/// 
/// 시간표 셀을 파싱하여 TimeSlot 객체로 변환하는 로직을 담당합니다.
class ExcelCellParser {
  /// 시간표 셀을 파싱하는 메서드
  /// 
  /// 셀 내용 예시:
  /// - 빈 셀 → TimeSlot 생성 (subject, className = null)
  /// - "103\n국어" → className: "103", subject: "국어" (정상 순서)
  /// - "국어\n103" → className: "103", subject: "국어" (바뀐 순서)
  /// - "1-3\n수학" → className: "1-3", subject: "수학"
  /// - "2-1" → className: "2-1", subject: null
  /// 
  /// 매개변수:
  /// - String cellValue: 셀 내용
  /// - Teacher teacher: 교사 정보
  /// - int dayOfWeek: 요일 번호
  /// - int period: 교시 번호
  /// - CellOrderPattern? orderPattern: 셀 순서 패턴 (null이면 자동 감지)
  static TimeSlot parseTimeSlotCell(
    String cellValue, 
    Teacher teacher, 
    int dayOfWeek, 
    int period,
    {CellOrderPattern? orderPattern}
  ) {
    try {
      String? className;
      String? subject;
      
      // 빈 셀이 아닌 경우에만 내용 파싱
      if (cellValue.trim().isNotEmpty) {
        // 셀 내용 정리: 특수 문자 제거 및 줄바꿈 정규화
        String cleanCellValue = cellValue
            .replaceAll('\r', '')           // 캐리지 리턴 제거
            .replaceAll('_x000D_', '')      // Excel 특수 문자 제거
            .replaceAll('\n', '\n')          // 줄바꿈 정규화
            .trim();
        
        // 셀 내용을 줄바꿈으로 분할하고 빈 줄 제거
        List<String> lines = cleanCellValue.split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        
        if (lines.isNotEmpty) {
          // 순서 패턴이 지정된 경우 해당 순서 사용, 없으면 자동 감지
          CellOrderPattern detectedPattern = orderPattern ?? CellOrderPattern.unknown;
          
          if (detectedPattern == CellOrderPattern.unknown && lines.length >= 2) {
            // 자동 감지: 각 줄의 패턴을 분석
            bool firstIsClassName = ExcelParsingUtils.isClassNamePattern(lines[0]);
            bool secondIsSubject = ExcelParsingUtils.isSubjectPattern(lines[1]);
            bool firstIsSubject = ExcelParsingUtils.isSubjectPattern(lines[0]);
            bool secondIsClassName = ExcelParsingUtils.isClassNamePattern(lines[1]);
            
            if (firstIsClassName && secondIsSubject) {
              detectedPattern = CellOrderPattern.normal;
            } else if (firstIsSubject && secondIsClassName) {
              detectedPattern = CellOrderPattern.reversed;
            } else {
              // 패턴을 확인할 수 없으면 기본값(정상 순서) 사용
              detectedPattern = CellOrderPattern.normal;
            }
          }
          
          // 순서 패턴에 따라 학급번호와 과목 추출
          if (lines.length >= 2) {
            if (detectedPattern == CellOrderPattern.reversed) {
              // 바뀐 순서: 첫 번째 줄 = 과목, 두 번째 줄 = 학급번호
              subject = lines[0];
              className = ExcelParsingUtils.convertClassName(lines[1]);
            } else {
              // 정상 순서 또는 확인 불가: 첫 번째 줄 = 학급번호, 두 번째 줄 = 과목
              className = ExcelParsingUtils.convertClassName(lines[0]);
              subject = lines[1];
            }
          } else if (lines.length == 1) {
            // 한 줄만 있는 경우: 패턴으로 판단
            if (ExcelParsingUtils.isClassNamePattern(lines[0])) {
              className = ExcelParsingUtils.convertClassName(lines[0]);
            } else if (ExcelParsingUtils.isSubjectPattern(lines[0])) {
              subject = lines[0];
            } else {
              // 패턴을 확인할 수 없으면 기본값으로 처리 (학급번호로 가정)
              className = ExcelParsingUtils.convertClassName(lines[0]);
            }
          }
        }
      }
      
      // 빈 셀과 내용이 있는 셀 모두 TimeSlot 생성
      return TimeSlot(
        teacher: teacher.name,
        subject: subject,  // 빈 셀은 null
        className: className,  // 빈 셀은 null
        dayOfWeek: dayOfWeek,
        period: period,
        isExchangeable: true, // 기본값: 교체 가능
      );
    } catch (e) {
      developer.log('시간표 셀 파싱 중 오류 발생: $e', name: 'ExcelCellParser');
      // 오류 발생 시에도 빈 TimeSlot 생성
      return TimeSlot(
        teacher: teacher.name,
        subject: null,
        className: null,
        dayOfWeek: dayOfWeek,
        period: period,
        isExchangeable: true,
      );
    }
  }
}

