use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HotkeyDef {
    pub key: String,
    pub ctrl: bool,
    pub shift: bool,
    pub alt: bool,
}

impl HotkeyDef {
    pub const fn new(key: String, ctrl: bool, shift: bool, alt: bool) -> Self {
        Self { key, ctrl, shift, alt }
    }

    pub fn display(&self) -> String {
        let mut parts = Vec::new();
        if self.ctrl {
            parts.push("Ctrl".to_string());
        }
        if self.alt {
            parts.push("Alt".to_string());
        }
        if self.shift {
            parts.push("Shift".to_string());
        }
        parts.push(self.key.to_uppercase());
        parts.join(" + ")
    }

    pub const fn default_copy() -> Self {
        Self {
            key: "C".to_string(),
            ctrl: true,
            shift: true,
            alt: false,
        }
    }

    pub const fn default_paste() -> Self {
        Self {
            key: "V".to_string(),
            ctrl: true,
            shift: true,
            alt: false,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ThemeModeSetting {
    System,
    Light,
    Dark,
}

impl Default for ThemeModeSetting {
    fn default() -> Self {
        Self::System
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub smart_copy_hotkey: HotkeyDef,
    pub smart_paste_hotkey: HotkeyDef,
    pub global_blacklist_folders: Vec<String>,
    pub global_blacklist_files: Vec<String>,
    pub auto_start: bool,
    pub minimize_to_tray: bool,
    pub show_notifications: bool,
    pub right_click_menu_enabled: bool,
    pub merge_global_rules: bool,
    pub robocopy_threads: u32,
    pub theme_mode: ThemeModeSetting,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            smart_copy_hotkey: HotkeyDef::default_copy(),
            smart_paste_hotkey: HotkeyDef::default_paste(),
            global_blacklist_folders: vec![
                "node_modules".to_string(),
                ".git".to_string(),
                ".svn".to_string(),
                "__pycache__".to_string(),
                ".idea".to_string(),
                ".vscode".to_string(),
                "dist".to_string(),
                "build".to_string(),
                ".gradle".to_string(),
                ".dart_tool".to_string(),
            ],
            global_blacklist_files: vec![
                "*.log".to_string(),
                "*.tmp".to_string(),
                "*.temp".to_string(),
                "Thumbs.db".to_string(),
                ".DS_Store".to_string(),
                "*.pyc".to_string(),
            ],
            auto_start: false,
            minimize_to_tray: true,
            show_notifications: true,
            right_click_menu_enabled: false,
            merge_global_rules: true,
            robocopy_threads: 8,
            theme_mode: ThemeModeSetting::System,
        }
    }
}

impl AppSettings {
    pub fn new() -> Self {
        Self::default()
    }
}
