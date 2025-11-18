import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_assistant/core/models/article_models.dart';
import 'package:quran_assistant/pages/articles/article_detail_page.dart';
import 'package:quran_assistant/pages/articles/article_categories_page.dart';
import 'package:quran_assistant/pages/articles/article_audio_detail_page.dart';
import 'package:quran_assistant/providers/article_provider.dart';
import 'package:quran_assistant/widgets/empty_state.dart';

class ArticleListPage extends StatelessWidget {
  const ArticleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: const [
          _ArticleTabSwitcher(),
          Expanded(
            child: TabBarView(
              physics: BouncingScrollPhysics(),
              children: [
                _ArticlesTab(),
                _PodcastTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleTabSwitcher extends StatelessWidget {
  const _ArticleTabSwitcher();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: TabBar(
          splashBorderRadius: BorderRadius.circular(22),
          indicator: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          indicatorPadding: const EdgeInsets.all(4),
          labelStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Artikel'),
            Tab(text: 'Podcast'),
          ],
        ),
      ),
    );
  }
}

class _ArticlesTab extends ConsumerStatefulWidget {
  const _ArticlesTab();

  @override
  ConsumerState<_ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends ConsumerState<_ArticlesTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _isFocused = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _isFocused.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(articleListProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(articleListProvider.notifier).refresh();
  }

