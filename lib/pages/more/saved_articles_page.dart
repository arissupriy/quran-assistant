import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/core/storage/saved_content_repository.dart';
import 'package:quran_assistant/pages/articles/article_detail_page.dart';
import 'package:quran_assistant/providers/article_bookmark_provider.dart';
import 'package:quran_assistant/providers/saved_content_providers.dart';

class SavedArticlesPage extends ConsumerStatefulWidget {
  const SavedArticlesPage({super.key});

  @override
  ConsumerState<SavedArticlesPage> createState() => _SavedArticlesPageState();
}

class _SavedArticlesPageState extends ConsumerState<SavedArticlesPage> {
  bool _selectionMode = false;
  final Set<String> _selected = <String>{};

  Future<void> _refresh() async {
    await ref.read(savedArticlesProvider.notifier).refresh();
  }

  void _toggleSelectionMode([bool? value]) {
    setState(() {
      _selectionMode = value ?? !_selectionMode;
      if (!_selectionMode) _selected.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty && _selectionMode) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await _showConfirmDialog(
      context,
      title: 'Hapus ${_selected.length} artikel?',
      message: 'Artikel yang dihapus akan hilang dari daftar tersimpan.',
    );
    if (confirm != true) return;
    final ids = List<String>.from(_selected);
    await ref.read(savedArticlesProvider.notifier).removeIds(ids);
    await ref.read(articleBookmarkProvider.notifier).removeIds(ids);
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteAll() async {
    final confirm = await _showConfirmDialog(
      context,
      title: 'Hapus semua artikel tersimpan?',
      message: 'Tindakan ini tidak dapat dibatalkan.',
      confirmLabel: 'Hapus semua',
    );
    if (confirm != true) return;
    final current = ref.read(savedArticlesProvider).valueOrNull;
    final ids = current?.map((entry) => entry.id).toList() ?? <String>[];
    await ref.read(savedArticlesProvider.notifier).clear();
    await ref.read(articleBookmarkProvider.notifier).removeIds(ids);
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncArticles = ref.watch(savedArticlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikel Tersimpan'),
        actions: [
          if (!_selectionMode)
            IconButton(
              tooltip: 'Pilih banyak',
              onPressed: () => _toggleSelectionMode(true),
              icon: const Icon(Icons.checklist_rounded),
            )
          else
            IconButton(
              tooltip: 'Batalkan pilih',
              onPressed: () => _toggleSelectionMode(false),
              icon: const Icon(Icons.close_rounded),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _deleteAll();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Hapus semua')),
            ],
          ),
        ],
      ),
      body: asyncArticles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Gagal memuat',
          message: error.toString(),
          action: TextButton(
            onPressed: _refresh,
            child: const Text('Coba lagi'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(
              icon: Icons.bookmark_remove_outlined,
              title: 'Belum ada artikel tersimpan',
              message: 'Simpan artikel favoritmu agar mudah dibaca ulang.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final article = items[index];
                return _SavedArticleTile(
                  entry: article,
                  selected: _selected.contains(article.id),
                  selectionMode: _selectionMode,
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(article.id);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArticleDetailPage(articleId: article.id),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    if (!_selectionMode) {
                      _toggleSelectionMode(true);
                    }
                    _toggleSelection(article.id);
                  },
                  onDismissed: () async {
                    final confirm = await _showConfirmDialog(
                      context,
                      title: 'Hapus dari tersimpan?',
                      message: '“${article.title}” akan dihapus dari daftar.',
                    );
                    if (confirm == true && context.mounted) {
                      await ref
                          .read(savedArticlesProvider.notifier)
                          .removeIds([article.id]);
                      await ref
                          .read(articleBookmarkProvider.notifier)
                          .removeIds([article.id]);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: _selectionMode && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: Text('Hapus (${_selected.length})'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Pilih semua',
                      onPressed: () {
                        setState(() {
                          if (_selected.length ==
                              (asyncArticles.valueOrNull?.length ?? 0)) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(
                                asyncArticles.valueOrNull!
                                    .map((entry) => entry.id),
                              );
                          }
                        });
                      },
                      icon: const Icon(Icons.select_all_rounded),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _SavedArticleTile extends StatelessWidget {
  const _SavedArticleTile({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
    required this.selectionMode,
    required this.selected,
  });

  final SavedArticleEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDismissed;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat('dd MMM yyyy • HH:mm').format(entry.savedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Dismissible(
        key: ValueKey('saved_article_${entry.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onDismissed();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    image: entry.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(entry.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey.shade200,
                  ),
                  child: entry.imageUrl == null
                      ? const Icon(Icons.menu_book_rounded, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (entry.excerpt != null)
                        Text(
                          entry.excerpt!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Disimpan $formattedDate',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selectionMode
                      ? Checkbox(
                          value: selected,
                          onChanged: (_) => onTap(),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool?> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
