use flutter_rust_bridge::frb;
use std::collections::HashMap;
use anyhow::{Context, Result};
use log::{info, error};

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
    info!("📥 Memulai load EngineData dari Flutter assets...");

    match load_all_engine_data_from_assets(map) {
        Ok(_) => {
            info!("✅ Berhasil load EngineData dari Flutter assets");
            Ok(())
        },
        Err(e) => {
            error!("❌ Gagal load EngineData dari Flutter assets: {:#}", e);
            Err(e).context("❌ Gagal memuat EngineData dari Flutter assets")
        }
    }
}

#[frb]
pub fn reset_engine_from_flutter(map: HashMap<String, Vec<u8>>) -> Result<()> {
    info!("🔄 Memulai reset EngineData dari Flutter...");

    match reset_engine_data(map) {
        Ok(_) => {
            info!("✅ Berhasil reset EngineData");
            Ok(())
        },
        Err(e) => {
            error!("❌ Gagal reset EngineData: {:#}", e);
            Err(e).context("❌ Gagal reset EngineData (belum pernah di-load?)")
        }
    }
}
