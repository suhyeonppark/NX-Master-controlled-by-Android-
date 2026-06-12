import 'package:flutter/material.dart';

import '../actions/action_ids.dart';
import '../app_state.dart';
import '../models/button_config.dart';
import '../widgets/control_button.dart';
import '../widgets/grouped_buttons_view.dart';
import '../widgets/section_card.dart';

class RelayScreen extends StatelessWidget {
  const RelayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pcs = AppScope.of(context).config.pcs;
    return GroupedButtonsView(
      screen: ButtonScreen.relay,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionCard(
            title: 'Relay 전체',
            child: ButtonGrid(
              tileWidth: kTileWidth,
              children: [
                ControlButton(
                  label: '전체 ON',
                  actionId: ActionIds.seqAllOn,
                  icon: Icons.power_settings_new,
                ),
                ControlButton(
                  label: '전체 OFF',
                  actionId: ActionIds.seqAllOff,
                  icon: Icons.power_off,
                  danger: true,
                ),
              ],
            ),
          ),
          if (pcs.isNotEmpty)
            SectionCard(
              title: 'PC (Wake-on-LAN)',
              child: ButtonGrid(
                tileWidth: kTileWidth,
                children: [
                  for (final pc in pcs)
                    ControlButton(
                      label: pc.name.isEmpty ? 'PC' : pc.name,
                      actionId: ActionIds.wol(pc.id),
                      icon: Icons.computer,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class GroupedScreen extends StatelessWidget {
  const GroupedScreen({super.key, required this.screen});

  final ButtonScreen screen;

  @override
  Widget build(BuildContext context) {
    return GroupedButtonsView(screen: screen);
  }
}
