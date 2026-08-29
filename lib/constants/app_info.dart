import '../services/storage_service.dart';

/// 남은 사용 기간 UI 색상 구분용 상태
enum RemainingPeriodStatus { unlimited, expired, urgent, normal, unknown }

/// 앱 정보 상수
///
/// 프로그램 정보를 중앙에서 관리합니다.
///
/// ⚠️ 중요: 이 파일의 programName을 변경할 때는 다음 네이티브 파일들도 함께 수정해야 합니다:
/// - windows/runner/main.cpp (윈도우 타이틀)
/// - windows/runner/Runner.rc (실행 파일 정보)
/// - macos/Runner/Configs/AppInfo.xcconfig (macOS 앱 이름)
/// - linux/runner/my_application.cc (Linux 윈도우 타이틀)
/// - android/app/src/main/AndroidManifest.xml (Android 앱 라벨)
class AppInfo {
  // StorageService 인스턴스 (마지막 실행 시간 저장용)
  static final StorageService _storageService = StorageService();

  /// 프로그램명
  ///
  /// ⚠️ 이 값을 변경하면 위에 명시된 모든 네이티브 파일도 동일한 값으로 수정해야 합니다.
  static const String programName = '수업 교체 도우미 Beta';

  /// 앱 버전 (이 값만 수정 — pubspec.yaml은 tool/bump_version.dart가 자동 동기화)
  static const String version = '1.0.10';

  /// 마지막 수정 일시 (빌드 정보).
  ///
  /// 커밋 시 tool/bump_version.dart가 자동 갱신하므로 수동 편집 금지.
  /// 빌드 시 --dart-define=BUILD_STAMP 가 없으면 이 값을 화면에 표시한다.
  static const String lastUpdated = '2026.08.29 20:38';

  // 소속
  static const String affiliation = '기술쿠키 & Noah Lab 후원';

  // 제작자 정보
  static const String developer = '정원길, 김진규';

  // 프로그램 소개
  static const String description = '''
대한민국의 교육 시스템에 맞는 교사용 수업 교체 관리 프로그램입니다.
시간표 관리, 교체 가능한 수업 찾기, 결보강계획서 출력, 학급 교사 안내 등의 기능을 제공합니다.
''';

  /// 프로그램 실행 가능 종료 날짜 (YYYY-MM-DD)
  ///
  /// 빌드 시 `--dart-define=EXPIRY_DATE=2027-02-28` 로 주입합니다.
  /// - 일반 exe: [build_release.ps1] — define 없음 → null (제한 없음)
  /// - 설치 프로그램: [build_installer.ps1] — [tool/build_installer.json] 값 적용
  static String? get expiryDate {
    const value = String.fromEnvironment('EXPIRY_DATE', defaultValue: '');
    return value.isEmpty ? null : value;
  }

  /// 빌드 스탬프 (빌드 시각, `YYYY-MM-DD_HHmm` 형태)
  ///
  /// 빌드 시 `--dart-define=BUILD_STAMP=2026-08-24_0135` 로 주입합니다.
  /// IDE 실행 등 define 없이 실행하면 null 이므로 화면에 표시하지 않습니다.
  static String? get buildStamp {
    const value = String.fromEnvironment('BUILD_STAMP', defaultValue: '');
    return value.isEmpty ? null : value;
  }

  /// UI 표시용 버전 라벨 — 빌드 스탬프가 있으면 버전 뒤에 붙인다.
  ///
  /// 예: `1.0.2 (2026-08-24 0135)` / 스탬프 없으면 커밋 시 자동 갱신되는
  /// [lastUpdated] 를 표시한다 (예: `1.0.2 (2026.08.24 02:40)`).
  static String get versionLabel {
    final stamp = buildStamp ?? lastUpdated;
    return '$version ($stamp)';
  }

