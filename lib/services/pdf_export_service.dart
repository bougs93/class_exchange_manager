import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/pdf_field_config.dart';
import '../constants/korean_fonts.dart';

/// PDF 내보내기 서비스
/// - 선택된 PDF 템플릿에 교체 데이터를 채워서 출력합니다.
class PdfExportService {
  /// PDF 필드의 기본 폰트 크기 (pt 단위)
  /// 템플릿의 폰트 크기를 읽는 것이 지원되지 않으므로 이 상수를 사용합니다.
  static const double defaultFontSize = 10.0;
  
  /// 비고(remarks) 필드의 폰트 크기 (pt 단위)
  /// 비고 필드는 텍스트가 길 수 있으므로 더 작은 폰트 사이즈를 사용합니다.
  static const double remarksFontSize = 7.0;

  /// 윈도우 Fonts 폴더에서 사용 가능한 모든 폰트 파일 목록 가져오기
  /// Returns: 폰트 파일명 리스트 (확장자 포함)
  static Future<List<String>> getAvailableFonts() async {
    try {
      final fontsDir = Directory('C:\\Windows\\Fonts');
      
      if (!await fontsDir.exists()) {
        developer.log('Windows Fonts 폴더를 찾을 수 없습니다.');
        return _getDefaultFonts();
      }
      
      final fontFiles = fontsDir.listSync()
          .whereType<File>()
          .map((entity) => entity.path.split(Platform.pathSeparator).last)
          .where((filename) => filename.toLowerCase().endsWith('.ttf') || 
                                filename.toLowerCase().endsWith('.ttc'))
          .toList();
      
      developer.log('사용 가능한 폰트 파일: ${fontFiles.length}개');
      
      if (fontFiles.isEmpty) {
        return _getDefaultFonts();
      }
      
      // 파일명 순서로 정렬
      fontFiles.sort();
      
      return fontFiles;
    } catch (e) {
      developer.log('폰트 목록 가져오기 오류: $e');
      return _getDefaultFonts();
    }
  }
  
  /// 기본 폰트 목록 (오류 시 사용)
  static List<String> _getDefaultFonts() {
    return KoreanFontConstants.fontFiles;
  }

