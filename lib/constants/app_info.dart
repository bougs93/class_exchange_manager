import '../services/storage_service.dart';

/// 앱 정보 상수
/// 
/// 프로그램 정보를 중앙에서 관리합니다.
class AppInfo {
  // StorageService 인스턴스 (마지막 실행 시간 저장용)
  static final StorageService _storageService = StorageService();
  // 프로그램명
  static const String programName = '교사용 수업 교체 관리자';
  
  // 버전 정보
  static const String version = '0.9.0 beta'; // 버전 번호는 나중에 추가 가능

  // 소속
  static const String affiliation = 'Noah Lab';

  // 제작자 정보
  static const String developer = 'Jeong won-gil';
  
  
  // 프로그램 소개
  static const String description = '''
대한민국의 교육 시스템에 맞는 교사용 수업 교체 관리 프로그램입니다.
시간표 관리, 교체 가능한 수업 찾기, 결보강계획서 출력, 학급 교사 안내 등의 기능을 제공합니다.
''';
  
  // 프로그램 실행 가능 종료 날짜 (YYYY-MM-DD 형식)
  // null로 설정하려면 아래 값을 null로 변경하세요 (날짜 제한 없음)
  // 예시: null 또는 '2026-12-31'
  // (향후 null로 변경 가능하도록 nullable 타입 유지)
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? expiryDate = '2026-02-29'; // 날짜 제한 없이 사용하려면 null로 변경
  
  // 프로그램 실행 제한 정보
  static String get usageRestriction {
    final baseMessage = '''
본 프로그램은 기능 구현을 위해 상용 라이브러리를 사용하고 있습니다.
이에 따라 정식 배포 시 라이선스 비용이 발생하며, 이는 향후 일부 광고 또는 유료 구매를 통해 충당될 예정입니다.
현재 제공되는 버전은 정식 출시 전 '베타 테스트 버전'으로, 테스트 기간 동안 무료로 이용 가능합니다.
베타 기간 종료 후에는 정식 버전으로의 업그레이드가 필요할 수 있으니 이용에 참고 바랍니다.''';
    
    if (expiryDate == null) {
      return baseMessage;
    } else {
      return '$baseMessage\n\n사용 가능 기간 : ~ $expiryDate';
    }
  }
  
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
  
  // 업데이트 정보
  static const String updateInfo = '''
최신 업데이트 정보는 홈페이지를 참조해주세요.
''';
  
  // 회사 정보
  static const String contact = '''
주소 : 광주광역시 북구 안산로 76 4층
연락처 : 062-267-0153
e-mail : happyreportr@gmail.com
''';
  
  // 라이센스 정보
  static const String license = '''
베타 테스트 기간 동안 무료로 이용 가능합니다.
''';
  
  
  
  // 홈페이지 링크 (여러 개 지원)
  // name: 링크 이름, url: 링크 주소
  static const List<Map<String, String>> homepageLinks = [
    {'name': '노아랩 카페(https://icmake.com/)', 'url': 'https://cafe.naver.com/partnara'},
    {'name': '노아랩랩 홈페이지(공사중)', 'url': 'https://NoahSystem.github.io/'},
    // 필요에 따라 링크 추가
  ];
}
