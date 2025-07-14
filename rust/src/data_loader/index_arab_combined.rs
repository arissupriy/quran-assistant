use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use bincode::{Encode, Decode}; // <--- TAMBAHKAN INI

/// Merepresentasikan struktur data untuk akar, batang, dan lema yang terkait dengan sebuah kata.
/// Ini digunakan untuk deserialisasi dari JSON dan serialisasi ke biner.
#[derive(Debug, Serialize, Deserialize, Encode, Decode)] // <--- TAMBAHKAN Encode, Decode
pub struct IndexData {
    #[serde(default)] // Gunakan nilai default (vektor kosong) jika bidang tidak ada di JSON
    pub root: Vec<String>,
    #[serde(default)]
    pub stem: Vec<String>,
    #[serde(default)]
    pub lemma: Vec<String>,
}

/// Merepresentasikan struktur keseluruhan dari indeks Arab gabungan.
/// Kunci adalah kata-kata Arab, dan nilainya adalah IndexData.
#[derive(Debug, Serialize, Deserialize, Encode, Decode)] // <--- TAMBAHKAN Encode, Decode
pub struct CombinedIndex {
    #[serde(flatten)] // Meratakan HashMap langsung ke dalam struct
    pub data: HashMap<String, IndexData>,
}