use crate::GLOBAL_DATA;
use crate::data_loader::search_models::SearchResult;
use crate::search_engine;
use flutter_rust_bridge::frb;
use log::{info, error};

#[frb]
pub fn fts_search(query: String) -> Vec<SearchResult> {
    let query_str = query.trim();

    if query_str.is_empty() {
        info!("API: Kueri pencarian kosong, mengembalikan hasil kosong.");
        return Vec::new();
    }

    info!("API: Menerima kueri pencarian: '{}'", query_str);

    // Hanya kirim satu argumen ke search()
    match search_engine::search(query_str) {
        Ok(results) => results,
        Err(err_msg) => {
            error!("API: Terjadi error saat pencarian: {}", err_msg);
            Vec::new()
        }
    }
}
