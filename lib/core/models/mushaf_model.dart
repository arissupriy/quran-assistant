// lib/core/models/mushaf_model.dart

// Representasi data kata di konteks PageLayout (WordData di Rust)
class MushafWordData {
  final int id;
  final int pageNumber;
  final int lineNumber;
  final int position;
  final String verseKey;
  final String charType; // e.g., "word", "end"
  final String textUthmani;
  final String? textIndopak; // Optional
  final int? rubElHizb; // Optional
  final String location;

  MushafWordData({
    required this.id,
    required this.pageNumber,
    required this.lineNumber,
    required this.position,
    required this.verseKey,
    required this.charType,
    required this.textUthmani,
    this.textIndopak,
    this.rubElHizb,
    required this.location,
  });

  factory MushafWordData.fromJson(Map<String, dynamic> json) {
    // Asumsi semua key di MushafWordData juga snake_case di JSON Rust
    return MushafWordData(
      id: json['id'] ?? 0,
      pageNumber: json['page_number'] ?? 0,
      lineNumber: json['line_number'] ?? 0,
      position: json['position'] ?? 0,
      verseKey: json['verse_key'] ?? '',
      charType: json['char_type'] ?? '',
      textUthmani: json['text_uthmani'] ?? '',
      textIndopak: json['text_indopak'],
      rubElHizb: json['rub_el_hizb'],
      location: json['location'] ?? '',
    );
  }
}

// Representasi satu baris dalam halaman (sesuai enum Line di Rust)
enum LineType {
  ayah,
  basmallah,
  sajdah,
  surahName,
  page,
  juz,
  ruku,
  manzil,
  hizb,
  rubElHizb, // from Rust's rub_el_hizb
  end,
  unknown,
}

class Line {
  final LineType type;
  final List<MushafWordData> words; // Hanya jika Ayah atau Basmallah
  final int? chapterId; // Hanya jika SurahName
  final String? verseKey; // Jika Ayah
  final String? text; // Untuk Sajdah, SurahName (nama), Juz, Ruku, Manzil, Hizb, RubElHizb, Page
  final int? verseMarker; // Hanya jika Ayah, untuk menandai posisi ayat dalam baris

  Line._({
    required this.type,
    this.words = const [],
    this.chapterId,
    this.verseKey,
    this.text,
    this.verseMarker,
  });

  factory Line.fromJson(Map<String, dynamic> json) {
    // Logging yang lebih agresif
    print('DEBUG_LINE_PARSE: Input to Line.fromJson: $json (Type: ${json.runtimeType})');
    if (json.isEmpty) {
      print('DEBUG_LINE_PARSE: WARNING: Empty JSON passed to Line.fromJson');
      return Line._(type: LineType.unknown);
    }
    
    // Perbaikan utama: Ambil tag 'type' langsung yang ada di level Map
    final String typeTag = json['type'] as String? ?? 'unknown'; // Get the 'type' field from the map
    print('DEBUG_LINE_PARSE: Identified type tag: "$typeTag"');

    switch (typeTag) { // Switch pada nilai string dari tag 'type'
      case 'surah_name': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.surahName,
          chapterId: json['chapterId'] as int?, // Asumsi chapterId di JSON adalah camelCase
          text: json['text'] as String?,
        );
      case 'basmallah': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.basmallah,
          words: (json['words'] as List<dynamic>?)
                  ?.map((e) => MushafWordData.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
        );
      case 'ayah': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.ayah,
          words: (json['words'] as List<dynamic>?)
                  ?.map((e) => MushafWordData.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
          verseKey: json['verseKey'] as String?, // Asumsi verseKey di JSON adalah camelCase
          // verseId: json['verseId'] as int?, // Jika ada di JSON, tambahkan field di class Line
          verseMarker: json['verseMarker'] as int?, // Asumsi verseMarker di JSON adalah camelCase
        );
      case 'sajdah': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.sajdah,
          text: json['text'] as String?, // Text adalah nilai langsung dari field 'text'
        );
      case 'juz': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.juz,
          text: json['text'] as String?,
        );
      case 'ruku': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.ruku,
          text: json['text'] as String?,
        );
      case 'manzil': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.manzil,
          text: json['text'] as String?,
        );
      case 'hizb': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.hizb,
          text: json['text'] as String?,
        );
      case 'rub_el_hizb': // Ini adalah tag string dari JSON (Rust akan mengubah snake_case ke snake_case di tag jika tidak ada rename)
        return Line._(
          type: LineType.rubElHizb,
          text: json['text'] as String?,
        );
      case 'page': // Ini adalah tag string dari JSON
        return Line._(
          type: LineType.page,
          text: json['text'] as String?,
        );
      case 'end': // Ini adalah tag string dari JSON
        return Line._(type: LineType.end);
      default:
        print('DEBUG_LINE_PARSE: Unknown LineType key (tag value): $typeTag. Full JSON: $json');
        return Line._(type: LineType.unknown);
    }
  }
}


// Merepresentasikan data satu halaman lengkap dalam mode mushaf.
class PageLayout {
  final int page; // From Rust 'page'
  final List<Line> lines; // Represents content lines on the page

  PageLayout({
    required this.page,
    required this.lines,
  });

  factory PageLayout.fromJson(Map<String, dynamic> json) {
    print('DEBUG_PAGELAYOUT_LINES: Input JSON to PageLayout.fromJson: $json'); 
    final rawLines = json['lines'] as List<dynamic>?;
    print('DEBUG_PAGELAYOUT_LINES: Raw lines list: $rawLines (Type: ${rawLines.runtimeType})'); 


    return PageLayout(
      page: json['page'] ?? 0,
      lines: rawLines
              ?.map((lineJson) {
                // LOGGING DETAIL UNTUK SETIAP ITEM LINE
                print('DEBUG_PAGELAYOUT_LINES: Mapping line item: $lineJson (Type: ${lineJson.runtimeType})'); 
                if (lineJson is! Map<String, dynamic>) {
                  // Ini seharusnya menangkap error jika lineJson bukan Map
                  print('DEBUG_PAGELAYOUT_LINES: CRITICAL ERROR: lineJson is NOT a Map! It is a ${lineJson.runtimeType}. Value: $lineJson'); 
                  return Line._(type: LineType.unknown); // Fallback
                }
                return Line.fromJson(lineJson);
              })
              .toList() ??
          [],
    );
  }
}