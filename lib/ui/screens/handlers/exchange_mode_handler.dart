import 'package:flutter/material.dart';
import '../../../utils/logger.dart';

/// 교체 모드 전환 관련 핸들러
mixin ExchangeModeHandler<T extends StatefulWidget> on State<T> {
  // 하위 클래스에서 구현해야 하는 속성들
  bool get isExchangeModeEnabled;
  bool get isCircularExchangeModeEnabled;
  bool get isChainExchangeModeEnabled;

  void Function(bool) get setExchangeModeEnabled;
  void Function(bool) get setCircularExchangeModeEnabled;
  void Function(bool) get setChainExchangeModeEnabled;

  void clearAllExchangeStates();
  void restoreUIToDefault();
  void Function() get refreshHeaderTheme;

  List<int> get availableSteps;
  set availableSteps(List<int> value);
  int? get selectedStep;
  set selectedStep(int? value);
  String? get selectedDay;
  set selectedDay(String? value);

  /// 1:1 교체 모드 토글
  void toggleExchangeMode() {
    bool wasEnabled = isExchangeModeEnabled;
    bool hasOtherModesActive = isCircularExchangeModeEnabled || isChainExchangeModeEnabled;

    // 다른 모드가 활성화되어 있다면 비활성화
    if (hasOtherModesActive) {
      setCircularExchangeModeEnabled(false);
      setChainExchangeModeEnabled(false);
    }

    setExchangeModeEnabled(!wasEnabled);

    // 교체 모드가 비활성화되면 UI를 기본값으로 복원
    if (!isExchangeModeEnabled) {
      clearAllExchangeStates();
      restoreUIToDefault();
      availableSteps = [];
      selectedStep = null;
      selectedDay = null;
    } else {
      // 1:1 교체 모드가 활성화되면 항상 초기화
      clearAllExchangeStates();
      availableSteps = [2]; // 1:1 교체는 항상 2개 노드
      selectedStep = null;
      selectedDay = null;
    }

    // 헤더 테마 업데이트
    refreshHeaderTheme();

    // 1:1교체 모드 활성화 시 안내 메시지
    if (isExchangeModeEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('1:1교체 모드가 활성화되었습니다. 두 교사의 시간을 서로 교체할 수 있습니다.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 순환교체 모드 토글
  void toggleCircularExchangeMode() {
    AppLogger.exchangeDebug('순환교체 모드 토글 시작 - 현재 상태: $isCircularExchangeModeEnabled');

    bool wasEnabled = isCircularExchangeModeEnabled;
    bool hasOtherModesActive = isExchangeModeEnabled || isChainExchangeModeEnabled;

    // 다른 모드가 활성화되어 있다면 비활성화
    if (hasOtherModesActive) {
      setExchangeModeEnabled(false);
      setChainExchangeModeEnabled(false);
    }

    setCircularExchangeModeEnabled(!wasEnabled);

    // 순환교체 모드가 비활성화되면 UI를 기본값으로 복원
    if (!isCircularExchangeModeEnabled) {
      clearAllExchangeStates();
      restoreUIToDefault();
      availableSteps = [];
      selectedStep = null;
    } else {
      // 순환교체 모드가 활성화되면 항상 초기화
      clearAllExchangeStates();
    }

    // 헤더 테마 업데이트
    refreshHeaderTheme();

    // 순환교체 모드 활성화 시 안내 메시지
    if (isCircularExchangeModeEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('순환교체 모드가 활성화되었습니다. 여러 교사의 시간을 순환하여 교체할 수 있습니다.'),
          backgroundColor: Colors.indigo,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 연쇄교체 모드 토글
  void toggleChainExchangeMode() {
    AppLogger.exchangeDebug('연쇄교체 모드 토글 시작 - 현재 상태: $isChainExchangeModeEnabled');

    bool wasEnabled = isChainExchangeModeEnabled;
    bool hasOtherModesActive = isExchangeModeEnabled || isCircularExchangeModeEnabled;

    // 다른 모드가 활성화되어 있다면 비활성화
    if (hasOtherModesActive) {
      setExchangeModeEnabled(false);
      setCircularExchangeModeEnabled(false);
    }

    setChainExchangeModeEnabled(!wasEnabled);

    // 연쇄교체 모드가 비활성화되면 UI를 기본값으로 복원
    if (!isChainExchangeModeEnabled) {
      clearAllExchangeStates();
      restoreUIToDefault();
    } else {
      // 연쇄교체 모드가 활성화되면 항상 초기화
      clearAllExchangeStates();
    }

    // 헤더 테마 업데이트
    refreshHeaderTheme();

    // 연쇄교체 모드 활성화 시 안내 메시지
    if (isChainExchangeModeEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('연쇄교체 모드가 활성화되었습니다. 2단계 교체로 결강을 해결할 수 있습니다.'),
          backgroundColor: Colors.deepOrange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
