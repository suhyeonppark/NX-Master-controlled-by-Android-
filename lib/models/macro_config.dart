import '../actions/action_models.dart';

/// User-editable macro definition. Mirrors [ButtonConfig]: a serializable config
/// object that the UI edits and that converts to a runtime [MacroAction] via
/// [toActionDef]. Persisted as JSON by `MacroRepository`.
class MacroConfig {
  const MacroConfig({
    required this.id,
    required this.label,
    this.confirm = false,
    this.confirmMessage,
    this.showOnHome = true,
    this.danger = false,
    this.steps = const [],
  });

  final String id;
  final String label;
  final bool confirm;
  final String? confirmMessage;

  /// Whether this macro is surfaced as a button on the home screen.
  final bool showOnHome;

  /// Renders the home button in the danger (red) style, e.g. power-off macros.
  final bool danger;

  final List<MacroStep> steps;

  String get _confirmMessage =>
      confirmMessage?.trim().isNotEmpty == true
          ? confirmMessage!.trim()
          : "'$label'을(를) 실행하시겠습니까?";

  MacroAction toActionDef() => MacroAction(
        id: id,
        steps: steps,
        confirm: confirm,
        confirmMessage: confirm ? _confirmMessage : null,
      );

  MacroConfig copyWith({
    String? label,
    bool? confirm,
    String? confirmMessage,
    bool? showOnHome,
    bool? danger,
    List<MacroStep>? steps,
  }) {
    return MacroConfig(
      id: id,
      label: label ?? this.label,
      confirm: confirm ?? this.confirm,
      confirmMessage: confirmMessage ?? this.confirmMessage,
      showOnHome: showOnHome ?? this.showOnHome,
      danger: danger ?? this.danger,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'confirm': confirm,
        'confirmMessage': confirmMessage,
        'showOnHome': showOnHome,
        'danger': danger,
        'steps': [
          for (final s in steps)
            {'actionId': s.actionId, 'delayAfterMs': s.delayAfterMs},
        ],
      };

  factory MacroConfig.fromJson(Map<String, dynamic> j) {
    final rawSteps = (j['steps'] as List<dynamic>?) ?? const [];
    return MacroConfig(
      id: j['id'] as String,
      label: j['label'] as String? ?? '',
      confirm: j['confirm'] as bool? ?? false,
      confirmMessage: j['confirmMessage'] as String?,
      showOnHome: j['showOnHome'] as bool? ?? true,
      danger: j['danger'] as bool? ?? false,
      steps: [
        for (final e in rawSteps)
          if (e is Map<String, dynamic> && e['actionId'] is String)
            MacroStep(
              e['actionId'] as String,
              delayAfterMs: (e['delayAfterMs'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  }
}
