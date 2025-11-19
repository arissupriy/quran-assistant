import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/storage/saved_content_repository.dart';
import 'package:quran_assistant/pages/articles/article_audio_detail_page.dart';
import 'package:quran_assistant/providers/saved_content_providers.dart';

class SavedAudioPage extends ConsumerWidget {
  const SavedAudioPage({super.key});

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${units[index]}';
  }

  Future<void> _playAudio(BuildContext context, WidgetRef ref, SavedAudioEntry entry) async {
    if (entry.filePath != null && !File(entry.filePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File audio tidak ditemukan. Menghapus dari daftar.')),
      );
      await ref.read(savedAudioProvider.notifier).remove(entry.id);
      ref.invalidate(dataStorageProvider);
      return;
    }
    final audio = entry.toArticleAudio();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleAudioDetailPage(audio: audio),
      ),
    );
  }

  Future<void> _removeEntry(
    BuildContext context,
    WidgetRef ref,
    SavedAudioEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus audio tersimpan?'),
        content: Text('“${entry.title}” akan dihapus dari perangkat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(savedAudioProvider.notifier).remove(entry.id);
      ref.invalidate(dataStorageProvider);
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus semua audio?'),
        content: const Text('Seluruh audio yang telah diunduh akan dihapus dari perangkat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(savedAudioProvider.notifier).clear();
      ref.invalidate(dataStorageProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAudios = ref.watch(savedAudioProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Tersimpan'),
        actions: [
          IconButton(
            tooltip: 'Hapus semua',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _clearAll(context, ref),
          ),
        ],
      ),
      body: asyncAudios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyAudioState();
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(savedAudioProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = items[index];
                final articleTitle = entry.articleTitle ?? 'Audio mandiri';
                final subtitle = '${_formatBytes(entry.sizeBytes)} • $articleTitle';
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.grey.withOpacity(0.15)),
                  ),
                  onTap: () => _playAudio(context, ref, entry),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage:
                        entry.imageUrl != null ? NetworkImage(entry.imageUrl!) : null,
                    backgroundColor: Colors.blueGrey.withOpacity(0.12),
                    child: entry.imageUrl == null
                        ? const Icon(Icons.podcasts_rounded)
                        : null,
                  ),
                  title: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(subtitle),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'play') {
                        await _playAudio(context, ref, entry);
                      } else if (value == 'delete') {
                        await _removeEntry(context, ref, entry);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'play', child: Text('Putar audio')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyAudioState extends StatelessWidget {
  const _EmptyAudioState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Belum ada audio tersimpan',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unduh audio dari halaman podcast agar dapat diputar ulang tanpa internet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
