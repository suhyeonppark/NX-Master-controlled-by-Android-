/// Severity of a command execution outcome, used to drive UI feedback
/// (color of SnackBar, whether to show a strong warning dialog, etc).
enum ResultSeverity {
  /// Command(s) sent successfully.
  success,

  /// Completed but something needs operator attention
  /// (e.g. a relay OPEN retry succeeded, or a momentary OPEN failed).
  warning,

  /// Command failed (network error, timeout, unknown action, ...).
  error,
}

/// Result of running an action or sending a low-level command.
///
/// This is the single value type that flows back from the CE clients,
/// the [InterlockManager], the [ActionRouter] and ultimately the UI.
///
/// IMPORTANT: per the spec, a successful result only means the command was
/// *sent*. It never means the physical device actually changed state. UI text
/// must reflect "command sent", not "device on".
class CommandResult {
  const CommandResult({
    required this.success,
    required this.severity,
    required this.message,
    this.sentCommands = const [],
  });

  /// Whether the operation completed without a hard failure.
  final bool success;

  /// Severity for UI feedback. A successful-but-warning result has
  /// [success] == true and [severity] == [ResultSeverity.warning].
  final ResultSeverity severity;

  /// Human-readable (Korean) message shown to the operator.
  final String message;

  /// Raw command strings that were transmitted. Useful for diagnostics and
  /// for tests that assert on the exact wire format.
  final List<String> sentCommands;

  bool get isWarning => severity == ResultSeverity.warning;

  factory CommandResult.ok(String message, {List<String> sentCommands = const []}) {
    return CommandResult(
      success: true,
      severity: ResultSeverity.success,
      message: message,
      sentCommands: sentCommands,
    );
  }

  factory CommandResult.warn(String message, {List<String> sentCommands = const []}) {
    return CommandResult(
      success: true,
      severity: ResultSeverity.warning,
      message: message,
      sentCommands: sentCommands,
    );
  }

  factory CommandResult.fail(String message, {List<String> sentCommands = const []}) {
    return CommandResult(
      success: false,
      severity: ResultSeverity.error,
      message: message,
      sentCommands: sentCommands,
    );
  }

  /// Merge another result's transmitted commands into this one, keeping the
  /// other result's message/severity. Used when chaining steps.
  CommandResult mergeCommandsFrom(CommandResult previous) {
    return CommandResult(
      success: success,
      severity: severity,
      message: message,
      sentCommands: [...previous.sentCommands, ...sentCommands],
    );
  }

  @override
  String toString() => 'CommandResult($severity, "$message", cmds=$sentCommands)';
}
