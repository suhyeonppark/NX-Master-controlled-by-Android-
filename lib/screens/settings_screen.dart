import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../ce/wol_client.dart';
import '../config/app_config.dart';
import '../models/device_status.dart';
import '../models/wol_pc.dart';
import 'button_list_screen.dart';
import 'macro_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nxIp;
  late TextEditingController _nxPort;
  late TextEditingController _timeout;
  late TextEditingController _lock;
  late List<WolPc> _pcs;
  DeviceStatus _testStatus = const DeviceStatus();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final c = AppScope.of(context).config;
    _nxIp = TextEditingController(text: c.nxIp);
    _nxPort = TextEditingController(text: '${c.nxPort}');
    _timeout = TextEditingController(text: '${c.tcpTimeoutMs}');
    _lock = TextEditingController(text: '${c.buttonLockMs}');
    _pcs = List.of(c.pcs);
    _initialized = true;
  }

  @override
  void dispose() {
    _nxIp.dispose();
    _nxPort.dispose();
    _timeout.dispose();
    _lock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final newConfig = AppConfig(
      nxIp: _nxIp.text.trim(),
      nxPort: int.parse(_nxPort.text.trim()),
      tcpTimeoutMs: int.parse(_timeout.text.trim()),
      buttonLockMs: int.parse(_lock.text.trim()),
      pcs: _pcs,
    );
    final ok = await state.saveConfig(newConfig);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '설정이 저장되었습니다.' : '설정 저장에 실패했습니다.'),
        backgroundColor: ok ? null : Colors.red.shade700,
      ),
    );
  }

  Future<void> _test() async {
    if (!_validHostPort()) return;
    setState(() {
      _testStatus =
          const DeviceStatus(state: DeviceConnectionState.checking);
    });
    final status = await AppScope.read(context).testNx(
      hostOverride: _nxIp.text.trim(),
      portOverride: int.tryParse(_nxPort.text.trim()),
    );
    if (!mounted) return;
    setState(() => _testStatus = status);
  }

  bool _validHostPort() {
    final ipOk = _validateIp(_nxIp.text) == null;
    final p = int.tryParse(_nxPort.text.trim());
    return ipOk && p != null && p >= 1 && p <= 65535;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('AMX NX-2200'),
          _ipField('NX IP', _nxIp),
          _portField('NX Port', _nxPort),
          _testRow('NX-2200', _testStatus, _test),
          const SizedBox(height: 24),
          _sectionTitle('공통'),
          _numberField('TCP Timeout (ms)', _timeout, min: 200, max: 30000),
          _numberField('Button Lock Time (ms)', _lock, min: 0, max: 10000),
          const SizedBox(height: 24),
          _sectionTitle('PC (Wake-on-LAN)'),
          _pcSection(),
          const SizedBox(height: 24),
          SizedBox(
            height: 64,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('설정 저장', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_button, size: 28),
              title: const Text(
                '버튼 편집',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Relay / IR / Serial / IO 버튼 추가 · 삭제 · 수정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ButtonListScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.playlist_play, size: 28),
              title: const Text(
                '매크로 편집',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('여러 동작을 묶은 매크로 추가 · 삭제 · 수정 (홈 화면 버튼)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MacroListScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('앱 정보'),
            subtitle: Text('NX-2200 Controller · v1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _pcSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pcs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('등록된 PC가 없습니다.', style: TextStyle(color: Colors.grey)),
          )
        else
          for (final pc in _pcs)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.computer),
                title: Text(pc.name.isEmpty ? '(이름 없음)' : pc.name),
                subtitle: Text(pc.mac),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: '수정',
                      onPressed: () => _editPc(existing: pc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '삭제',
                      onPressed: () => setState(
                        () => _pcs = [
                          for (final p in _pcs)
                            if (p.id != pc.id) p,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _editPc(),
          icon: const Icon(Icons.add),
          label: const Text('PC 추가'),
        ),
      ],
    );
  }

  Future<void> _editPc({WolPc? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final macCtrl = TextEditingController(text: existing?.mac ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<WolPc>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'PC 추가' : 'PC 수정'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: macCtrl,
                decoration: const InputDecoration(
                  labelText: 'MAC 주소',
                  border: OutlineInputBorder(),
                  hintText: 'AA:BB:CC:DD:EE:FF',
                ),
                validator: (v) => WolClient.parseMac((v ?? '').trim()) == null
                    ? '올바른 MAC 주소를 입력하세요'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final id =
                  existing?.id ?? 'pc_${DateTime.now().microsecondsSinceEpoch}';
              Navigator.of(ctx).pop(WolPc(
                id: id,
                name: nameCtrl.text.trim(),
                mac: macCtrl.text.trim(),
              ));
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    macCtrl.dispose();
    if (result == null) return;
    setState(() {
      if (existing == null) {
        _pcs = [..._pcs, result];
      } else {
        _pcs = [
          for (final p in _pcs)
            if (p.id == result.id) result else p,
        ];
      }
    });
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );

  Widget _ipField(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'NX IP',
            border: OutlineInputBorder(),
            hintText: '192.168.1.100',
          ),
          keyboardType: TextInputType.text,
          validator: _validateIp,
        ),
      );

  Widget _portField(String label, TextEditingController c) =>
      _numberField(label, c, min: 1, max: 65535);

  Widget _numberField(
    String label,
    TextEditingController c, {
    required int min,
    required int max,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return '숫자를 입력하세요';
            if (n < min || n > max) return '$min ~ $max 범위로 입력하세요';
            return null;
          },
        ),
      );

  String? _validateIp(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'IP를 입력하세요';
    final parts = s.split('.');
    if (parts.length != 4) return '올바른 IPv4 주소를 입력하세요';
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return '올바른 IPv4 주소를 입력하세요';
    }
    return null;
  }

  Widget _testRow(String name, DeviceStatus status, VoidCallback onTest) {
    final (color, text) = switch (status.state) {
      DeviceConnectionState.online => (Colors.green, '$name: ONLINE'),
      DeviceConnectionState.offline => (
          Colors.red,
          '$name: OFFLINE${status.detail != null ? ' - ${status.detail}' : ''}'
        ),
      DeviceConnectionState.checking => (Colors.orange, '$name: 확인 중...'),
      DeviceConnectionState.unknown => (Colors.grey, '$name: 미확인'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: status.state == DeviceConnectionState.checking
                ? null
                : onTest,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('연결 테스트'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
