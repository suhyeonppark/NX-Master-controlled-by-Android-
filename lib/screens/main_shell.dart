import 'package:flutter/material.dart';

import '../actions/action_ids.dart';
import '../app_state.dart';
import '../models/button_config.dart';
import '../widgets/control_button.dart';
import '../widgets/section_card.dart';
import '../widgets/status_bar.dart';
import 'home_screen.dart';
import 'ir_screen.dart';
import 'relay_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['NX 제어', '전원제어', 'IR제어', 'PC', 'Serial', '설정'];

  static const _screens = [
    HomeScreen(),
    RelayScreen(),
    IrScreen(),
    PcScreen(),
    SerialScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        centerTitle: true,
        actions: const [ConnectionDots(), SizedBox(width: 8)],
      ),
      body: SafeArea(child: IndexedStack(index: _index, children: _screens)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 72,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.power), label: '전원제어'),
          NavigationDestination(icon: Icon(Icons.settings_remote), label: 'IR제어'),
          NavigationDestination(icon: Icon(Icons.computer), label: 'PC'),
          NavigationDestination(icon: Icon(Icons.cable), label: 'Serial'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}

class SerialScreen extends StatelessWidget {
  const SerialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GroupedScreen(screen: ButtonScreen.serial);
  }
}

class PcScreen extends StatelessWidget {
  const PcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pcs = AppScope.of(context).config.pcs;
    if (pcs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '등록된 PC가 없습니다.\n설정 > PC (Wake-on-LAN)에서 추가하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF8A8F98)),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            if (pcs.length > 1)
              const SectionCard(
                title: 'PC 전체',
                child: ButtonGrid(
                  tileWidth: kTileWidth,
                  children: [
                    ControlButton(
                      label: '전체 켜기',
                      actionId: ActionIds.wolAll,
                      icon: Icons.computer,
                    ),
                  ],
                ),
              ),
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
      ),
    );
  }
}
