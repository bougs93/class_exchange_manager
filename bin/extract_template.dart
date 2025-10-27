// ignore_for_file: avoid_print
// 이 파일은 템플릿 추출 스크립트로, 콘솔 출력이 주요 기능입니다.
// avoid_print 규칙을 무시합니다.

import 'dart:io';
import 'package:excel/excel.dart';

/// 엑셀 템플릿에서 서식 정보를 추출하는 스크립트
/// 
/// 사용법: dart bin/extract_template.dart
/// 
/// 이 스크립트는:
/// 1. 결보강계획서_양식.xlsx 파일을 읽기
/// 2. 템플릿 정보 추출 (셀, 테그 위치 등)
/// 3. JSON 형식으로 저장
/// 4. 콘솔에 출력

Future<void> main() async {
  print('🔍 엑셀 템플릿 추출 시작...\n');
  
  // 파일 경로 (프로젝트 루트에 있는 파일)
  final templatePath = '결보강계획서_양식.xlsx';
  final outputPath = 'lib/assets/templates/template_info.json';
  
  final templateFile = File(templatePath);
  
  // 파일 존재 확인
  if (!await templateFile.exists()) {
    print('❌ 파일을 찾을 수 없습니다: $templatePath');
    print('   현재 위치: ${Directory.current.path}');
    print('   찾고 있는 경로: ${templateFile.absolute.path}');
    
    // 가능한 파일 찾기
    print('\n📂 현재 디렉토리의 파일:');
    final dir = Directory('.');
    final entities = dir.listSync();
    for (final entity in entities.take(10)) {
      final name = entity.path.split('\\').last;
      if (name.contains('xlsx')) {
        print('   • $name');
      }
    }
    exit(1);
  }
  
  try {
    // 엑셀 파일 읽기
    print('📂 파일 읽기 중: $templatePath');
    final bytes = await templateFile.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    
    if (excel.tables.isEmpty) {
      print('❌ 워크시트가 없습니다.');
      exit(1);
    }
    
    // 첫 번째 워크시트
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    
    print('✅ 워크시트 로드 완료: $sheetName\n');
    
    // 템플릿 정보 추출
    print('📊 템플릿 정보 분석 중...');
    print('   최대 행: ${sheet.maxRows}');
    
    // 모든 셀 정보 추출
    final List<Map<String, dynamic>> cells = [];
    final Map<String, Map<String, int>> tagLocations = {};
    int maxCols = 0;
    
    // 첫 번째 행에서 테그 찾기 (헤더)
    print('\n🏷️ 테그 검색 중...');
    for (var row in sheet.rows) {
      for (var cell in row) {
        if (cell == null) continue;
        
        // 최대 열 업데이트
        if (cell.columnIndex > maxCols) {
          maxCols = cell.columnIndex;
        }
        
        // 셀 정보 저장
        cells.add({
          'row': cell.rowIndex,
          'col': cell.columnIndex,
          'value': cell.value?.toString() ?? '',
        });
        
        // 테그 위치 확인 (첫 번째 행만)
        if (cell.rowIndex == 0 && cell.value != null) {
          final cellValue = cell.value.toString().trim();
          if (_isTagName(cellValue)) {
            tagLocations[cellValue] = {
              'row': cell.rowIndex,
              'col': cell.columnIndex,
            };
            print('   ✓ 발견: $cellValue (행: ${cell.rowIndex}, 열: ${cell.columnIndex})');
          }
        }
      }
    }
    
    // 서식 정보 생성
    final templateInfo = {
      'sheetName': sheetName,
      'maxRows': sheet.maxRows,
      'maxCols': maxCols,
      'cellCount': cells.length,
      'tagCount': tagLocations.length,
      'tagLocations': tagLocations,
      'cells': cells.take(100).toList(), // 처음 100개 셀만 저장
      'extractedAt': DateTime.now().toIso8601String(),
      'extractedBy': 'extract_template.dart',
    };
    
    // JSON으로 변환
    print('\n💾 JSON 파일 생성 중...');
    final jsonString = _prettyJson(templateInfo);
    
    // 디렉토리 생성
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    
    // 파일 저장
    await outputFile.writeAsString(jsonString);
    
    print('✅ 저장 완료: $outputPath\n');
    
    // 콘솔에 요약 출력
    _printSummary(templateInfo);
    
  } catch (e, stackTrace) {
    print('❌ 오류 발생: $e');
    print('스택 트레이스: $stackTrace');
    exit(1);
  }
}

