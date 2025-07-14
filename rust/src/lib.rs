pub mod api;
pub mod models;
mod frb_generated;
mod data_loader;
// mod engine_data_loader;
pub mod search_engine;
pub mod quiz_utils;


// Import EngineData dari modul engine_data_loader
pub mod engine_data_assets;

use once_cell::sync::Lazy;

use crate::engine_data_assets::{get_engine_data, EngineData};


pub static GLOBAL_DATA: Lazy<EngineData> = Lazy::new(|| {
    get_engine_data().expect("❌ EngineData belum pernah di-load dari Flutter")
});
