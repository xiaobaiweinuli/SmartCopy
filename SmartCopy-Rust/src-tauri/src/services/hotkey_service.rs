use std::sync::Arc;
use std::collections::HashMap;
use tokio::sync::mpsc;
use global_hotkey::{GlobalHotKeyManager, HotKey, Modifiers, Code};
use crate::models::HotkeyDef;
use crate::services::logger_service;

pub type HotkeyCallback = Box<dyn Fn(HotkeyAction) + Send + Sync>;

#[derive(Debug, Clone)]
pub enum HotkeyAction {
    SmartCopy,
    SmartPaste,
}

pub struct HotkeyService {
    manager: Option<GlobalHotKeyManager>,
    registered_keys: HashMap<HotKey, HotkeyAction>,
    sender: Option<mpsc::Sender<HotkeyAction>>,
}

impl HotkeyService {
    pub fn new() -> Self {
        Self {
            manager: None,
            registered_keys: HashMap::new(),
            sender: None,
        }
    }

    pub fn start(&mut self) -> Result<mpsc::Receiver<HotkeyAction>, String> {
        let manager = GlobalHotKeyManager::new().map_err(|e| e.to_string())?;
        self.manager = Some(manager);

        let (tx, rx) = mpsc::channel::<HotkeyAction>(32);
        self.sender = Some(tx);

        Ok(rx)
    }

    pub fn register(&mut self, hotkey_def: &HotkeyDef, action: HotkeyAction) -> Result<(), String> {
        let manager = self.manager.as_mut().ok_or("热键服务未启动")?;

        let modifiers = {
            let mut m = Modifiers::empty();
            if hotkey_def.ctrl {
                m |= Modifiers::CONTROL;
            }
            if hotkey_def.shift {
                m |= Modifiers::SHIFT;
            }
            if hotkey_def.alt {
                m |= Modifiers::ALT;
            }
            m
        };

        let key_code = self.parse_key_code(&hotkey_def.key)?;

        let hotkey = HotKey::new(Some(modifiers), key_code);

        manager.register(hotkey).map_err(|e| e.to_string())?;

        self.registered_keys.insert(hotkey, action);

        logger_service::log_info("HotkeyService", &format!(
            "已注册热键: {} -> {:?}",
            hotkey_def.display(),
            action
        ));

        Ok(())
    }

    pub fn unregister_all(&mut self) -> Result<(), String> {
        let manager = self.manager.as_mut().ok_or("热键服务未启动")?;

        for hotkey in self.registered_keys.keys() {
            let _ = manager.unregister(*hotkey);
        }

        self.registered_keys.clear();
        logger_service::log_info("HotkeyService", "已注销所有热键");

        Ok(())
    }

    fn parse_key_code(&self, key: &str) -> Result<Code, String> {
        let key_upper = key.to_uppercase();

        match key_upper.as_str() {
            "A" => Ok(Code::KeyA),
            "B" => Ok(Code::KeyB),
            "C" => Ok(Code::KeyC),
            "D" => Ok(Code::KeyD),
            "E" => Ok(Code::KeyE),
            "F" => Ok(Code::KeyF),
            "G" => Ok(Code::KeyG),
            "H" => Ok(Code::KeyH),
            "I" => Ok(Code::KeyI),
            "J" => Ok(Code::KeyJ),
            "K" => Ok(Code::KeyK),
            "L" => Ok(Code::KeyL),
            "M" => Ok(Code::KeyM),
            "N" => Ok(Code::KeyN),
            "O" => Ok(Code::KeyO),
            "P" => Ok(Code::KeyP),
            "Q" => Ok(Code::KeyQ),
            "R" => Ok(Code::KeyR),
            "S" => Ok(Code::KeyS),
            "T" => Ok(Code::KeyT),
            "U" => Ok(Code::KeyU),
            "V" => Ok(Code::KeyV),
            "W" => Ok(Code::KeyW),
            "X" => Ok(Code::KeyX),
            "Y" => Ok(Code::KeyY),
            "Z" => Ok(Code::KeyZ),
            "0" => Ok(Code::Digit0),
            "1" => Ok(Code::Digit1),
            "2" => Ok(Code::Digit2),
            "3" => Ok(Code::Digit3),
            "4" => Ok(Code::Digit4),
            "5" => Ok(Code::Digit5),
            "6" => Ok(Code::Digit6),
            "7" => Ok(Code::Digit7),
            "8" => Ok(Code::Digit8),
            "9" => Ok(Code::Digit9),
            _ => Err(format!("不支持的按键: {}", key)),
        }
    }

    pub fn get_action(&self, hotkey: &HotKey) -> Option<&HotkeyAction> {
        self.registered_keys.get(hotkey)
    }
}

impl Default for HotkeyService {
    fn default() -> Self {
        Self::new()
    }
}
