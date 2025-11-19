import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  Future<PackageInfo> _loadInfo() => PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<PackageInfo>(
        future: _loadInfo(),
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                title: Text(snapshot.data?.appName ?? 'Tentang Aplikasi'),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.primaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: colorScheme.onPrimary,
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  color: colorScheme.primary,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                snapshot.data?.appName ?? 'Quran Assistant',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                snapshot.hasData
                                    ? 'Versi ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                                    : 'Memuat informasi versi…',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: colorScheme.onPrimary.withOpacity(0.84)),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList.list(
                  children: [
                    _InfoCard(
                      title: 'Misi Produk',
                      icon: Icons.favorite_rounded,
                      content:
                          'Membantu kamu mendekat pada Al-Qur’an lewat mushaf digital yang nyaman, audio yang terkurasi, dan artikel inspiratif setiap hari.',
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Fitur Unggulan',
                      icon: Icons.star_rate_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _Bullet(text: 'Mushaf interaktif dengan penanda bacaan terakhir.'),
                          _Bullet(text: 'Kumpulan podcast dan audio kajian yang bisa diunduh.'),
                          _Bullet(text: 'Artikel kurasi harian dengan kategori terpersonalisasi.'),
                          _Bullet(text: 'Mode offline untuk akses kapan pun.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Tim & Dukungan',
                      icon: Icons.handshake_rounded,
                      content:
                          'Kami adalah tim kecil yang mencintai Al-Qur’an dan teknologi. Butuh bantuan atau ingin menyampaikan masukan? Kirim email ke support@quran-assistant.app.',
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Informasi Tambahan',
                      icon: Icons.info_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapshot.hasData) ...[
                            _Bullet(text: 'Paket aplikasi: ${snapshot.data!.packageName}'),
                            _Bullet(text: 'Build number: ${snapshot.data!.buildNumber}'),
                          ],
                          const _Bullet(text: 'Lisensi audio dan konten mengikuti kebijakan masing-masing penerbit.'),
                          const _Bullet(text: 'Seluruh data pribadi disimpan secara lokal di perangkat.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    this.content,
    this.child,
  });

  final String title;
  final IconData icon;
  final String? content;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (content != null)
            Text(
              content!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          const Text('• '),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
