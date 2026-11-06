import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class LockInApp extends ConsumerWidget {
  const LockInApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final theme = AppTheme.dark();

    return MaterialApp.router(
      title: 'Lock-in',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // On wide screens (web, tablets) keep the phone layout as a centred
      // column instead of stretching tiles across the whole window.
      builder: (context, child) => _PhoneFrame(child: child!),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});
  final Widget child;

  static const _maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= _maxWidth + 40) return child;
    return ColoredBox(
      color: const Color(0xFF0B0B0D),
      child: Center(
        child: Container(
          width: _maxWidth,
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border.symmetric(
              vertical: BorderSide(color: Color(0xFF1F1F24)),
            ),
          ),
          child: MediaQuery(
            data: media.copyWith(size: Size(_maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
