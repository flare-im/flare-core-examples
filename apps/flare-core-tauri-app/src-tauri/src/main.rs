fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .manage(flare_im_core_sdk_tauri::SdkState::default())
        .invoke_handler(flare_im_core_sdk_tauri::im_invoke_handler())
        .run(tauri::generate_context!())
        .expect("failed to run flare core tauri app");
}
