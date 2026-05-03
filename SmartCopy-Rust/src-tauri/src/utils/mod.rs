use std::path::Path;

pub fn normalize_path(path: &str) -> String {
    path.replace('\\', "/")
}

pub fn get_file_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default()
}

pub fn get_parent_path(path: &str) -> Option<String> {
    Path::new(path)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
}

pub fn join_paths(base: &str, name: &str) -> String {
    Path::new(base).join(name).to_string_lossy().to_string()
}

pub fn path_exists(path: &str) -> bool {
    Path::new(path).exists()
}

pub fn is_directory(path: &str) -> bool {
    Path::new(path).is_dir()
}

pub fn is_file(path: &str) -> bool {
    Path::new(path).is_file()
}

pub fn format_bytes(bytes: u64) -> String {
    if bytes < 1024 {
        format!("{} B", bytes)
    } else if bytes < 1024 * 1024 {
        format!("{:.1} KB", bytes as f64 / 1024.0)
    } else if bytes < 1024 * 1024 * 1024 {
        format!("{:.1} MB", bytes as f64 / (1024.0 * 1024.0))
    } else {
        format!("{:.1} GB", bytes as f64 / (1024.0 * 1024.0 * 1024.0))
    }
}

pub fn format_duration(seconds: u64) -> String {
    if seconds < 60 {
        format!("{} 秒", seconds)
    } else if seconds < 3600 {
        format!("{} 分钟", seconds / 60)
    } else {
        format!("{} 小时", seconds / 3600)
    }
}

pub fn format_speed(bytes_per_second: f64) -> String {
    format!("{}/秒", format_bytes(bytes_per_second as u64))
}