  // 프로그램 실행 제한 정보 (베타 버전 이용 안내 본문)
  static const String usageRestriction = '''
수업 교체 도우미는 시간표·PDF 출력 등에 일부 상용 소프트웨어 라이브러리를 포함하고 있습니다.
정식 서비스를 위해서는 라이브러리 제작사에 대한 라이선스 비용 지불 및 사용 허가가 필요합니다.
현재 정식 라이선스를 획득하지 못한 상태이므로, 부득이하게 베타 버전에 사용 기한이 설정되어 있습니다.
사용 기한이 지난 후에는 프로그램 실행이 중지됩니다.
정식 라이선스 비용이 청구될 수 있으며, 추후 광고 기반 또는 부분 유료 모델로 전환될 가능성이 있습니다.''';

  /// 프로그램 실행 가능 여부 확인
  ///
  /// 반환값:
  /// - `true`: 실행 가능
  /// - `false`: 만료됨
  static bool isExpired() {
    if (expiryDate == null) {
      return false; // 날짜 제한이 없으면 만료되지 않음
    }

    try {
      final expiry = DateTime.parse(expiryDate!);
      final now = DateTime.now();
      // 오늘 날짜가 만료일보다 나중이면 만료
      return now.isAfter(expiry);
    } catch (e) {
      // 날짜 파싱 실패 시 실행 가능으로 간주
      return false;
    }
  }

  /// 만료일까지 남은 일수
  ///
  /// 반환값:
  /// - `null`: 날짜 제한이 없음
  /// - 음수: 만료됨
  /// - 양수: 남은 일수
  static int? getDaysUntilExpiry() {
    if (expiryDate == null) {
      return null;
    }

    try {
      final expiry = DateTime.parse(expiryDate!);
      final now = DateTime.now();
      return expiry.difference(now).inDays;
    } catch (e) {
      return null;
    }
  }

  /// 사용 가능 기간 표시 문자열 (홈·도움말 공통)
  static String get availablePeriodDisplay {
    final date = expiryDate;
    if (date == null) {
      return '제한 없음';
    }

    try {
      final expiry = DateTime.parse(date);
      return '${expiry.year}년 ${expiry.month}월 ${expiry.day}일까지';
    } catch (e) {
      return date;
    }
  }

  /// 남은 사용 기간 표시 문자열 (홈·도움말 공통)
  static String get remainingPeriodDisplay {
    final date = expiryDate;
    if (date == null) {
      return '제한 없음';
    }
    if (isExpired()) {
      return '만료됨';
    }

    final daysUntilExpiry = getDaysUntilExpiry();
    if (daysUntilExpiry == null) {
      return '계산 불가';
    }
    if (daysUntilExpiry == 0) {
      return '오늘까지';
    }
    return '$daysUntilExpiry일 남음';
  }

  /// 남은 사용 기간 상태 (UI 색상 결정용)
  static RemainingPeriodStatus get remainingPeriodStatus {
    if (expiryDate == null) {
      return RemainingPeriodStatus.unlimited;
    }
    if (isExpired()) {
      return RemainingPeriodStatus.expired;
    }

    final daysUntilExpiry = getDaysUntilExpiry();
    if (daysUntilExpiry == null) {
      return RemainingPeriodStatus.unknown;
    }
    if (daysUntilExpiry <= 30) {
      return RemainingPeriodStatus.urgent;
    }
    return RemainingPeriodStatus.normal;
  }

  /// 마지막 실행 시간 저장
  ///
  /// 현재 시간을 마지막 실행 시간으로 저장합니다.
  /// 시스템 날짜 조작 공격을 방어하기 위해 사용됩니다.
  static Future<void> saveLastExecutionTime() async {
    try {
      final now = DateTime.now();
      final data = {
        'lastExecutionTime': now.toIso8601String(),
        'timestamp': now.millisecondsSinceEpoch,
      };
      await _storageService.saveJson('last_execution_time.json', data);
    } catch (e) {
      // 저장 실패해도 프로그램 실행은 계속 (로그만 기록)
      // ignore: avoid_print
      print('⚠️ 마지막 실행 시간 저장 실패: $e');
    }
  }

