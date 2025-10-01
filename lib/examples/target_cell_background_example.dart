import 'package:flutter/material.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/logger.dart';

/// 타겟 셀 배경색 상수 예시
/// 
/// 이 파일은 타겟 셀의 배경색이 상수로 정의되어 있음을 보여줍니다.
/// 배경색을 변경하려면 SimplifiedTimetableTheme 클래스의 상수를 직접 수정해야 합니다.
class TargetCellBackgroundExample {
  
  /// 현재 설정된 배경색 정보 출력
  static void printCurrentSettings() {
    AppLogger.exchangeInfo('=== 타겟 셀 배경색 설정 (상수) ===');
    AppLogger.exchangeInfo('배경색: ${SimplifiedTimetableTheme.targetCellBackgroundColor}');
    AppLogger.exchangeInfo('표시 여부: ${SimplifiedTimetableTheme.showTargetCellBackground}');
    AppLogger.exchangeInfo('테두리 색상: ${SimplifiedTimetableTheme.targetCellBorderColor}');
    AppLogger.exchangeInfo('테두리 표시 여부: ${SimplifiedTimetableTheme.showTargetCellBorder}');
  }
  
  /// 타겟 셀 배경색 변경 방법 안내
  static void showHowToChangeBackgroundColor() {
    AppLogger.exchangeInfo('=== 타겟 셀 배경색 변경 방법 ===');
    AppLogger.exchangeInfo('1. lib/utils/simplified_timetable_theme.dart 파일을 열어주세요.');
    AppLogger.exchangeInfo('2. 다음 상수를 찾아주세요:');
    AppLogger.exchangeInfo('   static const Color targetCellBackgroundColor = Color.fromARGB(255, 200, 255, 200);');
    AppLogger.exchangeInfo('3. 원하는 색상으로 변경해주세요.');
    AppLogger.exchangeInfo('');
    AppLogger.exchangeInfo('예시 색상들:');
    AppLogger.exchangeInfo('- 연한 녹색: Color.fromARGB(255, 200, 255, 200)');
    AppLogger.exchangeInfo('- 연한 파란색: Color.fromARGB(255, 227, 242, 253)');
    AppLogger.exchangeInfo('- 연한 노란색: Color.fromARGB(255, 255, 249, 196)');
    AppLogger.exchangeInfo('- 연한 주황색: Color.fromARGB(255, 255, 224, 178)');
    AppLogger.exchangeInfo('- 연한 빨간색: Color.fromARGB(255, 255, 235, 238)');
    AppLogger.exchangeInfo('- 연한 보라색: Color.fromARGB(255, 243, 229, 245)');
  }
}

/// 사용 예시 위젯
class TargetCellBackgroundExampleWidget extends StatelessWidget {
  const TargetCellBackgroundExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('타겟 셀 배경색 상수 예시'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '타겟 셀 배경색 (상수)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 현재 설정 확인
            ElevatedButton(
              onPressed: TargetCellBackgroundExample.printCurrentSettings,
              child: const Text('현재 설정 확인 (콘솔)'),
            ),
            const SizedBox(height: 8),
            
            // 변경 방법 안내
            ElevatedButton(
              onPressed: TargetCellBackgroundExample.showHowToChangeBackgroundColor,
              child: const Text('색상 변경 방법 안내 (콘솔)'),
            ),
            const SizedBox(height: 16),
            
            const Text(
              '현재 설정:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SimplifiedTimetableTheme.targetCellBackgroundColor,
                border: Border.all(
                  color: SimplifiedTimetableTheme.targetCellBorderColor,
                  width: SimplifiedTimetableTheme.targetCellBorderWidth,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '타겟 셀 샘플',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              '사용법:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 타겟 셀 배경색은 상수로 정의되어 있습니다.\n'
              '2. 색상을 변경하려면 SimplifiedTimetableTheme 클래스의 상수를 직접 수정해야 합니다.\n'
              '3. 현재 설정: 연한 녹색 배경 + 녹색 테두리\n'
              '4. 1:1 교체모드에서 경로 선택 시 타겟 셀이 이 색상으로 표시됩니다.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            const Text(
              '색상 변경 예시:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '// 연한 파란색으로 변경\n'
              'static const Color targetCellBackgroundColor = Color.fromARGB(255, 227, 242, 253);\n\n'
              '// 연한 노란색으로 변경\n'
              'static const Color targetCellBackgroundColor = Color.fromARGB(255, 255, 249, 196);\n\n'
              '// 연한 주황색으로 변경\n'
              'static const Color targetCellBackgroundColor = Color.fromARGB(255, 255, 224, 178);',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
