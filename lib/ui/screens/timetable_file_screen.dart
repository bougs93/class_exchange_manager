import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/exchange_screen_provider.dart';
import '../../providers/state_reset_provider.dart';
import '../../models/exchange_mode.dart';
import 'exchange_screen/exchange_screen_state_proxy.dart';
import 'exchange_screen/managers/exchange_operation_manager.dart';

/// 시간표 파일 관리 화면
///
/// 시간표 파일 선택 및 해제 기능을 제공합니다.
/// - 현재 선택된 파일 정보 표시
/// - 다른 파일 선택 기능
/// - 파일 선택 해제 기능
class TimetableFileScreen extends ConsumerStatefulWidget {
  const TimetableFileScreen({super.key});

  @override
  ConsumerState<TimetableFileScreen> createState() => _TimetableFileScreenState();
}

class _TimetableFileScreenState extends ConsumerState<TimetableFileScreen> {
  // 엑셀 파일 선택 관련 상태 관리
  ExchangeScreenStateProxy? _stateProxy;
  ExchangeOperationManager? _operationManager;

  @override
  void initState() {
    super.initState();
    
    // StateProxy 초기화
    _stateProxy = ExchangeScreenStateProxy(ref);
    
    // Manager 초기화 (엑셀 파일 처리 및 상태 관리)
    _operationManager = ExchangeOperationManager(
      context: context,
      ref: ref,
      stateProxy: _stateProxy!,
      onCreateSyncfusionGridData: () {
        if (mounted) setState(() {});
      },
      onClearAllExchangeStates: () {
        if (mounted) setState(() {});
      },
      onRefreshHeaderTheme: () {
        if (mounted) setState(() {});
      },
    );
  }

  /// 엑셀 파일 선택 메서드
  Future<void> _selectExcelFile() async {
    if (_operationManager != null) {
      // 파일 선택 시도
      bool fileSelected = await _operationManager!.selectExcelFile();
      
      // 파일 선택이 성공한 경우에만 초기화 수행
      if (fileSelected) {
        // 파일 선택 후 보기 모드로 전환
        final globalNotifier = ref.read(exchangeScreenProvider.notifier);
        globalNotifier.setCurrentMode(ExchangeMode.view);

        // 파일 선택 후 Level 3 초기화
        ref.read(stateResetProvider.notifier).resetAllStates(
          reason: '파일 선택 후 전체 상태 초기화',
        );
        
        if (mounted) {
          setState(() {});
        }
      }
      // 파일 선택이 취소된 경우 아무 동작하지 않음
    }
  }

  /// 엑셀 파일 선택 해제 메서드 (확인 다이얼로그 포함)
  Future<void> _clearSelectedFile() async {
    // 확인 다이얼로그 표시
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('파일 선택 해제'),
              ),
            ],
          ),
          content: const Text(
            '선택된 시간표 파일을 해제하시겠습니까?\n해제하면 현재 로드된 시간표 정보가 삭제됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('해제'),
            ),
          ],
        );
      },
    );

    // 확인 버튼을 눌렀을 때만 파일 해제
    if (confirm == true && mounted) {
      _operationManager?.clearSelectedFile();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenState = ref.watch(exchangeScreenProvider);
    final selectedFile = screenState.selectedFile;
    final isLoading = screenState.isLoading;

    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 현재 파일 정보 카드
            _buildFileInfoCard(context, theme, selectedFile),
            
            const SizedBox(height: 24),
            
            // 파일 관리 버튼들
            _buildActionButtons(context, theme, selectedFile, isLoading),
          ],
        ),
      ),
    );
  }

  /// 현재 파일 정보 카드 생성
  Widget _buildFileInfoCard(
    BuildContext context,
    ThemeData theme,
    File? selectedFile,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description,
                  color: theme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 선택된 시간표 파일',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selectedFile != null)
                      Text(
                        selectedFile.path.split(Platform.pathSeparator).last,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        '선택된 파일이 없습니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
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

  /// 파일 관리 버튼들 생성
  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    File? selectedFile,
    bool isLoading,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 다른 파일 선택 버튼
        ElevatedButton.icon(
          onPressed: isLoading ? null : _selectExcelFile,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  selectedFile == null ? Icons.upload_file : Icons.refresh,
                ),
          label: Text(
            selectedFile == null ? '엑셀 파일 선택' : '다른 파일 선택',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 파일 선택 해제 버튼 (파일이 선택된 경우에만 표시)
        if (selectedFile != null)
          OutlinedButton.icon(
            onPressed: isLoading ? null : _clearSelectedFile,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.delete_outline),
            label: const Text(
              '파일 선택 해제',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}

