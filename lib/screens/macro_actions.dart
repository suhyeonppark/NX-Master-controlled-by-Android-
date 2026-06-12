import '../actions/action_ids.dart';
import '../app_state.dart';

/// A selectable action a macro step can reference: a button, another macro, or a
/// Wake-on-LAN target. [id] is the action_id stored on the step; [label] is the
/// human-readable name shown in the editor and step summaries.
class ActionChoice {
  const ActionChoice(this.id, this.label);

  final String id;
  final String label;
}

const _typeLabel = {
  'relay': 'Relay',
  'ir': 'IR',
  'serial': 'Serial',
  'io': 'IO',
};

/// Builds the list of actions a macro step can target: every button, every other
/// macro (excluding [excludeMacroId] to avoid trivial self-reference), and the
/// PC Wake-on-LAN actions generated from settings.
List<ActionChoice> macroActionChoices(AppState state, {String? excludeMacroId}) {
  final choices = <ActionChoice>[
    for (final b in state.buttons)
      ActionChoice(b.id, '[${_typeLabel[b.type.name] ?? b.type.name}] ${b.label}'),
    for (final m in state.macros)
      if (m.id != excludeMacroId) ActionChoice(m.id, '매크로: ${m.label}'),
  ];
  final pcs = state.config.pcs;
  if (pcs.isNotEmpty) {
    choices.add(const ActionChoice(ActionIds.wolAll, 'PC 전체 켜기'));
    for (final pc in pcs) {
      choices.add(
        ActionChoice(ActionIds.wol(pc.id), 'PC: ${pc.name.isEmpty ? '이름 없음' : pc.name}'),
      );
    }
  }
  return choices;
}

/// Human-readable name for an action_id, for step summaries. Falls back to the
/// raw id if nothing resolves (e.g. a referenced button was deleted).
String describeActionId(AppState state, String id) {
  for (final c in macroActionChoices(state)) {
    if (c.id == id) return c.label;
  }
  return id;
}
