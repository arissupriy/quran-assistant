import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart'; // Import AppTheme
// Hapus import CustomAppBar karena tidak lagi digunakan di sini
// import 'package:quran_assistant/widgets/custom_navigation_widgets.dart';

import 'package:quran_assistant/core/models/fts_search_model.dart_'; // Model hasil pencarian Anda
import 'package:quran_assistant/providers/fts_search_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/search_models.dart'; // Provider pencarian Anda

class FtsSearchPage extends ConsumerStatefulWidget {
  const FtsSearchPage({super.key});

  @override
  ConsumerState<FtsSearchPage> createState() => _FtsSearchPageState();
}

class _FtsSearchPageState extends ConsumerState<FtsSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ftsSearchState = ref.watch(ftsSearchProvider);
    final ftsSearchNotifier = ref.read(ftsSearchProvider.notifier);

    // Hapus Scaffold dan AppBar di sini.
    // Konten FtsSearchPage akan menjadi body dari Scaffold di MainScreen.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0), // Padding lebih besar
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari ayat...',
              // Gaya input decoration sudah diatur di AppTheme
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppTheme.secondaryTextColor), // Warna ikon clear
                      onPressed: () {
                        _searchController.clear();
                        ftsSearchNotifier.clearSearchResults();
                      },
                    )
                  : null,
              prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor), // Ikon search di awal
            ),
            onSubmitted: (query) {
              if (query.isNotEmpty) {
                ftsSearchNotifier.search(query);
              } else {
                ftsSearchNotifier.clearSearchResults();
              }
            },
            onChanged: (query) {
              // Memperbarui UI untuk menampilkan/menyembunyikan tombol clear
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: _buildBody(
            ftsSearchState,
            ftsSearchNotifier,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(FtsSearchState state, FtsSearchNotifier notifier) {
    if (state.isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)); // Warna loading
    } else if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: ${state.errorMessage}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error), // Warna error dari tema
          ),
        ),
      );
    } else if (state.searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text(
          'Tidak ada hasil ditemukan.',
          style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor), // Warna teks
        ),
      );
    } else if (state.searchResults.isEmpty && _searchController.text.isEmpty) {
      return Center(
        child: Text(
          'Masukkan kueri untuk mencari ayat.',
          style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor), // Warna teks
        ),
      );
    } else {
      return ListView.builder(
        itemCount: state.searchResults.length,
        itemBuilder: (context, index) {
          final result = state.searchResults[index];
          return Card(
            // Gaya Card sudah diatur di AppTheme
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Margin disesuaikan
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.verseKey}', // Hapus skor jika tidak diperlukan di UI
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.0, // Ukuran font lebih besar
                      color: AppTheme.textColor, // Warna teks
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  _buildVerseWords(
                    result.words,
                    state,
                  ),
                  const SizedBox(height: 8.0),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'Skor: ${result.score.toStringAsFixed(2)}', // Skor di pojok kanan bawah
                      style: TextStyle(
                        fontSize: 12.0,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ),
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
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0), // Padding disesuaikan
          decoration: BoxDecoration(
            color: word.highlighted
                ? AppTheme.secondaryColor.withOpacity(0.3) // Warna sorotan dari tema
                : Colors.transparent, // Warna sorotan
            borderRadius: BorderRadius.circular(8.0), // Sudut membulat
          ),
          child: Builder(
            builder: (context) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end, // Teks Arab ke kanan
                children: [
                  Text(
                    word.textUthmani,
                    style: TextStyle(
                      fontSize: 20.0, // Ukuran font Arab lebih besar
                      fontFamily: 'UthmanicHafs',
                      color: word.highlighted
                          ? AppTheme.primaryColor // Warna teks sorotan dari tema
                          : AppTheme.textColor, // Warna teks normal dari tema
                      fontWeight: word.highlighted
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                  if (state.showTranslation && word.translationText != null && word.translationText!.isNotEmpty)
                    Text(
                      word.translationText!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: AppTheme.secondaryTextColor, // Warna terjemahan dari tema
                      ),
                      textAlign: TextAlign.right, // Terjemahan juga ke kanan
                      textDirection: TextDirection.rtl, // Terjemahan juga ke kanan
                    ),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor, // Latar belakang dialog dari tema
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Sudut membulat
          ),
          title: Text(
            'Pengaturan Tampilan',
            style: TextStyle(color: AppTheme.textColor), // Warna judul dialog
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final showTranslation = ref.watch(ftsSearchProvider).showTranslation;
                  return SwitchListTile(
                    title: Text(
                      'Tampilkan Terjemahan',
                      style: TextStyle(color: AppTheme.textColor), // Warna teks switch
                    ),
                    value: showTranslation,
                    activeColor: AppTheme.primaryColor, // Warna aktif dari tema
                    inactiveThumbColor: AppTheme.secondaryTextColor.withOpacity(0.5), // Warna tombol nonaktif
                    inactiveTrackColor: AppTheme.secondaryTextColor.withOpacity(0.2), // Warna track nonaktif

                    onChanged: (bool value) {
                      ref.read(ftsSearchProvider.notifier).toggleShowTranslation();
                    },
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Tutup',
                style: TextStyle(color: AppTheme.primaryColor), // Warna teks tombol dialog
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
