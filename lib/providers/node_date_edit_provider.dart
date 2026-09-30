import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 순환·2중 교체의 노드(슬롯)별 날짜 확정 기능 스위치 (S5.6.5~S5.6.7).
///
/// true(S5.6.8부터 기본값)면:
/// - 교체 실행 시점에 참여 노드 전부의 날짜를 즉시 확정 기록한다
///   (`ExchangeExecutor.executeExchange` → `seedNodeDatesForWeek`, S5.6.7) —
///   실행 직후 교체 화면(날짜표시 ON)에 "?" 없이 바로 날짜가 보인다.
/// - 계획서 화면의 순환·2중 행이 `item.nodeDates`에 확정된 슬롯이 있으면
///   추정 대신 그 확정 날짜를 보여준다(`SubstitutionPlanViewModel`).
/// - 계획서의 날짜 선택기가 순환·2중 항목에 대해 `updateDates`(항목 전체의
///   결강일/교체일 쌍) 대신 `updateNodeDate`(그 행이 가리키는 노드 하나만)를
///   호출한다(`content_input_grid.dart`).
///
/// false면 세 화면 모두 S5.6 이전과 완전히 동일하게 동작한다 — 이 스위치
/// 하나가 S5.5.4와 같은 3단계 롤백의 1단계(즉시 토글, 재빌드 불필요)다.
///
/// **주의(세션 전용)**: 다른 실험용 스위치와 마찬가지로 세션 메모리에만
/// 저장된다 — Flutter hot restart(코드 수정 후 재시작)를 하면 이 값도 다시
/// 기본값으로 돌아간다(영구 저장 아님, 앱 재시작마다 초기화).
final nodeDateEditEnabledProvider = StateProvider<bool>((ref) => true);
