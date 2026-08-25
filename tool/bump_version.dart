// 버전은 lib/constants/app_info.dart 한 곳에서만 관리합니다.
// pubspec.yaml은 Flutter 빌드용으로 이 스크립트가 자동 동기화합니다.
//
// bump 시 AppInfo.version(패치 +1)과 AppInfo.lastUpdated(빌드 정보)를 함께
// 갱신하고 pubspec.yaml version 줄을 동기화합니다.
//
// 사용:
//   dart tool/bump_version.dart       → 패치 +1 (커밋 hook)
//   dart tool/bump_version.dart sync  → app_info → pubspec 동기화만 (수동 변경 후)

import 'dart:io';

const _pubspecPath = 'pubspec.yaml';
const _appInfoPath = 'lib/constants/app_info.dart';

final _versionInAppInfo = RegExp(
  r"static const String version = '(\d+)\.(\d+)\.(\d+)';",
);

final _lastUpdatedInAppInfo = RegExp(
  r"(static const String lastUpdated = ')([^']*)(';)",
);

void main(List<String> args) {
  if (args.contains('sync')) {
    final version = _readVersionFromAppInfo();
    _writeVersionToPubspec(version);
    stdout.writeln('pubspec.yaml 동기화: $version');
    return;
  }

  final (major, minor, patch) = _readVersionPartsFromAppInfo();
  final nextVersion = '$major.$minor.${patch + 1}';
  final nowStamp = _nowStamp();

  _writeVersionToAppInfo(nextVersion);
  _writeLastUpdatedToAppInfo(nowStamp);
  _writeVersionToPubspec(nextVersion);

  stdout.writeln('버전 업데이트: $nextVersion');
  stdout.writeln('빌드 정보 업데이트: $nowStamp');
}

/// `yyyy.MM.dd HH:mm` 형태의 빌드 정보 스탬프.
String _nowStamp() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}.${two(n.month)}.${two(n.day)} '
      '${two(n.hour)}:${two(n.minute)}';
}

String _readVersionFromAppInfo() {
  final parts = _readVersionPartsFromAppInfo();
  return '${parts.$1}.${parts.$2}.${parts.$3}';
}

(int, int, int) _readVersionPartsFromAppInfo() {
  final appInfo = File(_appInfoPath);
  if (!appInfo.existsSync()) {
    stderr.writeln('$_appInfoPath 파일을 찾을 수 없습니다.');
    exit(1);
  }

  final match = _versionInAppInfo.firstMatch(appInfo.readAsStringSync());
  if (match == null) {
    stderr.writeln(
      'app_info.dart에서 static const String version = \'X.Y.Z\'; 형식을 찾을 수 없습니다.',
    );
    exit(1);
  }

  return (
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

void _writeVersionToAppInfo(String version) {
  final appInfo = File(_appInfoPath);
  final updated = appInfo.readAsStringSync().replaceFirst(
    _versionInAppInfo,
    "static const String version = '$version';",
  );
  appInfo.writeAsStringSync(updated);
}

void _writeLastUpdatedToAppInfo(String stamp) {
  final appInfo = File(_appInfoPath);
  final text = appInfo.readAsStringSync();
  if (!_lastUpdatedInAppInfo.hasMatch(text)) {
    stderr.writeln("$_appInfoPath에서 lastUpdated 상수를 찾을 수 없습니다.");
    exit(1);
  }
  appInfo.writeAsStringSync(
    text.replaceFirstMapped(_lastUpdatedInAppInfo, (m) {
      return '${m.group(1)}$stamp${m.group(3)}';
    }),
  );
}

void _writeVersionToPubspec(String version) {
  final pubspec = File(_pubspecPath);
  if (!pubspec.existsSync()) {
    stderr.writeln('$_pubspecPath 파일을 찾을 수 없습니다.');
    exit(1);
  }

  final updated = pubspec.readAsStringSync().replaceFirst(
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $version',
  );
  pubspec.writeAsStringSync(updated);
}
