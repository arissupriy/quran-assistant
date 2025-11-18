import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final articleBookmarkProvider =
    StateNotifierProvider<ArticleBookmarkNotifier, Set<String>>((ref) {
  return ArticleBookmarkNotifier();
});

class ArticleBookmarkNotifier extends StateNotifier<Set<String>> {
  ArticleBookmarkNotifier() : super(<String>{}) {
    _load();
  }

  SharedPreferences? _prefs;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final ids = _prefs?.getStringList(_kStorageKey) ?? [];
    state = ids.toSet();
  }

  static const String _kStorageKey = 'article_bookmarks';

  bool isBookmarked(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final newSet = state.contains(id)
        ? (state.toSet()..remove(id))
        : (state.toSet()..add(id));
    state = newSet;
    await _prefs?.setStringList(_kStorageKey, newSet.toList());
  }
}
