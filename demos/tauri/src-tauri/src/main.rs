#[cfg(desktop)]
use tauri::Manager;

fn main() {
    let builder = tauri::Builder::default();
    #[cfg(desktop)]
    let builder = builder.plugin(tauri_plugin_single_instance::init(|app, _, _| {
        if let Some(window) = app.get_webview_window("main") {
            let _ = window.unminimize();
            let _ = window.set_focus();
        }
    }));

    builder
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .manage(flare_im_core_sdk_tauri::SdkState::default())
        .invoke_handler(flare_im_core_sdk_tauri::im_invoke_handler())
        .run(tauri::generate_context!())
        .expect("failed to run the Flare Core Tauri demo");
}
