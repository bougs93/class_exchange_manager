// 초기 비밀번호 부트스트랩용 해시 생성기 (웹 전환 2단계)
//
// 사용법: dart tool/make_auth_hashes.dart <접속자비밀번호> <관리자비밀번호> <마스터비밀번호>
// 출력된 salt/hash 값을 Firebase 콘솔 Firestore에 직접 입력한다.
// - config/auth 문서: viewerSalt, viewerPasswordHash, adminSalt, adminPasswordHash
// - config/public 문서: loginMessage (안내 문구는 콘솔에서 직접 입력)
// - 마스터 ID와 MASTER_PASSWORD_HASH는 빌드 시 --dart-define 으로 주입
//
// 이 스크립트와 출력값은 비밀번호이므로, 사용 후 터미널 기록을 지우고
// git에 커밋하지 않는다.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

String newSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln('사용법: dart tool/make_auth_hashes.dart <접속자비밀번호> <관리자비밀번호> <마스터비밀번호>');
    exit(2);
  }
  final viewerSalt = newSalt();
  final adminSalt = newSalt();
  final viewerHash =
      sha256.convert(utf8.encode('$viewerSalt${args[0]}')).toString();
  final adminHash =
      sha256.convert(utf8.encode('$adminSalt${args[1]}')).toString();
  final masterHash = sha256.convert(utf8.encode(args[2])).toString();

  stdout.writeln('--- config/auth 문서 ---');
  stdout.writeln('viewerSalt: $viewerSalt');
  stdout.writeln('viewerPasswordHash: $viewerHash');
  stdout.writeln('adminSalt: $adminSalt');
  stdout.writeln('adminPasswordHash: $adminHash');
  stdout.writeln('--- 빌드 주입값 (--dart-define) ---');
  stdout.writeln('MASTER_PASSWORD_HASH=$masterHash');
  stdout.writeln('(MASTER_ID는 마스터 ID 평문을 그대로 넣는다)');
}
