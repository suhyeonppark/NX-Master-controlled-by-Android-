import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions/action_models.dart';
import '../app_state.dart';
import '../models/macro_config.dart';
import 'macro_actions.dart';

/// One editable macro step. Carries a stable [key] so its widgets keep their
/// state across reorders.
class _StepDraft {
  _StepDraft(this.key, this.actionId, this.delayAfterMs);

  final int key;
  String actionId;
  int delayAfterMs;
}

class MacroEditScreen extends StatefulWidget {
  const MacroEditScreen({super.key, this.existing});

  final MacroConfig? existing;

  @override
  State<MacroEditScreen> createState() => _MacroEditScreenState();
}

class _MacroEditScreenState extends State<MacroEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _confirmMessage;
  late bool _showOnHome;
  late bool _confirm;
  late bool _danger;
  late List<_StepDraft> _steps;
  int _nextKey = 0;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _label = TextEditingController(text: m?.label ?? '');
    _confirmMessage = TextEditingController(text: m?.confirmMessage ?? '');
    _showOnHome = m?.showOnHome ?? true;
    _confirm = m?.confirm ?? false;
    _danger = m?.danger ?? false;
    _steps = [
      for (final s in m?.steps ?? const <MacroStep>[])
        _StepDraft(_nextKey++, s.actionId, s.delayAfterMs),
    ];
  }

  @override
  void dispose() {
    _label.dispose();
    _confirmMessage.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = AppScope.read(context);
    final id = widget.existing?.id ?? state.newMacroId();
    final message = _confirmMessage.text.trim();
    Navigator.of(context).pop(MacroConfig(
      id: id,
      label: _label.text.trim(),
      confirm: _confirm,
      confirmMessage: message.isEmpty ? null : message,
      showOnHome: _showOnHome,
      danger: _danger,
      steps: [
        for (final s in _steps)
          MacroStep(s.actionId, delayAfterMs: s.delayAfterMs),
      ],
    ));
  }

  void _addStep(List<ActionChoice> choices) {
    if (choices.isEmpty) return;
    setState(() {
      _steps = [..._steps, _StepDraft(_nextKey++, choices.first.id, 0)];
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final editing = widget.existing != null;
    final choices = macroActionChoices(state, excludeMacroId: widget.existing?.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? '매크로 수정' : '매크로 추가'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('저장', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: '매크로 이름',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '매크로 이름을 입력하세요' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('홈 화면에 표시'),
              value: _showOnHome,
              onChanged: (v) => setState(() => _showOnHome = v),
            ),
            SwitchListTile(
              title: const Text('위험 버튼 색상 (빨강)'),
              value: _danger,
              onChanged: (v) => setState(() => _danger = v),
            ),
            SwitchListTile(
              title: const Text('실행 전 확인 팝업'),
              value: _confirm,
              onChanged: (v) => setState(() => _confirm = v),
            ),
            if (_confirm) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmMessage,
                decoration: const InputDecoration(
                  labelText: '확인 메시지 (비우면 기본 문구)',
                  border: OutlineInputBorder(),
                  hintText: '전체 전원을 켜시겠습니까?',
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              '단계',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              '위에서 아래로 순서대로 실행됩니다. 각 단계의 지연은 그 단계 실행 후 다음 단계까지 기다리는 시간입니다.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (choices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '추가할 수 있는 동작이 없습니다. 먼저 버튼이나 PC를 등록하세요.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else if (_steps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('단계가 없습니다. 아래에서 추가하세요.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = _steps.removeAt(oldIndex);
                    _steps.insert(newIndex, item);
                  });
                },
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    _stepRow(i, _steps[i], choices),
                ],
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: choices.isEmpty ? null : () => _addStep(choices),
              icon: const Icon(Icons.add),
              label: const Text('단계 추가'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(int index, _StepDraft step, List<ActionChoice> choices) {
    // If the step targets a now-deleted action, keep it selectable by adding a
    // fallback entry so the dropdown value stays valid.
    final items = [
      for (final c in choices)
        DropdownMenuItem(value: c.id, child: Text(c.label, overflow: TextOverflow.ellipsis)),
      if (!choices.any((c) => c.id == step.actionId))
        DropdownMenuItem(
          value: step.actionId,
          child: Text('(삭제됨) ${step.actionId}',
              overflow: TextOverflow.ellipsis),
        ),
    ];

    return Padding(
      key: ValueKey(step.key),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: step.actionId,
              decoration: const InputDecoration(
                labelText: '동작',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: items,
              onChanged: (v) =>
                  setState(() => step.actionId = v ?? step.actionId),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: '${step.delayAfterMs}',
              decoration: const InputDecoration(
                labelText: '지연(ms)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => step.delayAfterMs = int.tryParse(v.trim()) ?? 0,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => setState(() => _steps.removeAt(index)),
          ),
        ],
      ),
    );
  }
}
