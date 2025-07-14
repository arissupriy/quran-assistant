// lib/features/search/fts_search_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- Gunakan flutter_riverpod

import 'package:quran_assistant/core/models/fts_search_model.dart_'; // Model hasil pencarian Anda
import 'package:quran_assistant/providers/fts_search_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/search_models.dart'; // Provider pencarian Anda

class FtsSearchPage extends ConsumerStatefulWidget {
  // <-- Ganti menjadi ConsumerStatefulWidget
  const FtsSearchPage({super.key});

  @override
  ConsumerState<FtsSearchPage> createState() => _FtsSearchPageState(); // <-- Ganti menjadi ConsumerState
}

class _FtsSearchPageState extends ConsumerState<FtsSearchPage> {
  // <-- Ganti menjadi ConsumerState
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mengakses state dari provider menggunakan ref.watch
    final ftsSearchState = ref.watch(ftsSearchProvider); // <-- Akses state
    // Mengakses notifier (untuk memanggil metode) menggunakan ref.read
    final ftsSearchNotifier = ref.read(
      ftsSearchProvider.notifier,
    ); // <-- Akses notifier

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pencarian Al-Qur\'an'),
        actions: [
          // --- TOMBOL PENGATURAN ---
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context, ref);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari ayat...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ftsSearchNotifier
                        .clearSearchResults(); // Panggil dari notifier
                  },
                ),
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  ftsSearchNotifier.search(query); // Panggil dari notifier
                } else {
                  ftsSearchNotifier.clearSearchResults();
                }
              },
            ),
          ),
        ),
      ),
      body: _buildBody(
        ftsSearchState,
        ftsSearchNotifier,
      ), // Teruskan state dan notifier
    );
  }

  Widget _buildBody(FtsSearchState state, FtsSearchNotifier notifier) {
    // Terima state dan notifier
    if (state.isLoading) {
      // Akses state
      return const Center(child: CircularProgressIndicator());
    } else if (state.errorMessage != null) {
      // Akses state
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: ${state.errorMessage}', // Akses state
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    } else if (state.searchResults.isEmpty &&
        _searchController.text.isNotEmpty) {
      // Akses state
      return const Center(
        child: Text(
          'Tidak ada hasil ditemukan.',
          style: TextStyle(fontSize: 16.0, color: Colors.grey),
        ),
      );
    } else if (state.searchResults.isEmpty && _searchController.text.isEmpty) {
      // Akses state
      return const Center(
        child: Text(
          'Masukkan kueri untuk mencari ayat.',
          style: TextStyle(fontSize: 16.0, color: Colors.grey),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: state.searchResults.length, // Akses state
        itemBuilder: (context, index) {
          final result = state.searchResults[index]; // Akses state
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.verseKey} (Skor: ${result.score.toStringAsFixed(2)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  _buildVerseWords(
                    result.words,
                    state,
                  ), // Fungsi untuk me-render kata-kata ayat
                  const SizedBox(height: 8.0),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  // Helper untuk me-render kata-kata ayat dengan penyorotan
  Widget _buildVerseWords(List<WordResult> words, FtsSearchState state) {
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      textDirection: TextDirection.rtl, // Mengatur arah teks ke kanan
      children: words.map((word) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: word.highlighted
                ? Colors.yellow.withOpacity(0.5)
                : Colors.transparent, // Warna sorotan
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Builder(
            builder: (context) {
              if (state.showTranslation) {
                return Column(
                  // textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      word.textUthmani,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontFamily: 'UthmaniHafs',
                        color: word.highlighted
                            ? Colors.blue.shade900
                            : Colors.black,
                        fontWeight: word.highlighted
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    ),
                    Text(
                      word.translationText,
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              } else {
                return Text(
                  word.textUthmani,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontFamily: 'UthmaniHafs',
                    color: word.highlighted
                        ? Colors.blue.shade900
                        : Colors.black,
                    fontWeight: word.highlighted
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                );
              }
            },
          ),
        );
      }).toList(),
    );
  }
}

void _showSettingsDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Pengaturan Tampilan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Consumer agar UI switch otomatis update
            Consumer(
              builder: (context, ref, child) {
                final showTranslation = ref
                    .watch(ftsSearchProvider)
                    .showTranslation;
                return SwitchListTile(
                  title: const Text('Tampilkan Terjemahan'),
                  value: showTranslation,
                  // -- TAMBAHKAN PROPERTI WARNA DI SINI --
                  activeColor: Theme.of(context)
                      .colorScheme
                      .primary, // Warna saat aktif (misal: warna utama tema)
                  inactiveThumbColor: Colors.grey, // Warna tombol saat nonaktif
                  inactiveTrackColor: Colors.grey.withOpacity(
                    0.5,
                  ), // Warna track saat nonaktif

                  onChanged: (bool value) {
                    ref
                        .read(ftsSearchProvider.notifier)
                        .toggleShowTranslation();
                  },
                );
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Tutup'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
