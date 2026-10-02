import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:class_exchange_manager/models/lesson.dart';
import 'package:class_exchange_manager/services/shared_timetable_sync_service.dart';

/// 공용 시간표 전송 압축 테스트
///
/// 첫 접속 때 9.49MB를 2.79초에 걸쳐 받던 것이 지연의 가장 큰 몫이었다
/// (2026-10-02 실측). 업로드 시 gzip으로 올리고 받는 쪽은 HTTP 단계에서
/// 자동으로 풀리는데, 그 전제인 "압축 후 다시 풀면 원본과 같다"와
/// "수업 JSON은 실제로 크게 줄어든다"를 고정해 둔다.
void main() {
  List<Lesson> makeLessons(int count) {
    return [
      for (var i = 0; i < count; i++)
        Lesson(
          id: 'lesson_$i',
          timetableId: 'tt1',
          date: DateTime(2026, 3, 2).add(Duration(days: i % 180)),
          period: (i % 7) + 1,
          teacher: '교사${i % 50}',
          subject: '기술가정',
          className: '${(i % 3) + 1}-${(i % 10) + 1}',
        ),
    ];
  }

  group('공용 시간표 전송 압축', () {
    test('gzip으로 압축했다가 풀면 원본 JSON과 같다', () {
      final json = SharedTimetableSyncService.encodeLessons(makeLessons(200));

      final compressed = GZipEncoder().encode(utf8.encode(json))!;
      final restored = utf8.decode(GZipDecoder().decodeBytes(compressed));

      expect(restored, json);
      expect(SharedTimetableSyncService.decodeLessons(restored).length, 200);
    });

    test('수업 JSON은 gzip으로 크게 줄어든다', () {
      final json = SharedTimetableSyncService.encodeLessons(makeLessons(5000));
      final raw = utf8.encode(json);
      final compressed = GZipEncoder().encode(raw)!;

      // 같은 필드 이름이 수천 번 반복되므로 압축률이 매우 높다.
      // 실측 기준으로 10배 이상 줄지만, 환경 차이를 감안해 5배로 느슨하게 고정한다.
      expect(compressed.length * 5, lessThan(raw.length));
    });
  });
}
