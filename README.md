# Quran Assistant

Flutter + Rust hybrid app that provides rich Quran exploration tools and, now, curated Islamic article experiences powered by the Laravel dashboard API.

## 🔌 Requirements
- Flutter 3.27+ / Dart 3.8+
- Rust toolchain for the embedded `rust_lib_quran_assistant`
- Local Laravel dashboard API reachable at `http://192.168.101.20:8000`
	- Update `ArticleApiService`'s `baseUrl` if your endpoint differs.

## ✨ Article Experience
- Modern article list with:
	- Animated search bar and inline query handling
	- Featured category grid (2×2) with "Lainnya" entry that opens the full category sheet
	- Horizontal aesthetic cards (image left, content right, category badge top-right)
	- Infinite scroll (per-page 10) + pull-to-refresh
- Article detail page with `SliverAppBar`, hero transitions, and a per-article settings FAB (font scaling, dark mode, share, bookmark toggle).
- Bookmarks persist locally via `SharedPreferences`.

## 🚀 Running the app
```bash
flutter pub get
flutter run -d <device-id>
```

Ensure the Laravel API is running and accessible from your device/emulator; otherwise article calls will fail.

## 🧭 Key paths
- `lib/core/api/article_api_service.dart` – HTTP client targeting the Laravel public endpoints.
- `lib/providers/article_provider.dart` – Riverpod state (pagination, search, categories).
- `lib/pages/articles/*` – UI for list, detail, and category browser.
- `lib/main_screen.dart` – Bottom navigation now includes the Article tab.

## 🧪 Validation
- `flutter analyze lib/...` (see `actions taken` section in the PR description) to keep linting clean.

Feel free to extend the API service or UI components; the new structure keeps article-specific logic compartmentalized.
