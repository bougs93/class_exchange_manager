import 'dart:io';

/// Build the Flutter application and its pure Dart search worker together.
/// Usage: dart run tool/build_web.dart [--dart-define=NAME=value ...]
Future<void> main(List<String> args) async {
  final flutter = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    ['build', 'web', '--release', ...args],
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final flutterExit = await flutter.exitCode;
  if (flutterExit != 0) {
    exitCode = flutterExit;
    return;
  }
  final worker = await Process.start(Platform.resolvedExecutable, [
    'compile',
    'js',
    '-O2',
    '-Ddart.vm.product=true',
    'tool/exchange_search_worker.dart',
    '-o',
    'build/web/exchange_search_worker.js',
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await worker.exitCode;
}
