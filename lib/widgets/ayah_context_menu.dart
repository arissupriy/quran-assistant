import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_assistant/src/rust/data_loader/mushaf_pack.dart';
import 'package:quran_assistant/widgets/verse_detail_bottom_sheet.dart';

class _AnimatedContextMenu extends StatefulWidget {
  final Offset position;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final VoidCallback onCopy;

  const _AnimatedContextMenu({
    required this.position,
    required this.onClose,
    required this.onDetail,
    required this.onCopy,
  });

  @override
  State<_AnimatedContextMenu> createState() => _AnimatedContextMenuState();
}

class _AnimatedContextMenuState extends State<_AnimatedContextMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Background tap area
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // Menu
            Positioned(
              left: widget.position.dx,
              top: widget.position.dy,
              child: FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MenuItem(
                              icon: Icons.search,
                              text: 'Lihat Detail',
                              onTap: widget.onDetail,
                            ),
                            _MenuItem(
                              icon: Icons.copy,
                              text: 'Salin Ayat',
                              onTap: widget.onCopy,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


void showAyahContextMenuOverlay({
  required BuildContext context,
  required Offset position,
  required int sura,
  required int ayah,
  required VoidCallback onDismiss,
}) {
  final overlay = Overlay.of(context);
  final renderBox = overlay.context.findRenderObject() as RenderBox;
  final screenSize = renderBox.size;

  const double menuWidth = 200;
  const double menuHeight = 110;

  double dx = position.dx;
  double dy = position.dy;

  // Adjust horizontal if overflow
  if (dx + menuWidth > screenSize.width) {
    dx = screenSize.width - menuWidth - 16;
  }

  // Adjust vertical if overflow
  if (dy + menuHeight > screenSize.height) {
    dy = dy - menuHeight;
    if (dy < 0) dy = 0;
  }

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) {
      return _AnimatedContextMenu(
        position: Offset(dx, dy),
        onClose: () {
          entry.remove();
          onDismiss();
        },
        onDetail: () {
          entry.remove();
          onDismiss();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => VerseDetailBottomSheet(verseKey: '$sura:$ayah'),
          );
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: '$sura:$ayah'));
          entry.remove();
          onDismiss();
        },
      );
    },
  );

  overlay.insert(entry);
}

