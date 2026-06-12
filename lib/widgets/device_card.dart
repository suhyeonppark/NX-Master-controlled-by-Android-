import 'package:flutter/material.dart';

import '../actions/action_models.dart';
import '../app_state.dart';
import '../models/button_config.dart';
import 'control_button.dart';
import 'section_card.dart';

class DeviceGroup {
  const DeviceGroup({
    required this.name,
    required this.icon,
    required this.members,
    this.onButton,
    this.offButton,
    this.relay,
    this.ioPort,
    this.ioCh,
  });

  /// Display name, derived from the shared prefix of the member labels.
  final String name;
  final IconData icon;

  /// Every button that targets this device, in saved order. Shown in the popup.
  final List<ButtonConfig> members;

  /// The latch-ON / latch-OFF relay buttons, when this is a relay with both, so
  /// the card can show live state and a one-tap corner toggle.
  final ButtonConfig? onButton;
  final ButtonConfig? offButton;

  /// Relay number for state lookup ([AppState.relayIsOn]); null for IR devices.
  final int? relay;
  final int? ioPort;
  final int? ioCh;

  /// True when the device has a clear binary state we can toggle in one tap.
  bool get isToggle => onButton != null && offButton != null;
}

List<DeviceGroup> groupDevices(List<ButtonConfig> buttons) {
  final order = <String>[];
  final byKey = <String, List<ButtonConfig>>{};
  for (final b in buttons) {
    final key = switch (b.type) {
      ButtonType.relay => 'relay:${b.relay}',
      ButtonType.ir => 'ir:${b.irPort}',
      ButtonType.serial => 'serial:${b.serialPort}',
      ButtonType.io => 'io:${b.ioPort}:${b.ioCh}',
    };
    byKey.putIfAbsent(key, () {
      order.add(key);
      return <ButtonConfig>[];
    }).add(b);
  }
  return [for (final k in order) _buildDevice(byKey[k]!)];
}

DeviceGroup _buildDevice(List<ButtonConfig> members) {
  final type = members.first.type;
  final isRelay = type == ButtonType.relay;
  final isIo = type == ButtonType.io;
  ButtonConfig? on;
  ButtonConfig? off;
  if (isRelay || isIo) {
    for (final b in members) {
      final isOn = isRelay ? b.relayMode == RelayMode.latchClose : b.ioValue != 0;
      if (isOn) {
        on ??= b;
      } else {
        off ??= b;
      }
    }
  }
  return DeviceGroup(
    name: _deviceName(members),
    // Identity icon only — must NOT be a power symbol, or it gets confused with
    // the power toggle button in the top-right corner.
    icon: _deviceIcon(_deviceName(members), type),
    members: members,
    onButton: on,
    offButton: off,
    relay: isRelay ? members.first.relay : null,
    ioPort: isIo ? members.first.ioPort : null,
    ioCh: isIo ? members.first.ioCh : null,
  );
}

/// Picks a meaningful, nice-looking (rounded) icon from the device name, so a
/// "음향전원" card shows a speaker, "프롬프터 TV" shows captions, etc. Falls back
/// to a generic plug (relay) / remote (IR) icon.
IconData _deviceIcon(String name, ButtonType type) {
  final n = name.toLowerCase();
  bool has(List<String> keywords) => keywords.any(n.contains);

  if (has(['음향', '오디오', '사운드', '스피커', 'audio', 'sound', 'speaker'])) {
    return Icons.volume_up_rounded;
  }
  if (has(['영상', '비디오', 'video'])) return Icons.videocam_rounded;
  if (has(['프롬프터', 'prompter'])) return Icons.subtitles_rounded;
  if (has(['pgm', '방송', 'live', 'program'])) return Icons.live_tv_rounded;
  if (has(['모니터', 'monitor', '디스플레이', 'display'])) {
    return Icons.desktop_windows_rounded;
  }
  if (has(['tv', '티비', '텔레비'])) return Icons.tv_rounded;
  if (has(['프로젝', '스크린', 'screen', 'beam', 'projector'])) {
    return Icons.cast_rounded;
  }
  if (has(['조명', '라이트', 'light', 'lamp'])) return Icons.lightbulb_rounded;
  if (has(['마이크', 'mic'])) return Icons.mic_rounded;
  if (has(['에어컨', '냉방', 'hvac', 'aircon', 'ac'])) return Icons.ac_unit_rounded;
  return switch (type) {
    ButtonType.relay => Icons.electrical_services_rounded,
    ButtonType.ir => Icons.settings_remote_rounded,
    ButtonType.serial => Icons.cable_rounded,
    ButtonType.io => Icons.input_rounded,
  };
}

/// A friendly device name. Strips the trailing state word from each member
/// label ("음향전원 ON" + "음향전원 OFF" → "음향전원"); if those agree, use it.
/// Otherwise fall back to the shared label prefix.
String _deviceName(List<ButtonConfig> members) {
  final stripped = {for (final b in members) _stripState(b.label)};
  if (stripped.length == 1) return stripped.first;
  var prefix = members.first.label;
  for (final b in members.skip(1)) {
    prefix = _commonPrefix(prefix, b.label);
  }
  prefix = prefix.replaceAll(RegExp(r'[\s\-·]+$'), '').trim();
  return prefix.isEmpty ? _stripState(members.first.label) : prefix;
}

String _commonPrefix(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  var i = 0;
  while (i < n && a[i] == b[i]) {
    i++;
  }
  return a.substring(0, i);
}

