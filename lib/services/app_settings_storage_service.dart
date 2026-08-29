import 'storage_service.dart';
import '../constants/teacher_row_highlight_colors.dart';
import '../theme/app_theme_type.dart';
import '../ui/widgets/timetable_grid/timetable_grid_constants.dart';
import '../utils/logger.dart';

/// 기타 설정(언어·하이라이트·간접교체·화살표 등)의 앱 기본값
class AppSettingsDefaults {
  AppSettingsDefaults._();

  static const String languageCode = 'ko';
  static const bool dualExchangeEnabled = true;
  static const bool circularExchangeEnabled = false;
  static const ArrowDirection oneToOneArrowDirection =
      ArrowDirection.bidirectional;
  static const ArrowDirection dualArrowDirection = ArrowDirection.bidirectional;

  /// 디자인 테마 기본값 (기존 클래식 디자인)
  static const AppThemeType appThemeType = AppThemeType.classic;

  /// 교사 행 하이라이트 기본색 (Teal 50)
  static int get highlightedTeacherColorArgb =>
      TeacherRowHighlightColors.defaultColor.toARGB32();
}

/// 2중 교체 설정 저장/로드 인터페이스 (테스트 mock 지원)
abstract class DualExchangeSettingsStorage {
  Future<bool> getDualExchangeEnabled();
  Future<bool> saveDualExchangeEnabled(bool enabled);
}

/// 순환 교체 설정 저장/로드 인터페이스 (테스트 mock 지원)
abstract class CircularExchangeSettingsStorage {
  Future<bool> getCircularExchangeEnabled();
  Future<bool> saveCircularExchangeEnabled(bool enabled);
}

/// 교체 화살표 방향 설정 저장/로드 인터페이스 (테스트 mock 지원)
abstract class ArrowDirectionSettingsStorage {
  Future<ArrowDirection> getOneToOneArrowDirection();
  Future<bool> saveOneToOneArrowDirection(ArrowDirection direction);
  Future<ArrowDirection> getDualArrowDirection();
  Future<bool> saveDualArrowDirection(ArrowDirection direction);
}

/// ArrowDirection ↔ JSON 문자열 변환
String arrowDirectionToJson(ArrowDirection direction) {
  return direction == ArrowDirection.bidirectional
      ? 'bidirectional'
      : 'forward';
}

/// JSON 문자열 → ArrowDirection (알 수 없는 값이면 [fallback])
ArrowDirection arrowDirectionFromJson(String? value, ArrowDirection fallback) {
  switch (value) {
    case 'forward':
      return ArrowDirection.forward;
    case 'bidirectional':
      return ArrowDirection.bidirectional;
    default:
      return fallback;
  }
}

