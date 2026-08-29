import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/print_profile.dart';

/// 미저장 변경(dirty) 판정용 [PrintProfile.contentEquals] 검증
///
/// `operator ==`는 id만 비교하므로 화면 값과 저장값의 차이를 알 수 없다.
/// 이 비교가 틀리면 전환 시 확인 없이 편집 내용이 사라진다(문서 §3③).
void main() {
  PrintProfile base({
    String id = 'pp_1',
    String name = '계획서1',
    int templateIndex = 0,
    double fontSize = 10.0,
    bool includeRemarks = false,
    Map<String, String> fields = const {'teacherName': '정원길'},
    String? templatePath,
  }) {
    return PrintProfile(
      id: id,
      name: name,
      teacherName: '정원길',
      templateIndex: templateIndex,
      fontSize: fontSize,
      remarksFontSize: 7.0,
      selectedFont: 'hanbatang.ttf',
      includeRemarks: includeRemarks,
      additionalFields: fields,
      selectedTemplateFilePath: templatePath,
    );
  }

  group('PrintProfile.contentEquals', () {
    test('설정이 같으면 true (id·이름이 달라도 무시)', () {
      expect(base().contentEquals(base(id: 'pp_2', name: '계획서9')), isTrue);
    });

    test('양식 인덱스가 다르면 false', () {
      expect(base().contentEquals(base(templateIndex: 1)), isFalse);
    });

    test('폰트 크기가 다르면 false', () {
      expect(base().contentEquals(base(fontSize: 11.0)), isFalse);
    });

    test('비고 포함 여부가 다르면 false', () {
      expect(base().contentEquals(base(includeRemarks: true)), isFalse);
    });

    test('추가 필드 값이 다르면 false', () {
      expect(
        base().contentEquals(base(fields: {'teacherName': '김철수'})),
        isFalse,
      );
    });

    test('추가 필드 개수가 다르면 false', () {
      expect(
        base().contentEquals(
          base(fields: {'teacherName': '정원길', 'schoolName': '월계중학교'}),
        ),
        isFalse,
      );
    });

    test('없는 키와 빈 문자열은 같게 본다', () {
      // 화면은 빈 입력란을 ''로 수집하지만 저장값에는 키 자체가 없을 수 있다.
      // 이를 다르게 보면 사용자가 아무것도 안 고쳐도 항상 dirty가 된다.
      final stored = base(fields: {'teacherName': '정원길'});
      final fromUi = base(fields: {'teacherName': '정원길', 'schoolName': ''});

      expect(stored.contentEquals(fromUi), isTrue);
    });

    test('ignoreFields로 지정한 키는 비교에서 빠진다', () {
      final a = base(fields: {'teacherName': '정원길', 'absencePeriod': '8.27'});
      final b = base(fields: {'teacherName': '정원길', 'absencePeriod': '8.28'});

      expect(a.contentEquals(b), isFalse);
      expect(a.contentEquals(b, ignoreFields: {'absencePeriod'}), isTrue);
    });

    test('ignoreFields는 한쪽에만 있는 키에도 적용된다', () {
      final stored = base(fields: {'teacherName': '정원길'});
      final fromUi = base(
        fields: {'teacherName': '정원길', 'absencePeriod': '8.27'},
      );

      expect(
        stored.contentEquals(fromUi, ignoreFields: {'absencePeriod'}),
        isTrue,
      );
    });

    test('사용자 지정 템플릿 경로가 다르면 false', () {
      expect(base().contentEquals(base(templatePath: 'D:/a.pdf')), isFalse);
    });

    test('operator ==는 여전히 id만 비교한다', () {
      expect(base() == base(templateIndex: 1), isTrue);
      expect(base() == base(id: 'pp_2'), isFalse);
    });
  });

  group('PrintProfile.generateId', () {
    test('연속 생성해도 ID가 중복되지 않는다', () {
      final ids = <String>{};
      final now = DateTime(2026, 8, 26, 15, 0, 0);
      for (var i = 0; i < 50; i++) {
        ids.add(PrintProfile.generateId(now: now));
      }
      expect(ids.length, 50);
    });
  });
}
