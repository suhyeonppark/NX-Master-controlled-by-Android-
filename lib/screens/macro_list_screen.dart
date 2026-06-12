import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/macro_config.dart';
import '../widgets/confirm_dialog.dart';
import 'macro_actions.dart';
import 'macro_edit_screen.dart';

class MacroListScreen extends StatelessWidget {
  const MacroListScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final state = AppScope.read(context);
    final result = await Navigator.of(context).push<MacroConfig>(
      MaterialPageRoute(builder: (_) => const MacroEditScreen()),
    );
    if (result != null) await state.addMacro(result);
  }

  Future<void> _edit(BuildContext context, MacroConfig macro) async {
    final state = AppScope.read(context);
    final result = await Navigator.of(context).push<MacroConfig>(
      MaterialPageRoute(builder: (_) => MacroEditScreen(existing: macro)),
    );
    if (result != null) await state.updateMacro(result);
  }

  Future<void> _delete(BuildContext context, MacroConfig macro) async {
    final state = AppScope.read(context);
    final ok = await showConfirmDialog(
      context,
      title: '매크로 삭제',
      message: "'${macro.label}' 매크로를 삭제하시겠습니까?",
      confirmLabel: '삭제',
    );
    if (ok) await state.deleteMacro(macro.id);
  }

  Future<void> _reset(BuildContext context) async {
    final state = AppScope.read(context);
    final ok = await showConfirmDialog(
      context,
      title: '기본값 복원',
      message: '모든 매크로를 기본값으로 되돌립니다. 추가/수정한 매크로는 사라집니다. 계속하시겠습니까?',
      confirmLabel: '복원',
    );
    if (ok) await state.resetMacros();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final macros = state.macros;

    return Scaffold(
      appBar: AppBar(
        title: const Text('매크로 편집'),
        actions: [
          IconButton(
            tooltip: '기본값 복원',
            icon: const Icon(Icons.restore),
            onPressed: () => _reset(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('매크로 추가'),
      ),
      body: macros.isEmpty
          ? const Center(
              child: Text('매크로가 없습니다. 우측 하단에서 추가하세요.',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView(
              children: [
                for (final m in macros) _macroTile(context, state, m),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _macroTile(BuildContext context, AppState state, MacroConfig m) {
    final steps = m.steps
        .map((s) => describeActionId(state, s.actionId))
        .join(' → ');
    final flags = [
      if (m.showOnHome) '홈 표시',
      if (m.confirm) '확인 팝업',
    ].join(' · ');
    final subtitle = [
      if (steps.isNotEmpty) steps else '(단계 없음)',
      if (flags.isNotEmpty) flags,
    ].join('\n');

    return ListTile(
      isThreeLine: true,
      leading: const Icon(Icons.playlist_play),
      title: Text(m.label),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _edit(context, m),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _delete(context, m),
          ),
        ],
      ),
      onTap: () => _edit(context, m),
    );
  }
}
