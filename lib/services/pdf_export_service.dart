import 'dart:io';
import 'dart:developer' as developer;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../providers/substitution_plan_viewmodel.dart';
import '../utils/pdf_field_config.dart';

/// PDF 내보내기 서비스
/// - 선택된 PDF 템플릿에 교체 데이터를 채워서 출력합니다.
class PdfExportService {
  /// PDF 필드의 기본 폰트 크기 (pt 단위)
  /// 템플릿의 폰트 크기를 읽는 것이 지원되지 않으므로 이 상수를 사용합니다.
  static const double defaultFontSize = 10.0;
  
  /// 비고(remarks) 필드의 폰트 크기 (pt 단위)
  /// 비고 필드는 텍스트가 길 수 있으므로 더 작은 폰트 사이즈를 사용합니다.
  static const double remarksFontSize = 7.0;

  /// 한글 폰트 로드 (로컬 파일)
  /// 로컬 폰트 파일이 있으면 사용, 없으면 null 반환
  /// [fontSize] 폰트 크기 (기본값: defaultFontSize 상수 사용)
  static Future<PdfFont?> _loadKoreanFont({double fontSize = defaultFontSize}) async {
    try {
      // 로컬 폰트 파일 확인 (우선순위대로)
      final commonFontPaths = [
        'C:\\Windows\\Fonts\\Hamchoromantic.ttf',  // 함초롱바탕 (정확한 이름)
        'C:\\Windows\\Fonts\\HCRBatang.ttf',       // 함초롱 바탕
        'C:\\Windows\\Fonts\\hcrbatang.ttf',       // 함초롱 바탕 (소문자)
        'C:\\Windows\\Fonts\\HCRBATANG.TTF',       // 함초롱 바탕 (대문자)
        'C:\\Windows\\Fonts\\batang.ttc',          // 바탕 (TrueType Collection)
        'C:\\Windows\\Fonts\\malgun.ttf',          // 맑은 고딕
        'C:\\Windows\\Fonts\\gulim.ttc',          // 굴림
        'C:\\Windows\\Fonts\\NotoSansKR-Regular.ttf',
      ];
      
      developer.log('한글 폰트 검색 시작 (폰트 크기: ${fontSize}pt)');
      
      for (String fontPath in commonFontPaths) {
        try {
          final fontFile = File(fontPath);
          if (await fontFile.exists()) {
            final fontBytes = await fontFile.readAsBytes();
            developer.log('✓ 한글 폰트 로드 성공: $fontPath (${fontBytes.length} bytes, 크기: ${fontSize}pt)');
            return PdfTrueTypeFont(fontBytes, fontSize);
          } else {
            developer.log('→ 폰트 파일 없음: $fontPath');
          }
        } catch (e) {
          developer.log('✗ 폰트 확인 실패 ($fontPath): $e');
          continue;
        }
      }
      
      developer.log('✗ 한글 폰트를 찾지 못했습니다. (시도한 경로: ${commonFontPaths.length}개)');
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
  /// 
  /// Returns: 성공 시 true
  static Future<bool> exportSubstitutionPlan({
    required List<SubstitutionPlanData> planData,
    required String templatePath,
    required String outputPath,
  }) async {
    try {
      // 1) 템플릿 PDF 파일 존재 확인
      final templateFile = File(templatePath);
      if (!await templateFile.exists()) {
          throw FileSystemException('템플릿 파일을 찾을 수 없습니다: $templatePath');
      }

      developer.log('템플릿 로드 시작: $templatePath');

      // 2) 템플릿 PDF 로드
      final PdfDocument document = PdfDocument(
        inputBytes: await templateFile.readAsBytes(),
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
                double fieldFontSize = columnKey == 'remarks' ? remarksFontSize : defaultFontSize;
                
                // 해당 사이즈로 폰트 로드
                final fontForField = await _loadKoreanFont(fontSize: fieldFontSize);
                
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
                double fieldFontSize = defaultFontSize;
                
                // 해당 사이즈로 폰트 로드
                final fontForField = await _loadKoreanFont(fontSize: fieldFontSize);
                
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
      final templateFile = File(templatePath);
      if (!await templateFile.exists()) {
        throw FileSystemException('템플릿 파일을 찾을 수 없습니다: $templatePath');
      }

      final PdfDocument document = PdfDocument(
        inputBytes: await templateFile.readAsBytes(),
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
