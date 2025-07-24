import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPopupMenu extends StatelessWidget {
  final Offset position;
  final List<PopupMenuEntry> items;

  const GlassPopupMenu({
    super.key,
    required this.position,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap luar area popup untuk menutup
        Positioned.fill(
          child: GestureDetector(onTap: () => Navigator.of(context).pop()),
        ),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: items),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
