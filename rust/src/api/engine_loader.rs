use flutter_rust_bridge::frb;
use std::collections::HashMap;
use anyhow::{Context, Result};

use crate::engine_data_assets::{
    load_all_engine_data_from_assets,
    reset_engine_data,
    // clear_engine_data,
};

/// Fungsi ini dipanggil dari Flutter untuk memuat seluruh EngineData dari assets.
/// Wajib dipanggil sebelum menggunakan fitur seperti pencarian, tafsir, dll.
/// Bisa memuat pertama kali atau override jika sudah ada.
#[frb]
pub fn load_engine_data_from_flutter_assets(map: HashMap<String, Vec<u8>>) -> Result<()> {
    load_all_engine_data_from_assets(map)
        .with_context(|| "Gagal memuat EngineData dari Flutter assets")
}

/// Hanya reset EngineData jika sudah pernah di-load sebelumnya.
/// Akan gagal jika belum pernah dipanggil.
#[frb]
pub fn reset_engine_from_flutter(map: HashMap<String, Vec<u8>>) -> Result<()> {
    reset_engine_data(map)
        .with_context(|| "Gagal reset EngineData (belum pernah di-load?)")
}

