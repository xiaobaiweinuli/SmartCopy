use winreg::enums::*;
use winreg::RegKey;
use std::path::Path;
use crate::services::logger_service;

pub struct RegistryService;

impl RegistryService {
    pub fn new() -> Self {
        Self
    }

    pub fn register_context_menu(&self, exe_path: &str) -> Result<(), String> {
        logger_service::log_info("RegistryService", "开始注册右键菜单...");

        let hkcu = RegKey::predef(HKEY_CURRENT_USER);

        self.register_single_directory_menu(&hkcu, exe_path)?;
        self.register_background_menu(&hkcu, exe_path)?;

        logger_service::log_info("RegistryService", "右键菜单注册成功");
        Ok(())
    }

    fn register_single_directory_menu(&self, hkcu: &RegKey, exe_path: &str) -> Result<(), String> {
        let key_path = r"Software\Classes\Directory\shell\SmartCopy";
        let (key, _) = hkcu.create_subkey(key_path)
            .map_err(|e| format!("创建注册表键失败: {}", e))?;

        key.set_value("", &"SmartCopy")
            .map_err(|e| format!("设置菜单名称失败: {}", e))?;
        key.set_value("Icon", &format!("\"{}\",0", exe_path))
            .map_err(|e| format!("设置图标失败: {}", e))?;

        let cmd_path = format!(r"{}\command", key_path);
        let (cmd_key, _) = hkcu.create_subkey(&cmd_path)
            .map_err(|e| format!("创建命令键失败: {}", e))?;

        cmd_key.set_value("", &format!("\"{}\" --copy \"%1\"", exe_path))
            .map_err(|e| format!("设置命令失败: {}", e))?;

        let paste_key_path = r"Software\Classes\Directory\shell\SmartPasteHere";
        let (paste_key, _) = hkcu.create_subkey(paste_key_path)
            .map_err(|e| format!("创建粘贴菜单键失败: {}", e))?;

        paste_key.set_value("", &"SmartPaste Here")
            .map_err(|e| format!("设置粘贴菜单名称失败: {}", e))?;
        paste_key.set_value("Icon", &format!("\"{}\",0", exe_path))
            .map_err(|e| format!("设置粘贴图标失败: {}", e))?;

        let paste_cmd_path = format!(r"{}\command", paste_key_path);
        let (paste_cmd_key, _) = hkcu.create_subkey(&paste_cmd_path)
            .map_err(|e| format!("创建粘贴命令键失败: {}", e))?;

        paste_cmd_key.set_value("", &format!("\"{}\" --paste \"%1\"", exe_path))
            .map_err(|e| format!("设置粘贴命令失败: {}", e))?;

        Ok(())
    }

    fn register_background_menu(&self, hkcu: &RegKey, exe_path: &str) -> Result<(), String> {
        let bg_path = r"Software\Classes\Directory\Background\shell\SmartPasteHere";
        let (bg_key, _) = hkcu.create_subkey(bg_path)
            .map_err(|e| format!("创建背景右键菜单键失败: {}", e))?;

        bg_key.set_value("", &"SmartPaste Here")
            .map_err(|e| format!("设置背景菜单名称失败: {}", e))?;
        bg_key.set_value("Icon", &format!("\"{}\",0", exe_path))
            .map_err(|e| format!("设置背景图标失败: {}", e))?;

        let bg_cmd_path = format!(r"{}\command", bg_path);
        let (bg_cmd_key, _) = hkcu.create_subkey(&bg_cmd_path)
            .map_err(|e| format!("创建背景命令键失败: {}", e))?;

        bg_cmd_key.set_value("", &format!("\"{}\" --paste \"%V\"", exe_path))
            .map_err(|e| format!("设置背景命令失败: {}", e))?;

        Ok(())
    }

    pub fn unregister_context_menu(&self) -> Result<(), String> {
        logger_service::log_info("RegistryService", "开始注销右键菜单...");

        let hkcu = RegKey::predef(HKEY_CURRENT_USER);

        let paths = [
            r"Software\Classes\Directory\shell\SmartCopy",
            r"Software\Classes\Directory\shell\SmartPasteHere",
            r"Software\Classes\Directory\Background\shell\SmartPasteHere",
        ];

        for path in &paths {
            if hkcu.open_subkey_with_flags(path, KEY_WRITE).is_ok() {
                let _ = hkcu.delete_subkey_all(path);
            }
        }

        logger_service::log_info("RegistryService", "右键菜单已注销");
        Ok(())
    }

    pub fn is_registered(&self) -> bool {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        hkcu.open_subkey(r"Software\Classes\Directory\shell\SmartCopy").is_ok()
    }

    pub fn set_auto_start(&self, enabled: bool, exe_path: &str) -> Result<(), String> {
        logger_service::log_info("RegistryService", if enabled {
            "启用开机自启..."
        } else {
            "禁用开机自启..."
        });

        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        let run_key = hkcu.open_subkey_with_flags(r"Software\Microsoft\Windows\CurrentVersion\Run", KEY_WRITE)
            .map_err(|e| format!("打开 Run 注册表键失败: {}", e))?;

        if enabled {
            run_key.set_value("SmartCopy", &exe_path)
                .map_err(|e| format!("设置开机自启失败: {}", e))?;
            logger_service::log_info("RegistryService", "开机自启已启用");
        } else {
            let _ = run_key.delete_value("SmartCopy");
            logger_service::log_info("RegistryService", "开机自启已禁用");
        }

        Ok(())
    }

    pub fn is_auto_start_enabled(&self) -> bool {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        hkcu.open_subkey(r"Software\Microsoft\Windows\CurrentVersion\Run")
            .map(|key| key.get_value::<String, _>("SmartCopy").is_ok())
            .unwrap_or(false)
    }
}
