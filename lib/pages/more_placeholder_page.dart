import 'package:flutter/material.dart';
import 'package:quran_assistant/pages/more/about_app_page.dart';
import 'package:quran_assistant/pages/more/app_settings_page.dart';
import 'package:quran_assistant/pages/more/data_storage_page.dart';
import 'package:quran_assistant/pages/more/read_articles_page.dart';
import 'package:quran_assistant/pages/more/saved_articles_page.dart';
import 'package:quran_assistant/pages/more/saved_audio_page.dart';

class MorePlaceholderPage extends StatelessWidget {
  const MorePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final menuItems = _buildMenuItems();
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeBanner(theme: theme),
              const SizedBox(height: 28),
              Text(
                'Panel Layanan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < menuItems.length; i++) ...[
                      _MoreMenuTile(data: menuItems[i]),
                      if (i != menuItems.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: theme.dividerColor.withOpacity(0.3),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_MenuTileData> _buildMenuItems() {
    return [
      _MenuTileData(
        title: 'Artikel Tersimpan',
        subtitle: 'Kumpulan artikel favoritmu untuk dibaca ulang.',
        icon: Icons.bookmark_added_rounded,
        accent: Color(0xFF6C63FF),
  builder: (_) => const SavedArticlesPage(),
      ),
      _MenuTileData(
        title: 'Artikel Terbaca',
        subtitle: 'Riwayat bacaan agar mudah dilanjutkan.',
        icon: Icons.history_rounded,
        accent: Color(0xFF00B4D8),
  builder: (_) => const ReadArticlesPage(),
      ),
      _MenuTileData(
        title: 'Audio Tersimpan',
        subtitle: 'Simak ulang podcast dan kajian favoritmu.',
        icon: Icons.headphones_rounded,
        accent: Color(0xFFFFAE00),
  builder: (_) => const SavedAudioPage(),
      ),
      _MenuTileData(
        title: 'Data Tersimpan',
        subtitle: 'Kelola cache, mushaf offline, dan ruang penyimpanan.',
        icon: Icons.storage_rounded,
        accent: Color(0xFF2EC4B6),
  builder: (_) => const DataStoragePage(),
      ),
      _MenuTileData(
        title: 'Pengaturan Aplikasi',
        subtitle: 'Atur notifikasi dan preferensi lainnya.',
        icon: Icons.tune_rounded,
        accent: Color(0xFF5E60CE),
  builder: (_) => const AppSettingsPage(),
      ),
      _MenuTileData(
        title: 'Tentang Aplikasi',
        subtitle: 'Ketahui visi, lisensi, dan pembaruan Quran Assistant.',
        icon: Icons.info_outline_rounded,
        accent: Color(0xFFFF5E5B),
  builder: (_) => const AboutAppPage(),
      ),
    ];
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D2B64), Color(0xFFF8CDDA)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.18),
            ),
            padding: const EdgeInsets.all(14),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat datang kembali!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Semoga setiap kunjunganmu membuka pintu kebaikan dan ilmu yang menenangkan jiwa.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTileData {
  _MenuTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final WidgetBuilder builder;
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({required this.data});

  final _MenuTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: data.builder),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.accent.withOpacity(0.16),
              ),
              child: Icon(data.icon, color: data.accent),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 28),
          ],
        ),
      ),
    );
  }
}
