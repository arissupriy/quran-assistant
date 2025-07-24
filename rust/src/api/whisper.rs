
use flutter_rust_bridge::frb;

use crate::whisper_loader;

/// Flutter kirim GGML sebagai bytes (model sudah diunduh)
#[frb]
pub fn load_whisper_model_from_flutter(data: Vec<u8>) -> Result<(), String> {
    whisper_loader::load_model_from_bytes(data)
}

/// Cek apakah model sudah dimuat
#[frb]
pub fn is_whisper_model_loaded() -> bool {
    whisper_loader::is_model_loaded()
}
