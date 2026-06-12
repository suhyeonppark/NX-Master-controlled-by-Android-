import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/main_shell.dart';

/// Root widget. Provides [AppState] to the tree and builds the MaterialApp.
class AmxControlApp extends StatelessWidget {
  const AmxControlApp({super.key, required this.state});

  final AppState state;

  // Minimal palette.
  static const Color _ink = Color(0xFF17181C);
  static const Color _bg = Color(0xFFF6F6F7);
  static const Color _border = Color(0xFFE4E5EA);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _ink,
      brightness: Brightness.light,
    ).copyWith(surface: Colors.white);

    return AppScope(
      state: state,
      child: MaterialApp(
        title: '전원제어',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: _bg,
          visualDensity: VisualDensity.comfortable,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: _bg,
            foregroundColor: _ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _border),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            elevation: 0,
            height: 70,
            surfaceTintColor: Colors.transparent,
            indicatorColor: _ink.withValues(alpha: 0.06),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? _ink : const Color(0xFF9AA0A8),
                size: 24,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _ink : const Color(0xFF9AA0A8),
              );
            }),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ink, width: 1.6),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
          dividerTheme: const DividerThemeData(color: _border, thickness: 1),
        ),
        home: const MainShell(),
      ),
    );
  }
}