  /// Fallback 한글 폰트 찾기
  /// 지정된 폰트를 찾지 못했을 때 실제 Windows Fonts 폴더에서 
  /// 사용 가능한 한글 폰트를 자동으로 찾아서 반환합니다.
  /// [fontSize] 폰트 크기
  static Future<PdfFont?> _findFallbackKoreanFont(double fontSize) async {
    try {
      final fontsDir = Directory('C:\\Windows\\Fonts');
      if (!await fontsDir.exists()) {
        developer.log('Windows Fonts 폴더를 찾을 수 없습니다.');
        return null;
      }

      // 한글 폰트로 알려진 일반적인 폰트 파일명 패턴들
      // 우선순위 순으로 정렬 (자주 사용되는 폰트 먼저)
      // 참고: Windows에서는 파일명이 대소문자를 구분하지 않지만, 실제 파일명은 다양할 수 있습니다.
      final List<String> koreanFontPatterns = [
        'malgun',        // 맑은 고딕 (가장 일반적) - 정확한 파일명: malgun.ttf
        'gulim',         // 굴림 - 정확한 파일명: gulim.ttc (TrueType Collection)
        'batang',        // 바탕 - 정확한 파일명: batang.ttc, batangche.ttc (바탕체)
        'dotum',         // 돋움 - 정확한 파일명: dotum.ttc, dotumche.ttc (돋움체)
        'gungsuh',       // 궁서 - 정확한 파일명: gungsuh.ttc, gungsuhche.ttc (궁서체)
      ];

      // 실제 폰트 파일 목록 가져오기 (한 번만 호출하여 성능 최적화)
      final allFontFiles = fontsDir.listSync()
          .whereType<File>()
          .toList();

      // 파일명을 소문자로 변환한 매핑 생성 (대소문자 무시 검색용)
      final fontFileMap = <String, File>{};
      for (File fontFile in allFontFiles) {
        final fileName = fontFile.path.split(Platform.pathSeparator).last.toLowerCase();
        if ((fileName.endsWith('.ttf') || fileName.endsWith('.ttc')) &&
            !fontFileMap.containsKey(fileName)) {
          fontFileMap[fileName] = fontFile;
        }
      }

      developer.log('Fallback 검색: 총 ${fontFileMap.length}개의 폰트 파일 발견');
      
      // 디버깅: 한글 폰트로 추정되는 파일 목록 출력 (처음 20개만)
      final koreanFontCandidates = fontFileMap.keys
          .where((name) => koreanFontPatterns.any((pattern) => name.contains(pattern.toLowerCase())))
          .take(20)
          .toList();
      if (koreanFontCandidates.isNotEmpty) {
        developer.log('한글 폰트 후보 (처음 20개): ${koreanFontCandidates.join(", ")}');
      }

      // 우선순위에 따라 폰트 검색
      // 정확한 파일명 매칭을 우선 시도하고, 실패하면 패턴 매칭 시도
      for (String pattern in koreanFontPatterns) {
        final patternLower = pattern.toLowerCase();
        
        // 1단계: 정확한 파일명 매칭 (예: malgun.ttf, gulim.ttc)
        // 확장자 변형도 시도 (.ttf와 .ttc 모두)
        final exactMatches = [
          '$patternLower.ttf',
          '$patternLower.ttc',
        ];
        
        for (String exactMatch in exactMatches) {
          if (fontFileMap.containsKey(exactMatch)) {
            try {
              final fontFile = fontFileMap[exactMatch]!;
              final fontBytes = await fontFile.readAsBytes();
              final actualFileName = fontFile.path.split(Platform.pathSeparator).last;
              developer.log('✓ Fallback 폰트 발견 (정확한 매칭): $actualFileName (패턴: $pattern)');
              return PdfTrueTypeFont(fontBytes, fontSize);
            } catch (e) {
              developer.log('✗ Fallback 폰트 로드 실패 ($exactMatch): $e');
            }
          }
        }
        
        // 2단계: 파일명이 패턴으로 시작하는 경우 (예: malgunbd.ttf -> malgun으로 시작)
        for (String fileName in fontFileMap.keys) {
          if (fileName.startsWith(patternLower) && 
              (fileName.endsWith('.ttf') || fileName.endsWith('.ttc'))) {
            try {
              final fontFile = fontFileMap[fileName]!;
              final fontBytes = await fontFile.readAsBytes();
              final actualFileName = fontFile.path.split(Platform.pathSeparator).last;
              developer.log('✓ Fallback 폰트 발견 (시작 매칭): $actualFileName (패턴: $pattern)');
              return PdfTrueTypeFont(fontBytes, fontSize);
            } catch (e) {
              developer.log('✗ Fallback 폰트 로드 실패 ($fileName): $e');
              continue;
            }
          }
        }
        
        // 3단계: 파일명에 패턴이 포함되어 있는지 확인 (가장 넓은 범위)
        for (String fileName in fontFileMap.keys) {
          if (fileName.contains(patternLower)) {
            try {
              final fontFile = fontFileMap[fileName]!;
              final fontBytes = await fontFile.readAsBytes();
              final actualFileName = fontFile.path.split(Platform.pathSeparator).last;
              developer.log('✓ Fallback 폰트 발견 (포함 매칭): $actualFileName (패턴: $pattern)');
              return PdfTrueTypeFont(fontBytes, fontSize);
            } catch (e) {
              developer.log('✗ Fallback 폰트 로드 실패 ($fileName): $e');
              continue;
            }
          }
        }
      }

      // 패턴 매칭으로 찾지 못한 경우, 첫 번째 사용 가능한 폰트 시도
      developer.log('패턴 매칭 실패, 첫 번째 사용 가능한 폰트 시도 중...');
      for (String fileName in fontFileMap.keys.take(10)) {
        try {
          final fontFile = fontFileMap[fileName]!;
          final fontBytes = await fontFile.readAsBytes();
          final actualFileName = fontFile.path.split(Platform.pathSeparator).last;
          developer.log('✓ Fallback 폰트 발견 (임의): $actualFileName');
          return PdfTrueTypeFont(fontBytes, fontSize);
        } catch (e) {
          continue;
        }
      }

      developer.log('✗ Fallback 한글 폰트를 찾지 못했습니다.');
      return null;
    } catch (e) {
      developer.log('Fallback 한글 폰트 검색 중 오류: $e');
      return null;
    }
  }

