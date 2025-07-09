// lib/core/models/chapter_model.dart

// Representasi terjemahan sebuah kata
class WordTranslation {
  final String text;
  final String languageName;

  WordTranslation({
    required this.text,
    required this.languageName,
  });

  factory WordTranslation.fromJson(Map<String, dynamic> json) {
    return WordTranslation(
      text: json['text'] ?? '',
      languageName: json['language_name'] ?? '',
    );
  }
}

// Representasi transliterasi sebuah kata
class WordTransliteration {
  final String? text;
  final String languageName;

  WordTransliteration({
    required this.text,
    required this.languageName,
  });

  factory WordTransliteration.fromJson(Map<String, dynamic> json) {
    return WordTransliteration(
      text: json['text'],
      languageName: json['language_name'] ?? '',
    );
  }
}

// Representasi detail dari satu kata dalam ayat.
class Word {
  final int id;
  final int position;
  final String? audioUrl;
  final String charTypeName;
  final int lineV1;
  final int lineV2;
  final String codeV1;
  final String codeV2;
  final String textQpcHafs;
  final String textUthmani;
  final String textUthmaniSimple;
  final String textUthmaniTajweed;
  final String location;
  final int chapterId;
  final int verseId;
  final String verseKey;
  final int lineNumber;
  final int pageNumber;
  final String text; // This might be redundant if textUthmani is always preferred
  final WordTranslation translation;
  final WordTransliteration transliteration;


  Word({
    required this.id,
    required this.position,
    this.audioUrl,
    required this.charTypeName,
    required this.lineV1,
    required this.lineV2,
    required this.codeV1,
    required this.codeV2,
    required this.textQpcHafs,
    required this.textUthmani,
    required this.textUthmaniSimple,
    required this.textUthmaniTajweed,
    required this.location,
    required this.chapterId,
    required this.verseId,
    required this.verseKey,
    required this.lineNumber,
    required this.pageNumber,
    required this.text,
    required this.translation,
    required this.transliteration,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] ?? 0,
      position: json['position'] ?? 0,
      audioUrl: json['audio_url'],
      charTypeName: json['char_type_name'] ?? '',
      lineV1: json['line_v1'] ?? 0,
      lineV2: json['line_v2'] ?? 0,
      codeV1: json['code_v1'] ?? '',
      codeV2: json['code_v2'] ?? '',
      textQpcHafs: json['text_qpc_hafs'] ?? '',
      textUthmani: json['text_uthmani'] ?? '',
      textUthmaniSimple: json['text_uthmani_simple'] ?? '',
      textUthmaniTajweed: json['text_uthmani_tajweed'] ?? '',
      location: json['location'] ?? '',
      chapterId: json['chapter_id'] ?? 0,
      verseId: json['verse_id'] ?? 0,
      verseKey: json['verse_key'] ?? '',
      lineNumber: json['line_number'] ?? 0,
      pageNumber: json['page_number'] ?? 0,
      text: json['text'] ?? '',
      translation: WordTranslation.fromJson(json['translation'] ?? {}),
      transliteration: WordTransliteration.fromJson(json['transliteration'] ?? {}),
    );
  }
}

// Representasi terjemahan sebuah ayat
class VerseTranslation {
  final int id;
  final int resourceId;
  final String text;

  VerseTranslation({
    required this.id,
    required this.resourceId,
    required this.text,
  });

  factory VerseTranslation.fromJson(Map<String, dynamic> json) {
    return VerseTranslation(
      id: json['id'] ?? 0,
      resourceId: json['resource_id'] ?? 0,
      text: json['text'] ?? '',
    );
  }
}


// Merepresentasikan satu ayat lengkap dengan terjemahannya dan kata-katanya.
class Verse {
  final int id;
  final int verseNumber;
  final String verseKey; // contoh: "2:255"
  final int hizbNumber;
  final int rubElHizbNumber;
  final int rukuNumber;
  final int manzilNumber;
  final int? sajdahNumber;
  final int pageNumber;
  final int juzNumber;
  final List<Word> words;
  final List<VerseTranslation> translations; // Dari Rust `translations`

