import 'package:flutter/material.dart';

import '../actions/action_ids.dart';
import '../models/button_config.dart';
import '../widgets/control_button.dart';
import '../widgets/grouped_buttons_view.dart';
import '../widgets/section_card.dart';

class IrScreen extends StatelessWidget {
  const IrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GroupedButtonsView(
      screen: ButtonScreen.ir,
      header: SectionCard(
        title: 'IR 전체',
        child: ButtonGrid(
          tileWidth: kTileWidth,
          children: [
            ControlButton(
              label: 'IR 전체 ON',
              actionId: ActionIds.allDisplayOn,
              icon: Icons.tv,
            ),
            ControlButton(
              label: 'IR 전체 OFF',
              actionId: ActionIds.allDisplayOff,
              icon: Icons.tv_off,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}
