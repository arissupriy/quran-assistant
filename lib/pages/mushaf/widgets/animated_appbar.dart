// lib/pages/mushaf/widgets/animated_appbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/providers/mushaf_provider.dart';
import 'package:quran_assistant/pages/mushaf/utils/session_manager.dart';

class AnimatedMushafAppBar extends ConsumerWidget {
  final int currentPageNumber;
  final SessionManager sessionManager;

  const AnimatedMushafAppBar({
    super.key,
    required this.currentPageNumber,
    required this.sessionManager,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(appBarVisibilityProvider);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: AppBar(
          title: Text(
            'Quran Assistant',
            style: TextStyle(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.iconColor),
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: AppTheme.iconColor),
                  onPressed: () async {
                    await sessionManager.forceEndSession(ref);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                )
              : null,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '$currentPageNumber / 604',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
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
