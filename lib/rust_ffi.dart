// lib/rust_ffi.dart (di proyek Flutter Anda)

import 'dart:ffi'; // Import pustaka FFI Dart
import 'dart:io' show Platform; // Untuk mendeteksi OS
import 'package:ffi/ffi.dart'; // Untuk String.toNativeUtf8 dan Utf8.toDartString

// Definisikan tipe fungsi Rust
// Contoh: init_engine() di Rust
typedef InitEngineNative = Void Function();
typedef InitEngineDart = void Function();

// Contoh: get_chapters_count() di Rust
typedef GetChaptersCountNative =
    Uint32 Function(); // Mengembalikan u32 (Rust) -> Uint32 (C/Dart)
typedef GetChaptersCountDart = int Function();

// Contoh: get_chapter_name_simple(chapter_id) di Rust
typedef GetChapterNameSimpleNative =
    Pointer<Utf8> Function(
      Uint32 chapterId,
    ); // Mengembalikan *mut c_char -> Pointer<Utf8>
typedef GetChapterNameSimpleDart = Pointer<Utf8> Function(int chapterId);

// Contoh: free_string(ptr) di Rust
typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

// Muat library Rust Anda
final DynamicLibrary rustLib = _openRustLibrary();

DynamicLibrary _openRustLibrary() {
  if (Platform.isAndroid) {
    // Nama file library tanpa 'lib' di depan dan tanpa ekstensi
    // Misalnya: libhafiz_assistant_engine_lib.so -> hafiz_assistant_engine_lib
    return DynamicLibrary.open('libhafiz_assistant_engine.so');
  } else if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.open('libhafiz_assistant_engine.dylib');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('hafiz_assistant_engine.dll');
  } else {
    throw UnsupportedError('Platform tidak didukung.');
  }
}

// Dapatkan pointer ke fungsi-fungsi Rust
final InitEngineDart initEngine = rustLib
    .lookup<NativeFunction<InitEngineNative>>('init_engine')
    .asFunction();

final GetChaptersCountDart getChaptersCount = rustLib
    .lookup<NativeFunction<GetChaptersCountNative>>('get_chapters_count')
    .asFunction();

final GetChapterNameSimpleDart getChapterNameSimple = rustLib
    .lookup<NativeFunction<GetChapterNameSimpleNative>>(
      'get_chapter_name_simple',
    )
    .asFunction();

final FreeStringDart freeString = rustLib
    .lookup<NativeFunction<FreeStringNative>>('free_string')
    .asFunction();

// TODO: Tambahkan binding untuk fungsi FFI lainnya di sini (get_verse_text_uthmani_simple, get_juz_number_for_verse, dll.)
// Contoh: get_verse_text_uthmani_simple
typedef GetVerseTextUthmaniSimpleNative =
    Pointer<Utf8> Function(Pointer<Utf8> verseKey);
typedef GetVerseTextUthmaniSimpleDart =
    Pointer<Utf8> Function(Pointer<Utf8> verseKey);

final GetVerseTextUthmaniSimpleDart getVerseTextUthmaniSimple = rustLib
    .lookup<NativeFunction<GetVerseTextUthmaniSimpleNative>>(
      'get_verse_text_uthmani_simple',
    )
    .asFunction();

typedef GetJuzNumberForVerseNative = Uint32 Function(Pointer<Utf8> verseKey);
typedef GetJuzNumberForVerseDart = int Function(Pointer<Utf8> verseKey);

final GetJuzNumberForVerseDart getJuzNumberForVerse = rustLib
    .lookup<NativeFunction<GetJuzNumberForVerseNative>>(
      'get_juz_number_for_verse',
    )
    .asFunction();

// Fungsi helper untuk mengonversi Dart String ke Pointer<Utf8>
// dan membebaskan memorinya setelah digunakan
String rustStringFromC(Pointer<Utf8> cString) {
  try {
    return cString.toDartString();
  } finally {
    // PENTING: Membebaskan memori yang dialokasikan oleh Rust
    freeString(cString);
  }
}
