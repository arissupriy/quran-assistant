use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use std::sync::{Arc, Mutex};

// Android-specific imports, callback, and stream holder
#[cfg(target_os = "android")]
use oboe::{
    AudioInputCallback, AudioInputStreamSafe, AudioStream, AudioStreamAsync, AudioStreamBuilder, DataCallbackResult, Input, InputPreset,
    Mono, PerformanceMode, SharingMode,
};

#[cfg(target_os = "android")]
struct MicCallback { buf: SharedBuffer }

#[cfg(target_os = "android")]
impl AudioInputCallback for MicCallback {
    type FrameType = (i16, Mono);
    fn on_audio_ready(&mut self, _stream: &mut dyn AudioInputStreamSafe, frames: &[i16]) -> DataCallbackResult {
        self.buf.push(frames);
        DataCallbackResult::Continue
    }
}

#[cfg(target_os = "android")]
static mut ANDROID_STREAM: Option<AudioStreamAsync<Input, MicCallback>> = None;

#[derive(Default, Clone)]
pub struct SharedBuffer {
    inner: Arc<Mutex<Vec<i16>>>,
}

impl SharedBuffer {
    fn push(&self, data: &[i16]) {
        if let Ok(mut buf) = self.inner.lock() { buf.extend_from_slice(data); }
    }
    fn take(&self) -> Vec<i16> {
        if let Ok(mut buf) = self.inner.lock() { return std::mem::take(&mut *buf); }
        Vec::new()
    }
}

static REC_BUFFER: OnceCell<SharedBuffer> = OnceCell::new();

#[frb]
pub fn recorder_init() { let _ = REC_BUFFER.set(SharedBuffer::default()); }

#[frb]
pub fn recorder_take_samples() -> Vec<i16> { REC_BUFFER.get().cloned().unwrap_or_default().take() }

#[frb]
pub fn recorder_start(sample_rate: i32) -> Result<(), String> {
    #[cfg(target_os = "android")] {
        let buf = REC_BUFFER.get().cloned().unwrap_or_default();
        let builder = AudioStreamBuilder::default()
            .set_input()
            .set_mono()
            .set_i16()
            .set_sample_rate(sample_rate as i32)
            .set_performance_mode(PerformanceMode::LowLatency)
            .set_input_preset(InputPreset::VoiceRecognition)
            .set_sharing_mode(SharingMode::Shared)
            .set_callback(MicCallback { buf });
        let mut stream = builder
            .open_stream()
            .map_err(|e| format!("oboe open_stream: {:?}", e))?;
        stream.start().map_err(|e| format!("oboe start: {:?}", e))?;
    unsafe { ANDROID_STREAM = Some(stream); }
        Ok(())
    }
    #[cfg(not(target_os = "android"))] {
        Err("Recorder hanya didukung di Android".into())
    }
}

#[frb]
pub fn recorder_stop() {
    #[cfg(target_os = "android")] {
    unsafe { if let Some(mut s) = ANDROID_STREAM.take() { let _ = s.stop(); } }
    }
}
