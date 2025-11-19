import 'dart:convert';
import 'dart:io';

import 'package:quran_assistant/core/models/article_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedArticleEntry {
  const SavedArticleEntry({
    required this.id,
    required this.title,
    this.slug,
    this.excerpt,
    this.imageUrl,
    required this.savedAt,
  });

  final String id;
  final String title;
  final String? slug;
  final String? excerpt;
  final String? imageUrl;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'excerpt': excerpt,
        'imageUrl': imageUrl,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedArticleEntry.fromJson(Map<String, dynamic> json) {
    return SavedArticleEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Artikel',
      slug: json['slug'] as String?,
      excerpt: json['excerpt'] as String?,
      imageUrl: json['imageUrl'] as String?,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  factory SavedArticleEntry.fromArticle(Article article, {DateTime? savedAt}) {
    return SavedArticleEntry(
      id: article.id,
      title: article.title,
      slug: article.slug,
      excerpt: article.excerpt,
      imageUrl: article.featuredImageUrl,
      savedAt: savedAt ?? DateTime.now(),
    );
  }
}

class ReadArticleEntry {
  const ReadArticleEntry({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.readAt,
    this.imageUrl,
  });

  final String id;
  final String title;
  final int durationSeconds;
  final DateTime readAt;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'durationSeconds': durationSeconds,
        'readAt': readAt.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory ReadArticleEntry.fromJson(Map<String, dynamic> json) {
    return ReadArticleEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Artikel dibaca',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      readAt: DateTime.tryParse(json['readAt'] as String? ?? '') ?? DateTime.now(),
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class SavedAudioEntry {
  const SavedAudioEntry({
    required this.id,
    required this.title,
    required this.savedAt,
    required this.sizeBytes,
    this.articleId,
    this.articleTitle,
    this.audioUrl,
    this.imageUrl,
    this.filePath,
  });

  final String id;
  final String title;
  final DateTime savedAt;
  final int sizeBytes;
  final String? articleId;
  final String? articleTitle;
  final String? audioUrl;
  final String? imageUrl;
  final String? filePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'savedAt': savedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
        'articleId': articleId,
        'articleTitle': articleTitle,
        'audioUrl': audioUrl,
        'imageUrl': imageUrl,
        'filePath': filePath,
      };

  factory SavedAudioEntry.fromJson(Map<String, dynamic> json) {
    return SavedAudioEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Audio',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      articleId: json['articleId'] as String?,
      articleTitle: json['articleTitle'] as String?,
      audioUrl: json['audioUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      filePath: json['filePath'] as String?,
    );
  }

  ArticleAudio toArticleAudio() {
    return ArticleAudio(
      id: id,
      title: title,
      slug: articleId ?? id,
      audioUrl: audioUrl,
      featuredImageUrl: imageUrl,
      article: articleId == null
          ? null
          : ArticleAudioParent(
              id: articleId!,
              title: articleTitle ?? 'Artikel',
              slug: articleId!,
              featuredImageUrl: imageUrl,
            ),
    );
  }
}

class SavedContentRepository {
  SavedContentRepository();

  SharedPreferences? _prefs;

  static const _articlesKey = 'saved_articles_v1';
  static const _historyKey = 'read_history_v1';
  static const _audioKey = 'saved_audio_v1';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<SavedArticleEntry>> loadSavedArticles() async {
    final prefs = await _ensurePrefs();
    final encoded = prefs.getStringList(_articlesKey) ?? <String>[];
    final entries = encoded
        .map((raw) {
          try {
            return SavedArticleEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedArticleEntry>()
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return entries;
  }

  Future<void> upsertArticle(SavedArticleEntry entry) async {
    final prefs = await _ensurePrefs();
    final articles = await loadSavedArticles();
    final updated = [
      entry,
      ...articles.where((existing) => existing.id != entry.id),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    await prefs.setStringList(
      _articlesKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> removeArticles(Iterable<String> ids) async {
    final prefs = await _ensurePrefs();
    final idSet = ids.toSet();
    final articles = await loadSavedArticles();
    final updated = articles.where((entry) => !idSet.contains(entry.id)).toList();
    await prefs.setStringList(
      _articlesKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> clearArticles() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_articlesKey);
  }

  Future<List<ReadArticleEntry>> loadReadHistory() async {
    final prefs = await _ensurePrefs();
    final encoded = prefs.getStringList(_historyKey) ?? <String>[];
    final entries = encoded
        .map((raw) {
          try {
            return ReadArticleEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ReadArticleEntry>()
        .toList()
      ..sort((a, b) => b.readAt.compareTo(a.readAt));
    return entries;
  }

  Future<void> addReadHistory(ReadArticleEntry entry, {int maxEntries = 200}) async {
    final prefs = await _ensurePrefs();
    final history = await loadReadHistory();
    final updated = [
      entry,
      ...history.where((existing) => !(existing.id == entry.id && existing.readAt == entry.readAt)),
    ];
    if (updated.length > maxEntries) {
      updated.removeRange(maxEntries, updated.length);
    }
    await prefs.setStringList(
      _historyKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> removeReadHistory(String id) async {
    final prefs = await _ensurePrefs();
    final history = await loadReadHistory();
    final updated = history.where((entry) => entry.id != id).toList();
    await prefs.setStringList(
      _historyKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> clearReadHistory() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_historyKey);
  }

  Future<List<SavedAudioEntry>> loadSavedAudios() async {
    final prefs = await _ensurePrefs();
    final encoded = prefs.getStringList(_audioKey) ?? <String>[];
    final entries = <SavedAudioEntry>[];
    var requiresCleanUp = false;
    for (final raw in encoded) {
      try {
        final entry = SavedAudioEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (entry.filePath != null && entry.filePath!.isNotEmpty) {
          final file = File(entry.filePath!);
          if (!file.existsSync()) {
            requiresCleanUp = true;
            continue;
          }
        }
        entries.add(entry);
      } catch (_) {
        requiresCleanUp = true;
      }
    }
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (requiresCleanUp) {
      await prefs.setStringList(
        _audioKey,
        entries.map((e) => jsonEncode(e.toJson())).toList(),
      );
    }
    return entries;
  }

  Future<void> upsertAudio(SavedAudioEntry entry) async {
    final prefs = await _ensurePrefs();
    final audios = await loadSavedAudios();
    final updated = [
      entry,
      ...audios.where((existing) => existing.id != entry.id),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    await prefs.setStringList(
      _audioKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> removeAudio(String id, {bool deleteFile = true}) async {
    final prefs = await _ensurePrefs();
    final audios = await loadSavedAudios();
    SavedAudioEntry? removed;
    final updated = <SavedAudioEntry>[];
    for (final entry in audios) {
      if (entry.id == id) {
        removed = entry;
        continue;
      }
      updated.add(entry);
    }
    await prefs.setStringList(
      _audioKey,
      updated.map((e) => jsonEncode(e.toJson())).toList(),
    );
    if (deleteFile && removed?.filePath != null) {
      final file = File(removed!.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> clearAudios({bool deleteFiles = true}) async {
    final audios = await loadSavedAudios();
    final prefs = await _ensurePrefs();
    await prefs.remove(_audioKey);
    if (deleteFiles) {
      for (final audio in audios) {
        if (audio.filePath == null) continue;
        final file = File(audio.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }
}
