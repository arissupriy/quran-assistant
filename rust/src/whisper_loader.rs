use std::sync::OnceLock;
use whisper_rs::WhisperContext;

/// Disimpan secara global
static WHISPER_CONTEXT: OnceLock<WhisperContext> = OnceLock::new();

/// Load model Whisper dari Flutter (Vec<u8>) sekali saja
pub fn load_model_from_bytes(data: Vec<u8>) -> Result<(), String> {
    let ctx = WhisperContext::new_from_buffer(data)
        .map_err(|e| format!("Gagal load model: {}", e))?;

    WHISPER_CONTEXT.set(ctx).map_err(|_| "Model sudah dimuat")?;
    Ok(())
}

/// Cek apakah sudah ada model yang dimuat
pub fn is_model_loaded() -> bool {
    WHISPER_CONTEXT.get().is_some()
}

/// Akses referensi model Whisper
pub fn get_model() -> Option<&'static WhisperContext> {
    WHISPER_CONTEXT.get()
}
