import 'package:dio/dio.dart';
import 'package:quran_assistant/core/models/article_models.dart';

/// Thin wrapper around Dio for interacting with the Laravel article endpoints.
class ArticleApiService {
  ArticleApiService({Dio? dio, String? baseUrl})
    : _dio = dio ?? Dio(),
      baseUrl = baseUrl ?? _defaultBaseUrl {
    _dio.options
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 10)
      ..headers.putIfAbsent('Accept', () => 'application/json');
  }

  static const String _defaultBaseUrl = 'http://192.168.101.20:8000/api/public';

  final Dio _dio;
  final String baseUrl;

  Future<ArticleListResponse> fetchArticles({
    int page = 1,
    int perPage = 10,
    String? search,
    bool includeContent = false,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (search != null && search.isNotEmpty) 'search': search,
      if (includeContent) 'include_content': 1,
    };

    final response = await _dio.get(
      '$baseUrl/articles',
      queryParameters: query,
    );

    return ArticleListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Article> fetchArticleDetail(
    String publicId, {
    bool includeContent = true,
  }) async {
    final response = await _dio.get(
      '$baseUrl/articles/$publicId',
      queryParameters: {if (includeContent) 'include_content': 1},
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final payload = data['data'];
      if (payload is Map<String, dynamic>) {
        return Article.fromJson(payload);
      }
      return Article.fromJson(data);
    }

    throw const FormatException('Unexpected article detail response shape');
  }

  Future<List<ArticleCategory>> fetchCategories() async {
    final response = await _dio.get('$baseUrl/categories');
    final data = response.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic>
              ? data['data'] as List<dynamic>?
              : null);

    final categories = (rawList ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ArticleCategory.fromJson)
        .toList();

    return categories;
  }

  Future<ArticleAudioListResponse> fetchArticleAudios({
    int page = 1,
    int perPage = 10,
    String? articleId,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (articleId != null && articleId.isNotEmpty) 'article': articleId,
    };

    final response = await _dio.get(
      '$baseUrl/article-audios',
      queryParameters: query,
    );

    return ArticleAudioListResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
