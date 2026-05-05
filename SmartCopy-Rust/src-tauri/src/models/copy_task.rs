use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum CopyStatus {
    Idle,
    Running,
    Success,
    Failed,
    Cancelled,
}

impl Default for CopyStatus {
    fn default() -> Self {
        Self::Idle
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ConflictResolution {
    Skip,
    Overwrite,
    KeepNewer,
}

impl Default for ConflictResolution {
    fn default() -> Self {
        Self::KeepNewer
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileInfo {
    pub path: String,
    pub relative_path: String,
    pub size: u64,
    pub modified: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DuplicateFile {
    pub source: FileInfo,
    pub dest: FileInfo,
    pub resolution: ConflictResolution,
}

impl DuplicateFile {
    pub fn new(source: FileInfo, dest: FileInfo) -> Self {
        Self {
            source,
            dest,
            resolution: ConflictResolution::Skip,
        }
    }

    pub fn display_path(&self) -> &str {
        &self.source.relative_path
    }

    pub fn is_source_newer(&self) -> bool {
        self.source.modified > self.dest.modified
    }

    pub fn is_same_size(&self) -> bool {
        self.source.size == self.dest.size
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanResult {
    pub all_files: Vec<FileInfo>,
    pub duplicates: Vec<DuplicateFile>,
    pub total_bytes: u64,
    pub total_files: usize,
}

impl Default for ScanResult {
    fn default() -> Self {
        Self {
            all_files: Vec::new(),
            duplicates: Vec::new(),
            total_bytes: 0,
            total_files: 0,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CopyTask {
    pub id: String,
    pub source_path: String,
    pub dest_path: String,
    pub is_directory: bool,
    pub status: CopyStatus,
    pub total_files: usize,
    pub copied_files: usize,
    pub skipped_files: usize,
    pub failed_files: usize,
    pub current_file: Option<String>,
    pub error_message: Option<String>,
    pub started_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
    pub bytes_total: u64,
    pub bytes_copied: u64,
    pub applied_rules: Vec<String>,
    pub speed_bytes_per_second: Option<f64>,
    pub estimated_remaining_seconds: Option<u64>,
}

impl CopyTask {
    pub fn new(id: String, source_path: String, dest_path: String, is_directory: bool) -> Self {
        Self {
            id,
            source_path,
            dest_path,
            is_directory,
            status: CopyStatus::Idle,
            total_files: 0,
            copied_files: 0,
            skipped_files: 0,
            failed_files: 0,
            current_file: None,
            error_message: None,
            started_at: Utc::now(),
            finished_at: None,
            bytes_total: 0,
            bytes_copied: 0,
            applied_rules: Vec::new(),
            speed_bytes_per_second: None,
            estimated_remaining_seconds: None,
        }
    }

    pub fn progress(&self) -> f64 {
        if self.bytes_total == 0 && self.total_files == 0 {
            return 0.0;
        }
        if self.bytes_total > 0 {
            return (self.bytes_copied as f64 / self.bytes_total as f64).clamp(0.0, 1.0);
        }
        (self.copied_files as f64 / self.total_files as f64).clamp(0.0, 1.0)
    }

    pub fn elapsed_seconds(&self) -> i64 {
        let end = self.finished_at.unwrap_or_else(Utc::now);
        (end - self.started_at).num_seconds()
    }

    pub fn is_finished(&self) -> bool {
        matches!(
            self.status,
            CopyStatus::Success | CopyStatus::Failed | CopyStatus::Cancelled
        )
    }

    pub fn status_label(&self) -> &str {
        match self.status {
            CopyStatus::Idle => "等待中",
            CopyStatus::Running => "复制中",
            CopyStatus::Success => "已完成",
            CopyStatus::Failed => "失败",
            CopyStatus::Cancelled => "已取消",
        }
    }

    pub fn source_name_short(&self) -> String {
        let parts = self.source_path.replace('\\', "/").split('/').collect::<Vec<_>>();
        parts.last().unwrap_or(&self.source_path).to_string()
    }

    pub fn update_progress(&mut self, copied: usize, skipped: usize, failed: usize, current: Option<String>) {
        self.copied_files = copied;
        self.skipped_files = skipped;
        self.failed_files = failed;
        self.current_file = current;
    }

    pub fn mark_running(&mut self) {
        self.status = CopyStatus::Running;
        self.started_at = Utc::now();
    }

    pub fn mark_success(&mut self) {
        self.status = CopyStatus::Success;
        self.finished_at = Some(Utc::now());
        if self.total_files == 0 {
            self.total_files = self.copied_files;
        }
    }

    pub fn mark_failed(&mut self, error: String) {
        self.status = CopyStatus::Failed;
        self.error_message = Some(error);
        self.finished_at = Some(Utc::now());
    }

    pub fn mark_cancelled(&mut self) {
        self.status = CopyStatus::Cancelled;
        self.finished_at = Some(Utc::now());
    }

    pub fn calculate_speed(&mut self) {
        let elapsed = self.elapsed_seconds();
        if elapsed > 0 && self.bytes_copied > 0 {
            self.speed_bytes_per_second = Some(self.bytes_copied as f64 / elapsed as f64);
            if self.speed_bytes_per_second.unwrap_or(0.0) > 0.0 {
                let remaining_bytes = self.bytes_total.saturating_sub(self.bytes_copied);
                self.estimated_remaining_seconds = Some(
                    (remaining_bytes as f64 / self.speed_bytes_per_second.unwrap_or(1.0)) as u64
                );
            }
        }
    }
}
