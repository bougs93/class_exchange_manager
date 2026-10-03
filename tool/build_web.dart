import 'dart:io';

/// 웹 앱과 순수 Dart 탐색 Worker를 함께 빌드한다.
///
/// 사용법: `dart run tool/build_web.dart [--dart-define=NAME=value ...]`
///
/// ## Worker를 `web/`에 먼저 만드는 이유
///
/// `exchange_search_worker.js`는 `flutter build web`이 만들어 주지 않는다.
/// 예전에는 이 스크립트가 `flutter build web` **이후** `build/web/`에 직접
/// 넣었는데, 그러면 `flutter run -d chrome`에는 Worker가 없어서 순환·2중 교체
/// 탐색이 실패했다(2026-10-04 보고).
///
/// `web/` 아래 파일은 Flutter가 빌드·개발 서버 양쪽에 그대로 복사하므로,
/// **Worker를 먼저 만들고 그다음 `flutter build web`을 돌리면** 한 번의 생성으로
/// 로컬 실행과 배포 빌드가 모두 해결된다. (`web/exchange_search_worker.js`는
/// 생성물이라 `.gitignore`에 올라가 있다.)
Future<void> main(List<String> args) async {
  // 1) Worker 먼저 — flutter build가 web/ 내용을 build/web/으로 복사한다.
  final workerExit = await buildSearchWorker();
  if (workerExit != 0) {
    exitCode = workerExit;
    return;
  }

  // `flutter run -d chrome` 전에 Worker만 만들고 싶을 때.
  if (args.contains('--worker-only')) {
    stdout.writeln('web/exchange_search_worker.js 생성 완료 (앱 빌드는 생략).');
    return;
  }

  // 2) Flutter 웹 빌드
  final flutter = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    [
      'build',
      'web',
      '--release',
      ...args.where((arg) => arg != '--worker-only'),
    ],
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await flutter.exitCode;
}

/// 탐색 Worker를 `web/exchange_search_worker.js`로 컴파일한다.
///
/// `flutter run -d chrome` 전에 한 번만 돌려도 된다:
/// `dart run tool/build_web.dart --worker-only`
Future<int> buildSearchWorker() async {
  final worker = await Process.start(Platform.resolvedExecutable, [
    'compile',
    'js',
    '-O2',
    '-Ddart.vm.product=true',
    'tool/exchange_search_worker.dart',
    '-o',
    'web/exchange_search_worker.js',
  ], mode: ProcessStartMode.inheritStdio);
  return worker.exitCode;
}
