import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quran_assistant/providers/app_settings_provider.dart';

class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  Future<void> _handleNotificationToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (value) {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isRestricted || status.isLimited) {
        final requested = await Permission.notification.request();
        if (!requested.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Izin notifikasi diperlukan untuk mengaktifkan pemberitahuan.'),
              ),
            );
          }
          return;
        }
      } else if (status.isPermanentlyDenied) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Izin diblokir'),
              content: const Text(
                  'Aktifkan izin notifikasi lewat pengaturan sistem agar Quran Assistant dapat mengirim pemberitahuan.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
                FilledButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('Buka Pengaturan'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    await ref.read(appSettingsProvider.notifier).setNotificationsEnabled(value);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Notifikasi diaktifkan.' : 'Notifikasi dinonaktifkan.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final switchTheme = theme.switchTheme.copyWith(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurfaceVariant.withOpacity(0.4);
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.onPrimary;
        }
        return colorScheme.onSurface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurfaceVariant.withOpacity(0.25);
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary.withOpacity(0.55);
        }
        return colorScheme.onSurfaceVariant.withOpacity(0.35);
      }),
      trackOutlineColor: WidgetStateProperty.all(
        colorScheme.onSurfaceVariant.withOpacity(0.25),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Aplikasi'),
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _SettingsCard(
              title: 'Notifikasi',
              description:
                  'Terima pengingat ketika ada artikel baru, mushaf selesai diunduh, atau audio favorit siap diputar.',
              leading: Icons.notifications_active_rounded,
              child: Theme(
                data: theme.copyWith(switchTheme: switchTheme),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan notifikasi'),
                  subtitle: Text(
                    state.notificationsEnabled
                        ? 'Kamu akan tetap mendapatkan pembaruan penting.'
                        : 'Semua notifikasi dari aplikasi dimatikan.',
                  ),
                  value: state.notificationsEnabled,
                  onChanged: (value) => _handleNotificationToggle(context, ref, value),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Preferensi lain akan segera hadir.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.description,
    required this.leading,
    required this.child,
  });

  final String title;
  final String description;
  final IconData leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primary.withOpacity(0.12),
                child: Icon(leading, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