/// 테그 이름인지 확인
bool _isTagName(String value) {
  final tags = [
    'date', 'day', 'period', 'grade', 'class', 'subject', 'teacher',
    'subject2', 'teacher2',
    'date3', 'day3', 'period3', 'subject3', 'teacher3',
    'remarks',
  ];
  
  final lowerValue = value.toLowerCase();
  
  // 1. 단순 태그 확인
  if (tags.contains(lowerValue)) {
    return true;
  }
  
  // 2. 괄호 형식 태그 확인
  for (final tag in tags) {
    final pattern = RegExp('^${RegExp.escape(tag)}\\([^)]+\\)\$');
    if (pattern.hasMatch(lowerValue)) {
      return true;
    }
  }
  
  return false;
}

/// 맵을 보기 좋은 JSON 문자열로 변환
String _prettyJson(Map<String, dynamic> map) {
  final buffer = StringBuffer();
  _writeJson(buffer, map, 0);
  return buffer.toString();
}

void _writeJson(StringBuffer buffer, dynamic value, int indent) {
  final indentStr = '  ' * indent;
  final nextIndentStr = '  ' * (indent + 1);
  
  if (value is Map) {
    buffer.write('{\n');
    final entries = value.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      buffer.write('$nextIndentStr"${entries[i].key}": ');
      _writeJson(buffer, entries[i].value, indent + 1);
      if (i < entries.length - 1) {
        buffer.write(',');
      }
      buffer.write('\n');
    }
    buffer.write('$indentStr}');
  } else if (value is List) {
    if (value.isEmpty) {
      buffer.write('[]');
    } else if (value.length <= 3 && value.every((e) => e is! Map && e is! List)) {
      buffer.write('[${value.join(', ')}]');
    } else {
      buffer.write('[\n');
      for (int i = 0; i < value.length; i++) {
        buffer.write(nextIndentStr);
        _writeJson(buffer, value[i], indent + 1);
        if (i < value.length - 1) {
          buffer.write(',');
        }
        buffer.write('\n');
      }
      buffer.write('$indentStr]');
    }
  } else if (value is String) {
    buffer.write('"${value.replaceAll('"', '\\"')}"');
  } else if (value is num || value is bool) {
    buffer.write(value);
  } else if (value == null) {
    buffer.write('null');
  } else {
    buffer.write('"$value"');
  }
}

/// 추출 결과 요약 출력
void _printSummary(Map<String, dynamic> info) {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📋 템플릿 서식 정보 추출 완료');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  print('📊 기본 정보:');
  print('  워크시트: ${info['sheetName']}');
  print('  최대 행: ${info['maxRows']}');
  print('  최대 열: ${info['maxCols']}');
  print('  총 셀: ${info['cellCount']}');
  print('  추출 시간: ${info['extractedAt']}\n');
  
  print('🏷️ 인식된 테그:');
  final tagLocations = info['tagLocations'] as Map;
  if (tagLocations.isEmpty) {
    print('  (테그 없음)');
  } else {
    for (final entry in tagLocations.entries) {
      final loc = entry.value;
      print('  • ${entry.key}: 행 ${loc['row']}, 열 ${loc['col']}');
    }
  }
  
  print('\n✅ 이제 이 서식 정보를 사용하여 데이터를 채울 수 있습니다!');
  print('\n💡 사용 방법:');
  print('   final info = await ExcelTemplateService().pickAndExtractTemplate();');
  print('   ref.read(excelTemplateProvider.notifier).setTemplate(info);');
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}
