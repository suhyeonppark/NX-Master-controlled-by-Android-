import 'package:flutter/material.dart';

/// A titled card grouping related control buttons (e.g. "전원", "프롬프터 TV").
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Minimal: no boxed card — a quiet section label over white tile buttons
    // floating on the grey page background, so each tile reads clearly.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF8A8F98),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Shared tile sizing so every control tile (master buttons + device cards)
/// is the same size across the app, regardless of screen width.
const double kTileWidth = 240;
const double kTileAspect = 1.5; // width / height

/// Caps the content column so tiles stay compact and grouped in a centred
/// 2-up layout (like the reference app) instead of spreading across a wide
/// tablet with empty columns on the right.
const double kContentMaxWidth = 540;

/// Lays out control tiles in a grid. Two modes:
///  - [tileWidth] set → uniform fixed-size tiles that wrap into as many columns
///    as fit (the default for control screens, so tiles never stretch into wide
///    bars on a tablet).
///  - otherwise → [columns] per row at a fixed [buttonHeight] (used inside the
///    device popup, where a simple 2-up layout is wanted).
class ButtonGrid extends StatelessWidget {
  const ButtonGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.buttonHeight = 92,
    this.maxWidth,
    this.tileWidth,
    this.tileAspect = kTileAspect,
  });

  final List<Widget> children;
  final int columns;

  /// Fixed height of each button cell (fixed-columns mode).
  final double buttonHeight;

  /// Optional cap on the grid width; the grid is centred within it.
  final double? maxWidth;

  /// Target tile width. When set, tiles are this size and wrap responsively.
  final double? tileWidth;

  /// Tile width / height ratio (tile mode).
  final double tileAspect;

  @override
  Widget build(BuildContext context) {
    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: children.length,
      gridDelegate: tileWidth != null
          ? SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: tileWidth!,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: tileAspect,
            )
          : SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: buttonHeight,
            ),
      itemBuilder: (context, i) => children[i],
    );
    if (maxWidth == null) return grid;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: grid,
      ),
    );
  }
}