  Verse({
    required this.id,
    required this.verseNumber,
    required this.verseKey,
    required this.hizbNumber,
    required this.rubElHizbNumber,
    required this.rukuNumber,
    required this.manzilNumber,
    this.sajdahNumber,
    required this.pageNumber,
    required this.juzNumber,
    required this.words,
    required this.translations,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    // Debug print untuk melihat struktur JSON jika ada masalah
    // print('Parsing Verse from JSON: ${jsonEncode(json)}');
    return Verse(
      id: json['id'] ?? 0,
      verseNumber: json['verse_number'] ?? 0,
      verseKey: json['verse_key'] ?? '',
      hizbNumber: json['hizb_number'] ?? 0,
      rubElHizbNumber: json['rub_el_hizb_number'] ?? 0,
      rukuNumber: json['ruku_number'] ?? 0,
      manzilNumber: json['manzil_number'] ?? 0,
      sajdahNumber: json['sajdah_number'], // Nullable
      pageNumber: json['page_number'] ?? 0,
      juzNumber: json['juz_number'] ?? 0,
      words: (json['words'] as List<dynamic>?)
              ?.map((wordJson) => Word.fromJson(wordJson))
              .toList() ??
          [],
      translations: (json['translations'] as List<dynamic>?)
              ?.map((transJson) => VerseTranslation.fromJson(transJson))
              .toList() ??
          [],
    );
  }
}

// Merepresentasikan detail dari satu surah (chapter).
class Chapter {
  final int id;
  final String nameSimple;
  final String nameArabic; // <-- ini yang ingin Anda tampilkan
  final int versesCount;
  final String revelationPlace;
  final int revelationOrder; // Menambahkan field ini
  final bool bismillahPre; // Menambahkan field ini
  final List<int> pages; // Menambahkan field ini
  final TranslatedName translatedName; // Menambahkan field ini

  Chapter({
    required this.id,
    required this.nameSimple,
    required this.nameArabic,
    required this.versesCount,
    required this.revelationPlace,
    required this.revelationOrder,
    required this.bismillahPre,
    required this.pages,
    required this.translatedName,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? 0,
      nameSimple: json['nameSimple'] ?? '', // <-- PERBAIKAN: Gunakan 'nameSimple' (camelCase)
      nameArabic: json['nameArabic'] ?? '', // <-- PERBAIKAN: Gunakan 'nameArabic' (camelCase)
      versesCount: json['versesCount'] ?? 0, // <-- PERBAIKAN: Gunakan 'versesCount' (camelCase)
      revelationPlace: json['revelationPlace'] ?? '', // <-- PERBAIKAN: Gunakan 'revelationPlace' (camelCase)
      revelationOrder: json['revelationOrder'] ?? 0, // <-- PERBAIKAN: Gunakan 'revelationOrder' (camelCase)
      bismillahPre: json['bismillahPre'] ?? false, // <-- PERBAIKAN: Gunakan 'bismillahPre' (camelCase)
      pages: (json['pages'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [], // <-- PERBAIKAN: Gunakan 'pages' (camelCase)
      translatedName: TranslatedName.fromJson(json['translatedName'] ?? {}), // <-- PERBAIKAN: Gunakan 'translatedName' (camelCase)
    );
  }
}

// Tambahkan model TranslatedName jika belum ada di file ini atau file lain
class TranslatedName {
  final String languageName;
  final String name;

  TranslatedName({required this.languageName, required this.name});

  factory TranslatedName.fromJson(Map<String, dynamic> json) {
    return TranslatedName(
      languageName: json['languageName'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

// Untuk AyahText sederhana yang dikembalikan oleh search_ayahs_by_word_form
class AyahText {
  final String verseKey;
  final String text; // Ini adalah text_uthmani dari AyahTextEntry

  AyahText({required this.verseKey, required this.text});

  factory AyahText.fromJson(Map<String, dynamic> json) {
    return AyahText(
      verseKey: json['verse_key'] ?? '',
      text: json['text'] ?? '',
    );
  }
}