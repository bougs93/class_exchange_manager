import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/providers/default_school_name_provider.dart';

/// 기본 학교명 Provider 테스트
///
/// `flutter test`는 kIsWeb=false인 데스크톱 VM에서 돈다. Firebase는 웹에서만
/// 초기화되므로([FirebaseAppConfig.ensureInitialized]), 이 Provider(지금은
/// Firestore 문서를 실시간 구독하는 StreamProvider)가 데스크톱에서는
/// Firestore를 아예 건드리지 않고 빈 문자열짜리 스트림으로 단락 평가되는지를
/// 고정한다 — 그렇지 않으면 Firebase 미초기화 상태에서 Firestore를 호출해
/// 예외가 난다(이 테스트가 Firestore 모킹 없이 돌 수 있는 이유이기도 하다).
void main() {
  test('데스크톱(비-웹)에서는 Firestore를 건드리지 않고 빈 문자열을 반환한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(defaultSchoolNameProvider.future);

    expect(value, '');
  });
}
