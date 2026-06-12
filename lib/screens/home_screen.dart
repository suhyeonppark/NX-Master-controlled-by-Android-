import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/control_button.dart';
import '../widgets/section_card.dart';

/// Operator home screen. Renders every user macro flagged `showOnHome` as a
/// single-tap button. Macros are edited in 설정 → 매크로 편집.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final macros =
        AppScope.of(context).macros.where((m) => m.showOnHome).toList();

    if (macros.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '홈에 표시할 매크로가 없습니다.\n설정 > 매크로 편집에서 추가하거나 "홈 화면에 표시"를 켜세요.',
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
            SectionCard(
              title: '매크로',
              child: ButtonGrid(
                tileWidth: kTileWidth,
                children: [
                  for (final m in macros)
                    ControlButton(
                      label: m.label,
                      actionId: m.id,
                      icon: Icons.playlist_play,
                      danger: m.danger,
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
