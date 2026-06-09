import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:printing/printing.dart';

/// 출력 미리 보기 화면
///
/// PDF 파일을 화면에 표시하고 줌, 저장, 인쇄 기능을 제공합니다.
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

  // PDF 뷰어 컨트롤러
  PdfViewerController? _pdfViewerController;

  // 줌 설정
  double _currentZoomLevel = 1.0;
  static const double _zoomStep = 0.25;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;

  @override
  void initState() {
    super.initState();
    _setupErrorHandler();
    _checkFile();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pdfViewerController?.dispose();
    _pdfViewerController = null;
    if (_originalErrorHandler != null) {
      FlutterError.onError = _originalErrorHandler;
    }
    try {
      super.dispose();
    } catch (e) {
      if (e is MissingPluginException && e.toString().contains('closeDocument')) {
        developer.log('PDF 뷰어 dispose 중 closeDocument 오류 발생 (무시됨)');
      } else {
        developer.log('PDF 뷰어 dispose 중 오류 발생 (무시됨): $e');
      }
    }
  }

  /// 오류 핸들러 설정
  void _setupErrorHandler() {
    _originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is MissingPluginException &&
          details.exception.toString().contains('closeDocument')) {
        developer.log('PDF 뷰어 closeDocument 오류 무시 (MissingPluginException)');
        return;
      }
      if (_originalErrorHandler != null) {
        _originalErrorHandler(details);
      }
    };
  }

  /// PDF 파일 확인
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// AppBar 생성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('출력 미리 보기'),
      actions: [
        if (!_isLoading && !_hasError) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('${(_currentZoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 14)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            onPressed: _canResetZoom() ? _handleResetZoom : null,
            tooltip: '원래대로 (100%)',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _canZoomOut() ? _handleZoomOut : null,
            tooltip: '축소',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _canZoomIn() ? _handleZoomIn : null,
            tooltip: '확대',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _handleSave,
            tooltip: 'PDF 저장',
          ),
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
    );
  }

  /// Body 생성
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
      return _buildErrorView();
    }

    return _buildPdfViewer();
  }

  /// 오류 화면
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              '출력 미리 보기 오류',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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

  /// PDF 뷰어
  Widget _buildPdfViewer() {
    try {
      _pdfViewerController ??= PdfViewerController();
      return SfPdfViewer.file(
        File(widget.pdfPath),
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        enableTextSelection: false,
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
      developer.log('PDF 뷰어 초기화 실패: $e');
      return _buildFallbackView();
    }
  }

  /// 폴백 화면 (PDF 뷰어 초기화 실패 시)
  Widget _buildFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            Text(
              '출력 미리 보기 사용 불가',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 8),
            const Text(
              'PDF 뷰어를 초기화할 수 없습니다.\nPDF는 저장되었으므로 파일 탐색기에서 확인할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('돌아가기'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openFileExplorer,
              icon: const Icon(Icons.folder_open),
              label: const Text('파일 위치 열기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 줌 제어
  bool _canZoomIn() => _currentZoomLevel < _maxZoom;
  bool _canZoomOut() => _currentZoomLevel > _minZoom;
  bool _canResetZoom() => (_currentZoomLevel - 1.0).abs() > 0.01;

  void _handleZoomIn() {
    if (!_canZoomIn()) return;
    setState(() {
      _currentZoomLevel = (_currentZoomLevel + _zoomStep).clamp(_minZoom, _maxZoom);
    });
    _applyZoomLevel();
  }

  void _handleZoomOut() {
    if (!_canZoomOut()) return;
    setState(() {
      _currentZoomLevel = (_currentZoomLevel - _zoomStep).clamp(_minZoom, _maxZoom);
    });
    _applyZoomLevel();
  }

  void _handleResetZoom() {
    setState(() {
      _currentZoomLevel = 1.0;
    });
    _applyZoomLevel();
  }

  void _applyZoomLevel() {
    if (_pdfViewerController != null && mounted) {
      try {
        _pdfViewerController!.zoomLevel = _currentZoomLevel;
      } catch (e) {
        developer.log('PDF 줌 적용 오류: $e');
      }
    }
  }

  /// 인쇄
  Future<void> _handlePrint() async {
    try {
      final file = File(widget.pdfPath);
      if (!await file.exists()) {
        if (mounted) {
          _showSnackBar('인쇄할 PDF 파일을 찾을 수 없습니다.', Colors.red);
        }
        return;
      }

      if (Platform.isWindows) {
        await _printWindows(file);
      } else {
        try {
          final pdfBytes = await file.readAsBytes();
          await Printing.layoutPdf(onLayout: (format) async => pdfBytes, name: '결보강계획서');
          if (mounted) {
            _showSnackBar('인쇄 다이얼로그가 열렸습니다.', Colors.green);
          }
        } catch (e) {
          developer.log('printing 패키지 오류: $e');
          if (mounted) {
            _showSnackBar('인쇄 패키지 오류\n파일 탐색기에서 PDF를 열어 인쇄해주세요.', Colors.orange);
          }
        }
      }
    } catch (e) {
      developer.log('PDF 인쇄 오류: $e');
      if (mounted) {
        _showSnackBar('인쇄 중 오류가 발생했습니다', Colors.red);
      }
    }
  }

  /// Windows 인쇄
  Future<void> _printWindows(File file) async {
    try {
      final result = await Process.run(
        'cmd',
        ['/c', 'start', '/min', '""', '/p', file.path],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        if (mounted) {
          _showSnackBar('인쇄 다이얼로그가 열렸습니다.', Colors.green);
        }
      } else {
        throw Exception('시스템 명령어 실행 실패: ${result.stderr}');
      }
    } catch (e) {
      developer.log('Windows 인쇄 명령어 오류: $e');
      try {
        await Process.run('cmd', ['/c', 'start', '""', file.path], runInShell: true);
        if (mounted) {
          _showSnackBar('PDF 파일을 열었습니다.\n파일에서 직접 인쇄해주세요. (Ctrl+P)', Colors.orange);
        }
      } catch (e2) {
        developer.log('Windows 파일 열기 오류: $e2');
        if (mounted) {
          _showSnackBar('PDF 파일 열기 실패', Colors.red);
        }
      }
    }
  }

  /// 저장
  Future<void> _handleSave() async {
    try {
      final sourceFile = File(widget.pdfPath);
      if (!await sourceFile.exists()) {
        if (mounted) {
          _showSnackBar('저장할 PDF 파일을 찾을 수 없습니다.', Colors.red);
        }
        return;
      }

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF 파일 저장',
        fileName: _getSaveFileName(),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath == null || outputPath.isEmpty) {
        if (mounted) {
          _showSnackBar('저장이 취소되었습니다.', Colors.orange);
        }
        return;
      }

      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }

      final targetFile = File(outputPath);
      final bytes = await sourceFile.readAsBytes();
      await targetFile.writeAsBytes(bytes);

      if (mounted) {
        _showSnackBar('PDF 저장 완료', Colors.green);
      }
    } catch (e) {
      developer.log('PDF 저장 오류: $e');
      if (mounted) {
        _showSnackBar('저장 중 오류가 발생했습니다', Colors.red);
      }
    }
  }

  /// 파일 탐색기 열기
  Future<void> _openFileExplorer() async {
    try {
      final file = File(widget.pdfPath);
      final directory = file.parent.path;
      if (Platform.isWindows) {
        Process.run('explorer.exe', [directory]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [directory]);
      } else if (Platform.isMacOS) {
        Process.run('open', [directory]);
      }
    } catch (e) {
      developer.log('파일 탐색기 열기 실패: $e');
    }
  }

  /// 저장 파일명 생성
  String _getSaveFileName() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} 결보강계획서';
  }

  /// 스낵바 표시
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
