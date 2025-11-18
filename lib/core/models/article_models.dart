import 'dart:convert';

/// Strongly typed models mirroring the Laravel ArticleResource payloads.
class Article {
  Article({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.content,
    this.formattedContent,
    this.featuredImageUrl,
    this.publishedAt,
    this.isVisible = true,
    this.author,
    this.source,
    this.category,
    this.categories = const [],
    this.tags = const [],
    this.audioIds = const [],
  });

  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? content;
  final String? formattedContent;
  final String? featuredImageUrl;
  final DateTime? publishedAt;
  final bool isVisible;
  final ArticleAuthor? author;
  final ArticleSource? source;
  final ArticleCategory? category;
  final List<String> categories;
  final List<String> tags;
  final List<String> audioIds;

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id']?.toString() ?? '',
      title: _extractTitle(json),
      slug: json['slug'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      content: json['content'] as String?,
      formattedContent: json['formatted_content'] as String?,
      featuredImageUrl: json['featured_image_url'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      isVisible: json['is_visible'] as bool? ?? true,
      author: json['author'] != null
          ? ArticleAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      source: json['source'] != null
          ? ArticleSource.fromJson(json['source'] as Map<String, dynamic>)
          : null,
      category: json['category'] != null
          ? ArticleCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      categories: _parseLabelList(json['categories']),
      tags: _parseLabelList(json['tags']),
      audioIds: _parseLabelList(json['audio_ids']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'slug': slug,
    'excerpt': excerpt,
    'content': content,
    'formatted_content': formattedContent,
    'featured_image_url': featuredImageUrl,
    'published_at': publishedAt?.toIso8601String(),
    'is_visible': isVisible,
    'author': author?.toJson(),
    'source': source?.toJson(),
    'category': category?.toJson(),
    'categories': categories,
    'tags': tags,
    'audio_ids': audioIds,
  }..removeWhere((_, value) => value == null);

  String get heroTag => 'article_$id';

  bool matchesCategory(String categorySlugOrId) {
    final target = categorySlugOrId.toLowerCase();
    if (category?.matches(target) ?? false) {
      return true;
    }
    return categories.map(_slugify).any((slug) => slug == target);
  }
}

class ArticleAuthor {
  const ArticleAuthor({this.name, this.url});

  factory ArticleAuthor.fromJson(Map<String, dynamic> json) {
    return ArticleAuthor(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }

  final String? name;
  final String? url;

  Map<String, dynamic> toJson() =>
      {'name': name, 'url': url}..removeWhere((_, value) => value == null);
}

class ArticleSource {
  const ArticleSource({this.name, this.domain});

  factory ArticleSource.fromJson(Map<String, dynamic> json) {
    return ArticleSource(
      name: json['name'] as String?,
      domain: json['domain'] as String?,
    );
  }

  final String? name;
  final String? domain;

  Map<String, dynamic> toJson() =>
      {'name': name, 'domain': domain}
        ..removeWhere((_, value) => value == null);
}

class ArticleCategory {
  const ArticleCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.color,
    this.description,
    this.isVirtual = false,
  });

  factory ArticleCategory.fromJson(Map<String, dynamic> json) {
    final slug = json['slug']?.toString() ?? _slugify(json['name']);
    return ArticleCategory(
      id: json['id']?.toString() ?? slug,
      name: json['name'] as String? ?? 'Kategori',
      slug: slug,
      color: json['color'] as String?,
      description: json['description'] as String?,
    );
  }

  factory ArticleCategory.fromLabel(String label) {
    final slug = _slugify(label);
    return ArticleCategory(id: slug, name: label, slug: slug, isVirtual: true);
  }

  final String id;
  final String name;
  final String slug;
  final String? color;
  final String? description;
  final bool isVirtual;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'color': color,
    'description': description,
  }..removeWhere((_, value) => value == null);

  bool matches(String slugOrId) {
    final normalized = slugOrId.toLowerCase();
    return slug.toLowerCase() == normalized || id.toLowerCase() == normalized;
  }
}

