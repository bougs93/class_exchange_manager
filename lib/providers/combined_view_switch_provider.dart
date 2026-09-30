import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 교체 화면 주차 바의 "날짜 반영"·"교체" 스위치를 하나로 합쳐서 보여줄지
/// 결정하는 설정 (2026-09-30, "준비 > 기타 설정"에서 사용자가 직접 고름).
///
/// true(기본값)면 두 스위치를 하나로 합친 스위치 하나만 보여준다 — 켜면
/// `showWeekHeaderProvider`(날짜 반영)와 교체 뷰(`exchangeViewProvider`)가
/// 동시에 켜지고, 끄면 동시에 꺼진다. false면 두 스위치를 각각 따로 켜고
/// 끌 수 있도록 나눠서 보여준다(합치기 전 기존 동작).
final combinedViewSwitchProvider = StateProvider<bool>((ref) => true);