  /// 한글 폰트 로드
  /// 1. 에셋 폰트 우선 사용 (배포된 앱에서 안정적)
  /// 2. 로컬 시스템 폰트 폴백 (개발/테스트용)
  /// [fontSize] 폰트 크기 (기본값: defaultFontSize 상수 사용)
  /// [fontType] 폰트 종류 (null이면 자동 선택)
  static Future<PdfFont?> _loadKoreanFont({
    double fontSize = defaultFontSize,
    String? fontType,
  }) async {
    try {
      developer.log('한글 폰트 검색 시작 (폰트 크기: ${fontSize}pt, 폰트 종류: ${fontType ?? "자동"})');
      developer.log('Windows 시스템 폰트 사용 (C:\\Windows\\Fonts\\)');
      
      // Windows 시스템 폰트 사용
      List<String> commonFontPaths;
      
      if (fontType != null) {
        // 폰트 파일명이 직접 지정된 경우 (예: "malgun.ttf", "HCRBatang.ttf")
        if (fontType.endsWith('.ttf') || fontType.endsWith('.ttc')) {
          // 파일명의 다양한 변형 시도 (대소문자, 확장자 등)
          final baseName = fontType.substring(0, fontType.lastIndexOf('.'));
          final ext = fontType.substring(fontType.lastIndexOf('.'));
          
          commonFontPaths = [
            // 원본 파일명 (정확한 대소문자)
            'C:\\Windows\\Fonts\\$fontType',
            // 소문자 변형
            'C:\\Windows\\Fonts\\${baseName.toLowerCase()}$ext',
            // 대문자 변형
            'C:\\Windows\\Fonts\\${baseName.toUpperCase()}$ext',
            // 첫 글자만 대문자
            'C:\\Windows\\Fonts\\${baseName[0].toUpperCase()}${baseName.substring(1).toLowerCase()}$ext',
          ];
          
          // 확장자 변형도 시도 (.ttf <-> .ttc)
          if (ext == '.ttf') {
            commonFontPaths.addAll([
              'C:\\Windows\\Fonts\\$baseName.ttc',
              'C:\\Windows\\Fonts\\${baseName.toLowerCase()}.ttc',
              'C:\\Windows\\Fonts\\${baseName.toUpperCase()}.ttc',
            ]);
          } else if (ext == '.ttc') {
            commonFontPaths.addAll([
              'C:\\Windows\\Fonts\\$baseName.ttf',
              'C:\\Windows\\Fonts\\${baseName.toLowerCase()}.ttf',
              'C:\\Windows\\Fonts\\${baseName.toUpperCase()}.ttf',
            ]);
          }
          
          // 실제 Fonts 폴더에서 파일 검색 시도
          try {
            final fontsDir = Directory('C:\\Windows\\Fonts');
            if (await fontsDir.exists()) {
              final files = fontsDir.listSync()
                  .whereType<File>()
                  .map((entity) => entity.path)
                  .where((path) {
                    final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
                    final searchName = baseName.toLowerCase();
                    return fileName.startsWith(searchName) && 
                           (fileName.endsWith('.ttf') || fileName.endsWith('.ttc'));
                  })
                  .take(5) // 최대 5개만
                  .toList();
              
              if (files.isNotEmpty) {
                // 실제로 찾은 파일들을 맨 앞에 추가
                commonFontPaths = [...files, ...commonFontPaths];
                developer.log('실제 폰트 파일 발견: ${files.length}개');
              }
            }
          } catch (e) {
            developer.log('폰트 폴더 검색 실패: $e');
          }
        } else {
          // 폰트 종류가 지정되었지만 정확한 파일명이 아닌 경우
          // Windows 시스템 기본 폰트 검색
          commonFontPaths = KoreanFontConstants.getWindowsFontPaths();
        }
      } else {
        // 폰트 종류가 지정되지 않으면 모든 폰트 검색
        commonFontPaths = KoreanFontConstants.getWindowsFontPaths();
      }
      
      for (String fontPath in commonFontPaths) {
        try {
          final fontFile = File(fontPath);
          if (await fontFile.exists()) {
            final fontBytes = await fontFile.readAsBytes();
            developer.log('✓ 로컬 한글 폰트 로드 성공: $fontPath (${fontBytes.length} bytes, 크기: ${fontSize}pt)');
            return PdfTrueTypeFont(fontBytes, fontSize);
          } else {
            developer.log('→ 폰트 파일 없음: $fontPath');
          }
        } catch (e) {
          developer.log('✗ 폰트 확인 실패 ($fontPath): $e');
          continue;
        }
      }
      
      // 지정된 폰트를 찾지 못한 경우, 실제 존재하는 한글 폰트 자동 탐색
      developer.log('지정된 폰트를 찾지 못했습니다. 사용 가능한 한글 폰트 자동 탐색 중...');
      final fallbackFont = await _findFallbackKoreanFont(fontSize);
      if (fallbackFont != null) {
        developer.log('✓ Fallback 한글 폰트 로드 성공 (크기: ${fontSize}pt)');
        return fallbackFont;
      }
      
      developer.log('✗ 한글 폰트를 찾지 못했습니다. 한글 텍스트가 표시되지 않을 수 있습니다.');
      return null;
    } catch (e) {
      developer.log('한글 폰트 로드 중 오류: $e');
      return null;
    }
  }

