import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

/// 관리자가 접속 설정 화면에서 지정하는 기본 학교명 (웹 전용).
///
/// `config/public.defaultSchoolName` 문서 하나를 실시간 구독한다 — 로그인
/// 안내 메시지(`loginMessage`)와 같은 문서를 공유한다.
///
/// 교사·학교명은 원래 전역 설정이 아니라 **시간표의 속성**이다(문서 §2).
/// 이 값은 그 규칙을 깨지 않는다 — 시간표·계획서에 이미 학교명이 저장돼
/// 있으면 그 값이 항상 우선하고, 이 기본값은 "아직 아무것도 지정되지 않은
/// 빈 칸"을 1회성으로 채워 주는 추천값일 뿐이다(2026-10-02 요청).
///
/// ## 왜 한 번만 읽는 `FutureProvider`가 아니라 `StreamProvider`인가
///
/// 처음에는 `FutureProvider`로 한 번만 읽었는데, 관리자가 값을 저장한
/// 직후 **같은 탭에서는** `ref.invalidate()`로 어떻게든 땜질할 수 있었지만,
/// 관리자와 교사가 **서로 다른 브라우저 탭(또는 기기)**을 쓰면 교사 쪽
/// `ProviderContainer`에는 무효화 신호가 전혀 닿지 않아 예전 빈 값이 계속
/// 캐시된 채로 남았다(2026-10-02 실제 보고 — "결보강 출력 > 학교명"에
/// 반영되지 않음). 실시간 구독으로 바꾸면 그 쪽은 신경 쓸 필요가 없다 —
/// 열려 있는 모든 탭이 Firestore의 새 값을 자동으로 받는다. 문서 하나,
/// 필드 하나짜리 구독이라 비용도 무시할 만하다.
///
/// PC/모바일에는 이런 공용 접속 설정 개념 자체가 없고 Firebase도 웹에서만
/// 초기화되므로([FirebaseAppConfig.ensureInitialized]), 웹이 아니면 빈
/// 문자열 하나만 내보내고 끝나는 스트림을 반환한다.
final defaultSchoolNameProvider = StreamProvider<String>((ref) {
  if (!kIsWeb) return Stream.value('');
  return FirebaseFirestore.instance
      .collection('config')
      .doc('public')
      .snapshots()
      .map(
        (doc) => (doc.data()?['defaultSchoolName'] as String?)?.trim() ?? '',
      )
      .handleError((Object e) {
        // 구독 중 오류가 나도 화면이 깨지지 않게 로그만 남긴다. 소비하는
        // 쪽은 전부 `.valueOrNull ?? ''`로 읽으므로 AsyncError 상태에서도
        // 안전하게 빈 문자열로 취급된다.
        AppLogger.warning('기본 학교명 구독 실패: $e');
      });
});
