import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/storage/data_storage_service.dart';
import 'package:quran_assistant/core/storage/saved_content_repository.dart';

final savedContentRepositoryProvider = Provider<SavedContentRepository>((ref) {
  return SavedContentRepository();
});

class SavedArticlesNotifier
    extends StateNotifier<AsyncValue<List<SavedArticleEntry>>> {
  SavedArticlesNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final SavedContentRepository _repository;

  Future<void> refresh() async {
    try {
      final data = await _repository.loadSavedArticles();
      state = AsyncValue.data(data);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> removeIds(Iterable<String> ids) async {
    await _repository.removeArticles(ids);
    await refresh();
  }

  Future<void> clear() async {
    await _repository.clearArticles();
    await refresh();
  }
}

final savedArticlesProvider =
    StateNotifierProvider<SavedArticlesNotifier, AsyncValue<List<SavedArticleEntry>>>(
  (ref) {
    final repo = ref.watch(savedContentRepositoryProvider);
    return SavedArticlesNotifier(repo);
  },
);

class ReadHistoryNotifier
    extends StateNotifier<AsyncValue<List<ReadArticleEntry>>> {
  ReadHistoryNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final SavedContentRepository _repository;

  Future<void> refresh() async {
    try {
      final data = await _repository.loadReadHistory();
      state = AsyncValue.data(data);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> remove(String id) async {
    await _repository.removeReadHistory(id);
    await refresh();
  }

  Future<void> clear() async {
    await _repository.clearReadHistory();
    await refresh();
  }
}

final readHistoryProvider =
    StateNotifierProvider<ReadHistoryNotifier, AsyncValue<List<ReadArticleEntry>>>(
  (ref) {
    final repo = ref.watch(savedContentRepositoryProvider);
    return ReadHistoryNotifier(repo);
  },
);

class SavedAudioNotifier
    extends StateNotifier<AsyncValue<List<SavedAudioEntry>>> {
  SavedAudioNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final SavedContentRepository _repository;

  Future<void> refresh() async {
    try {
      final data = await _repository.loadSavedAudios();
      state = AsyncValue.data(data);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> remove(String id) async {
    await _repository.removeAudio(id);
    await refresh();
  }

  Future<void> clear() async {
    await _repository.clearAudios();
    await refresh();
  }
}

final savedAudioProvider =
    StateNotifierProvider<SavedAudioNotifier, AsyncValue<List<SavedAudioEntry>>>(
  (ref) {
    final repo = ref.watch(savedContentRepositoryProvider);
    return SavedAudioNotifier(repo);
  },
);

final dataStorageProvider = FutureProvider<List<StorageDataItem>>((ref) async {
  final service = DataStorageService();
  return service.collect();
});
