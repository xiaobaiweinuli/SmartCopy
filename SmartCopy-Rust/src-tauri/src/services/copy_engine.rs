use std::collections::HashMap;
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::time::Instant;
use anyhow::Result;
use ignore::gitignore::GitignoreBuilder;
use chrono::{DateTime, Utc};
use crate::models::{
    AppSettings, CopyTask, CopyStatus, ConflictResolution,
    FileInfo, DuplicateFile, ScanResult, FolderProfile,
};
use crate::services::logger_service;

pub struct CopyEngine {
    current_task: Arc<Mutex<Option<CopyTask>>>,
    current_process: Arc<Mutex<Option<std::process::Child>>>,
    file_info_map: Arc<Mutex<Option<HashMap<String, FileInfo>>>>,
    total_bytes_from_scan: Arc<Mutex<u64>>,
}

impl CopyEngine {
    pub fn new() -> Self {
        Self {
            current_task: Arc::new(Mutex::new(None)),
            current_process: Arc::new(Mutex::new(None)),
            file_info_map: Arc::new(Mutex::new(None)),
            total_bytes_from_scan: Arc::new(Mutex::new(0)),
        }
    }

    pub fn is_running(&self) -> bool {
        if let Ok(task_guard) = self.current_task.lock() {
            if let Some(ref task) = *task_guard {
                return task.status == CopyStatus::Running;
            }
        }
        false
    }

    pub fn scan_source_and_detect_duplicates(
        &self,
        source_path: &str,
        dest_path: &str,
        blacklist_folders: &[String],
        blacklist_files: &[String],
    ) -> Result<ScanResult> {
        logger_service::log_info("CopyEngine", &format!("开始预扫描目录: {}", source_path));

        let path = Path::new(source_path);
        let is_dir = path.is_dir();

        let mut all_files = Vec::new();
        let mut duplicates = Vec::new();
        let mut total_bytes: u64 = 0;

        let mut folder_matcher = GitignoreBuilder::new("");
        for folder in blacklist_folders {
            let _ = folder_matcher.add_line(folder);
        }
        let folder_glob = folder_matcher.build()?;

        let mut file_matcher = GitignoreBuilder::new("");
        for file in blacklist_files {
            let _ = file_matcher.add_line(file);
        }
        let file_glob = file_matcher.build()?;

        let source_path_for_relative = source_path.to_string();

        if is_dir {
            for entry in walkdir::WalkDir::new(source_path)
                .follow_links(false)
                .into_iter()
                .filter_map(|e| e.ok())
            {
                let entry_path = entry.path();
                if entry_path.is_file() {
                    let relative_path = entry_path
                        .strip_prefix(&source_path_for_relative)
                        .unwrap_or(entry_path)
                        .to_string_lossy()
                        .replace('\\', "/");

                    let file_name = entry_path
                        .file_name()
                        .map(|n| n.to_string_lossy().to_string())
                        .unwrap_or_default();

                    if let ignore::Match::Ignore(_) = file_glob.matched(&file_name, false) {
                        continue;
                    }

                    let path_parts: Vec<&str> = relative_path.split('/').collect();
                    let mut should_skip = false;
                    for i in 0..path_parts.len().saturating_sub(1) {
                        if let ignore::Match::Ignore(_) = folder_glob.matched(path_parts[i], false) {
                            should_skip = true;
                            break;
                        }
                    }
                    if should_skip {
                        continue;
                    }

                    if let Ok(metadata) = entry_path.metadata() {
                        let modified: DateTime<Utc> = metadata.modified()
                            .map(|t| t.into())
                            .unwrap_or_else(|_| Utc::now());

                        let file_info = FileInfo {
                            path: entry_path.to_string_lossy().to_string(),
                            relative_path: relative_path.clone(),
                            size: metadata.len(),
                            modified,
                        };

                        all_files.push(file_info.clone());
                        total_bytes += metadata.len();

                        let src_name = Path::new(source_path)
                            .file_name()
                            .map(|n| n.to_string_lossy().to_string())
                            .unwrap_or_default();
                        let final_dest_dir = Path::new(dest_path).join(&src_name);
                        let dest_file_path = final_dest_dir.join(&relative_path);
                        let dest_file = Path::new(&dest_file_path);

                        if dest_file.exists() {
                            if let Ok(dest_metadata) = dest_file.metadata() {
                                let dest_modified: DateTime<Utc> = dest_metadata.modified()
                                    .map(|t| t.into())
                                    .unwrap_or_else(|_| Utc::now());
                                let dest_file_info = FileInfo {
                                    path: dest_file_path.to_string_lossy().to_string(),
                                    relative_path: relative_path.clone(),
                                    size: dest_metadata.len(),
                                    modified: dest_modified,
                                };
                                duplicates.push(DuplicateFile::new(file_info, dest_file_info));
                            }
                        }
                    }
                }
            }
        } else {
            let file_name = path
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_default();

            if let ignore::Match::Ignore(_) = file_glob.matched(&file_name, false) {
                return Ok(ScanResult::default());
            }

            if let Ok(metadata) = entry_path.metadata() {
                let modified: DateTime<Utc> = metadata.modified()
                    .map(|t| t.into())
                    .unwrap_or_else(|_| Utc::now());

                let file_info = FileInfo {
                    path: source_path.to_string(),
                    relative_path: file_name.clone(),
                    size: metadata.len(),
                    modified,
                };

                all_files.push(file_info.clone());
                total_bytes += metadata.len();

                let dest_file_path = Path::new(dest_path).join(&file_name);
                let dest_file = Path::new(&dest_file_path);

                if dest_file.exists() {
                    if let Ok(dest_metadata) = dest_file.metadata() {
                        let dest_modified: DateTime<Utc> = dest_metadata.modified()
                            .map(|t| t.into())
                            .unwrap_or_else(|_| Utc::now());
                        let dest_file_info = FileInfo {
                            path: dest_file_path.to_string_lossy().to_string(),
                            relative_path: file_name,
                            size: dest_metadata.len(),
                            modified: dest_modified,
                        };
                        duplicates.push(DuplicateFile::new(file_info, dest_file_info));
                    }
                }
            }
        }

        logger_service::log_info("CopyEngine", &format!(
            "扫描完成: {} 个文件, {} 字节, {} 个重复",
            all_files.len(),
            total_bytes,
            duplicates.len()
        ));

        Ok(ScanResult {
            all_files,
            duplicates,
            total_bytes,
            total_files: all_files.len(),
        })
    }

