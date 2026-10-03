import '../models/notice_message.dart';
import '../providers/substitution_plan_viewmodel.dart';
import 'notice/class_notice_builder.dart';
import 'notice/teacher_notice_builder.dart';

/// 안내 메시지 생성기
///
/// SubstitutionPlanData를 기반으로 학급안내와 교사안내 메시지를 생성합니다.
/// 교체 유형(수업교체/보강)과 메시지 옵션(옵션1/옵션2)에 따라 다른 형태의 메시지를 생성합니다.
///
/// 실제 구현은 `lib/utils/notice/` 하위 파일들로 분리되어 있다:
/// - [ClassNoticeBuilder]: 학급별 안내 메시지
/// - [TeacherNoticeBuilder]: 교사별 안내 메시지
/// - `notice_exchange_category.dart`: 학급/교사 공통 교체 유형 판별 로직
/// - `teacher_notice_line.dart`: 교사 메시지 줄 정렬용 데이터 클래스
/// - `teacher_notice_question_lines.dart` / `teacher_notice_option1_lines.dart` /
///   `teacher_notice_option2_lines.dart`: 교사 메시지 옵션별(질문/교체 안내/수업 안내) 라인 생성
///
/// 이 클래스는 기존 호출부(`NoticeMessageGenerator.generateClassMessages`,
/// `NoticeMessageGenerator.generateTeacherMessages`)가 그대로 동작하도록 두는
/// 얇은 퍼사드(facade)이다.
class NoticeMessageGenerator {
  /// 학급별 안내 메시지 생성
  ///
  /// [planDataList]: 교체 계획 데이터 리스트
  /// [messageOption]: 메시지 옵션 (옵션1 또는 옵션2)
  /// 반환: 학급별로 그룹화된 안내 메시지 리스트
  static List<NoticeMessageGroup> generateClassMessages(
    List<SubstitutionPlanData> planDataList,
    MessageOption messageOption,
  ) {
    return ClassNoticeBuilder.generateClassMessages(
      planDataList,
      messageOption,
    );
  }

  /// 교사별 안내 메시지 생성
  ///
  /// [planDataList]: 교체 계획 데이터 리스트
  /// [messageOption]: 메시지 옵션 (옵션1 또는 옵션2)
  /// 반환: 교사별로 그룹화된 안내 메시지 리스트
  static List<NoticeMessageGroup> generateTeacherMessages(
    List<SubstitutionPlanData> planDataList,
    MessageOption messageOption,
  ) {
    return TeacherNoticeBuilder.generateTeacherMessages(
      planDataList,
      messageOption,
    );
  }
}
