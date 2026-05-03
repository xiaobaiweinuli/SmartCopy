use std::sync::Mutex;
use tauri::{AppHandle, Manager, State};
use crate::models::{
    AppSettings, CopyTask, CopyStatus, ConflictResolution,
    ScanResult, FolderProfile,
};
use crate::services::{CopyEngine, StorageService, logger_service};

pub struct AppState {
    pub copy_engine: CopyEngine,
    pub settings: Mutex<AppSettings>,
    pub profiles: Mutex<Vec<FolderProfile>>,
    pub copy_source: Mutex<Option<String>>,
    pub active_task: Mutex<Option<CopyTask>>,
}

impl AppState {
    pub fn new() -> Self {
        let settings = StorageService::load_settings().unwrap_or_default();
        let profiles = StorageService::load_profiles().unwrap_or_default();

        Self {
            copy_engine: CopyEngine::new(),
            settings: Mutex::new(settings),
            profiles: Mutex::new(profiles),
            copy_source: Mutex::new(None),
            active_task: Mutex::new(None),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}

#[tauri::command]
pub fn get_settings(state: State<'_, AppState>) -> AppSettings {
    state.settings.lock().unwrap().clone()
}

#[tauri::command]
pub fn save_settings(state: State<'_, AppState>, settings: AppSettings) -> Result<(), String> {
    StorageService::save_settings(&settings)
        .map_err(|e| e.to_string())?;
    *state.settings.lock().unwrap() = settings;
    Ok(())
}

#[tauri::command]
pub fn get_profiles(state: State<'_, AppState>) -> Vec<FolderProfile> {
    state.profiles.lock().unwrap().clone()
}

#[tauri::command]
pub fn add_profile(state: State<'_, AppState>, profile: FolderProfile) -> Result<FolderProfile, String> {
    let mut profiles = state.profiles.lock().unwrap();
    let new_profile = FolderProfile {
        id: uuid::Uuid::new_v4().to_string(),
        ..profile
    };
    profiles.push(new_profile.clone());
    StorageService::save_profiles(&profiles)
        .map_err(|e| e.to_string())?;
    Ok(new_profile)
}

#[tauri::command]
pub fn update_profile(state: State<'_, AppState>, profile: FolderProfile) -> Result<(), String> {
    let mut profiles = state.profiles.lock().unwrap();
    if let Some(pos) = profiles.iter().position(|p| p.id == profile.id) {
        profiles[pos] = profile;
        StorageService::save_profiles(&profiles)
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
pub fn delete_profile(state: State<'_, AppState>, id: String) -> Result<(), String> {
    let mut profiles = state.profiles.lock().unwrap();
    profiles.retain(|p| p.id != id);
    StorageService::save_profiles(&profiles)
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub fn set_copy_source(state: State<'_, AppState>, path: String) {
    logger_service::log_info("App", &format!("已标记复制源: {}", path));
    *state.copy_source.lock().unwrap() = Some(path);
}

#[tauri::command]
pub fn clear_copy_source(state: State<'_, AppState>) {
    *state.copy_source.lock().unwrap() = None;
}

#[tauri::command]
pub fn get_copy_source(state: State<'_, AppState>) -> Option<String> {
    state.copy_source.lock().unwrap().clone()
}

#[tauri::command]
pub async fn scan_source(
    state: State<'_, AppState>,
    source_path: String,
    dest_path: String,
) -> Result<ScanResult, String> {
    let settings = state.settings.lock().unwrap().clone();
    let profiles = state.profiles.lock().unwrap();

    let profile = crate::models::find_best_profile(&profiles, &source_path);

    let blacklist_folders: Vec<String> = if settings.merge_global_rules {
        let mut folders = settings.global_blacklist_folders.clone();
        if let Some(p) = profile {
            for f in &p.blacklist_folders {
                if !folders.contains(f) {
                    folders.push(f.clone());
                }
            }
        }
        folders
    } else {
        profile.map(|p| p.blacklist_folders.clone()).unwrap_or_default()
    };

    let blacklist_files: Vec<String> = if settings.merge_global_rules {
        let mut files = settings.global_blacklist_files.clone();
        if let Some(p) = profile {
            for f in &p.blacklist_files {
                if !files.contains(f) {
                    files.push(f.clone());
                }
            }
        }
        files
    } else {
        profile.map(|p| p.blacklist_files.clone()).unwrap_or_default()
    };

    state.copy_engine
        .scan_source_and_detect_duplicates(&source_path, &dest_path, &blacklist_folders, &blacklist_files)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn execute_copy(
    state: State<'_, AppState>,
    dest_path: String,
    resolution: Option<ConflictResolution>,
) -> Result<CopyTask, String> {
    let source_path = state.copy_source.lock().unwrap().clone()
        .ok_or_else(|| "请先设置复制源".to_string())?;

    let settings = state.settings.lock().unwrap().clone();
    let profiles = state.profiles.lock().unwrap();
    let profile = crate::models::find_best_profile(&profiles, &source_path);

    let resolution = resolution.unwrap_or(ConflictResolution::KeepNewer);

    let task = state.copy_engine
        .execute(
            source_path,
            dest_path,
            &settings,
            profile,
            None,
            resolution,
        )
        .await
        .map_err(|e| e.to_string())?;

    if task.status == CopyStatus::Success {
        *state.copy_source.lock().unwrap() = None;
    }

    StorageService::append_task(&task).ok();

    Ok(task)
}

#[tauri::command]
pub fn cancel_copy(state: State<'_, AppState>) {
    state.copy_engine.cancel();
}

#[tauri::command]
pub fn get_task_history() -> Result<Vec<CopyTask>, String> {
    StorageService::load_task_history().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn clear_task_history() -> Result<(), String> {
    StorageService::clear_task_history().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn get_data_directory() -> String {
    StorageService::get_data_dir_string()
}

#[tauri::command]
pub fn import_from_gitignore(state: State<'_, AppState>, content: String) -> Result<usize, String> {
    let mut settings = state.settings.lock().unwrap();
    let mut added = 0;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let is_folder = line.ends_with('/');
        let pattern = line.trim_end_matches('/').to_string();
        if pattern.is_empty() {
            continue;
        }

        if is_folder {
            if !settings.global_blacklist_folders.contains(&pattern) {
                settings.global_blacklist_folders.push(pattern.clone());
                added += 1;
            }
        } else {
            if !settings.global_blacklist_files.contains(&pattern) {
                settings.global_blacklist_files.push(pattern.clone());
                added += 1;
            }
        }
    }

    StorageService::save_settings(&settings).map_err(|e| e.to_string())?;
    logger_service::log_info("App", &format!("从 .gitignore 导入了 {} 条规则", added));

    Ok(added)
}

pub fn run() {
    if let Err(e) = logger_service::init_logger() {
        eprintln!("初始化日志系统失败: {}", e);
    }

    logger_service::log_info("Main", "SmartCopy 启动中...");

    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(AppState::new())
        .invoke_handler(tauri::generate_handler![
            get_settings,
            save_settings,
            get_profiles,
            add_profile,
            update_profile,
            delete_profile,
            set_copy_source,
            clear_copy_source,
            get_copy_source,
            scan_source,
            execute_copy,
            cancel_copy,
            get_task_history,
            clear_task_history,
            get_data_directory,
            import_from_gitignore,
        ])
        .setup(|app| {
            logger_service::log_info("Main", "Tauri 应用已初始化");
            Ok(())
        });

    builder
        .run(tauri::generate_context!())
        .expect("启动 Tauri 应用时发生错误");
}
