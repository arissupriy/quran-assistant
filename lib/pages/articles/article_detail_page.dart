import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quran_assistant/core/models/article_models.dart';
import 'package:quran_assistant/core/storage/saved_content_repository.dart';
import 'package:quran_assistant/providers/article_bookmark_provider.dart';
import 'package:quran_assistant/providers/article_provider.dart';
import 'package:quran_assistant/providers/saved_content_providers.dart';

const String _publicSiteBaseUrl = 'http://192.168.101.20:8000';

class ArticleDetailPage extends ConsumerStatefulWidget {
  const ArticleDetailPage({super.key, required this.articleId});

  final String articleId;

  @override
  ConsumerState<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends ConsumerState<ArticleDetailPage> {
  double fontScale = 1.0;
  bool darkMode = false;
  final Stopwatch _readStopwatch = Stopwatch();
  Article? _lastArticle;

  @override
  void initState() {
    super.initState();
    _readStopwatch.start();
  }

  @override
  void dispose() {
    _readStopwatch.stop();
    unawaited(_logReadHistory());
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(articleDetailProvider(widget.articleId));
    await ref.read(articleDetailProvider(widget.articleId).future);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final articleAsync = ref.watch(articleDetailProvider(widget.articleId));
    final bookmarks = ref.watch(articleBookmarkProvider);
    final isBookmarked = bookmarks.contains(widget.articleId);

  final background = darkMode
    ? const Color(0xFF0F1117)
    : colorScheme.surface;
  final textColor = darkMode ? Colors.white : colorScheme.onSurface;

    final Article? article = articleAsync.valueOrNull;
    if (article != null) {
      _lastArticle = article;
    }

    return Scaffold(
      backgroundColor: background,
      floatingActionButton: article == null
          ? null
          : FloatingActionButton(
              backgroundColor: colorScheme.primary,
              onPressed: () => _showSettingsBottomSheet(article, isBookmarked),
              child: const Icon(Icons.settings_rounded),
            ),
      body: Container(
        color: background,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          displacement: 72,
          child: CustomScrollView(
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: articleAsync.when(
              loading: _buildLoadingSlivers,
              error: (error, _) => _buildErrorSlivers(error),
              data: (article) => _buildArticleSlivers(
                context: context,
                article: article,
                textColor: textColor,
                backgroundColor: background,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoadingSlivers() {
    return const [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ];
  }

  List<Widget> _buildErrorSlivers(Object error) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text('Gagal memuat artikel\n$error', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _onRefresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildArticleSlivers({
    required BuildContext context,
    required Article article,
    required Color textColor,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    return [
      SliverLayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.scrollOffset > 140;
          return SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            backgroundColor: backgroundColor,
            surfaceTintColor: Colors.transparent,
            foregroundColor: textColor,
            title: AnimatedOpacity(
              opacity: collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                article.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.fadeTitle,
              ],
              background: Hero(
                tag: article.heroTag,
                child: CachedNetworkImage(
                  imageUrl: article.featuredImageUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image_rounded, size: 48),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      article.author?.name ?? 'Tanpa penulis',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (_parseHexColor(article.category?.color) ??
                                  theme.colorScheme.primary)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      article.category?.name ??
                          (article.categories.isNotEmpty
                              ? article.categories.first
                              : 'Artikel'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth =
                      (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
                          ? constraints.maxWidth
                          : MediaQuery.of(context).size.width;
                  return Html(
                    data: article.formattedContent ??
                        article.content ??
                        article.excerpt ??
                        '',
                    style: {
                      'body': Style(
                        color: textColor,
                        backgroundColor: Colors.transparent,
                        fontSize: FontSize(16 * fontScale),
                        lineHeight: const LineHeight(1.6),
                        fontFamily: 'Merriweather',
                      ),
                      'img': Style(
                        width: Width(availableWidth, Unit.px),
                        height: Height.auto(),
                        display: Display.block,
                        alignment: Alignment.center,
                        margin: Margins.symmetric(vertical: 12),
                        backgroundColor: Colors.transparent,
                      ),
                      'figure': Style(
                        margin: Margins.symmetric(vertical: 12),
                        padding: HtmlPaddings.zero,
                        alignment: Alignment.center,
                        backgroundColor: Colors.transparent,
                      ),
                    },
                    extensions: [
                      TagExtension(
                        tagsToExtend: const {'img'},
                        builder: (extensionContext) {
                          final rawSrc = extensionContext.attributes['src'];
                          final imageUrl = _resolveContentUrl(rawSrc);
                          if (imageUrl.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final alt = extensionContext.attributes['alt'];

                          Widget buildErrorPlaceholder() {
                            return Container(
                              width: availableWidth,
                              padding: const EdgeInsets.symmetric(
                                vertical: 32,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: textColor.withValues(alpha: 0.6),
                                    size: 32,
                                  ),
                                  if (alt != null && alt.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        alt,
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: textColor.withValues(alpha: 0.7),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: availableWidth),
                                    child: Image.network(
                                      imageUrl,
                                      width: availableWidth,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        final value = progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                            : null;
                                        return SizedBox(
                                          height: availableWidth * 0.6,
                                          child: Center(
                                            child: CircularProgressIndicator(value: value),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) =>
                                          buildErrorPlaceholder(),
                                    ),
                                  ),
                                ),
                                if (alt != null && alt.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      alt,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: textColor.withValues(alpha: 0.75),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ];
  }

  void _showSettingsBottomSheet(Article article, bool isBookmarked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final sheetTheme = Theme.of(context);
        final colorScheme = sheetTheme.colorScheme;
        final switchTheme = sheetTheme.switchTheme.copyWith(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
            }
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurface;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
            }
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary.withValues(alpha: 0.5);
            }
            return colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
          }),
          trackOutlineColor: WidgetStateProperty.all(
            colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32 + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Pengaturan tampilan',
                    style: sheetTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.text_fields_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ukuran huruf'),
                            Slider(
                              value: fontScale,
                              min: 0.8,
                              max: 1.5,
                              divisions: 7,
                              label: fontScale.toStringAsFixed(1),
                              onChanged: (value) {
                                setModalState(() => fontScale = value);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Theme(
                    data: sheetTheme.copyWith(switchTheme: switchTheme),
                    child: SwitchListTile.adaptive(
                      title: const Text('Mode gelap untuk artikel ini'),
                      secondary: Icon(
                        Icons.dark_mode_rounded,
                        color: colorScheme.primary,
                      ),
                      value: darkMode,
                      onChanged: (value) {
                        setModalState(() => darkMode = value);
                        setState(() {});
                      },
                    ),
                  ),
                  const Divider(height: 32),
                  ListTile(
                    leading: Icon(
                      isBookmarked
                          ? Icons.bookmark_remove_rounded
                          : Icons.bookmark_add_rounded,
                    ),
                    title: Text(
                      isBookmarked
                          ? 'Hapus dari bookmark'
                          : 'Simpan ke bookmark',
                    ),
                    onTap: () async {
                      final repo = ref.read(savedContentRepositoryProvider);
                      if (isBookmarked) {
                        await repo.removeArticles([article.id]);
                      } else {
                        await repo.upsertArticle(
                          SavedArticleEntry.fromArticle(article),
                        );
                      }
                      await ref
                          .read(articleBookmarkProvider.notifier)
                          .toggle(widget.articleId);
                      await ref.read(savedArticlesProvider.notifier).refresh();
                      setState(() {});
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_rounded),
                    title: const Text('Bagikan'),
                    onTap: () {
                      final shareUrl =
                          '$_publicSiteBaseUrl/artikel/${article.slug}';
                      Share.share('${article.title}\n$shareUrl');
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logReadHistory() async {
    final article = _lastArticle;
    if (article == null) return;
    final seconds = _readStopwatch.elapsed.inSeconds;
    if (seconds < 5) return;
    final repo = ref.read(savedContentRepositoryProvider);
    final entry = ReadArticleEntry(
      id: article.id,
      title: article.title,
      durationSeconds: seconds,
      readAt: DateTime.now(),
      imageUrl: article.featuredImageUrl,
    );
    await repo.addReadHistory(entry);
    await ref.read(readHistoryProvider.notifier).refresh();
  }

  String _resolveContentUrl(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'http:$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return '$_publicSiteBaseUrl$trimmed';
    }
    return '$_publicSiteBaseUrl/$trimmed';
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6 && cleaned.length != 8) return null;
    try {
      return Color(int.parse('0xff$cleaned'));
    } catch (_) {
      return null;
    }
  }
}
