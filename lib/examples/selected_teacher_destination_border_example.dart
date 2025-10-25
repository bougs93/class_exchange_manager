import 'package:flutter/material.dart';
import '../utils/simplified_timetable_theme.dart';
import '../utils/logger.dart';

/// 선택된 교사가 이동할 목적지 셀 테두리 색상 상수 예시
/// 
/// 이 파일은 선택된 교사가 이동할 목적지 셀의 테두리 색상이 상수로 정의되어 있음을 보여줍니다.
/// 테두리 색상을 변경하려면 SimplifiedTimetableTheme 클래스의 상수를 직접 수정해야 합니다.
class SelectedTeacherDestinationBorderExample {
  
  /// 현재 설정된 테두리 색상 정보 출력
  static void printCurrentSettings() {
    AppLogger.exchangeInfo('=== 선택된 교사가 이동할 목적지 셀 테두리 설정 (상수) ===');
    AppLogger.exchangeInfo('테두리 색상: ${SimplifiedTimetableTheme.selectedTeacherDestinationBorderColor}');
    AppLogger.exchangeInfo('테두리 표시 여부: ${SimplifiedTimetableTheme.showSelectedTeacherDestinationBorder}');
  }
  
  /// 선택된 교사가 이동할 목적지 셀 테두리 색상 변경 방법 안내
  static void showHowToChangeBorderColor() {
    AppLogger.exchangeInfo('=== 선택된 교사가 이동할 목적지 셀 테두리 색상 변경 방법 ===');
    AppLogger.exchangeInfo('1. lib/utils/simplified_timetable_theme.dart 파일을 열어주세요.');
    AppLogger.exchangeInfo('2. 다음 상수를 찾아주세요:');
    AppLogger.exchangeInfo('   static const Color selectedTeacherDestinationBorderColor = Color(0xFFFF0000);');
    AppLogger.exchangeInfo('3. 원하는 색상으로 변경해주세요.');
    AppLogger.exchangeInfo('');
    AppLogger.exchangeInfo('예시 색상들:');
    AppLogger.exchangeInfo('- 빨간색: Color(0xFFFF0000)');
    AppLogger.exchangeInfo('- 파란색: Color(0xFF0000FF)');
    AppLogger.exchangeInfo('- 녹색: Color(0xFF00FF00)');
    AppLogger.exchangeInfo('- 주황색: Color(0xFFFFA500)');
    AppLogger.exchangeInfo('- 보라색: Color(0xFF800080)');
    AppLogger.exchangeInfo('');
    AppLogger.exchangeInfo('주의: 배경색은 변경되지 않고 테두리 색상만 변경됩니다.');
  }
}

/// 사용 예시 위젯
class SelectedTeacherDestinationBorderExampleWidget extends StatelessWidget {
  const SelectedTeacherDestinationBorderExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('선택된 교사가 이동할 목적지 셀 테두리 색상 상수 예시'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '선택된 교사가 이동할 목적지 셀 테두리 색상 (상수)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 현재 설정 확인
            ElevatedButton(
              onPressed: SelectedTeacherDestinationBorderExample.printCurrentSettings,
              child: const Text('현재 설정 확인 (콘솔)'),
            ),
            const SizedBox(height: 8),
            
            // 변경 방법 안내
            ElevatedButton(
              onPressed: SelectedTeacherDestinationBorderExample.showHowToChangeBorderColor,
              child: const Text('테두리 색상 변경 방법 안내 (콘솔)'),
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
                color: SimplifiedTimetableTheme.defaultColor, // 기본 배경색 사용
                border: Border.all(
                  color: SimplifiedTimetableTheme.selectedTeacherDestinationBorderColor,
                  width: SimplifiedTimetableTheme.selectedTeacherDestinationBorderWidth,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '선택된 교사가 이동할 목적지 셀 샘플',
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
              '1. 선택된 교사가 이동할 목적지 셀의 테두리 색상은 상수로 정의되어 있습니다.\n'
              '2. 색상을 변경하려면 SimplifiedTimetableTheme 클래스의 상수를 직접 수정해야 합니다.\n'
              '3. 현재 설정: 빨간색 테두리 (배경색은 변경되지 않음)\n'
              '4. 1:1 교체모드에서 경로 선택 시 목적지 셀이 이 테두리 색상으로 표시됩니다.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            const Text(
              '색상 변경 예시:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '// 파란색으로 변경\n'
              'static const Color selectedTeacherDestinationBorderColor = Color(0xFF0000FF);\n\n'
              '// 녹색으로 변경\n'
              'static const Color selectedTeacherDestinationBorderColor = Color(0xFF00FF00);\n\n'
              '// 주황색으로 변경\n'
              'static const Color selectedTeacherDestinationBorderColor = Color(0xFFFFA500);',
              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
