use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FolderProfile {
    pub id: String,
    pub name: String,
    pub folder_path: String,
    pub blacklist_folders: Vec<String>,
    pub blacklist_files: Vec<String>,
    pub enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl FolderProfile {
    pub fn new(id: String, name: String, folder_path: String) -> Self {
        let now = Utc::now();
        Self {
            id,
            name,
            folder_path,
            blacklist_folders: Vec::new(),
            blacklist_files: Vec::new(),
            enabled: true,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn total_rules(&self) -> usize {
        self.blacklist_folders.len() + self.blacklist_files.len()
    }

    pub fn add_folder_rule(&mut self, pattern: String) {
        if !self.blacklist_folders.contains(&pattern) {
            self.blacklist_folders.push(pattern);
            self.updated_at = Utc::now();
        }
    }

    pub fn add_file_rule(&mut self, pattern: String) {
        if !self.blacklist_files.contains(&pattern) {
            self.blacklist_files.push(pattern);
            self.updated_at = Utc::now();
        }
    }

    pub fn remove_folder_rule(&mut self, pattern: &str) {
        self.blacklist_folders.retain(|p| p != pattern);
        self.updated_at = Utc::now();
    }

    pub fn remove_file_rule(&mut self, pattern: &str) {
        self.blacklist_files.retain(|p| p != pattern);
        self.updated_at = Utc::now();
    }

    pub fn with_folder_rules(mut self, patterns: Vec<String>) -> Self {
        self.blacklist_folders = patterns;
        self
    }

    pub fn with_file_rules(mut self, patterns: Vec<String>) -> Self {
        self.blacklist_files = patterns;
        self
    }

    pub fn matches_path(&self, path: &str) -> bool {
        let norm_src = path.replace('\\', "/").to_lowercase();
        let norm_profile_path = self.folder_path.replace('\\', "/").to_lowercase();
        norm_src.starts_with(&norm_profile_path)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfilesData {
    pub profiles: Vec<FolderProfile>,
}

impl Default for ProfilesData {
    fn default() -> Self {
        Self {
            profiles: Vec::new(),
        }
    }
}

pub fn find_best_profile<'a>(profiles: &'a [FolderProfile], source_path: &str) -> Option<&'a FolderProfile> {
    let norm_src = source_path.replace('\\', "/").to_lowercase();
    let mut best: Option<&FolderProfile> = None;
    let mut best_depth: i32 = -1;

    for profile in profiles {
        if !profile.enabled {
            continue;
        }
        let norm_path = profile.folder_path.replace('\\', "/").to_lowercase();
        if norm_src.starts_with(&norm_path) {
            let depth = norm_path.split('/').count() as i32;
            if depth > best_depth {
                best_depth = depth;
                best = Some(profile);
            }
        }
    }

    best
}
