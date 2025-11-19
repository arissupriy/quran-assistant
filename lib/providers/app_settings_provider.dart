import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState {
  const AppSettingsState({required this.notificationsEnabled});

  final bool notificationsEnabled;
}

class AppSettingsNotifier extends StateNotifier<AsyncValue<AppSettingsState>> {
  AppSettingsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const _notificationsKey = 'app_notifications_enabled_v1';
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _load() async {
    try {
      final prefs = await _ensurePrefs();
      final enabled = prefs.getBool(_notificationsKey) ?? true;
      state = AsyncValue.data(AppSettingsState(notificationsEnabled: enabled));
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final prefs = await _ensurePrefs();
      await prefs.setBool(_notificationsKey, enabled);
      state = AsyncValue.data(AppSettingsState(notificationsEnabled: enabled));
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
      if (current != null) {
        state = AsyncValue.data(current);
      }
    }
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AsyncValue<AppSettingsState>>(
  (ref) => AppSettingsNotifier(),
);
