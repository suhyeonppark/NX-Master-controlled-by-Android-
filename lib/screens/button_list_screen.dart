import 'package:flutter/material.dart';

import '../actions/action_models.dart';
import '../app_state.dart';
import '../models/button_config.dart';
import '../widgets/confirm_dialog.dart';
import 'button_edit_screen.dart';

class ButtonListScreen extends StatelessWidget {
  const ButtonListScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final state = AppScope.read(context);
    final result = await Navigator.of(context).push<ButtonConfig>(
      MaterialPageRoute(builder: (_) => const ButtonEditScreen()),
    );
    if (result != null) await state.addButton(result);
  }

  Future<void> _edit(BuildContext context, ButtonConfig button) async {
    final state = AppScope.read(context);
    final result = await Navigator.of(context).push<ButtonConfig>(
      MaterialPageRoute(builder: (_) => ButtonEditScreen(existing: button)),
    );
    if (result != null) await state.updateButton(result);
  }

  Future<void> _delete(BuildContext context, ButtonConfig button) async {
    final state = AppScope.read(context);
    final ok = await showConfirmDialog(
      context,
      title: '버튼 삭제',
      message: "'${button.label}' 버튼을 삭제하시겠습니까?",
      confirmLabel: '삭제',
    );
    if (ok) await state.deleteButton(button.id);
  }

  Future<void> _reset(BuildContext context) async {
    final state = AppScope.read(context);
    final ok = await showConfirmDialog(
      context,
      title: '기본값 복원',
      message: '모든 버튼을 기본값으로 되돌립니다. 추가/수정한 버튼은 사라집니다. 계속하시겠습니까?',
      confirmLabel: '복원',
    );
    if (ok) await state.resetButtons();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sections = <Widget>[];
    for (final screen in ButtonScreen.values) {
      final groups = state.buttonsByGroup(screen);
      if (groups.isEmpty) continue;
      sections.add(_screenHeader(screen));
      for (final entry in groups.entries) {
        sections.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            entry.key,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ));
        for (final b in entry.value) {
          sections.add(_buttonTile(context, b));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('버튼 편집'),
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
        label: const Text('버튼 추가'),
      ),
      body: sections.isEmpty
          ? const Center(
              child: Text('버튼이 없습니다. 우측 하단에서 추가하세요.',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView(children: [...sections, const SizedBox(height: 80)]),
    );
  }

  Widget _screenHeader(ButtonScreen screen) {
    final (label, icon) = switch (screen) {
      ButtonScreen.relay => ('Relay', Icons.power),
      ButtonScreen.ir => ('IR', Icons.settings_remote),
      ButtonScreen.serial => ('Serial', Icons.cable),
      ButtonScreen.io => ('IO', Icons.input),
    };
    return Container(
      width: double.infinity,
      color: Colors.black12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buttonTile(BuildContext context, ButtonConfig b) {
    return ListTile(
      leading: b.danger
          ? const Icon(Icons.warning_amber, color: Colors.red)
          : const Icon(Icons.smart_button),
      title: Text(b.label),
      subtitle: Text(_describe(b)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(context, b)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _delete(context, b),
          ),
        ],
      ),
      onTap: () => _edit(context, b),
    );
  }

  String _describe(ButtonConfig b) {
    final confirm = b.confirm ? ' · 확인 팝업' : '';
    return switch (b.type) {
      ButtonType.ir => 'IR · 포트 ${b.irPort} · 채널 ${b.irCh}$confirm',
      ButtonType.serial => 'Serial · 포트 ${b.serialPort} · "${b.serialMessage}"$confirm',
      ButtonType.io => 'IO · ${b.ioPort}-${b.ioCh} · ${b.ioValue == 0 ? 'OFF' : 'ON'}$confirm',
      ButtonType.relay => 'Relay ${b.relay} · ${_relayMode(b.relayMode, b.durationMs)}$confirm',
    };
  }

  String _relayMode(RelayMode mode, int durationMs) => switch (mode) {
        RelayMode.latchClose => 'ON 유지',
        RelayMode.latchOpen => 'OFF 유지',
        RelayMode.momentary => '순간 ${durationMs}ms',
      };
}
