import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/pages/articles/article_detail_page.dart';
import 'package:quran_assistant/providers/saved_content_providers.dart';

class ReadArticlesPage extends ConsumerWidget {
  const ReadArticlesPage({super.key});

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '< 1 menit';
    final minutes = seconds / 60.0;
    if (minutes < 1) {
      return '${seconds}s dibaca';
    }
    return minutes >= 10
        ? '${minutes.toStringAsFixed(0)} menit dibaca'
        : '${minutes.toStringAsFixed(1)} menit dibaca';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(readHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikel Terbaca'),
        actions: [
          IconButton(
            tooltip: 'Hapus semua',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirm = await _confirm(context,
                  'Hapus seluruh riwayat?', 'Riwayat bacaan tidak dapat dikembalikan.');
              if (confirm == true && context.mounted) {
                await ref.read(readHistoryProvider.notifier).clear();
              }
            },
          ),
        ],
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyHistory();
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(readHistoryProvider.notifier).refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = items[index];
                final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(entry.readAt);
                return Dismissible(
                  key: ValueKey('history_${entry.id}_$index'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    final confirm = await _confirm(
                      context,
                      'Hapus riwayat?',
                      '“${entry.title}” akan dihapus dari riwayat bacaan.',
                    );
                    if (confirm == true && context.mounted) {
                      await ref.read(readHistoryProvider.notifier).remove(entry.id);
                    }
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.redAccent,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withOpacity(0.15),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.teal),
                    ),
                    title: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDuration(entry.durationSeconds)),
                        Text(
                          formattedDate,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArticleDetailPage(articleId: entry.id),
                        ),
                      );
                    },
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Belum ada catatan baca',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Riwayat bacaan muncul otomatis ketika kamu membaca artikel cukup lama.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirm(BuildContext context, String title, String message) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
      ],
    ),
  );
}
