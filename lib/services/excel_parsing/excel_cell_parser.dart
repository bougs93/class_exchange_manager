import 'dart:developer' as developer;
import '../../models/teacher.dart';
import '../../models/time_slot.dart';
import '../excel_service.dart';
import 'excel_parsing_utils.dart';

/// 엑셀 셀 파싱 관련 클래스
///
/// 시간표 셀을 파싱하여 TimeSlot 객체로 변환하는 로직을 담당합니다.
class ExcelCellParser {
  /// 셀 내용을 정리하고 줄 단위로 분리하는 헬퍼 메서드
  ///
  /// 특수 문자를 제거하고 빈 줄을 제거합니다.
  ///
  /// 매개변수:
  /// - `cellValue`: 원본 셀 내용
  ///
  /// 반환값:
  /// - `List<String>`: 정리된 줄 목록 (빈 줄 제외)
  static List<String> _cleanCellLines(String cellValue) {
    String cleanCellValue = cellValue
        .replaceAll('\r', '')           // 캐리지 리턴 제거
        .replaceAll('_x000D_', '')      // Excel 특수 문자 제거
        .replaceAll('\n', '\n')          // 줄바꿈 정규화
        .trim();

    return cleanCellValue.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// 셀 내용의 순서 패턴을 감지하는 헬퍼 메서드
  ///
  /// 학급번호와 과목의 순서를 자동으로 감지합니다.
  ///
  /// 매개변수:
  /// - `lines`: 셀 내용 줄 목록
  /// - `orderPattern`: 지정된 순서 패턴 (null이면 자동 감지)
  ///
  /// 반환값:
  /// - `CellOrderPattern`: 감지된 순서 패턴
  static CellOrderPattern _detectOrderPattern(
    List<String> lines,
    CellOrderPattern? orderPattern,
  ) {
    // 순서 패턴이 지정된 경우 해당 순서 사용
    if (orderPattern != null && orderPattern != CellOrderPattern.unknown) {
      return orderPattern;
    }

    // 줄이 2개 미만이면 자동 감지 불가 (기본값 사용)
    if (lines.length < 2) {
      return CellOrderPattern.normal;
    }

    // 자동 감지: 각 줄의 패턴을 분석
    bool firstIsClassName = ExcelParsingUtils.isClassNamePattern(lines[0]);
    bool secondIsSubject = ExcelParsingUtils.isSubjectPattern(lines[1]);
    bool firstIsSubject = ExcelParsingUtils.isSubjectPattern(lines[0]);
    bool secondIsClassName = ExcelParsingUtils.isClassNamePattern(lines[1]);

    if (firstIsClassName && secondIsSubject) {
      return CellOrderPattern.normal;
    } else if (firstIsSubject && secondIsClassName) {
      return CellOrderPattern.reversed;
    }

    // 패턴을 확인할 수 없으면 기본값(정상 순서) 사용
    return CellOrderPattern.normal;
  }

  /// 셀 내용에서 학급번호와 과목을 추출하는 헬퍼 메서드
  ///
  /// 순서 패턴에 따라 올바르게 추출합니다.
  ///
  /// 매개변수:
  /// - `lines`: 셀 내용 줄 목록
  /// - `pattern`: 순서 패턴
  ///
  /// 반환값:
  /// - `Map<String, String?>`: {'className': 학급번호, 'subject': 과목}
  static Map<String, String?> _extractClassAndSubject(
    List<String> lines,
    CellOrderPattern pattern,
  ) {
    String? className;
    String? subject;

    if (lines.isEmpty) {
      return {'className': null, 'subject': null};
    }

    if (lines.length >= 2) {
      if (pattern == CellOrderPattern.reversed) {
        // 바뀐 순서: 첫 번째 줄 = 과목, 두 번째 줄 = 학급번호
        subject = lines[0];
        className = ExcelParsingUtils.convertClassName(lines[1]);
      } else {
        // 정상 순서 또는 확인 불가: 첫 번째 줄 = 학급번호, 두 번째 줄 = 과목
        className = ExcelParsingUtils.convertClassName(lines[0]);
        subject = lines[1];
      }
    } else {
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

    return {'className': className, 'subject': subject};
  }

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
        // 1단계: 셀 내용 정리
        List<String> lines = _cleanCellLines(cellValue);

        if (lines.isNotEmpty) {
          // 2단계: 순서 패턴 감지
          CellOrderPattern detectedPattern = _detectOrderPattern(lines, orderPattern);

          // 3단계: 학급번호와 과목 추출
          Map<String, String?> result = _extractClassAndSubject(lines, detectedPattern);
          className = result['className'];
          subject = result['subject'];
        }
      }

      // 빈 셀과 내용이 있는 셀 모두 TimeSlot 생성
      return TimeSlot(
        teacher: teacher.name,
        subject: subject,
        className: className,
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

