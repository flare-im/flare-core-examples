#[cfg(desktop)]
use tauri::Manager;

fn main() {
    let context = tauri::generate_context!();
    let mut builder = tauri::Builder::default();

    #[cfg(desktop)]
    {
        // A second instance does not start: the deep link has reached this one, the window only comes
        // forward. This has to be the first plugin registered.
        builder = builder.plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.unminimize();
                let _ = window.set_focus();
            }
        }));
        // The key and the endpoints only exist at build time (the SDK package's
        // scripts/tauri-build-with-updater.mjs), and never on a store build. Without them the
        // configuration has no such section, and registering the plugin would fail at startup.
        if context.config().plugins.0.contains_key("updater") {
            builder = builder.plugin(tauri_plugin_updater::Builder::new().build());
        }
    }

    builder
        .plugin(tauri_plugin_deep_link::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_process::init())
        .manage(flare_im_core_sdk_tauri::SdkState::default())
        .setup(|_app| {
            // No installer registers the scheme in these two cases.
            #[cfg(any(target_os = "linux", all(debug_assertions, windows)))]
            {
                use tauri_plugin_deep_link::DeepLinkExt;
                _app.deep_link().register_all()?;
            }
            Ok(())
        })
        .invoke_handler(flare_im_core_sdk_tauri::im_invoke_handler())
        .run(context)
        .expect("failed to run flare core tauri app");
}
