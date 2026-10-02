import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/constants/korean_fonts.dart';

/// 웹·모바일 PDF 출력용 번들 폰트 테스트
///
/// 2026-10-02: Microsoft/상용 폰트(맑은 고딕 등)는 라이선스상 앱에 번들할
/// 수 없어, 웹과 모바일(Android/iOS)에서는 OFL 라이선스의 Noto Sans/Serif
/// KR 서브셋 2종(고딕체/명조체)을 대신 제공한다. `C:\Windows\Fonts`는
/// Windows에만 있으므로, 이 제약은 웹만이 아니라 모바일에도 그대로
/// 적용된다 — 플랫폼 분기를 `kIsWeb` 하나로만 하면 모바일이 데스크톱 쪽
/// 9종 목록을 보게 되는 회귀가 생긴다.
///
/// 이 테스트는 (1) 목록 정의가 서로 어긋나지 않는지, (2) 실제 에셋
/// 파일이 모두 존재하고 올바른 TrueType 폰트인지, (3) 플랫폼 분기 조건이
/// 의도대로 구성됐는지를 고정한다. `flutter test`는 데스크톱(VM)에서
/// 돌기 때문에 모바일 분기 자체는 기기/에뮬레이터 없이 단위 테스트로
/// 직접 돌려볼 수 없다 — 그 경계는 이 테스트가 아니라
/// `KoreanFontConstants._isBundledFontPlatform`의 조건식 리뷰로 지킨다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KoreanFontConstants 번들 폰트 목록 (웹 + 모바일 공용)', () {
    test('bundledFontListWithNames과 bundledFontFiles가 1:1로 대응한다', () {
      final listedFiles =
          KoreanFontConstants.bundledFontListWithNames
              .map((f) => f['file'])
              .toList();
      expect(listedFiles, KoreanFontConstants.bundledFontFiles);
    });

    test('항목마다 표시용 한글 이름이 비어있지 않다', () {
      for (final font in KoreanFontConstants.bundledFontListWithNames) {
        expect(font['name'], isNotNull);
        expect(font['name'], isNotEmpty);
      }
    });

    test('웹·모바일 기본값은 둘 다 bundledFontFiles 안에 있다', () {
      // 기본값 자체는 웹(명조체)과 모바일(고딕체)이 다르지만(2026-10-02
      // 요청), 둘 다 선택 가능한 번들 목록 안에 있어야 한다.
      expect(
        KoreanFontConstants.bundledFontFiles,
        contains(KoreanFontConstants.webDefaultFont),
      );
      expect(
        KoreanFontConstants.bundledFontFiles,
        contains(KoreanFontConstants.mobileDefaultFont),
      );
    });

    test('웹 기본값은 명조체, 모바일 기본값은 고딕체다', () {
      expect(KoreanFontConstants.webDefaultFont, 'NotoSerifKR-Subset.ttf');
      expect(KoreanFontConstants.mobileDefaultFont, 'NotoSansKR-Subset.ttf');
    });

    test('platform* 접근자는 flutter test(데스크톱 VM) 환경에서 네이티브 목록을 가리킨다', () {
      // `flutter test`는 kIsWeb=false, Platform.isAndroid/isIOS=false인
      // 데스크톱 VM에서 돈다. 데스크톱(PC) 목록이 그대로 나오는지 확인해
      // 두면, 이번 변경이 기존 PC 동작(맑은 고딕 등 9종 선택)을 건드리지
      // 않았음을 회귀로 잡아낼 수 있다.
      expect(
        KoreanFontConstants.platformFontListWithNames,
        KoreanFontConstants.fontListWithNames,
      );
      expect(
        KoreanFontConstants.platformFontFiles,
        KoreanFontConstants.fontFiles,
      );
      expect(
        KoreanFontConstants.platformDefaultFont,
        KoreanFontConstants.defaultFont,
      );
    });

    test('데스크톱 목록과 번들 목록은 서로 다른 파일 집합이다', () {
      // 두 목록이 우연히 겹치면(예: 같은 파일명을 재사용) 플랫폼 분기가
      // 있으나 마나한 상태가 된다 — 완전히 분리돼 있어야 한다.
      final desktopFiles = KoreanFontConstants.fontFiles.toSet();
      final bundledFiles = KoreanFontConstants.bundledFontFiles.toSet();
      expect(desktopFiles.intersection(bundledFiles), isEmpty);
    });
  });

  group('번들 폰트 에셋 파일', () {
    /// TrueType 폰트는 'true'(Mac) 또는 0x00,0x01,0x00,0x00 시그니처로
    /// 시작한다. 서브셋/인스턴스 변환이 깨진 바이너리를 만들지 않았는지
    /// 최소한으로 확인한다.
    bool looksLikeTrueType(Uint8List bytes) {
      if (bytes.length < 4) return false;
      final sig = bytes.sublist(0, 4);
      final isSfnt1 =
          sig[0] == 0x00 && sig[1] == 0x01 && sig[2] == 0x00 && sig[3] == 0x00;
      final isTrue = String.fromCharCodes(sig) == 'true';
      return isSfnt1 || isTrue;
    }

    for (final fileName in KoreanFontConstants.bundledFontFiles) {
      test('$fileName 에셋이 존재하고 올바른 TrueType 폰트다', () async {
        final data = await rootBundle.load('lib/assets/fonts/$fileName');
        final bytes = data.buffer.asUint8List();
        expect(bytes, isNotEmpty);
        expect(
          looksLikeTrueType(bytes),
          isTrue,
          reason: '$fileName이 유효한 TrueType 시그니처로 시작하지 않는다',
        );
      });
    }

    test('가장 무거운 명조체도 10MB를 넘지 않는다 (용량 회귀 방지)', () async {
      final data = await rootBundle.load(
        'lib/assets/fonts/NotoSerifKR-Subset.ttf',
      );
      expect(data.lengthInBytes, lessThan(10 * 1024 * 1024));
    });
  });
}
