// lib/pages/search_page.dart
import 'dart:async'; // Untuk Timer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Impor provider dari file barunya
import 'package:quran_assistant/providers/search_provider.dart'; 
// chapter_model diimpor oleh search_provider.dart, jadi tidak perlu lagi di sini
// (kecuali ada penggunaan langsung Chapter atau AyahTextSearchResult yang tidak melalui provider)
// import 'package:quran_assistant/core/models/search_model.dart'; 
// import 'package:quran_assistant/core/models/chapter_model.dart';


// Widget UI untuk Halaman Pencarian
class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mendapatkan state dari provider
    final searchState = ref.watch(searchProvider);
    // Mendapatkan notifier untuk memanggil method
    final searchNotifier = ref.read(searchProvider.notifier);
    // Gunakan TextEditingController lokal untuk TextField
    final TextEditingController _searchController = TextEditingController(text: searchState.query);

    // Untuk memastikan kursor di akhir teks saat controller diperbarui
    _searchController.selection = TextSelection.collapsed(offset: searchState.query.length);

    Timer? _debounce;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pencarian Ayat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0), // Tinggi AppBar kembali ke 60.0
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController, // Gunakan controller
              decoration: InputDecoration(
                hintText: 'Cari ayat...',
                suffixIcon: searchState.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (searchState.query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear(); // Bersihkan teks di controller
                              searchNotifier.performSearch(''); // Bersihkan pencarian di state
                            },
                          )
                        : null),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              ),
              onChanged: (query) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  searchNotifier.performSearch(query); // Panggilan performSearch tanpa tipe pencarian
                });
              },
              onSubmitted: (query) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                searchNotifier.performSearch(query); // Panggilan performSearch tanpa tipe pencarian
              },
            ),
          ),
        ),
      ),
      body: searchState.isLoading && searchState.results.isEmpty && searchState.query.isNotEmpty
          ? const Center(child: CircularProgressIndicator())
          : searchState.errorMessage != null
              ? Center(child: Text(searchState.errorMessage!))
              : searchState.results.isEmpty && searchState.query.isNotEmpty
                  ? const Center(child: Text('Tidak ada hasil untuk pencarian ini.'))
                  : searchState.query.isEmpty
                      ? const Center(child: Text('Masukkan kata kunci untuk mencari ayat.'))
                      : ListView.builder(
                          itemCount: searchState.results.length,
                          itemBuilder: (context, index) {
                            final ayah = searchState.results[index];
                            final chapterId = int.tryParse(ayah.verseKey.split(':')[0]) ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Tampilkan Nama Surah Arab dan Nomor Ayat
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final chapterDetailsAsync = ref.watch(chapterDetailsProvider(chapterId));
                                        return chapterDetailsAsync.when(
                                          data: (chapter) => Text(
                                            '${chapter?.nameArabic ?? 'Nama Surah Tidak Ditemukan'} : ${ayah.verseKey.split(':')[1]}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.teal,
                                              fontFamily: 'UthmaniHafs',
                                            ),
                                          ),
                                          loading: () => const Text(
                                            'Memuat...',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.teal,
                                            ),
                                          ),
                                          error: (err, stack) => Text(
                                            'Error: $err',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.red,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ayah.textUthmani, // Teks Uthmani dari AyahTextSearchResult
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontFamily: 'UthmaniHafs',
                                        fontSize: 20,
                                        height: 1.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
    );
  }
}