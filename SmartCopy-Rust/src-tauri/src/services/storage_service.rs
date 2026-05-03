use std::fs;
use std::path::PathBuf;
use std::sync::OnceLock;
use anyhow::Result;
use crate::models::{AppSettings, FolderProfile, ProfilesData};

static DATA_DIR: OnceLock<PathBuf> = OnceLock::new();

pub fn get_data_directory() -> PathBuf {
    if let Some(dir) = DATA_DIR.get() {
        return dir.clone();
    }

    let exe_path = std::env::current_exe().ok();
    let data_dir = if let Some(exe) = exe_path {
        exe.parent()
            .map(|p| p.join("data"))
            .unwrap_or_else(get_default_data_dir)
    } else {
        get_default_data_dir()
    };

    if !data_dir.exists() {
        let _ = fs::create_dir_all(&data_dir);
    }

    DATA_DIR.get_or_init(|| data_dir.clone());
    data_dir
}

fn get_default_data_dir() -> PathBuf {
    dirs::data_local_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("SmartCopy")
        .join("data")
}

pub fn ensure_data_dir() -> Result<PathBuf> {
    let dir = get_data_directory();
    if !dir.exists() {
        fs::create_dir_all(&dir)?;
    }
    Ok(dir)
}

pub struct StorageService;

impl StorageService {
    pub fn new() -> Self {
        let _ = ensure_data_dir();
        Self
    }

    pub fn load_settings() -> Result<AppSettings> {
        let path = get_data_directory().join("settings.json");
        if !path.exists() {
            return Ok(AppSettings::default());
        }
        let content = fs::read_to_string(&path)?;
        let settings: AppSettings = serde_json::from_str(&content)
            .unwrap_or_default();
        Ok(settings)
    }

    pub fn save_settings(settings: &AppSettings) -> Result<()> {
        let path = get_data_directory().join("settings.json");
        let content = serde_json::to_string_pretty(settings)?;
        fs::write(&path, content)?;
        Ok(())
    }

    pub fn load_profiles() -> Result<Vec<FolderProfile>> {
        let path = get_data_directory().join("profiles.json");
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(&path)?;
        let data: ProfilesData = serde_json::from_str(&content)
            .unwrap_or_default();
        Ok(data.profiles)
    }

    pub fn save_profiles(profiles: &[FolderProfile]) -> Result<()> {
        let path = get_data_directory().join("profiles.json");
        let data = ProfilesData {
            profiles: profiles.to_vec(),
        };
        let content = serde_json::to_string_pretty(&data)?;
        fs::write(&path, content)?;
        Ok(())
    }

    pub fn load_task_history() -> Result<Vec<crate::models::CopyTask>> {
        let path = get_data_directory().join("tasks.json");
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(&path)?;
        let tasks: Vec<crate::models::CopyTask> = serde_json::from_str(&content)
            .unwrap_or_default();
        Ok(tasks)
    }

    pub fn append_task(task: &crate::models::CopyTask) -> Result<()> {
        let path = get_data_directory().join("tasks.json");
        let mut tasks = Self::load_task_history().unwrap_or_default();
        tasks.insert(0, task.clone());
        let trimmed: Vec<_> = tasks.into_iter().take(50).collect();
        let content = serde_json::to_string_pretty(&trimmed)?;
        fs::write(&path, content)?;
        Ok(())
    }

    pub fn clear_task_history() -> Result<()> {
        let path = get_data_directory().join("tasks.json");
        fs::write(&path, "[]")?;
        Ok(())
    }

    pub fn get_data_dir_string() -> String {
        get_data_directory().to_string_lossy().to_string()
    }
}
