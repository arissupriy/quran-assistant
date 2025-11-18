import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/api/article_api_service.dart';
import 'package:quran_assistant/core/models/article_models.dart';

final articleApiServiceProvider = Provider<ArticleApiService>((ref) {
  return ArticleApiService();
});

class ArticleListState {
  const ArticleListState({
    this.articles = const [],
    this.categories = const [],
    this.isInitialLoading = false,
    this.isPaging = false,
    this.hasMore = true,
    this.nextPage = 1,
    this.searchQuery = '',
    this.errorMessage,
    this.lastUpdated,
  });

  factory ArticleListState.initial() => const ArticleListState();

  final List<Article> articles;
  final List<ArticleCategory> categories;
  final bool isInitialLoading;
  final bool isPaging;
  final bool hasMore;
  final int nextPage;
  final String searchQuery;
  final String? errorMessage;
  final DateTime? lastUpdated;

  ArticleListState copyWith({
    List<Article>? articles,
    List<ArticleCategory>? categories,
    bool? isInitialLoading,
    bool? isPaging,
    bool? hasMore,
    int? nextPage,
    String? searchQuery,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return ArticleListState(
      articles: articles ?? this.articles,
      categories: categories ?? this.categories,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isPaging: isPaging ?? this.isPaging,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class ArticleListNotifier extends StateNotifier<ArticleListState> {
  ArticleListNotifier(this._api) : super(ArticleListState.initial()) {
    refresh();
  }

  final ArticleApiService _api;

  Future<void> refresh({String? searchQuery}) async {
    final query = searchQuery ?? state.searchQuery;
    state = state.copyWith(
      isInitialLoading: true,
      errorMessage: null,
      searchQuery: query,
      nextPage: 1,
      hasMore: true,
    );

    try {
      final results = await Future.wait<dynamic>([
        _api.fetchArticles(page: 1, search: query),
        _api.fetchCategories().catchError((_) => <ArticleCategory>[]),
      ]);
      final response = results[0] as ArticleListResponse;
      final fetchedCategories = results[1] as List<ArticleCategory>;
      state = state.copyWith(
        articles: response.data,
        categories: _mergeCategories(fetchedCategories, response.data),
        isInitialLoading: false,
        nextPage: response.meta.currentPage + 1,
        hasMore: response.meta.hasMore,
        lastUpdated: DateTime.now(),
      );
    } catch (err) {
      state = state.copyWith(
        isInitialLoading: false,
        errorMessage: err.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isPaging || state.isInitialLoading) {
      return;
    }

    state = state.copyWith(isPaging: true, errorMessage: null);

    try {
      final response = await _api.fetchArticles(
        page: state.nextPage,
        search: state.searchQuery,
      );
      final mergedArticles = [...state.articles, ...response.data];
      state = state.copyWith(
        articles: mergedArticles,
        categories: _mergeCategories(state.categories, response.data),
        isPaging: false,
        nextPage: response.meta.currentPage + 1,
        hasMore: response.meta.hasMore,
        lastUpdated: DateTime.now(),
      );
    } catch (err) {
      state = state.copyWith(isPaging: false, errorMessage: err.toString());
    }
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  List<ArticleCategory> _mergeCategories(
    List<ArticleCategory> existing,
    List<Article> articles,
  ) {
    final Map<String, ArticleCategory> map = {
      for (final category in existing) _categoryKey(category): category,
    };

    for (final article in articles) {
      final category = article.category;
      if (category != null) {
        map.putIfAbsent(_categoryKey(category), () => category);
      }

      for (final label in article.categories) {
        final virtualCategory = ArticleCategory.fromLabel(label);
        map.putIfAbsent(_categoryKey(virtualCategory), () => virtualCategory);
      }
    }

    final categories = map.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  String _categoryKey(ArticleCategory category) {
    final slug = category.slug.trim().toLowerCase();
    if (slug.isNotEmpty) return slug;
    return category.id.toLowerCase();
  }
}

final articleListProvider =
    StateNotifierProvider<ArticleListNotifier, ArticleListState>((ref) {
      final api = ref.watch(articleApiServiceProvider);
      return ArticleListNotifier(api);
    });

final featuredCategoriesProvider = Provider<List<ArticleCategory>>((ref) {
  final state = ref.watch(articleListProvider);
  return state.categories.take(6).toList();
});

final articleDetailProvider = FutureProvider.family<Article, String>((ref, id) {
  final api = ref.watch(articleApiServiceProvider);
  return api.fetchArticleDetail(id, includeContent: true);
});

class ArticleAudioListState {
  const ArticleAudioListState({
    this.audios = const [],
    this.isInitialLoading = false,
    this.isPaging = false,
    this.hasMore = true,
    this.nextPage = 1,
    this.articleFilter,
    this.errorMessage,
  });

  factory ArticleAudioListState.initial() => const ArticleAudioListState();

  final List<ArticleAudio> audios;
  final bool isInitialLoading;
  final bool isPaging;
  final bool hasMore;
  final int nextPage;
  final String? articleFilter;
  final String? errorMessage;

  ArticleAudioListState copyWith({
    List<ArticleAudio>? audios,
    bool? isInitialLoading,
    bool? isPaging,
    bool? hasMore,
    int? nextPage,
    String? articleFilter,
    String? errorMessage,
  }) {
    return ArticleAudioListState(
      audios: audios ?? this.audios,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isPaging: isPaging ?? this.isPaging,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      articleFilter: articleFilter ?? this.articleFilter,
      errorMessage: errorMessage,
    );
  }
}

class ArticleAudioListNotifier extends StateNotifier<ArticleAudioListState> {
  ArticleAudioListNotifier(this._api)
    : super(ArticleAudioListState.initial()) {
    refresh();
  }

  final ArticleApiService _api;

  Future<void> refresh({String? articleId}) async {
    final filter = articleId ?? state.articleFilter;
    state = state.copyWith(
      isInitialLoading: true,
      errorMessage: null,
      hasMore: true,
      nextPage: 1,
      articleFilter: filter,
    );

    try {
      final response = await _api.fetchArticleAudios(
        page: 1,
        articleId: filter,
      );
      state = state.copyWith(
        audios: response.data,
        isInitialLoading: false,
        nextPage: response.meta.currentPage + 1,
        hasMore: response.meta.hasMore,
      );
    } catch (err) {
      state = state.copyWith(
        isInitialLoading: false,
        errorMessage: err.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isPaging || state.isInitialLoading) {
      return;
    }

    state = state.copyWith(isPaging: true, errorMessage: null);

    try {
      final response = await _api.fetchArticleAudios(
        page: state.nextPage,
        articleId: state.articleFilter,
      );

      state = state.copyWith(
        audios: [...state.audios, ...response.data],
        isPaging: false,
        nextPage: response.meta.currentPage + 1,
        hasMore: response.meta.hasMore,
      );
    } catch (err) {
      state = state.copyWith(
        isPaging: false,
        errorMessage: err.toString(),
      );
    }
  }
}

final articleAudioListProvider =
    StateNotifierProvider<ArticleAudioListNotifier, ArticleAudioListState>(
      (ref) {
        final api = ref.watch(articleApiServiceProvider);
        return ArticleAudioListNotifier(api);
      },
    );
