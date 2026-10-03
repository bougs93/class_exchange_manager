import '../../providers/substitution_plan_viewmodel.dart';
import 'teacher_notice_option1_lines.dart';

/// 교사 메시지 옵션(질문 형태) 라인 생성 로직
class TeacherNoticeQuestionLines {
  /// 교사 메시지 질문 라인 생성 (교체 안내 문구를 질문 형태로 변환)
  static List<String> generateTeacherQuestionLines(
    List<SubstitutionPlanData> sortedDataList,
    String teacherName,
  ) {
    return TeacherNoticeOption1Lines.generateTeacherOption1Lines(
      sortedDataList,
      teacherName,
    ).map(_convertExchangeLineToQuestion).toList();
  }

  /// 교체 안내 문구를 질문 형태로 변환
  static String _convertExchangeLineToQuestion(String line) {
    if (line.endsWith('수업 교체되었습니다.')) {
      return line.replaceFirst('수업 교체되었습니다.', '수업 교체 가능할까요?');
    }
    if (line.endsWith('이동 되었습니다.')) {
      return line.replaceFirst('이동 되었습니다.', '이동 가능하신지요?');
    }
    if (line.endsWith('결강 되었습니다.')) {
      return line.replaceFirst('결강 되었습니다.', '결강 - 대체 가능하신지요?');
    }
    if (line.endsWith('보강 수업입니다.')) {
      return line.replaceFirst('보강 수업입니다.', '보강 수업 가능하신지요?');
    }
    return '$line 교체 가능하신지요?';
  }
}
