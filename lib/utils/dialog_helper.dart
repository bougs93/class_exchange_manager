import 'package:flutter/material.dart';

/// 다이얼로그 표시를 위한 헬퍼 클래스
///
/// 프로젝트 전체에서 일관된 다이얼로그 UI를 제공합니다.
class DialogHelper {
  /// 확인/취소 다이얼로그 표시
  ///
  /// 사용자에게 작업 확인을 요청하는 다이얼로그를 표시합니다.
  /// 위험한 작업(삭제, 초기화 등)인 경우 isDangerous를 true로 설정하면
  /// 확인 버튼이 빨간색으로 표시됩니다.
  ///
  /// 반환값:
  /// - true: 사용자가 확인 버튼 클릭
  /// - false: 사용자가 취소 버튼 클릭
  /// - null: 다이얼로그 외부 클릭 또는 뒤로가기
  ///
  /// 예시:
  /// ```dart
  /// final confirmed = await DialogHelper.showConfirmDialog(
  ///   context,
  ///   title: '삭제 확인',
  ///   message: '정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
  ///   confirmText: '삭제',
  ///   isDangerous: true,
  /// );
  ///
  /// if (confirmed == true) {
  ///   // 삭제 작업 수행
  /// }
  /// ```
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDangerous ? Colors.red.shade600 : Colors.blue.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 정보 다이얼로그 표시
  ///
  /// 사용자에게 정보를 알리는 단순 다이얼로그를 표시합니다.
  /// 확인 버튼만 있습니다.
  ///
  /// 예시:
  /// ```dart
  /// await DialogHelper.showInfoDialog(
  ///   context,
  ///   title: '알림',
  ///   message: '작업이 완료되었습니다.',
  /// );
  /// ```
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = '확인',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              buttonText,
              style: TextStyle(color: Colors.blue.shade600),
            ),
          ),
        ],
      ),
    );
  }

  /// 선택 다이얼로그 표시
  ///
  /// 여러 옵션 중 하나를 선택하도록 하는 다이얼로그를 표시합니다.
  ///
  /// 반환값:
  /// - 선택된 항목의 인덱스 (0부터 시작)
  /// - null: 취소 또는 외부 클릭
  ///
  /// 예시:
  /// ```dart
  /// final selected = await DialogHelper.showChoiceDialog(
  ///   context,
  ///   title: '정렬 기준 선택',
  ///   choices: ['이름순', '날짜순', '크기순'],
  /// );
  ///
  /// if (selected != null) {
  ///   print('선택된 옵션: ${selected}');
  /// }
  /// ```
  static Future<int?> showChoiceDialog(
    BuildContext context, {
    required String title,
    required List<String> choices,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            choices.length,
            (index) => ListTile(
              title: Text(choices[index]),
              onTap: () => Navigator.pop(context, index),
            ),
          ),
        ),
      ),
    );
  }
}
