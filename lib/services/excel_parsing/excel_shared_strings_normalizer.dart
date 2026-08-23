import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Excel `sharedStrings.xml` 중복 항목을 정규화하는 유틸리티
///
/// Dart `excel` 패키지(4.x)는 sharedStrings를 **문자열 값 기준 중복 제거**한 뒤
/// 셀의 원본 인덱스로 조회합니다. Excel이 같은 텍스트를 여러 번 저장한 파일에서는
/// 인덱스 불일치가 나며 `Null check operator used on a null value`로 읽기에 실패합니다.
///
/// 이 클래스는 decode 전에:
/// 1. sharedStrings를 고유 문자열만 남기고
/// 2. 시트 셀의 sharedString 인덱스를 재매핑
/// 하여 패키지와 인덱스를 맞춥니다.
class ExcelSharedStringsNormalizer {
  ExcelSharedStringsNormalizer._();

  static const _logName = 'ExcelSharedStringsNormalizer';
  static const _sharedStringsPath = 'xl/sharedStrings.xml';
  static const _spreadsheetNs =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  /// xlsx 바이트를 정규화합니다. 변경이 없으면 원본을 그대로 반환합니다.
  static Uint8List normalize(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedFile = archive.findFile(_sharedStringsPath);
      if (sharedFile == null) {
        return Uint8List.fromList(bytes);
      }

      sharedFile.decompress();
      final sharedXml = utf8.decode(sharedFile.content as List<int>);
      final document = XmlDocument.parse(sharedXml);

      final siNodes = document.findAllElements('si').toList();
      if (siNodes.isEmpty) {
        return Uint8List.fromList(bytes);
      }

      // 원본 인덱스 → 고유 인덱스
      final oldToNew = <int, int>{};
      final uniqueSiXml = <String>[];
      final valueToNewIndex = <String, int>{};

      for (var oldIndex = 0; oldIndex < siNodes.length; oldIndex++) {
        final si = siNodes[oldIndex];
        final value = _sharedStringValue(si);
        final existing = valueToNewIndex[value];
        if (existing != null) {
          oldToNew[oldIndex] = existing;
        } else {
          final newIndex = uniqueSiXml.length;
          valueToNewIndex[value] = newIndex;
          oldToNew[oldIndex] = newIndex;
          // 네임스페이스 없는 로컬 조각으로 저장 (sst에서 xmlns 상속)
          uniqueSiXml.add(si.toXmlString(pretty: false));
        }
      }

      if (uniqueSiXml.length == siNodes.length) {
        return Uint8List.fromList(bytes);
      }

      developer.log(
        'sharedStrings 정규화: ${siNodes.length}개 → ${uniqueSiXml.length}개 '
        '(중복 ${siNodes.length - uniqueSiXml.length}개 제거)',
        name: _logName,
      );

      final newArchive = Archive();
      for (final file in archive.files) {
        if (!file.isFile) continue;
        file.decompress();
        final content = file.content as List<int>;
        final name = file.name;

        if (name == _sharedStringsPath) {
          final rebuilt = _buildSharedStringsXml(uniqueSiXml);
          newArchive.addFile(ArchiveFile(name, rebuilt.length, rebuilt));
        } else if (_isWorksheetXml(name)) {
          final remapped = _remapWorksheetSharedStringIndices(
            utf8.decode(content),
            oldToNew,
          );
          final remappedBytes = utf8.encode(remapped);
          newArchive.addFile(
            ArchiveFile(name, remappedBytes.length, remappedBytes),
          );
        } else {
          newArchive.addFile(ArchiveFile(name, content.length, content));
        }
      }

      final encoded = ZipEncoder().encode(newArchive);
      if (encoded == null) {
        developer.log('ZIP 재압축 실패 — 원본 바이트 사용', name: _logName);
        return Uint8List.fromList(bytes);
      }
      return Uint8List.fromList(encoded);
    } catch (e, st) {
      developer.log(
        'sharedStrings 정규화 중 오류 — 원본 바이트 사용: $e\n$st',
        name: _logName,
      );
      return Uint8List.fromList(bytes);
    }
  }

  /// `<si>`에서 표시 문자열 추출 (음독 rPh 제외)
  static String _sharedStringValue(XmlElement si) {
    final buffer = StringBuffer();
    for (final t in si.findAllElements('t')) {
      final parent = t.parentElement;
      if (parent != null && parent.localName == 'rPh') continue;
      buffer.write(t.innerText);
    }
    return buffer.toString();
  }

  static List<int> _buildSharedStringsXml(List<String> uniqueSiXml) {
    final count = uniqueSiXml.length;
    final buffer =
        StringBuffer()
          ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
          ..write(
            '<sst xmlns="$_spreadsheetNs" count="$count" uniqueCount="$count">',
          );
    for (final si in uniqueSiXml) {
      buffer.write(si);
    }
    buffer.write('</sst>');
    return utf8.encode(buffer.toString());
  }

  static bool _isWorksheetXml(String name) {
    return name.startsWith('xl/worksheets/') &&
        name.endsWith('.xml') &&
        !name.contains('_rels');
  }

  /// 시트의 `t="s"` 셀 `<v>` 인덱스를 XML 파서로 재매핑 (정규식보다 안전)
  static String _remapWorksheetSharedStringIndices(
    String sheetXml,
    Map<int, int> oldToNew,
  ) {
    final doc = XmlDocument.parse(sheetXml);
    var changed = 0;

    for (final cell in doc.findAllElements('c')) {
      if (cell.getAttribute('t') != 's') continue;

      // <v> 직접 자식만 대상 (수식 결과 등)
      for (final vNode in cell.childElements) {
        if (vNode.localName != 'v') continue;
        final raw = vNode.innerText.trim();
        final oldIndex = int.tryParse(raw);
        if (oldIndex == null) continue;

        final newIndex = oldToNew[oldIndex];
        if (newIndex == null || newIndex == oldIndex) continue;

        // 텍스트 노드 교체
        vNode.children.clear();
        vNode.children.add(XmlText('$newIndex'));
        changed++;
      }
    }

    developer.log('시트 sharedString 인덱스 재매핑: $changed개 셀', name: _logName);
    return doc.toXmlString(pretty: false);
  }
}