    fn build_robocopy_args(
        source: &str,
        dest: &str,
        blacklist_folders: &[String],
        blacklist_files: &[String],
        threads: u32,
        resolution: ConflictResolution,
    ) -> Vec<String> {
        let mut args = vec![
            source.to_string(),
            dest.to_string(),
            "/E".to_string(),
            "/COPY:DAT".to_string(),
            "/R:2".to_string(),
            "/W:1".to_string(),
            "/MT:8".to_string(),
        ];

        match resolution {
            ConflictResolution::Skip => {
                args.push("/XC".to_string());
                args.push("/XN".to_string());
                args.push("/XO".to_string());
            }
            ConflictResolution::Overwrite => {
                args.push("/IS".to_string());
            }
            ConflictResolution::KeepNewer => {
                args.push("/XO".to_string());
            }
        }

        if !blacklist_folders.is_empty() {
            args.push("/XD".to_string());
            for folder in blacklist_folders {
                args.push(folder.clone());
            }
        }

        if !blacklist_files.is_empty() {
            args.push("/XF".to_string());
            for file in blacklist_files {
                args.push(file.clone());
            }
        }

        args
    }

    pub async fn execute(
        &self,
        source_path: String,
        dest_path: String,
        settings: &AppSettings,
        profile: Option<&FolderProfile>,
        scan_result: Option<&ScanResult>,
        resolution: ConflictResolution,
    ) -> Result<CopyTask> {
        logger_service::log_info("CopyEngine", "开始复制任务");
        logger_service::log_info("CopyEngine", &format!("源目录: {}", source_path));
        logger_service::log_info("CopyEngine", &format!("目标目录: {}", dest_path));
        logger_service::log_info("CopyEngine", &format!("冲突策略: {:?}", resolution));

        let path = Path::new(&source_path);
        let is_dir = path.is_dir();

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
            profile
                .map(|p| p.blacklist_folders.clone())
                .unwrap_or_default()
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
            profile
                .map(|p| p.blacklist_files.clone())
                .unwrap_or_default()
        };