String _stripState(String label) => label
    .replaceAll(RegExp(r'\s*(ON|OFF|켜기|끄기|켬|끔)\s*$', caseSensitive: false), '')
    .trim();

// Palette, kept in step with [ControlButton].
const Color _ink = Color(0xFF20242B);
const Color _muted = Color(0xFF7D848D);
const Color _border = Color(0xFFE2E5E8);
const Color _on = Color(0xFF356F62);
const Color _idle = Color(0xFFF1F3F5);

/// Reference-style device tile: icon, name, a state line, and a corner power
/// toggle. Tapping the body opens [showDeviceControlSheet] with every action.
class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device});

  final DeviceGroup device;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final busy = state.isBusy;
    final bool? isOn = _deviceState(state, device);

    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border, width: 1.1),
        ),
        child: InkWell(
          onTap: busy ? null : () => showDeviceControlSheet(context, device),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(device.icon, size: 28, color: _muted),
                    ),
                    const Spacer(),
                    _CornerToggle(device: device, isOn: isOn, busy: busy),
                  ],
                ),
                const Spacer(),
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                _StateLine(device: device, isOn: isOn),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small status text under the device name.
class _StateLine extends StatelessWidget {
  const _StateLine({required this.device, required this.isOn});

  final DeviceGroup device;
  final bool? isOn;

  @override
  Widget build(BuildContext context) {
    if (device.isToggle) {
      final (text, color) = switch (isOn) {
        true => ('켜짐', _on),
        false => ('꺼짐', _muted),
        null => ('상태 미확인', _muted),
      };
      return Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      );
    }
    final subtitle = device.relay != null
        ? 'Relay ${device.relay}'
        : device.ioPort != null
            ? 'IO ${device.ioPort}-${device.ioCh}'
        : '동작 ${device.members.length}개';
    return Text(
      subtitle,
      style: const TextStyle(fontSize: 13, color: _muted),
    );
  }
}

/// Top-right power control. For a binary device it toggles to the opposite
/// state in one tap; otherwise it just opens the detail popup.
class _CornerToggle extends StatelessWidget {
  const _CornerToggle({
    required this.device,
    required this.isOn,
    required this.busy,
  });

  final DeviceGroup device;
  final bool? isOn;
  final bool busy;

  Future<void> _toggle(BuildContext context) async {
    final target = isOn == true ? device.offButton! : device.onButton!;
    await runActionWithFeedback(
      context,
      actionId: target.id,
      label: target.label,
      danger: target.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = isOn == true;

    // A switch metaphor (toggle_on/off), NOT a power glyph: this corner control
    // is the device's own on/off switch and must not read like the master "전체
    // 전원" power buttons. Green = on, grey = off. Non-toggle devices show a
    // "more" affordance, since tapping them just opens the detail sheet.
    final (Color bg, Color fg, IconData icon, double size) =
        switch ((device.isToggle, active)) {
      (true, true) => (_on, Colors.white, Icons.toggle_on, 30.0),
      (true, false) => (_idle, _muted, Icons.toggle_off, 30.0),
      (false, _) => (_idle, _muted, Icons.more_horiz, 24.0),
    };

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy
            ? null
            : device.isToggle
                ? () => _toggle(context)
                : () => showDeviceControlSheet(context, device),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: size, color: fg),
        ),
      ),
    );
  }
}

/// Bottom-sheet popup with the full set of actions for [device]. Reuses
/// [ControlButton] so confirmation, busy-lock and feedback stay identical.
Future<void> showDeviceControlSheet(BuildContext context, DeviceGroup device) {
  return showModalBottomSheet<void>(
    context: context,
    // A clearly grey sheet (not white): the action buttons are white, so a white
    // sheet made the inactive ones vanish into the background. This grey is dark
    // enough to read against pure-white tiles, so every action looks tappable.
    backgroundColor: const Color(0xFFE9EBEF),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final state = AppScope.of(ctx);
      final bool? isOn = _deviceState(state, device);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(device.icon, color: _muted),
                  const SizedBox(width: 10),
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const Spacer(),
                  if (device.isToggle)
                    Text(
                      switch (isOn) {
                        true => '켜짐',
                        false => '꺼짐',
                        null => '상태 미확인',
                      },
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isOn == true ? _on : _muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ButtonGrid(
                buttonHeight: 84,
                children: [
                  for (final b in device.members)
                    ControlButton(
                      label: b.label,
                      actionId: b.id,
                      danger: b.danger,
                      active: _memberActive(state, b),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Mirrors the latch-state highlight logic used in the grid.
bool _memberActive(AppState state, ButtonConfig b) {
  final bool? on = switch (b.type) {
    ButtonType.relay => state.relayIsOn(b.relay),
    ButtonType.io => state.ioIsOn(b.ioPort, b.ioCh),
    ButtonType.ir || ButtonType.serial => null,
  };
  if (on == null) return false;
  return switch (b.type) {
    ButtonType.relay => switch (b.relayMode) {
        RelayMode.latchClose => on == true,
        RelayMode.latchOpen => on == false,
        RelayMode.momentary => false,
      },
    ButtonType.io => (b.ioValue != 0) == on,
    ButtonType.ir || ButtonType.serial => false,
  };
}

bool? _deviceState(AppState state, DeviceGroup device) {
  if (device.relay != null) return state.relayIsOn(device.relay!);
  if (device.ioPort != null && device.ioCh != null) {
    return state.ioIsOn(device.ioPort!, device.ioCh!);
  }
  return null;
}
