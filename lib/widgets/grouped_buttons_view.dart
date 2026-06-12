import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/button_config.dart';
import 'device_card.dart';
import 'section_card.dart';

/// Renders all user-defined buttons for a [screen] as reference-style device
/// cards: ON/OFF buttons that target the same relay / IR port are paired into
/// one tile (see [groupDevices]). Tapping a tile opens a popup with every
/// action; binary relay devices also get a one-tap corner toggle.
///
/// Data-driven: edits made in the settings button editor appear here
/// immediately.
class GroupedButtonsView extends StatelessWidget {
  const GroupedButtonsView({super.key, required this.screen, this.header});

  final ButtonScreen screen;

  /// Optional widget shown above the first section (e.g. a hint).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final groups = state.buttonsByGroup(screen);

    if (groups.isEmpty) {
      return _centered(
        ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ?header,
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '버튼이 없습니다.\n설정 탭에서 버튼을 추가하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Flatten every group into one grid so the individual device cards flow
    // horizontally side by side, instead of each device sitting alone in its
    // own stacked section. Each card already shows its own name, so per-group
    // headings are redundant.
    final devices = groupDevices([
      for (final entry in groups.entries) ...entry.value,
    ]);

    return _centered(
      ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ?header,
          SectionCard(
            title: _deviceSectionTitle,
            child: ButtonGrid(
              tileWidth: kTileWidth,
              children: [
                for (final device in devices) DeviceCard(device: device),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _deviceSectionTitle => switch (screen) {
        ButtonScreen.relay => '전원제어',
        ButtonScreen.ir => 'IR제어',
        ButtonScreen.serial => 'Serial',
        ButtonScreen.io => 'IO',
      };

  /// Caps the content width so tiles stay compact and grouped on wide tablets.
  Widget _centered(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: child,
        ),
      );
}