        let mut effective_blacklist_folders = blacklist_folders.clone();
        if is_dir {
            if let Some(source_dir_name) = path.file_name() {
                let source_name = source_dir_name.to_string_lossy().to_string();
                effective_blacklist_folders.retain(|f| f != &source_name);
                if effective_blacklist_folders.len() < blacklist_folders.len() {
                    logger_service::log_info("CopyEngine", &format!(
                        "源目录本身在黑名单中，临时移除: {}", source_name
                    ));
                }
            }
        }

        let mut file_info_map = HashMap::new();
        let mut total_bytes_from_scan: u64 = 0;
        if let Some(scan) = scan_result {
            for file in &scan.all_files {
                file_info_map.insert(file.relative_path.to_lowercase(), file.clone());
            }
            total_bytes_from_scan = scan.total_bytes;
        }
        *self.file_info_map.lock().unwrap() = Some(file_info_map);
        *self.total_bytes_from_scan.lock().unwrap() = total_bytes_from_scan;

        let mut task = CopyTask::new(
            uuid::Uuid::new_v4().to_string(),
            source_path.clone(),
            dest_path.clone(),
            is_dir,
        );
        task.status = CopyStatus::Running;
        task.total_files = scan_result.map(|s| s.total_files).unwrap_or(0);
        task.bytes_total = total_bytes_from_scan;
        task.applied_rules = blacklist_folders
            .iter()
            .chain(blacklist_files.iter())
            .cloned()
            .collect();

        *self.current_task.lock().unwrap() = Some(task.clone());

        let result = if is_dir {
            self.copy_directory(
                &mut task,
                &effective_blacklist_folders,
                &blacklist_files,
                settings.robocopy_threads,
                resolution,
            )
            .await
        } else {
            self.copy_single_file(&mut task, &blacklist_files).await
        };

        *self.current_task.lock().unwrap() = None;
        *self.file_info_map.lock().unwrap() = None;
        *self.total_bytes_from_scan.lock().unwrap() = 0;