/// 앱 설정 저장 서비스
///
/// 언어 설정 등 앱 전역 설정을 JSON 파일로 저장하고 로드합니다.
class AppSettingsStorageService
    implements
        DualExchangeSettingsStorage,
        CircularExchangeSettingsStorage,
        ArrowDirectionSettingsStorage {
  final StorageService _storageService = StorageService();
  Future<void> _settingsWriteQueue = Future<void>.value();

  // 싱글톤 인스턴스
  static final AppSettingsStorageService _instance =
      AppSettingsStorageService._internal();

  factory AppSettingsStorageService() => _instance;

  AppSettingsStorageService._internal();

  /// 앱 설정 저장
  ///
  /// 매개변수:
  /// - `languageCode`: 언어 코드 (예: "ko", "en")
  ///
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveAppSettings({required String languageCode}) {
    return _mergeAndSaveSettings({
      'languageCode': languageCode,
    }, logLabel: '앱 설정(languageCode=$languageCode)');
  }

  /// 앱 설정 로드
  ///
  /// 저장된 앱 설정을 로드합니다.
  ///
  /// 반환값:
  /// - `Future<Map<String, dynamic>?>`: 앱 설정 (없으면 null)
  Future<Map<String, dynamic>?> loadAppSettings() async {
    try {
      final settings = await _storageService.loadJson('app_settings.json');

      if (settings == null) {
        AppLogger.info('앱 설정 파일이 없습니다.');
        return null;
      }

      AppLogger.info('앱 설정 로드 성공');
      return settings;
    } catch (e) {
      AppLogger.error('앱 설정 로드 중 오류: $e', e);
      return null;
    }
  }

  /// app_settings.json에 [patch]를 병합 저장하는 공통 처리 (merge 방식)
  ///
  /// 기존 설정을 로드해 [patch]의 키만 덮어쓰고 나머지는 유지합니다.
  /// [logLabel]은 성공/실패/오류 로그 메시지의 접두어로 사용됩니다.
  Future<bool> _mergeAndSaveSettings(
    Map<String, dynamic> patch, {
    required String logLabel,
  }) {
    final operation = _settingsWriteQueue.then(
      (_) => _performMergeAndSaveSettings(patch, logLabel: logLabel),
    );
    _settingsWriteQueue = operation.then<void>((_) {});
    return operation;
  }

  Future<bool> _performMergeAndSaveSettings(
    Map<String, dynamic> patch, {
    required String logLabel,
  }) async {
    try {
      final settings = await loadAppSettings();
      final updatedSettings =
          settings == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(settings);

      updatedSettings.addAll(patch);

      final success = await _storageService.saveJson(
        'app_settings.json',
        updatedSettings,
      );

      if (success) {
        AppLogger.info('$logLabel 저장 성공');
      } else {
        AppLogger.error('$logLabel 저장 실패');
      }

      return success;
    } catch (e) {
      AppLogger.error('$logLabel 저장 중 오류: $e', e);
      return false;
    }
  }

  /// 언어 코드 가져오기
  ///
  /// 반환값:
  /// - `Future<String>`: 언어 코드 (기본값: "ko")
  Future<String> getLanguageCode() async {
    try {
      final settings = await loadAppSettings();
      if (settings == null) {
        return 'ko'; // 기본값: 한국어
      }

      return (settings['languageCode'] as String?) ?? 'ko';
    } catch (e) {
      AppLogger.error('언어 코드 가져오기 실패: $e', e);
      return 'ko'; // 기본값: 한국어
    }
  }

  /// 하이라이트된 교사 행 색상 저장
  ///
  /// 설정에서 지정한 하이라이트 색상을 ARGB 값으로 저장합니다.
  ///
  /// 매개변수:
  /// - `colorValue`: ARGB 값 (int)
  ///
  /// 반환값:
  /// - `Future<bool>`: 저장 성공 여부
  Future<bool> saveHighlightedTeacherColor(int colorValue) async {
    return _mergeAndSaveSettings({
      'highlightedTeacherColor': colorValue,
    }, logLabel: '하이라이트 교사 행 색상($colorValue)');
  }

  /// 하이라이트된 교사 행 색상 로드
  ///
  /// 저장된 하이라이트 색상을 로드합니다.
  ///
  /// 반환값:
  /// - `Future<int?>`: ARGB 값 (없으면 null)
  Future<int?> getHighlightedTeacherColor() async {
    try {
      final settings = await loadAppSettings();
      if (settings == null) {
        return null;
      }

      final colorValue = settings['highlightedTeacherColor'] as int?;
      return colorValue;
    } catch (e) {
      AppLogger.error('하이라이트 교사 행 색상 로드 중 오류: $e', e);
      return null;
    }
  }

  /// 2중 교체 기능 사용 여부 저장
  ///
  /// 홈>설정에서 2중 교체 메뉴 표시 여부를 저장합니다.
  /// 기존 설정은 merge 방식으로 유지합니다.
  @override
  Future<bool> saveDualExchangeEnabled(bool enabled) async {
    return _mergeAndSaveSettings({
      'dualExchangeEnabled': enabled,
    }, logLabel: '2중 교체 설정(enabled=$enabled)');
  }

  /// 2중 교체 기능 사용 여부 로드
  ///
  /// 반환값:
  /// - `Future<bool>`: 활성화 여부 (기본값: true)
  @override
  Future<bool> getDualExchangeEnabled() async {
    try {
      final settings = await loadAppSettings();
      if (settings == null) {
        return true;
      }

      return settings['dualExchangeEnabled'] as bool? ?? true;
    } catch (e) {
      AppLogger.error('2중 교체 설정 로드 중 오류: $e', e);
      return true;
    }
  }

  /// 순환 교체 기능 사용 여부 저장
  @override
  Future<bool> saveCircularExchangeEnabled(bool enabled) async {
    return _mergeAndSaveSettings({
      'circularExchangeEnabled': enabled,
    }, logLabel: '순환 교체 설정(enabled=$enabled)');
  }

  /// 순환 교체 기능 사용 여부 로드
  ///
  /// 반환값:
  /// - `Future<bool>`: 활성화 여부 (기본값: false)
  @override
  Future<bool> getCircularExchangeEnabled() async {
    try {
      final settings = await loadAppSettings();
      if (settings == null) {
        return false;
      }

      return settings['circularExchangeEnabled'] as bool? ?? false;
    } catch (e) {
      AppLogger.error('순환 교체 설정 로드 중 오류: $e', e);
      return false;
    }
  }

  /// 1:1 교체 화살표 방향 로드 (기본값: 양방향 bidirectional)
  @override
  Future<ArrowDirection> getOneToOneArrowDirection() async {
    try {
      final settings = await loadAppSettings();
      return arrowDirectionFromJson(
        settings?['oneToOneArrowDirection'] as String?,
        ArrowDirection.bidirectional,
      );
    } catch (e) {
      AppLogger.error('1:1 화살표 방향 로드 중 오류: $e', e);
      return ArrowDirection.bidirectional;
    }
  }

  /// 1:1 교체 화살표 방향 저장 (기존 설정은 merge 방식 유지)
  @override
  Future<bool> saveOneToOneArrowDirection(ArrowDirection direction) async {
    return _mergeAndSaveSettings({
      'oneToOneArrowDirection': arrowDirectionToJson(direction),
    }, logLabel: '1:1 화살표 방향(${arrowDirectionToJson(direction)})');
  }

  /// 2중 교체 화살표 방향 로드 (기본값: 양방향 bidirectional)
  @override
  Future<ArrowDirection> getDualArrowDirection() async {
    try {
      final settings = await loadAppSettings();
      return arrowDirectionFromJson(
        settings?['dualArrowDirection'] as String?,
        ArrowDirection.bidirectional,
      );
    } catch (e) {
      AppLogger.error('2중 화살표 방향 로드 중 오류: $e', e);
      return ArrowDirection.bidirectional;
    }
  }

  /// 2중 교체 화살표 방향 저장 (기존 설정은 merge 방식 유지)
  @override
  Future<bool> saveDualArrowDirection(ArrowDirection direction) async {
    return _mergeAndSaveSettings({
      'dualArrowDirection': arrowDirectionToJson(direction),
    }, logLabel: '2중 화살표 방향(${arrowDirectionToJson(direction)})');
  }

  /// 디자인 테마 유형 로드 (기본값: 클래식)
  Future<AppThemeType> getAppThemeType() async {
    try {
      final settings = await loadAppSettings();
      return AppThemeType.fromJson(
        settings?['appTheme'] as String?,
        AppSettingsDefaults.appThemeType,
      );
    } catch (e) {
      AppLogger.error('디자인 테마 로드 중 오류: $e', e);
      return AppSettingsDefaults.appThemeType;
    }
  }

  /// 디자인 테마 유형 저장 (기존 설정은 merge 방식 유지)
  Future<bool> saveAppThemeType(AppThemeType type) async {
    return _mergeAndSaveSettings({
      'appTheme': type.toJson(),
    }, logLabel: '디자인 테마(${type.name})');
  }

  /// 기타 설정을 기본값으로 복원
  ///
  /// 하이라이트 색상·2중/순환 교체·화살표 방향을 초기화합니다.
  /// [languageCode]는 유지합니다.
  ///
  /// 교사명·학교명은 전역 설정이 아니라 시간표 속성이므로 여기서 다루지 않습니다.
  Future<bool> restoreMiscSettingsToDefaults() {
    return _mergeAndSaveSettings({
      'highlightedTeacherColor':
          AppSettingsDefaults.highlightedTeacherColorArgb,
      'dualExchangeEnabled': AppSettingsDefaults.dualExchangeEnabled,
      'circularExchangeEnabled': AppSettingsDefaults.circularExchangeEnabled,
      'oneToOneArrowDirection': arrowDirectionToJson(
        AppSettingsDefaults.oneToOneArrowDirection,
      ),
      'dualArrowDirection': arrowDirectionToJson(
        AppSettingsDefaults.dualArrowDirection,
      ),
    }, logLabel: '기타 설정 기본값 복원');
  }
}