  /// 마지막 실행 시간 로드
  ///
  /// 저장된 마지막 실행 시간을 반환합니다.
  ///
  /// 반환값:
  /// - `DateTime?`: 마지막 실행 시간 (저장된 값이 없으면 null)
  static Future<DateTime?> getLastExecutionTime() async {
    try {
      final data = await _storageService.loadJson('last_execution_time.json');
      if (data == null) {
        return null;
      }

      // ISO 8601 형식으로 저장된 경우
      if (data['lastExecutionTime'] != null) {
        return DateTime.parse(data['lastExecutionTime'] as String);
      }

      // 타임스탬프로 저장된 경우 (구버전 호환)
      if (data['timestamp'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
      }

      return null;
    } catch (e) {
      // 로드 실패 시 null 반환 (첫 실행으로 간주)
      return null;
    }
  }

  /// 시간 역행 검증
  ///
  /// 현재 시간이 마지막 실행 시간보다 이전인지 확인합니다.
  /// 시스템 날짜를 조작한 경우를 감지합니다.
  ///
  /// 반환값:
  /// - `true`: 시간 역행 감지됨 (시스템 날짜 조작 의심)
  /// - `false`: 정상적인 시간 흐름
  static Future<bool> isTimeReversed() async {
    try {
      final lastExecutionTime = await getLastExecutionTime();

      // 마지막 실행 시간이 없으면 (첫 실행) 역행이 아님
      if (lastExecutionTime == null) {
        return false;
      }

      final now = DateTime.now();

      // 현재 시간이 마지막 실행 시간보다 이전이면 역행
      // 1분 이내의 차이는 시스템 시간 동기화 오차로 간주하여 허용
      final difference = now.difference(lastExecutionTime);
      if (difference.inMinutes < -1) {
        return true; // 1분 이상 역행하면 조작으로 간주
      }

      return false;
    } catch (e) {
      // 검증 실패 시 안전하게 false 반환 (프로그램 실행 허용)
      return false;
    }
  }

  /// 시간 비정상 점프 검증
  ///
  /// 현재 시간이 마지막 실행 시간보다 비정상적으로 앞서 있는지 확인합니다.
  /// 예: 마지막 실행이 2024-01-01이고 현재가 2025-01-01인 경우
  ///
  /// 반환값:
  /// - `true`: 비정상적인 시간 점프 감지됨
  /// - `false`: 정상적인 시간 흐름
  static Future<bool> isTimeAbnormallyJumped() async {
    try {
      final lastExecutionTime = await getLastExecutionTime();

      // 마지막 실행 시간이 없으면 (첫 실행) 점프가 아님
      if (lastExecutionTime == null) {
        return false;
      }

      final now = DateTime.now();
      final difference = now.difference(lastExecutionTime);

      // 1년 이상 앞서 있으면 비정상으로 간주
      // (일반적으로 프로그램을 1년 이상 사용하지 않았다가 다시 실행하는 경우는 드뭅니다)
      if (difference.inDays > 365) {
        return true;
      }

      return false;
    } catch (e) {
      // 검증 실패 시 안전하게 false 반환
      return false;
    }
  }

  // 회사 정보
  static const String contact = '''
주소 : 전북특별자치도 순창군 금과면 방계로
e-mail : happyreportr@gmail.com
''';

  // 라이센스 정보
  static const String license = '''
베타 테스트 기간 동안 무료로 이용 가능합니다.
''';

  // 홈페이지 링크 (여러 개 지원)
  // name: 링크 이름, url: 링크 주소
  static const List<Map<String, String>> homepageLinks = [
    {
      'name': '기술쿠키(https://techclass.tistory.com/)',
      'url': 'https://techclass.tistory.com/',
    },
    {
      'name': '노아랩 카페(https://icmake.com/)',
      'url': 'https://cafe.naver.com/partnara',
    },
    {'name': '노아랩랩 홈페이지(공사중)', 'url': 'https://NoahSystem.github.io/'},
    // 필요에 따라 링크 추가
  ];
}
