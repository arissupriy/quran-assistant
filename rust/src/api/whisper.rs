
use flutter_rust_bridge::frb;

use crate::whisper_loader;
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperState};
use std::io::Cursor;
use hound::WavReader;

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

/// Transcribe audio from 16-bit PCM mono samples at a given sample rate.
/// - `pcm_s16_mono` is little-endian i16 samples (e.g., from recorder)
/// - `sample_rate` typically 16000
#[frb]
pub fn transcribe_pcm(pcm_s16_mono: Vec<i16>, _sample_rate: i32) -> Result<String, String> {
    let ctx: &WhisperContext = whisper_loader::get_model().ok_or_else(|| "Model belum dimuat".to_string())?;
    let mut state = ctx.create_state().map_err(map_whisper_err)?;
    run_full(&mut state, &pcm_s16_mono)
}

/// Transcribe audio from WAV bytes. Supports PCM mono/stereo; will downmix to mono.
#[frb]
pub fn transcribe_wav_bytes(wav_bytes: Vec<u8>) -> Result<String, String> {
    let ctx: &WhisperContext = whisper_loader::get_model().ok_or_else(|| "Model belum dimuat".to_string())?;
    let mut reader = WavReader::new(Cursor::new(wav_bytes)).map_err(|e| format!("Gagal baca WAV: {}", e))?;
    let spec = reader.spec();
    // Collect samples as f32, then convert to i16 mono
    let channels = spec.channels.max(1) as usize;

    // Convert to mono f32
    let mut mono: Vec<f32> = Vec::new();
    match spec.sample_format {
        hound::SampleFormat::Int => {
            let bits = spec.bits_per_sample;
            if bits <= 16 {
                let samples: Result<Vec<i16>, _> = reader.samples::<i16>().collect();
                let samples = samples.map_err(|e| format!("Gagal baca sample i16: {}", e))?;
                if channels == 1 {
                    mono = samples.into_iter().map(|s| s as f32 / i16::MAX as f32).collect();
                } else {
                    for frame in samples.chunks(channels) {
                        let sum: i32 = frame.iter().map(|&s| s as i32).sum();
                        mono.push((sum as f32 / channels as f32) / i16::MAX as f32);
                    }
                }
            } else if bits <= 24 {
                // 24-bit packed into i32 in hound via samples::<i32>()
                let samples: Result<Vec<i32>, _> = reader.samples::<i32>().collect();
                let samples = samples.map_err(|e| format!("Gagal baca sample i24/i32: {}", e))?;
                let scale = (1i64 << (bits - 1)) as f32;
                if channels == 1 {
                    mono = samples.into_iter().map(|s| s as f32 / scale).collect();
                } else {
                    for frame in samples.chunks(channels) {
                        let sum: i64 = frame.iter().map(|&s| s as i64).sum();
                        mono.push((sum as f32 / channels as f32) / scale);
                    }
                }
            } else {
                return Err(format!("Bit depth {} tidak didukung", bits));
            }
        }
        hound::SampleFormat::Float => {
            let samples: Result<Vec<f32>, _> = reader.samples::<f32>().collect();
            let samples = samples.map_err(|e| format!("Gagal baca sample f32: {}", e))?;
            if channels == 1 {
                mono = samples;
            } else {
                for frame in samples.chunks(channels) {
                    let sum: f32 = frame.iter().sum();
                    mono.push(sum / channels as f32);
                }
            }
        }
    }

    // Convert f32 mono (-1..1) to i16 for whisper input helper below
    let pcm_i16: Vec<i16> = mono.into_iter().map(|x| (x.clamp(-1.0, 1.0) * i16::MAX as f32) as i16).collect();

    let mut state = ctx.create_state().map_err(map_whisper_err)?;
    run_full(&mut state, &pcm_i16)
}

fn run_full(state: &mut WhisperState, pcm_s16_mono: &[i16]) -> Result<String, String> {
    // Convert i16 PCM to f32 expected by whisper-rs
    let audio: Vec<f32> = pcm_s16_mono.iter().map(|&s| s as f32 / i16::MAX as f32).collect();

    // If sample rate is not 16000, we can still pass; whisper-rs expects 16k f32.
    // For correctness, user should provide 16k. Optionally, do a simple resample (skipped here for speed).

    let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
    params.set_translate(false);
    // Leave language None for auto-detection; set with params.set_language(Some("ar")) if needed.

    state.full(params, &audio).map_err(map_whisper_err)?;

    // Collect segments
    let num_segments = state.full_n_segments().map_err(map_whisper_err)?;
    let mut text = String::new();
    for i in 0..num_segments {
        let seg = state.full_get_segment_text(i).map_err(map_whisper_err)?;
        text.push_str(&seg);
    }
    Ok(text)
}

fn map_whisper_err<E: std::fmt::Display>(e: E) -> String { format!("Whisper error: {}", e) }
