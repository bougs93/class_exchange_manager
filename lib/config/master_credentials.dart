/// 마스터 계정 (웹 전환 2단계, 계획서 4.2절)
///
/// 관리자 비밀번호 분실 시 진입하는 ID + 비밀번호 조합. 평문이 아니라
/// SHA-256 해시로 들고 있으며, 실제 값은 소스코드에 커밋하지 않고 빌드 시
/// `--dart-define`으로 주입한다 (CI Secret 연동 예정).
///
/// 예: flutter build web --dart-define=MASTER_ID=... --dart-define=MASTER_PASSWORD_HASH=...
class MasterCredentials {
  /// 마스터 ID (평문 비교, 추측 어렵게 임의 문자열 권장).
  static const String masterId = String.fromEnvironment('MASTER_ID');

  /// 마스터 비밀번호의 SHA-256 해시 (소문자 hex 64자).
  static const String masterPasswordHash = String.fromEnvironment(
    'MASTER_PASSWORD_HASH',
  );

  /// 마스터 계정이 설정됐는지 (빌드 주입 여부).
  static bool get isConfigured =>
      masterId.isNotEmpty && masterPasswordHash.isNotEmpty;
}