  /// 결보강 계획서 PDF 내보내기
  /// 
  /// [planData] 교체 데이터 목록
  /// [templatePath] 사용자 선택 PDF 템플릿 경로(파일 시스템 경로 또는 에셋 경로)
  /// [outputPath] 생성될 PDF 파일의 저장 경로
  /// [fontSize] 폰트 크기 (기본값: defaultFontSize)
  /// [remarksFontSize] 비고 필드 폰트 크기 (기본값: remarksFontSize)
  /// [fontType] 폰트 종류 (Windows 시스템 폰트 파일명: malgun.ttf, malgunbd.ttf, gulim.ttc, batang.ttc, dotum.ttc, gungsuh.ttc)
  /// [includeRemarks] 비고 필드 출력 여부 (기본값: true)
  /// [additionalFields] 추가 필드 데이터 (teacherName, absencePeriod, workStatus, reasonForAbsence, notes, schoolName)
  /// 
  /// Returns: 성공 시 true
  static Future<bool> exportSubstitutionPlan({
    required List<SubstitutionPlanData> planData,
    required String templatePath,
    required String outputPath,
    double? fontSize,
    double? remarksFontSize,
    String? fontType,
    bool includeRemarks = true,
    Map<String, String>? additionalFields,
  }) async {
    try {
      // 폰트 캐시 (동일한 폰트를 반복 로드하지 않도록)
      final Map<String, PdfFont> fontCache = {};
      
      // 1) 템플릿 PDF 파일 로드
      // 에셋 경로인지 파일 시스템 경로인지 구분하여 처리
      List<int> templateBytes;
      
      // 에셋 경로 판단: 'assets/' 또는 'lib/assets/'로 시작하는 경우
      if (templatePath.startsWith('assets/') || templatePath.startsWith('lib/assets/')) {
        // 에셋 경로인 경우: rootBundle을 사용하여 로드
        // 참고: Flutter에서 에셋 파일은 pubspec.yaml에 등록되어 있어야 합니다.
        try {
          developer.log('템플릿 에셋 로드 시작: $templatePath');
          final assetData = await rootBundle.load(templatePath);
          templateBytes = assetData.buffer.asUint8List();
          developer.log('템플릿 에셋 로드 성공: ${templateBytes.length} bytes');
        } catch (e) {
          throw FileSystemException('에셋 템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
      } else {
        // 파일 시스템 경로인 경우: File을 사용하여 로드
        final templateFile = File(templatePath);
        if (!await templateFile.exists()) {
          throw FileSystemException('템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
        developer.log('템플릿 파일 로드 시작: $templatePath');
        templateBytes = await templateFile.readAsBytes();
        developer.log('템플릿 파일 로드 성공: ${templateBytes.length} bytes');
      }

      // 2) 템플릿 PDF 로드
      final PdfDocument document = PdfDocument(
        inputBytes: templateBytes,
      );

      // 3) 폼 필드 접근
      final PdfForm form = document.form;
      developer.log('폼 필드 개수: ${form.fields.count}');

      // 4) 데이터를 폼 필드에 채우기
      int successCount = 0;
      int failCount = 0;
      
      // 각 데이터 행에 대해 필드 이름 생성 및 채우기
      for (int rowIndex = 0; rowIndex < planData.length; rowIndex++) {
        final data = planData[rowIndex];
        
        // 각 컬럼 키에 대해 필드 이름 생성 (예: date.0, date.1, ...)
        for (String columnKey in kPdfTableColumns) {
          // 비고 필드 출력 여부 확인
          if (columnKey == 'remarks' && !includeRemarks) {
            // 비고 출력이 비활성화된 경우 건너뛰기
            continue;
          }
          
          // 필드 이름 생성: {컬럼키}.{행인덱스}
          final String fieldName = '$columnKey.$rowIndex';
          
          // 데이터 매핑
          String? value = _getFieldValue(data, columnKey);
          
          if (value != null && value.isNotEmpty) {
            // 해당 이름의 폼 필드 찾기 (인덱스로 접근)
            bool found = false;
            for (int i = 0; i < form.fields.count; i++) {
              final field = form.fields[i];
              if (field is PdfTextBoxField && field.name == fieldName) {
                // 필드의 기존 폰트 크기 정보 추출 시도
                // 참고: 템플릿의 폰트 크기를 읽는 것이 지원되지 않으므로 기본값 사용
                // 실제 폰트 크기는 템플릿 PDF 파일에 정의된 대로 유지됩니다
                // 비고(remarks) 필드는 더 작은 폰트 사이즈 사용
                double fieldFontSize = columnKey == 'remarks' 
                  ? (remarksFontSize ?? PdfExportService.remarksFontSize)
                  : (fontSize ?? PdfExportService.defaultFontSize);
                
                // 폰트 캐시 키 생성 (폰트타입_폰트사이즈)
                final fontCacheKey = '${fontType ?? "default"}_$fieldFontSize';
                
                // 캐시에서 폰트 가져오기 또는 새로 로드
                PdfFont? fontForField = fontCache[fontCacheKey];
                if (fontForField == null) {
                  fontForField = await _loadKoreanFont(
                    fontSize: fieldFontSize,
                    fontType: fontType,
                  );
                  if (fontForField != null) {
                    fontCache[fontCacheKey] = fontForField;
                    developer.log('폰트 캐시에 저장: $fontCacheKey');
                  }
                } else {
                  developer.log('폰트 캐시에서 재사용: $fontCacheKey');
                }
                
                // 필드에 값 채우기 전에 한글 폰트 먼저 설정
                if (fontForField != null) {
                  try {
                    // 폰트 설정 후 텍스트 설정
                    field.font = fontForField;
                    field.text = value;
                    developer.log('필드 채웠음 (한글폰트 적용): $fieldName = $value');
                  } catch (e) {
                    developer.log('폰트 설정 실패, 기본 폰트로 시도: $fieldName - $e');
                    field.text = value; // 폰트 설정 실패해도 텍스트는 입력
                  }
                } else {
                  // 한글 폰트를 찾지 못한 경우
                  developer.log('한글 폰트를 찾지 못함, 기본 폰트로 진행: $fieldName');
                  field.text = value;
                }
                successCount++;
                found = true;
                break;
              }
            }
            
            if (!found) {
              developer.log('필드를 찾지 못함: $fieldName');
              failCount++;
            }
          }
        }
        
        // 복합 필드 처리 (예: date(day), 3date(3day))
        for (String compositeField in kPdfCompositeFieldBases) {
          final String fieldName = '$compositeField.$rowIndex';
          final List<String> componentFields = kPdfCompositeFieldMapping[compositeField] ?? [];
          
          if (componentFields.isEmpty) {
            developer.log('복합 필드 분석 실패: $compositeField');
            continue;
          }
          
          // 개별 필드 값들을 수집
          List<String> values = [];
          for (String component in componentFields) {
            String? value = _getFieldValue(data, component);
            if (value != null && value.isNotEmpty) {
              values.add(value);
            }
          }
          
          if (values.isNotEmpty) {
            // 복합 필드가 존재하는지 확인
            bool found = false;
            for (int i = 0; i < form.fields.count; i++) {
              final field = form.fields[i];
              if (field is PdfTextBoxField && field.name == fieldName) {
                // 필드의 기존 폰트 크기 정보 추출 시도
                // 참고: 템플릿의 폰트 크기를 읽는 것이 지원되지 않으므로 기본값 사용
                // 실제 폰트 크기는 템플릿 PDF 파일에 정의된 대로 유지됩니다
                double fieldFontSize = fontSize ?? PdfExportService.defaultFontSize;
                
                // 해당 사이즈로 폰트 로드
                final fontForField = await _loadKoreanFont(
                  fontSize: fieldFontSize,
                  fontType: fontType,
                );
                
                // 복합 필드 포맷팅: date(day) 형식으로 입력
                final formattedValue = formatCompositeFieldValue(compositeField, values);
                
                // 한글 폰트 먼저 설정 (텍스트 설정 전에)
                if (fontForField != null) {
                  try {
                    // 폰트 설정 후 텍스트 설정
                    field.font = fontForField;
                    field.text = formattedValue;
                    developer.log('복합 필드 채웠음 (한글폰트 적용): $fieldName = $formattedValue');
                  } catch (e) {
                    developer.log('복합 필드 폰트 설정 실패, 기본 폰트로 시도: $fieldName - $e');
                    field.text = formattedValue; // 폰트 설정 실패해도 텍스트는 입력
                  }
                } else {
                  // 한글 폰트를 찾지 못한 경우
                  developer.log('한글 폰트를 찾지 못함, 기본 폰트로 진행: $fieldName');
                  field.text = formattedValue;
                }
                successCount++;
                found = true;
                break;
              }
            }
            
            if (!found) {
              developer.log('복합 필드를 찾지 못함: $fieldName');
              failCount++;
            }
          }
        }
      }

      developer.log('필드 채우기 완료: 성공 $successCount, 실패 $failCount');

      // 4-1) 추가 필드 채우기
      if (additionalFields != null && additionalFields.isNotEmpty) {
        developer.log('추가 필드 채우기 시작: ${additionalFields.length}개');
        
        for (final entry in additionalFields.entries) {
          final fieldName = entry.key;
          final fieldValue = entry.value;
          
          // 빈 값은 건너뛰기
          if (fieldValue.isEmpty) continue;
          
          try {
            // 필드 찾기
            PdfField? targetField;
            for (int i = 0; i < form.fields.count; i++) {
              final field = form.fields[i];
              if (field.name == fieldName) {
                targetField = field;
                break;
              }
            }
            
            if (targetField == null) {
              developer.log('추가 필드를 찾을 수 없음: $fieldName');
              failCount++;
              continue;
            }
            
            if (targetField is PdfTextBoxField) {
              // 학교명 필드는 20pt, 나머지는 기본 폰트 크기 사용
              final fieldFontSize = fieldName == 'schoolName' ? 20.0 : (fontSize ?? defaultFontSize);
              
              // 폰트 캐시 키 생성 (폰트타입_폰트사이즈)
              final fontCacheKey = '${fontType ?? "default"}_$fieldFontSize';
              
              // 캐시에서 폰트 가져오기 또는 새로 로드
              PdfFont? koreanFont = fontCache[fontCacheKey];
              if (koreanFont == null) {
                koreanFont = await _loadKoreanFont(
                  fontSize: fieldFontSize,
                  fontType: fontType,
                );
                if (koreanFont != null) {
                  fontCache[fontCacheKey] = koreanFont;
                  developer.log('폰트 캐시에 저장: $fontCacheKey');
                }
              } else {
                developer.log('폰트 캐시에서 재사용: $fontCacheKey');
              }
              
              if (koreanFont != null) {
                targetField.font = koreanFont;
              }
              
              // 필드 값 설정
              targetField.text = fieldValue;
              developer.log('추가 필드 채웠음: $fieldName = $fieldValue (폰트 크기: ${fieldFontSize}pt)');
              successCount++;
            }
          } catch (e) {
            developer.log('추가 필드 채우기 실패 ($fieldName): $e');
            failCount++;
          }
        }
        
        developer.log('추가 필드 채우기 완료');
      }

      // 5) 폼 필드 플래튼 (편집 불가능하게 만듦)
      try {
        form.flattenAllFields();
        developer.log('폼 필드 평탄화 완료');
      } catch (e) {
        developer.log('폼 필드 평탄화 중 오류: $e');
      }

      // 6) PDF 저장
      final file = File(outputPath);
      final List<int> bytes = await document.save();
      await file.writeAsBytes(bytes);
      developer.log('PDF 저장 완료: $outputPath (${bytes.length} bytes)');

      // 7) 문서 닫기
      document.dispose();

      return true;
    } catch (e) {
      developer.log('PDF 내보내기 오류: $e');
      return false;
    }
  }

  /// 컬럼 키에 해당하는 값을 데이터에서 가져오기
  /// [data] 교체 데이터
  /// [columnKey] 컬럼 키 (kPdfTableColumns에 정의된 키)
  /// Returns: 필드 값 또는 null
  static String? _getFieldValue(SubstitutionPlanData data, String columnKey) {
    switch (columnKey) {
      case 'date':
        return data.absenceDate;
      case 'day':
        return data.absenceDay;
      case 'period':
        return data.period;
      case 'grade':
        return data.grade;
      case 'class':
        return data.className;
      case 'subject':
        return data.subject;
      case 'teacher':
        return data.teacher;
      case '2subject':
        return data.supplementSubject;
      case '2teacher':
        return data.supplementTeacher;
      case '3date':
        return data.substitutionDate;
      case '3day':
        return data.substitutionDay;
      case '3period':
        return data.substitutionPeriod;
      case '3subject':
        return data.substitutionSubject;
      case '3teacher':
        return data.substitutionTeacher;
      case 'remarks':
        return data.remarks;
      default:
        return null;
    }
  }

  /// 템플릿의 모든 폼 필드 정보 출력 (디버깅용)
  /// 선택한 PDF 템플릿의 폼 필드 이름과 상세 정보를 확인할 때 사용합니다.
  static Future<Map<String, dynamic>> getTemplateFieldInfo(String templatePath) async {
    try {
      // 에셋 경로인지 파일 시스템 경로인지 구분하여 처리
      List<int> templateBytes;
      
      // 에셋 경로 판단: 'assets/' 또는 'lib/assets/'로 시작하는 경우
      if (templatePath.startsWith('assets/') || templatePath.startsWith('lib/assets/')) {
        // 에셋 경로인 경우: rootBundle을 사용하여 로드
        try {
          developer.log('템플릿 에셋 로드 시작 (필드 정보 읽기): $templatePath');
          final assetData = await rootBundle.load(templatePath);
          templateBytes = assetData.buffer.asUint8List();
          developer.log('템플릿 에셋 로드 성공 (필드 정보 읽기): ${templateBytes.length} bytes');
        } catch (e) {
          throw FileSystemException('에셋 템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
      } else {
        // 파일 시스템 경로인 경우: File을 사용하여 로드
        final templateFile = File(templatePath);
        if (!await templateFile.exists()) {
          throw FileSystemException('템플릿 파일을 찾을 수 없습니다: $templatePath', '');
        }
        developer.log('템플릿 파일 로드 시작 (필드 정보 읽기): $templatePath');
        templateBytes = await templateFile.readAsBytes();
        developer.log('템플릿 파일 로드 성공 (필드 정보 읽기): ${templateBytes.length} bytes');
      }

      final PdfDocument document = PdfDocument(
        inputBytes: templateBytes,
      );

      final Map<String, dynamic> info = {
        'totalFields': document.form.fields.count,
        'fields': <Map<String, String>>[]
      };
      
      for (int i = 0; i < document.form.fields.count; i++) {
        final field = document.form.fields[i];
        
        final fieldInfo = {
          'index': '$i',
          'name': field.name ?? '(unnamed)',
          'type': field.runtimeType.toString(),
          'value': (field is PdfTextBoxField) ? field.text : '(N/A)',
        };
        
        (info['fields'] as List).add(fieldInfo);
        developer.log('필드 $i: ${fieldInfo['name']} (${fieldInfo['type']}) = ${fieldInfo['value']}');
      }

      document.dispose();
      return info;
    } catch (e) {
      developer.log('템플릿 필드 정보 읽기 오류: $e');
      return {'error': e.toString()};
    }
  }
}