        result
    }

    async fn copy_directory(
        &self,
        task: &mut CopyTask,
        blacklist_folders: &[String],
        blacklist_files: &[String],
        threads: u32,
        resolution: ConflictResolution,
    ) -> Result<CopyTask> {
        logger_service::log_info("CopyEngine", "开始 Robocopy 复制目录");

        let start_time = Instant::now();
        let mut bytes_copied: u64 = 0;
        let mut line_count = 0;

        let src_name = Path::new(&task.source_path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        let final_dest = Path::new(&task.dest_path).join(&src_name);
        let final_dest_str = final_dest.to_string_lossy().to_string();

        logger_service::log_info("CopyEngine", &format!("最终目标目录: {}", final_dest_str));

        let args = Self::build_robocopy_args(
            &task.source_path,
            &final_dest_str,
            blacklist_folders,
            blacklist_files,
            threads,
            resolution,
        );

        logger_service::log_info("CopyEngine", &format!("执行命令: robocopy {}", args.join(" ")));

        let mut child = Command::new("robocopy")
            .args(&args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        let stdout = child.stdout.take();
        let stderr = child.stderr.take();

        if let Some(stdout) = stdout {
            let file_map = Arc::clone(&self.file_info_map);
            let total_bytes = Arc::clone(&self.total_bytes_from_scan);
            let task_arc = Arc::new(Mutex::new(task.clone()));

            std::thread::spawn(move || {
                let reader = BufReader::new(stdout);
                for line in reader.lines().filter_map(|l| l.ok()) {
                    let trimmed = line.trim();
                    if trimmed.is_empty() {
                        continue;
                    }

                    let is_copy_line = trimmed.contains("New File")
                        || trimmed.contains("新建文件")
                        || trimmed.contains("Newer")
                        || trimmed.contains("更新")
                        || trimmed.contains("Same")
                        || trimmed.contains("相同");

                    if is_copy_line {
                        line_count += 1;
                        if let Ok(mut task_guard) = task_arc.lock() {
                            task_guard.copied_files = line_count;
                            let file_name = Self::extract_file_name(trimmed);
                            task_guard.current_file = Some(file_name.clone());

                            if let Some(ref map) = *file_map.lock().unwrap() {
                                let lower_file_name = file_name.to_lowercase();
                                if let Some(file_info) = map.get(&lower_file_name) {
                                    bytes_copied += file_info.size;
                                    task_guard.bytes_copied = bytes_copied;

                                    let elapsed = start_time.elapsed().as_secs();
                                    if elapsed > 0 {
                                        task_guard.speed_bytes_per_second =
                                            Some(bytes_copied as f64 / elapsed as f64);

                                        let total = *total_bytes.lock().unwrap();
                                        if total > bytes_copied
                                            && task_guard.speed_bytes_per_second.unwrap_or(0.0) > 0.0
                                        {
                                            let remaining_bytes = total - bytes_copied;
                                            task_guard.estimated_remaining_seconds = Some(
                                                (remaining_bytes as f64
                                                    / task_guard.speed_bytes_per_second.unwrap_or(1.0))
                                                    as u64,
                                            );
                                        }
                                    }
                                }
                            }
                        }
                    } else if trimmed.contains("Skipped") || trimmed.contains("跳过") {
                        if let Ok(mut task_guard) = task_arc.lock() {
                            task_guard.skipped_files += 1;
                        }
                    } else if trimmed.contains("ERROR") || trimmed.contains("错误") {
                        if let Ok(mut task_guard) = task_arc.lock() {
                            task_guard.failed_files += 1;
                        }
                    }
                }
            });

            *task = task_arc.lock().unwrap().clone();
        }

        let status = child.wait()?;
        logger_service::log_info("CopyEngine", &format!("进程已退出，退出码: {:?}", status));

        *self.current_process.lock().unwrap() = None;
        task.finished_at = Some(chrono::Utc::now());

        if task.status == CopyStatus::Cancelled {
            logger_service::log_info("CopyEngine", "任务已取消");
        } else if status.code().map(|c| c <= 7).unwrap_or(false) {
            task.mark_success();
            logger_service::log_info("CopyEngine", &format!(
                "复制成功！复制了 {} 个文件",
                task.copied_files
            ));
            if task.total_files == 0 {
                task.total_files = task.copied_files;
            }
        } else {
            task.mark_failed("复制失败，请查看日志".to_string());
            logger_service::log_error("CopyEngine", &format!("复制失败: {:?}", status));
        }

        Ok(task.clone())
    }

    async fn copy_single_file(
        &self,
        task: &mut CopyTask,
        blacklist_files: &[String],
    ) -> Result<CopyTask> {
        let src_path = Path::new(&task.source_path);
        let file_name = src_path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();

        let mut file_matcher = GitignoreBuilder::new("");
        for file in blacklist_files {
            let _ = file_matcher.add_line(file);
        }
        let matcher = file_matcher.build()?;

        if let ignore::Match::Ignore(_) = matcher.matched(&file_name, false) {
            task.status = CopyStatus::Success;
            task.total_files = 1;
            task.skipped_files = 1;
            task.finished_at = Some(chrono::Utc::now());
            return Ok(task.clone());
        }

        let dest_file = Path::new(&task.dest_path).join(&file_name);
        if let Some(parent) = dest_file.parent() {
            std::fs::create_dir_all(parent)?;
        }

        task.total_files = 1;
        task.current_file = Some(file_name.clone());
        task.bytes_total = self.total_bytes_from_scan.lock().unwrap().clone();

        std::fs::copy(&task.source_path, &dest_file)?;

        task.status = CopyStatus::Success;
        task.copied_files = 1;
        task.bytes_copied = task.bytes_total;
        task.finished_at = Some(chrono::Utc::now());

        Ok(task.clone())
    }

    fn extract_file_name(line: &str) -> String {
        let parts: Vec<&str> = line.split_whitespace().collect();
        for part in parts.iter().rev() {
            let trimmed = part.trim();
            if !trimmed.is_empty()
                && !trimmed.contains('%')
                && !trimmed.contains("File")
                && !trimmed.contains("New")
                && !trimmed.contains("新建")
            {
                return trimmed.to_string();
            }
        }
        parts.last().unwrap_or(&line).to_string()
    }

    pub fn cancel(&self) {
        logger_service::log_info("CopyEngine", "用户请求取消任务");

        if let Ok(mut task_guard) = self.current_task.lock() {
            if let Some(ref mut task) = *task_guard {
                if task.status == CopyStatus::Running {
                    task.mark_cancelled();
                }
            }
        }

        if let Ok(mut process_guard) = self.current_process.lock() {
            if let Some(ref mut child) = *process_guard {
                let _ = child.kill();
                logger_service::log_info("CopyEngine", "进程已终止");
            }
        }
    }
}

impl Default for CopyEngine {
    fn default() -> Self {
        Self::new()
    }
}
