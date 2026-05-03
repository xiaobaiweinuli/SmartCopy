use tauri::{AppHandle, App};
use tauri::menu::{Menu, MenuItem};
use crate::services::logger_service;

pub struct TrayService;

impl TrayService {
    pub fn new() -> Self {
        Self
    }

    pub fn setup(app: &mut App) {
        logger_service::log_info("TrayService", "正在设置系统托盘...");

        let menu = Menu::with_items(
            app,
            &[
                &MenuItem::with_id(app, "show_window", "显示窗口", true, None::<&str>).unwrap(),
                &MenuItem::with_id(app, "quit", "退出", true, None::<&str>).unwrap(),
            ]
        ).unwrap();

        app.set_tray_icon(tauri::image::Image::from_bytes(include_bytes!("../../icons/32x32.png")).unwrap()).unwrap();
        app.set_tray_menu(Some(menu)).unwrap();
        app.set_tray_icon_tooltip(Some("SmartCopy")).unwrap();

        app.on_menu_event(|app, event| {
            match event.id().as_ref() {
                "show_window" => {
                    logger_service::log_info("TrayService", "显示主窗口");
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.show();
                        let _ = window.set_focus();
                    }
                }
                "quit" => {
                    logger_service::log_info("TrayService", "用户退出应用");
                    app.exit(0);
                }
                _ => {}
            }
        });

        logger_service::log_info("TrayService", "系统托盘设置成功");
    }
}

