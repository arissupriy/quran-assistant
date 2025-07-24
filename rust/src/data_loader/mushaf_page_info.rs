use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)] // Tambahkan Serialize, Deserialize untuk FRB dan JSON
pub struct MushafPageInfo {
    pub surah_name_arabic: String,
    pub juz_number: u32,
    pub page_number: u32,
    pub next_page_route_text: String, // 1 atau 2 kata dari halaman selanjutnya
    // pub chapter_ids: Vec<u32>, // Tambahkan chapter_id untuk referensi
}