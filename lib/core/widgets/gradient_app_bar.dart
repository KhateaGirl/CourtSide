import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/theme_mode_provider.dart';

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  /// Title: [String] (shows as styled text) or [Widget] (e.g. Row with badge).
  final dynamic title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.primaryGradientDark : AppColors.primaryGradientLight,
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.cyan500 : AppColors.blue600).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AppBar(
        title: title is String ? Text(title as String, style: _titleStyle) : title as Widget,
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: leading,
        actions: actions,
      ),
    );
  }
}

class AppBarThemeToggle extends ConsumerWidget {
  const AppBarThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(
        themeMode == ThemeMode.dark
            ? Icons.light_mode_rounded
            : themeMode == ThemeMode.light
                ? Icons.dark_mode_rounded
                : (isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      ),
      onPressed: () {
        ref.read(themeModeProvider.notifier).state = themeMode == ThemeMode.dark
            ? ThemeMode.light
            : themeMode == ThemeMode.light
                ? ThemeMode.system
                : ThemeMode.dark;
      },
    );
  }
}
