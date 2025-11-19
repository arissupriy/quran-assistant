import 'package:shared_preferences/shared_preferences.dart';

class MushafDownloadPreferences {
  static const _initialPageKey = 'mushaf_initial_page';

  static Future<void> setInitialPage(int? page) async {
    final prefs = await SharedPreferences.getInstance();
    if (page == null) {
      await prefs.remove(_initialPageKey);
    } else {
      await prefs.setInt(_initialPageKey, page);
    }
  }

  static Future<int?> getInitialPage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_initialPageKey)) return null;
    return prefs.getInt(_initialPageKey);
  }

  static Future<void> clearInitialPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_initialPageKey);
  }
}
