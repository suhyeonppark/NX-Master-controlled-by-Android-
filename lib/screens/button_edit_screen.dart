import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions/action_models.dart';
import '../app_state.dart';
import '../models/button_config.dart';

class ButtonEditScreen extends StatefulWidget {
  const ButtonEditScreen({super.key, this.existing});

  final ButtonConfig? existing;

  @override
  State<ButtonEditScreen> createState() => _ButtonEditScreenState();
}

class _ButtonEditScreenState extends State<ButtonEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _group;
  late final TextEditingController _duration;
  late final TextEditingController _serialMessage;

  late ButtonType _type;
  late int _relay;
  late RelayMode _relayMode;
  late int _irPort;
  late int _irCh;
  late int _serialPort;
  late int _ioPort;
  late int _ioCh;
  late int _ioValue;
  late bool _confirm;
  late bool _danger;

  ButtonScreen get _screen => switch (_type) {
        ButtonType.relay => ButtonScreen.relay,
        ButtonType.ir => ButtonScreen.ir,
        ButtonType.serial => ButtonScreen.serial,
        ButtonType.io => ButtonScreen.io,
      };

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _label = TextEditingController(text: b?.label ?? '');
    _group = TextEditingController(text: b?.group ?? '');
    _duration = TextEditingController(text: '${b?.durationMs ?? 500}');
    _serialMessage = TextEditingController(text: b?.serialMessage ?? '');
    _type = b?.type ?? ButtonType.relay;
    _relay = b?.relay ?? 1;
    _relayMode = b?.relayMode ?? RelayMode.latchClose;
    _irPort = b?.irPort ?? 1;
    _irCh = b?.irCh ?? 1;
    _serialPort = b?.serialPort ?? 1;
    _ioPort = b?.ioPort ?? 1;
    _ioCh = b?.ioCh ?? 1;
    _ioValue = b?.ioValue ?? 1;
    _confirm = b?.confirm ?? false;
    _danger = b?.danger ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _group.dispose();
    _duration.dispose();
    _serialMessage.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = AppScope.read(context);
    final id = widget.existing?.id ?? state.newButtonId();
    Navigator.of(context).pop(ButtonConfig(
      id: id,
      label: _label.text.trim(),
      screen: _screen,
      group: _group.text.trim().isEmpty ? '기타' : _group.text.trim(),
      type: _type,
      order: widget.existing?.order ?? 0,
      confirm: _confirm,
      danger: _danger,
      relay: _relay,
      relayMode: _relayMode,
      durationMs: int.tryParse(_duration.text.trim()) ?? 500,
      irPort: _irPort,
      irCh: _irCh,
      serialPort: _serialPort,
      serialMessage: _serialMessage.text.trim(),
      ioPort: _ioPort,
      ioCh: _ioCh,
      ioValue: _ioValue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? '버튼 수정' : '버튼 추가'),
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
                labelText: '버튼 이름',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '버튼 이름을 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ButtonType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: '타입',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: ButtonType.relay, child: Text('Relay')),
                DropdownMenuItem(value: ButtonType.ir, child: Text('IR')),
                DropdownMenuItem(value: ButtonType.serial, child: Text('Serial')),
                DropdownMenuItem(value: ButtonType.io, child: Text('IO')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _group,
              decoration: const InputDecoration(
                labelText: '그룹',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ...switch (_type) {
              ButtonType.relay => _relayFields(),
              ButtonType.ir => _irFields(),
              ButtonType.serial => _serialFields(),
              ButtonType.io => _ioFields(),
            },
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('실행 전 확인 팝업'),
              value: _confirm,
              onChanged: (v) => setState(() => _confirm = v),
            ),
            SwitchListTile(
              title: const Text('위험 버튼 색상'),
              value: _danger,
              onChanged: (v) => setState(() => _danger = v),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _relayFields() => [
        _sectionLabel('Relay 설정'),
        _intDropdown(
          label: 'Relay 채널',
          value: _relay,
          max: 8,
          onChanged: (v) => setState(() => _relay = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<RelayMode>(
          initialValue: _relayMode,
          decoration: const InputDecoration(
            labelText: '동작',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: RelayMode.latchClose, child: Text('ON 유지')),
            DropdownMenuItem(value: RelayMode.latchOpen, child: Text('OFF 유지')),
            DropdownMenuItem(value: RelayMode.momentary, child: Text('순간 ON→OFF')),
          ],
          onChanged: (v) => setState(() => _relayMode = v ?? _relayMode),
        ),
        if (_relayMode == RelayMode.momentary) ...[
          const SizedBox(height: 16),
          _numberField('순간 동작 시간 (ms)', _duration, min: 50, max: 10000),
        ],
      ];

  List<Widget> _irFields() => [
        _sectionLabel('IR 설정'),
        _intDropdown(
          label: 'IR 포트',
          value: _irPort,
          min: 1,
          max: 4,
          onChanged: (v) => setState(() => _irPort = v),
        ),
        const SizedBox(height: 16),
        _intDropdown(
          label: 'IR 채널',
          value: _irCh,
          max: 255,
          onChanged: (v) => setState(() => _irCh = v),
        ),
      ];

  List<Widget> _serialFields() => [
        _sectionLabel('Serial 설정'),
        _intDropdown(
          label: 'Serial 포트',
          value: _serialPort,
          max: 8,
          onChanged: (v) => setState(() => _serialPort = v),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _serialMessage,
          decoration: const InputDecoration(
            labelText: '전송 메시지',
            border: OutlineInputBorder(),
            hintText: 'PWR ON',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '메시지를 입력하세요' : null,
        ),
      ];

  List<Widget> _ioFields() => [
        _sectionLabel('IO 설정'),
        _intDropdown(
          label: 'IO 포트',
          value: _ioPort,
          max: 8,
          onChanged: (v) => setState(() => _ioPort = v),
        ),
        const SizedBox(height: 16),
        _intDropdown(
          label: 'IO 채널',
          value: _ioCh,
          max: 16,
          onChanged: (v) => setState(() => _ioCh = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _ioValue,
          decoration: const InputDecoration(
            labelText: '값',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('ON (1)')),
            DropdownMenuItem(value: 0, child: Text('OFF (0)')),
          ],
          onChanged: (v) => setState(() => _ioValue = v ?? _ioValue),
        ),
      ];

  Widget _intDropdown({
    required String label,
    required int value,
    int min = 1,
    required int max,
    required ValueChanged<int> onChanged,
  }) =>
      DropdownButtonFormField<int>(
        initialValue: value.clamp(min, max),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          for (var i = min; i <= max; i++) DropdownMenuItem(value: i, child: Text('$i')),
        ],
        onChanged: (v) => onChanged(v ?? value),
      );

  Widget _numberField(
    String label,
    TextEditingController c, {
    required int min,
    required int max,
  }) =>
      TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          final n = int.tryParse((v ?? '').trim());
          if (n == null || n < min || n > max) return '$min ~ $max 범위';
          return null;
        },
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
}