class ArticleListResponse {
  const ArticleListResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory ArticleListResponse.fromJson(Map<String, dynamic> json) {
    return ArticleListResponse(
      data: (json['data'] as List<dynamic>? ?? [])
          .map((item) => Article.fromJson(item as Map<String, dynamic>))
          .toList(),
      links: PaginationLinks.fromJson(
        json['links'] as Map<String, dynamic>? ?? {},
      ),
      meta: PaginationMeta.fromJson(
        json['meta'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  final List<Article> data;
  final PaginationLinks links;
  final PaginationMeta meta;
}

class ArticleAudio {
  const ArticleAudio({
    required this.id,
    required this.title,
    required this.slug,
    this.audioUrl,
    this.featuredImageUrl,
    this.article,
  });

  final String id;
  final String title;
  final String slug;
  final String? audioUrl;
  final String? featuredImageUrl;
  final ArticleAudioParent? article;

  String get heroTag => 'audio_art_$id';

  factory ArticleAudio.fromJson(Map<String, dynamic> json) {
    return ArticleAudio(
      id: json['id']?.toString() ?? '',
      title: _extractTitle(json),
      slug: json['slug'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
      featuredImageUrl: json['featured_image_url'] as String?,
      article: json['article'] is Map<String, dynamic>
          ? ArticleAudioParent.fromJson(json['article'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ArticleAudioParent {
  const ArticleAudioParent({
    required this.id,
    required this.title,
    required this.slug,
    this.featuredImageUrl,
  });

  final String id;
  final String title;
  final String slug;
  final String? featuredImageUrl;

  factory ArticleAudioParent.fromJson(Map<String, dynamic> json) {
    return ArticleAudioParent(
      id: json['id']?.toString() ?? '',
      title: _extractTitle(json),
      slug: json['slug'] as String? ?? '',
      featuredImageUrl: json['featured_image_url'] as String?,
    );
  }
}

class ArticleAudioListResponse {
  const ArticleAudioListResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory ArticleAudioListResponse.fromJson(Map<String, dynamic> json) {
    return ArticleAudioListResponse(
      data: (json['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ArticleAudio.fromJson)
          .toList(),
      links: PaginationLinks.fromJson(
        json['links'] as Map<String, dynamic>? ?? {},
      ),
      meta: PaginationMeta.fromJson(
        json['meta'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  final List<ArticleAudio> data;
  final PaginationLinks links;
  final PaginationMeta meta;
}

class PaginationLinks {
  const PaginationLinks({this.first, this.last, this.prev, this.next});

  factory PaginationLinks.fromJson(Map<String, dynamic> json) {
    return PaginationLinks(
      first: json['first'] as String?,
      last: json['last'] as String?,
      prev: json['prev'] as String?,
      next: json['next'] as String?,
    );
  }

  final String? first;
  final String? last;
  final String? prev;
  final String? next;
}

class PaginationMeta {
  const PaginationMeta({
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 10,
    this.total = 0,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 10,
      total: json['total'] as int? ?? 0,
    );
  }

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

String _slugify(String? value) {
  if (value == null) return '';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().trim().runes) {
    final char = String.fromCharCode(rune);
    if (RegExp(r'[a-z0-9]').hasMatch(char)) {
      buffer.write(char);
    } else if (' -_'.contains(char)) {
      if (buffer.isNotEmpty &&
          buffer.toString().codeUnitAt(buffer.length - 1) != 45) {
        buffer.write('-');
      }
    }
  }
  final slug = buffer.toString();
  return slug.endsWith('-') ? slug.substring(0, slug.length - 1) : slug;
}

String _extractTitle(Map<String, dynamic> json) {
  final candidates = [json['title'], json['name'], json['headline']];
  for (final candidate in candidates) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }

  final slug = json['slug'];
  if (slug is String && slug.trim().isNotEmpty) {
    final cleaned = slug.replaceAll('-', ' ').trim();
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    return slug;
  }

  return 'Untitled';
}

List<String> _parseLabelList(dynamic raw) {
  if (raw is! List) return const [];
  final result = <String>[];
  for (final item in raw) {
    final label = _extractLabel(item);
    if (label != null && label.isNotEmpty) {
      result.add(label);
    }
  }
  return result;
}

String? _extractLabel(dynamic item) {
  if (item == null) return null;
  if (item is String) return item.trim();
  if (item is Map<String, dynamic>) {
    final value = item['name'] ?? item['title'] ?? item['slug'];
    return value?.toString().trim();
  }
  final text = item.toString();
  return text.isEmpty ? null : text.trim();
}

String articleListCacheKey({required int page, String? search}) {
  final payload = {
    'page': page,
    if (search != null && search.isNotEmpty) 'search': search,
  };
  return base64Encode(utf8.encode(jsonEncode(payload)));
}
