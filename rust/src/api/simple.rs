// use once_cell::sync::Lazy;

// use crate::GLOBAL_DATA;

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {

    // Inisialisasi logger hanya sekali, aman walaupun dipanggil berkali-kali
    // let _ = android_logger::init_once(
    //     android_logger::Config::default()
    //         .with_max_level(log::LevelFilter::Debug)
    //         .with_tag("rust_quran"), // ganti sesuai kebutuhan
    // );

    flutter_rust_bridge::setup_default_user_utils();

    
}
