import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import '../../services/excel_service.dart';

/// 교체 관리 화면
class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  File? _selectedFile;        // 선택된 엑셀 파일
  Excel? _excelData;         // 읽은 엑셀 데이터
  bool _isLoading = false;    // 로딩 상태
  String? _errorMessage;     // 오류 메시지

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교체 관리'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  /// 메인 바디 위젯 구성
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 파일 선택 섹션
          _buildFileSelectionSection(),
          
          const SizedBox(height: 24),
          
          // 엑셀 데이터 표시 섹션
          if (_excelData != null) _buildExcelDataSection(),
          
          // 오류 메시지 표시
          if (_errorMessage != null) _buildErrorMessageSection(),
        ],
      ),
    );
  }

  /// 파일 선택 섹션 UI
  Widget _buildFileSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upload_file,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '엑셀 파일 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 선택된 파일이 있을 때와 없을 때 다른 UI 표시
            if (_selectedFile == null) ...[
              Text(
                '시간표가 포함된 엑셀 파일(.xlsx, .xls)을 선택하세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _selectExcelFile,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(_isLoading ? '처리 중...' : '엑셀 파일 선택'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // 선택된 파일 정보 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '선택된 파일: ${_selectedFile!.path.split('\\').last}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _selectExcelFile,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isLoading ? '처리 중...' : '다른 파일 선택'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.clear),
                      label: const Text('선택 해제'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }


  /// 엑셀 데이터 표시 섹션 UI
  Widget _buildExcelDataSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.table_chart,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '엑셀 데이터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '워크시트 개수: ${_excelData!.tables.length}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '워크시트 이름: ${_excelData!.tables.keys.join(', ')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showExcelInfo,
                icon: const Icon(Icons.info_outline),
                label: const Text('상세 정보 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 오류 메시지 섹션 UI
  Widget _buildErrorMessageSection() {
    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade600,
                ),
              ),
            ),
            IconButton(
              onPressed: _clearError,
              icon: Icon(
                Icons.close,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 엑셀 파일 선택 및 자동 읽기 메서드
  Future<void> _selectExcelFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      File? selectedFile = await ExcelService.pickExcelFile();
      
      if (selectedFile != null) {
        setState(() {
          _selectedFile = selectedFile;
          _excelData = null; // 새로운 파일 선택 시 기존 데이터 초기화
        });
        
        // 파일 선택 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('파일이 선택되었습니다: ${selectedFile.path.split('/').last}'),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 1),
            ),
          );
        }
        
        // 자동으로 엑셀 데이터 읽기
        await _loadExcelData();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '파일 선택 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 엑셀 데이터 읽기 메서드 (내부용)
  Future<void> _loadExcelData() async {
    if (_selectedFile == null) return;

    try {
      Excel? excel = await ExcelService.readExcelFile(_selectedFile!);
      
      if (excel != null) {
        // 파일 유효성 검사
        bool isValid = ExcelService.isValidExcelFile(excel);
        
        if (isValid) {
          setState(() {
            _excelData = excel;
          });
          
          // 시간표 데이터 파싱 시도
          await _parseTimetableData(excel);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('엑셀 파일을 성공적으로 읽었습니다!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = '유효하지 않은 엑셀 파일입니다.';
          });
        }
      } else {
        setState(() {
          _errorMessage = '엑셀 파일을 읽을 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '엑셀 파일 읽기 중 오류가 발생했습니다: $e';
      });
    }
  }

  /// 시간표 데이터 파싱 메서드
  Future<void> _parseTimetableData(Excel excel) async {
    try {
      // 시간표 데이터 파싱
      TimetableData? timetableData = ExcelService.parseTimetableData(excel);
      
      if (timetableData != null) {
        // 파싱 성공 - 콘솔에 로그가 출력됨
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('시간표 파싱 완료! 교사 ${timetableData.teachers.length}명, 슬롯 ${timetableData.timeSlots.length}개'),
              backgroundColor: Colors.blue.shade600,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // 파싱 실패
        setState(() {
          _errorMessage = '시간표 데이터를 파싱할 수 없습니다. 파일 형식을 확인해주세요.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '시간표 파싱 중 오류가 발생했습니다: $e';
      });
    }
  }

  /// 엑셀 상세 정보 보기 메서드
  void _showExcelInfo() {
    if (_excelData == null) return;
    
    ExcelService.printExcelInfo(_excelData!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('콘솔에서 상세 정보를 확인하세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 선택 해제 메서드
  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _excelData = null;
      _errorMessage = null;
    });
  }

  /// 오류 메시지 제거 메서드
  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }
}
