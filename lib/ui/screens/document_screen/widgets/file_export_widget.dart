import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:printing/printing.dart';
import '../../../../providers/substitution_plan_viewmodel.dart';
import '../../../../utils/pdf_field_config.dart';
import '../../../../services/pdf_export_service.dart';

/// 파일 출력 위젯
/// 
/// 결보강 계획서를 PDF 형식으로 미리보고 저장할 수 있는 위젯입니다.
class FileExportWidget extends ConsumerStatefulWidget {
  const FileExportWidget({super.key});

  @override
  ConsumerState<FileExportWidget> createState() => _FileExportWidgetState();
}

class _FileExportWidgetState extends ConsumerState<FileExportWidget> {
  // 현재 선택된 PDF 템플릿 인덱스 (기본: 첫 번째)
  int _selectedTemplateIndex = 0;
  // 사용자가 직접 선택한 PDF 템플릿 파일 경로(있으면 이것을 우선 사용)
  String? _selectedTemplateFilePath;
  // 폰트 사이즈 설정
  double _fontSize = 10.0;
  double _remarksFontSize = 7.0;
  
  // 폰트 종류 설정
  String _selectedFont = 'malgun.ttf';
  
  // 사용 가능한 폰트 사이즈 옵션
  final List<double> _fontSizeOptions = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0];
  final List<double> _remarksFontSizeOptions = [6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0];
  
  // Windows 시스템 폰트 목록 (정확한 파일명)
  // 위치: C:\Windows\Fonts\
  final List<Map<String, String>> _fontList = [
    {'file': 'malgun.ttf', 'name': '맑은 고딕'},
    {'file': 'malgunbd.ttf', 'name': '맑은 고딕 Bold'},
    {'file': 'gulim.ttc', 'name': '굴림'},
    {'file': 'batang.ttc', 'name': '바탕'},
    {'file': 'dotum.ttc', 'name': '돋움'},
    {'file': 'gungsuh.ttc', 'name': '궁서'},
    {'file': 'hanbatang.ttf', 'name': '한바탕'},
    {'file': 'handotum.ttf', 'name': '한돋움'},
    {'file': 'hansantteutdotum-regular.ttf', 'name': '한산뜻돋움'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // PDF 양식 파일 선택 (드롭다운 + 파일 선택 버튼 통합)
          _buildTemplateSelector(),
          
          const SizedBox(height: 15),
          
          // 폰트 사이즈 설정
          _buildFontSizeSettings(),
          
          const SizedBox(height: 15),
          
          // 문서 출력 버튼
          _buildDocumentOutputButton(),
          
        ],
      ),
    );
  }

  /// PDF 양식 파일 선택 드롭다운 및 파일 선택 버튼
  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        Text(
          '양식 PDF 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        // 드롭다운과 버튼을 같은 row에 배치
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 드롭다운
            Expanded(
              child: Container(
                height: 37,  // 버튼 높이와 동일하게 설정
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerLeft,  // 내부 정렬
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _getCurrentSelectedIndex(),
                  underline: const SizedBox.shrink(),
                  iconSize: 24,  // 드롭다운 아이콘 크기
                  isDense: false,  // 컴팩트 모드 해제하여 높이 확보
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                  ),
                  items: _buildDropdownItems(),
                  onChanged: (int? newIndex) {
                    if (newIndex == null) return;
                    setState(() {
                      // 기본 템플릿 선택 (인덱스가 kPdfTemplates.length보다 작은 경우)
                      if (newIndex < kPdfTemplates.length) {
                        _selectedTemplateIndex = newIndex;
                        _selectedTemplateFilePath = null;  // 사용자 파일 선택 초기화
                      } else {
                        // 사용자 선택 파일 선택 (인덱스가 kPdfTemplates.length와 같은 경우)
                        // 이미 _selectedTemplateFilePath가 설정되어 있으므로 유지
                        // _selectedTemplateIndex는 그대로 유지 (기본 양식 인덱스로 표시 용도)
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 내 컴퓨터에서 PDF 선택 버튼
            OutlinedButton.icon(
              onPressed: _pickPdfTemplate,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text(
                '내 컴퓨터에서 PDF 선택',
                style: TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 45),  // 높이 고정
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        // 사용자가 직접 파일을 선택한 경우에만 파일 경로 표시
        if (_selectedTemplateFilePath != null) ...[
          const SizedBox(height: 2),
          Text(
            _selectedTemplateFilePath!,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            '사용자 선택 파일이 우선 적용됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
          ),
        ],
      ],
    );
  }


  /// 드롭다운에 표시할 항목 목록 생성
  /// 기본 템플릿들과 사용자 선택 파일(있는 경우)을 포함합니다.
  List<DropdownMenuItem<int>> _buildDropdownItems() {
    final items = <DropdownMenuItem<int>>[];
    
    // 기본 템플릿들 추가
    for (int i = 0; i < kPdfTemplates.length; i++) {
      items.add(
        DropdownMenuItem<int>(
          value: i,
          child: Text(
            kPdfTemplates[i].name,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    
    // 사용자가 파일을 선택한 경우 드롭다운에 추가
    if (_selectedTemplateFilePath != null) {
      // 파일명만 추출 (전체 경로에서 파일명만)
      final fileName = _selectedTemplateFilePath!.split(Platform.pathSeparator).last;
      items.add(
        DropdownMenuItem<int>(
          value: kPdfTemplates.length,  // 마지막 인덱스로 사용자 파일 표시
          child: Text(
            fileName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    
    return items;
  }
  
  /// 현재 드롭다운에서 선택되어야 할 인덱스 반환
  /// 사용자 파일이 선택된 경우 kPdfTemplates.length를 반환하고,
  /// 그렇지 않으면 _selectedTemplateIndex를 반환합니다.
  int _getCurrentSelectedIndex() {
    if (_selectedTemplateFilePath != null) {
      return kPdfTemplates.length;  // 사용자 파일 선택된 경우
    }
    return _selectedTemplateIndex;  // 기본 템플릿 선택된 경우
  }

  Future<void> _pickPdfTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
      dialogTitle: 'PDF 양식 파일 선택',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    setState(() {
      _selectedTemplateFilePath = path;
      // 파일 선택 시 드롭다운에서 사용자 파일 항목이 선택되도록
      // (인덱스는 _getCurrentSelectedIndex()에서 자동으로 처리됨)
    });
  }

  /// 폰트 사이즈 설정 섹션
  Widget _buildFontSizeSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.font_download,
                size: 20,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '폰트 설정',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 폰트 종류 선택
          Row(
            children: [
              Expanded(
                child: Text(
                  '폰트 종류',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedFont,
                    underline: const SizedBox.shrink(),
                    isExpanded: true,
                    isDense: true,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                    ),
                    items: _fontList.map((font) {
                      return DropdownMenuItem(
                        value: font['file']!,
                        child: Text(
                          font['name']!,
                          style: const TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newFont) {
                      if (newFont != null) {
                        setState(() {
                          _selectedFont = newFont;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 일반 필드 폰트 사이즈와 비고 필드 폰트 사이즈를 같은 행에 배치
          Row(
            children: [
              // 일반 필드 폰트 사이즈
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '일 반',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<double>(
                        value: _fontSize,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                        ),
                        items: _fontSizeOptions.map((size) {
                          return DropdownMenuItem(
                            value: size,
                            child: Text(
                              '${size.toInt()}pt',
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (double? newSize) {
                          if (newSize != null) {
                            setState(() {
                              _fontSize = newSize;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // 구분선 추가
              Container(
                width: 1,
                height: 25,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(0.5),
                ),
              ),
              // 비고 필드 폰트 사이즈
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '비 고',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<double>(
                        value: _remarksFontSize,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                        ),
                        items: _remarksFontSizeOptions.map((size) {
                          return DropdownMenuItem(
                            value: size,
                            child: Text(
                              '${size.toInt()}pt',
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (double? newSize) {
                          if (newSize != null) {
                            setState(() {
                              _remarksFontSize = newSize;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 문서 출력 버튼
  Widget _buildDocumentOutputButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handlePreview(),
        icon: const Icon(Icons.description, size: 20),
        label: const Text(
          '문서 출력',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.purple.shade600,
          side: BorderSide(color: Colors.purple.shade600),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// PDF 미리보기 처리
  Future<void> _handlePreview() async {
    if (!mounted) return;

    try {
      // 1) 데이터 수집
      final planData = ref.read(substitutionPlanViewModelProvider).planData;
      if (planData.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('미리볼 데이터가 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2) 임시 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}${Platform.pathSeparator}preview_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 3) PDF 생성 (임시 파일)
      final String templatePath = _selectedTemplateFilePath ?? kPdfTemplates[_selectedTemplateIndex].assetPath;
      final success = await PdfExportService.exportSubstitutionPlan(
        planData: planData,
        outputPath: tempPath,
        templatePath: templatePath,
        fontSize: _fontSize,
        remarksFontSize: _remarksFontSize,
        fontType: _selectedFont,
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF 미리보기 생성 실패'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 4) 미리보기 화면으로 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(pdfPath: tempPath),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}

/// PDF 미리보기 화면
/// PDF 파일을 화면에 표시합니다.
class PdfPreviewScreen extends StatefulWidget {
  final String pdfPath;

  const PdfPreviewScreen({
    super.key,
    required this.pdfPath,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isDisposed = false;
  dynamic _originalErrorHandler;
  
  // PDF 뷰어 컨트롤러 (확대/축소 제어용)
  PdfViewerController? _pdfViewerController;
  
  // 현재 줌 레벨 (기본값: 1.0 = 100%)
  double _currentZoomLevel = 1.0;
  
  // 줌 단계 (한 번에 0.25배씩 변경)
  static const double _zoomStep = 0.25;
  
  // 최소/최대 줌 레벨
  static const double _minZoom = 0.5;  // 50%
  static const double _maxZoom = 3.0;  // 300%

  @override
  void initState() {
    super.initState();
    
    // Flutter 오류 핸들러 설정 (Windows에서 PDF 뷰어 플러그인 오류 캐치)
    _originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // PDF 뷰어 closeDocument 오류만 조용히 무시
      if (details.exception is MissingPluginException &&
          details.exception.toString().contains('closeDocument')) {
        developer.log('PDF 뷰어 closeDocument 오류 무시 (MissingPluginException)');
        return; // 오류를 무시하고 처리 종료
      }
      // 다른 오류는 기본 처리로 전달
      if (_originalErrorHandler != null) {
        _originalErrorHandler(details);
      }
    };
    
    _checkFile();
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // PDF 뷰어 컨트롤러 정리
    _pdfViewerController?.dispose();
    _pdfViewerController = null;
    
    // 원래 오류 핸들러로 복원
    if (_originalErrorHandler != null) {
      FlutterError.onError = _originalErrorHandler;
    }
    
    // PDF 뷰어 dispose 시 발생할 수 있는 MissingPluginException 처리
    // Windows 플랫폼에서 syncfusion_flutter_pdfviewer 플러그인이
    // 제대로 등록되지 않은 경우 오류가 발생할 수 있습니다.
    try {
      super.dispose();
    } catch (e) {
      // MissingPluginException을 포함한 모든 dispose 오류를 조용히 처리
      // PDF 저장은 이미 완료되었으므로 오류를 무시해도 됩니다.
      if (e is MissingPluginException &&
          e.toString().contains('closeDocument')) {
        developer.log('PDF 뷰어 dispose 중 closeDocument 오류 발생 (무시됨)');
      } else {
        developer.log('PDF 뷰어 dispose 중 오류 발생 (무시됨): $e');
      }
    }
  }

  Future<void> _checkFile() async {
    try {
      final file = File(widget.pdfPath);
      if (!await file.exists()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'PDF 파일을 찾을 수 없습니다.\n경로: ${widget.pdfPath}';
          _isLoading = false;
        });
        return;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        setState(() {
          _hasError = true;
          _errorMessage = 'PDF 파일이 비어 있습니다.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '파일 확인 중 오류 발생: $e';
        _isLoading = false;
      });
    }
  }

  /// PDF 인쇄 처리
  /// Windows에서는 시스템 명령어를 사용하고, 다른 플랫폼에서는 printing 패키지를 사용합니다.
  Future<void> _handlePrint() async {
    try {
      final file = File(widget.pdfPath);
      
      // 파일 존재 확인
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('인쇄할 PDF 파일을 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Windows 플랫폼에서는 시스템 명령어 사용
      // Windows에서 printing 패키지의 네이티브 구현이 제대로 동작하지 않을 수 있습니다.
      if (Platform.isWindows) {
        await _printWindows(file);
        return;
      }

      // 다른 플랫폼(Android, iOS, Linux, macOS)에서는 printing 패키지 사용
      try {
        final pdfBytes = await file.readAsBytes();
        
        // 인쇄 다이얼로그 표시 및 인쇄 실행
        // Printing.layoutPdf()는 시스템 인쇄 다이얼로그를 열어 사용자가 프린터를 선택하고 인쇄할 수 있게 합니다.
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: '결보강계획서', // 인쇄 작업 이름
        );

        // 인쇄 성공 시 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('인쇄 다이얼로그가 열렸습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // printing 패키지 오류 시 폴백 처리
        developer.log('printing 패키지 오류, 폴백 처리: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('인쇄 패키지 오류: $e\n파일 탐색기에서 PDF를 열어 인쇄해주세요.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '파일 열기',
                onPressed: () => _openWindowsExplorer(file),
              ),
            ),
          );
        }
      }
    } catch (e) {
      developer.log('PDF 인쇄 오류: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('인쇄 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Windows에서 PDF 인쇄 처리
  /// Windows에서는 기본 PDF 뷰어(보통 Microsoft Edge 또는 기본 PDF 뷰어)를 사용하여 인쇄합니다.
  Future<void> _printWindows(File file) async {
    try {
      // Windows에서 PDF 파일을 시스템 기본 프로그램으로 열어서 인쇄
      // /p 옵션은 인쇄 다이얼로그를 바로 열어주는 옵션입니다.
      final result = await Process.run(
        'cmd',
        [
          '/c',
          'start',
          '/min',
          '""',
          '/p',
          file.path,
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('인쇄 다이얼로그가 열렸습니다.\nPDF 뷰어에서 인쇄 버튼을 클릭해주세요.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('시스템 명령어 실행 실패: ${result.stderr}');
      }
    } catch (e) {
      developer.log('Windows 인쇄 명령어 오류: $e');
      
      // /p 옵션이 작동하지 않는 경우, 파일을 열기만 함
      try {
        await Process.run(
          'cmd',
          [
            '/c',
            'start',
            '""',
            file.path,
          ],
          runInShell: true,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF 파일을 열었습니다.\n파일에서 직접 인쇄해주세요. (Ctrl+P)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e2) {
        developer.log('Windows 파일 열기 오류: $e2');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF 파일 열기 실패: $e2\n파일 경로: ${file.path}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '경로 복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: file.path));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('경로가 클립보드에 복사되었습니다.')),
                  );
                },
              ),
            ),
          );
        }
      }
    }
  }

  /// Windows 파일 탐색기에서 PDF 파일이 있는 폴더 열기
  Future<void> _openWindowsExplorer(File file) async {
    try {
      final directory = file.parent.path;
      await Process.run('explorer.exe', [directory]);
    } catch (e) {
      developer.log('파일 탐색기 열기 오류: $e');
    }
  }

  /// PDF 저장 처리
  /// 미리보기 화면에서 현재 PDF 파일을 사용자가 선택한 위치에 저장합니다.
  Future<void> _handleSave() async {
    try {
      final sourceFile = File(widget.pdfPath);
      
      // 파일 존재 확인
      if (!await sourceFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장할 PDF 파일을 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 파일 저장 위치 선택 다이얼로그 표시
      // file_picker 패키지를 사용하여 저장 위치를 선택합니다.
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF 파일 저장',
        fileName: _getSaveFileName(),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      // 사용자가 취소한 경우
      if (outputPath == null || outputPath.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장이 취소되었습니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 확장자가 없으면 추가
      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }

      // 파일 복사
      final targetFile = File(outputPath);
      final bytes = await sourceFile.readAsBytes();
      await targetFile.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF 저장 완료\n${targetFile.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '폴더 열기',
              textColor: Colors.white,
              onPressed: () => _openWindowsExplorer(targetFile),
            ),
          ),
        );
      }

      developer.log('PDF 저장 완료: ${targetFile.path}');
    } catch (e) {
      developer.log('PDF 저장 오류: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 저장 파일명 생성
  /// 기본 파일명은 현재 날짜를 기준으로 생성합니다.
  String _getSaveFileName() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} 결보강계획서';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 미리보기'),
        actions: [
          // 줌 조절 버튼들 (로딩 완료되고 오류가 없을 때만 표시)
          if (!_isLoading && !_hasError) ...[
            // 현재 줌 레벨 표시
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '${(_currentZoomLevel * 100).toInt()}%',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            // 원래대로 버튼
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: _canResetZoom() ? _handleResetZoom : null,
              tooltip: '원래대로 (100%)',
            ),
            // 축소 버튼
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _canZoomOut() ? _handleZoomOut : null,
              tooltip: '축소',
            ),
            // 확대 버튼
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _canZoomIn() ? _handleZoomIn : null,
              tooltip: '확대',
            ),
            const SizedBox(width: 8),
            // PDF 저장 버튼
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _handleSave,
              tooltip: 'PDF 저장',
            ),
            // 인쇄 버튼
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _handlePrint,
              tooltip: '인쇄',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '닫기',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  /// 확대 가능한지 확인
  bool _canZoomIn() {
    return _currentZoomLevel < _maxZoom;
  }
  
  /// 축소 가능한지 확인
  bool _canZoomOut() {
    return _currentZoomLevel > _minZoom;
  }
  
  /// 원래대로 가능한지 확인 (현재 줌이 1.0이 아니면 가능)
  bool _canResetZoom() {
    return (_currentZoomLevel - 1.0).abs() > 0.01;  // 0.01 오차 허용
  }
  
  /// 확대 처리
  void _handleZoomIn() {
    if (!_canZoomIn()) return;
    
    setState(() {
      _currentZoomLevel = (_currentZoomLevel + _zoomStep).clamp(_minZoom, _maxZoom);
    });
    
    // PDF 뷰어 컨트롤러가 있으면 줌 적용
    _applyZoomLevel();
    
    developer.log('PDF 확대: ${(_currentZoomLevel * 100).toInt()}%');
  }
  
  /// 축소 처리
  void _handleZoomOut() {
    if (!_canZoomOut()) return;
    
    setState(() {
      _currentZoomLevel = (_currentZoomLevel - _zoomStep).clamp(_minZoom, _maxZoom);
    });
    
    // PDF 뷰어 컨트롤러가 있으면 줌 적용
    _applyZoomLevel();
    
    developer.log('PDF 축소: ${(_currentZoomLevel * 100).toInt()}%');
  }
  
  /// 원래대로 (100%)로 되돌리기
  void _handleResetZoom() {
    setState(() {
      _currentZoomLevel = 1.0;
    });
    
    // PDF 뷰어 컨트롤러가 있으면 줌 적용
    _applyZoomLevel();
    
    developer.log('PDF 원래대로: 100%');
  }
  
  /// 줌 레벨을 PDF 뷰어에 적용
  /// SfPdfViewer는 컨트롤러의 zoomLevel 속성을 사용하여 줌을 제어합니다.
  void _applyZoomLevel() {
    if (_pdfViewerController != null && mounted) {
      try {
        // PdfViewerController의 zoomLevel 속성 설정
        // 주의: zoomLevel은 1.0이 기본값이며, 0.5~3.0 범위에서 동작합니다.
        _pdfViewerController!.zoomLevel = _currentZoomLevel;
        
        // 줌이 적용되었는지 확인하기 위해 로그 출력
        developer.log('PDF 줌 적용 완료: ${(_currentZoomLevel * 100).toInt()}%');
      } catch (e) {
        developer.log('PDF 줌 적용 오류: $e');
        // 오류 발생 시에도 사용자에게 알림은 하지 않음 (줌은 부가 기능)
      }
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF 파일을 불러오는 중...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'PDF 미리보기 오류',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    // SfPdfViewer를 안전하게 래핑하여 MissingPluginException 처리
    try {
      // PDF 뷰어 컨트롤러 초기화 (아직 생성되지 않은 경우)
      _pdfViewerController ??= PdfViewerController();
      
      return SfPdfViewer.file(
        File(widget.pdfPath),
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,  // 더블 탭으로 줌 인/아웃 가능
        enableTextSelection: false,    // 텍스트 선택 비활성화 (줌과의 충돌 방지)
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          if (mounted && !_isDisposed) {
            setState(() {
              _hasError = true;
              _errorMessage = 'PDF 로드 실패: ${details.error}';
            });
          }
        },
      );
    } catch (e) {
      // PDF 뷰어 초기화 실패 시 (예: Windows에서 플러그인 미등록)
      developer.log('PDF 뷰어 초기화 실패: $e');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.orange.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'PDF 미리보기 사용 불가',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'PDF 뷰어를 초기화할 수 없습니다.\nPDF는 저장되었으므로 파일 탐색기에서 확인할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('돌아가기'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // 파일 탐색기에서 PDF 파일이 있는 폴더 열기
                  // Windows에서는 explorer.exe를 사용하여 폴더를 엽니다
                  try {
                    final file = File(widget.pdfPath);
                    final directory = file.parent.path;
                    
                    // Windows에서 파일 탐색기로 폴더 열기
                    if (Platform.isWindows) {
                      Process.run('explorer.exe', [directory]);
                    } else if (Platform.isLinux) {
                      Process.run('xdg-open', [directory]);
                    } else if (Platform.isMacOS) {
                      Process.run('open', [directory]);
                    }
                  } catch (e) {
                    developer.log('파일 탐색기에서 열기 실패: $e');
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('파일 위치 열기'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