  void _performSearch(String query) {
    ref.read(articleListProvider.notifier).refresh(searchQuery: query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(articleListProvider);
    final categories = state.categories;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildSearchBar(context, state)),
          SliverToBoxAdapter(
            child: _CategoryGrid(
              categories: categories,
              onTapCategory: (category) {
                ref
                    .read(articleListProvider.notifier)
                    .refresh(searchQuery: category.name);
              },
              onTapSeeMore: () {
                Navigator.of(context)
                    .push<ArticleCategory?>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ArticleCategoriesPage(categories: categories),
                      ),
                    )
                    .then((selected) {
                      if (selected != null && mounted) {
                        ref
                            .read(articleListProvider.notifier)
                            .refresh(searchQuery: selected.name);
                      }
                    });
              },
            ),
          ),
          if (state.isInitialLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (state.articles.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyState(
                  icon: Icons.article_outlined,
                  title: 'Belum ada artikel',
                  subtitle:
                      'Coba ubah kata kunci atau tarik untuk memuat ulang.',
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final article = state.articles[index];
                return _AnimatedArticleCard(
                  delay: index * 40,
                  child: _ArticleCard(
                    article: article,
                    badgeColor: _resolveBadgeColor(article.category?.color),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ArticleDetailPage(articleId: article.id),
                        ),
                      );
                    },
                  ),
                );
              }, childCount: state.articles.length),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: state.isPaging
                    ? const CircularProgressIndicator()
                    : state.hasMore
                    ? const SizedBox.shrink()
                    : Text(
                        'Sudah sampai akhir',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: Colors.grey),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ArticleListState state) {
    final theme = Theme.of(context);
    if (_searchController.text.isEmpty && state.searchQuery.isNotEmpty) {
      _searchController.text = state.searchQuery;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _isFocused,
            builder: (context, focused, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: focused ? 0.08 : 0.04,
                      ),
                      blurRadius: focused ? 16 : 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performSearch,
                  onChanged: ref
                      .read(articleListProvider.notifier)
                      .updateSearch,
                  onTap: () => _isFocused.value = true,
                  onEditingComplete: () => _isFocused.value = false,
                  decoration: InputDecoration(
                    hintText: 'Cari artikel kajian... ',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PodcastTab extends ConsumerStatefulWidget {
  const _PodcastTab();

  @override
  ConsumerState<_PodcastTab> createState() => _PodcastTabState();
}

class _PodcastTabState extends ConsumerState<_PodcastTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 320) {
      ref.read(articleAudioListProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(articleAudioListProvider.notifier).refresh();
  }

  void _openAudio(BuildContext context, ArticleAudio audio) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleAudioDetailPage(audio: audio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(articleAudioListProvider);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: _PodcastHeader()),
          if (state.isInitialLoading && state.audios.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.audios.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: EmptyState(
                  icon: Icons.podcasts_rounded,
                  title: 'Belum ada audio',
                  subtitle:
                      'Tarik untuk memuat ulang daftar podcast artikel.',
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final audio = state.audios[index];
                return Column(
                  children: [
                    _PodcastCard(
                      audio: audio,
                      onTap: () => _openAudio(context, audio),
                    ),
                    if (index != state.audios.length - 1)
                      const SizedBox(height: 4),
                  ],
                );
              }, childCount: state.audios.length),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  if (state.isPaging) const CircularProgressIndicator(),
                  if (!state.isPaging && !state.hasMore)
                    Text(
                      'Sudah semua podcast 🎧',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.errorMessage!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastHeader extends StatelessWidget {
  const _PodcastHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Podcast kajian terbaru',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dengarkan rekaman audio dari artikel pilihan tim kurasi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastCard extends StatelessWidget {
  const _PodcastCard({required this.audio, required this.onTap});

  final ArticleAudio audio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parentArticle = audio.article;
    final imageUrl = audio.featuredImageUrl ?? parentArticle?.featuredImageUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        elevation: 3,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            height: 130,
            child: Row(
              children: [
                Hero(
                  tag: audio.heroTag,
                  child: _PodcastArtwork(imageUrl: imageUrl),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          audio.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (parentArticle != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.article_outlined,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  parentArticle.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Audio mandiri',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.podcasts_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                audio.audioUrl ?? 'Audio belum tersedia',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: audio.audioUrl == null
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                            const Icon(Icons.play_arrow_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PodcastArtwork extends StatelessWidget {
  const _PodcastArtwork({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
      child: Container(
        width: 110,
        color: Colors.grey.shade200,
        child: imageUrl == null
            ? const Icon(Icons.audiotrack_rounded, size: 36)
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                width: 110,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.onTapCategory,
    required this.onTapSeeMore,
  });

  final List<ArticleCategory> categories;
  final ValueChanged<ArticleCategory> onTapCategory;
  final VoidCallback onTapSeeMore;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayCategories = categories.take(3).toList();
    final hasOverflow = categories.length > 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kategori unggulan',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: hasOverflow ? 4 : displayCategories.length,
            itemBuilder: (context, index) {
              if (hasOverflow && index == 3) {
                return _CategoryCard(
                  title: 'Lainnya',
                  icon: Icons.arrow_forward_rounded,
                  onTap: onTapSeeMore,
                );
              }
              final category = displayCategories[index];
              final color =
                  _resolveBadgeColor(category.color) ??
                  Theme.of(context).colorScheme.primary;
              return _CategoryCard(
                title: category.name,
                color: color,
                onTap: () => onTapCategory(category),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    this.icon,
    this.color,
    required this.onTap,
  });

  final String title;
  final IconData? icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ?? theme.colorScheme.surfaceContainerHighest;
    final backgroundColor = baseColor.withValues(alpha: 0.9);
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: backgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon ?? Icons.local_library_rounded, color: foregroundColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.onTap,
    this.badgeColor,
  });

  final Article article;
  final VoidCallback onTap;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeLabel =
        article.category?.name ??
        (article.categories.isNotEmpty ? article.categories.first : 'Artikel');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        elevation: 4,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 160,
            child: Row(
              children: [
                _ArticleImage(
                  url: article.featuredImageUrl,
                  heroTag: article.heroTag,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? theme.colorScheme.primary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: badgeColor ?? theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(article.publishedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tidak diketahui';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.url, required this.heroTag});

  final String? url;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        child: Container(
          width: 140,
          color: Colors.grey.shade200,
          child: url == null
              ? const Icon(Icons.image_not_supported_outlined)
              : CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  width: 140,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade100,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
        ),
      ),
    );
  }
}

class _AnimatedArticleCard extends StatefulWidget {
  const _AnimatedArticleCard({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  State<_AnimatedArticleCard> createState() => _AnimatedArticleCardState();
}

class _AnimatedArticleCardState extends State<_AnimatedArticleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

Color? _resolveBadgeColor(String? hexColor) {
  if (hexColor == null) return null;
  final value = hexColor.replaceAll('#', '');
  try {
    return Color(int.parse('0xff$value'));
  } catch (_) {
    return null;
  }
}
