import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 모든 플랫폼에서 공통으로 사용하는 AppBar 위젯
/// 
/// 특징:
/// - 왼쪽에 메뉴 버튼 (Drawer 열기)
/// - 일관된 스타일과 동작
/// - 모든 플랫폼에서 동일한 디자인
class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  /// AppBar 제목
  final String title;
  
  /// AppBar 배경색 (기본값: 파란색)
  final Color? backgroundColor;
  
  /// AppBar 전경색 (기본값: 흰색)
  final Color? foregroundColor;
  
  /// 추가 actions (오른쪽 아이콘 버튼들)
  final List<Widget>? actions;
  
  /// 커스텀 leading 위젯 (기본값: null이면 자동으로 메뉴 아이콘 표시)
  final Widget? leading;
  
  /// elevation (그림자 효과, 기본값: 0)
  final double? elevation;
  
  /// 자동으로 leading 표시 여부 (기본값: true)
  /// true이면 Drawer가 있으면 메뉴 아이콘, 없으면 뒤로가기 버튼 표시
  final bool automaticallyImplyLeading;

  const CommonAppBar({
    super.key,
    required this.title,
    this.backgroundColor,
    this.foregroundColor,
    this.actions,
    this.leading,
    this.elevation,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 모든 플랫폼에서 동일한 스타일 적용
    return AppBar(
      // leading: null이면 자동으로 처리 (Drawer가 있으면 메뉴 아이콘, 없으면 뒤로가기)
      leading: leading ?? (automaticallyImplyLeading
        ? IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // Scaffold의 Drawer 열기
              Scaffold.of(context).openDrawer();
            },
            tooltip: '메뉴 열기',
          )
        : null),
      automaticallyImplyLeading: false,
      
      // 제목
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // 배경색 (기본값: 파란색)
      backgroundColor: backgroundColor ?? Colors.blue,
      
      // 전경색 (기본값: 흰색)
      foregroundColor: foregroundColor ?? Colors.white,
      
      // 그림자 효과
      elevation: elevation ?? 0,
      
      // 오른쪽 액션 버튼들
      actions: actions,
      
      // 중앙 정렬 (선택사항)
      centerTitle: false,
      
      // 아이콘 테마 (모든 플랫폼에서 동일)
      iconTheme: IconThemeData(
        color: foregroundColor ?? Colors.white,
        size: 24,
      ),
      
      // 제목 텍스트 스타일
      titleTextStyle: TextStyle(
        color: foregroundColor ?? Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

