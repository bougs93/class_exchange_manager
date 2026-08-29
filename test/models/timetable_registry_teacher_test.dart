import 'package:flutter_test/flutter_test.dart';
import 'package:class_exchange_manager/models/timetable_registry.dart';

/// 교사·학교명이 시간표 속성으로 저장되는지 검증
///
/// 전역 설정이 아니라 시간표에 종속되어야 시간표를 전환했을 때
/// 교사가 함께 바뀐다(문서 §2).
void main() {
  TimetableRegistryEntry makeEntry({
    String id = 'tt_1',
    String? teacherName,
    String? schoolName,
  }) {
    return TimetableRegistryEntry(
      id: id,
      name: '월계중2학기',
      fileName: '시간표.xlsx',
      filePath: 'D:/시간표.xlsx',
      hash: 'h',
      contentHash: 'c',
      teacherName: teacherName,
      schoolName: schoolName,
      registeredAt: DateTime(2026, 8, 26),
    );
  }

  group('TimetableRegistryEntry 교사·학교명', () {
    test('미지정이면 hasTeacher가 false다', () {
      expect(makeEntry().hasTeacher, isFalse);
      expect(makeEntry(teacherName: '  ').hasTeacher, isFalse);
    });

    test('지정되면 hasTeacher가 true다', () {
      expect(makeEntry(teacherName: '정원길').hasTeacher, isTrue);
    });

    test('JSON 왕복에서 값이 보존된다', () {
      final entry = makeEntry(teacherName: '정원길', schoolName: '월계중학교');
      final restored = TimetableRegistryEntry.fromJson(entry.toJson());

      expect(restored.teacherName, '정원길');
      expect(restored.schoolName, '월계중학교');
    });

    test('빈 문자열은 null로 정규화된다 (미지정과 동일 취급)', () {
      final json = makeEntry().toJson();
      json['teacherName'] = '   ';
      json['schoolName'] = '';

      final restored = TimetableRegistryEntry.fromJson(json);
      expect(restored.teacherName, isNull);
      expect(restored.schoolName, isNull);
      expect(restored.hasTeacher, isFalse);
    });

    test('구버전 JSON(필드 없음)도 읽을 수 있다', () {
      final json = makeEntry().toJson()
        ..remove('teacherName')
        ..remove('schoolName');

      final restored = TimetableRegistryEntry.fromJson(json);
      expect(restored.teacherName, isNull);
      expect(restored.schoolName, isNull);
    });

    test('copyWith의 clear 플래그로 미지정으로 되돌릴 수 있다', () {
      final entry = makeEntry(teacherName: '정원길', schoolName: '월계중학교');

      final cleared = entry.copyWith(
        clearTeacherName: true,
        clearSchoolName: true,
      );
      expect(cleared.teacherName, isNull);
      expect(cleared.schoolName, isNull);

      // 다른 필드는 보존된다
      expect(cleared.name, entry.name);
      expect(cleared.hash, entry.hash);
    });

    test('시간표별로 서로 다른 교사를 가질 수 있다', () {
      final registry = TimetableRegistry(
        activeId: 'tt_1',
        timetables: [
          makeEntry(id: 'tt_1', teacherName: '정원길'),
          makeEntry(id: 'tt_2', teacherName: '김철수'),
        ],
      );

      expect(registry.activeEntry?.teacherName, '정원길');
      expect(registry.getById('tt_2')?.teacherName, '김철수');
    });
  });
}
