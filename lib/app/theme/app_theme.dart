import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seed = Color(0xFF3F51B5);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        DueDateColors(
          overdue: scheme.error,
          warning: Colors.amber.shade700,
          normal: scheme.onSurfaceVariant,
        ),
      ],
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        DueDateColors(
          overdue: scheme.error,
          warning: Colors.amber.shade400,
          normal: scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class DueDateColors extends ThemeExtension<DueDateColors> {
  final Color overdue;
  final Color warning;
  final Color normal;

  const DueDateColors({
    required this.overdue,
    required this.warning,
    required this.normal,
  });

  @override
  DueDateColors copyWith({Color? overdue, Color? warning, Color? normal}) {
    return DueDateColors(
      overdue: overdue ?? this.overdue,
      warning: warning ?? this.warning,
      normal: normal ?? this.normal,
    );
  }

  @override
  DueDateColors lerp(ThemeExtension<DueDateColors>? other, double t) {
    if (other is! DueDateColors) return this;
    return DueDateColors(
      overdue: Color.lerp(overdue, other.overdue, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      normal: Color.lerp(normal, other.normal, t)!,
    );
  }
}
