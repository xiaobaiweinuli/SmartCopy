use std::process::Command;
use crate::services::logger_service;

pub struct ClipboardService;

impl ClipboardService {
    pub fn new() -> Self {
        Self
    }

    pub fn get_files_from_clipboard(&self) -> Result<Vec<String>, String> {
        logger_service::log_info("ClipboardService", "正在获取剪贴板文件列表...");

        let output = Command::new("powershell")
            .args([
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                r#"
                Add-Type -AssemblyName System.Windows.Forms
                $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
                if ($files.Count -gt 0) {
                    $files -join '|'
                }
                "#
            ])
            .output()
            .map_err(|e| format!("执行 PowerShell 失败: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!("获取剪贴板失败: {}", stderr));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let stdout_trimmed = stdout.trim();

        if stdout_trimmed.is_empty() {
            logger_service::log_info("ClipboardService", "剪贴板中没有文件");
            return Ok(Vec::new());
        }

        let files: Vec<String> = stdout_trimmed
            .split('|')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        logger_service::log_info("ClipboardService", &format!(
            "从剪贴板获取到 {} 个文件",
            files.len()
        ));

        Ok(files)
    }

    pub fn get_explorer_selection(&self) -> Result<Vec<String>, String> {
        logger_service::log_info("ClipboardService", "正在获取资源管理器选中文件...");

        let script = r#"
        Add-Type -AssemblyName Microsoft.Office.Interop.Shell32
        $shell = New-Object -ComObject Shell.Application
        $windows = $shell.Windows()

        if ($windows -ne $null) {
            foreach ($window in $windows) {
                if ($window -is [System.__ComObject]) {
                    try {
                        $selectedItems = $window.Document.SelectedItems()
                        if ($selectedItems.Count -gt 0) {
                            $result = @()
                            foreach ($item in $selectedItems) {
                                $result += $item.Path
                            }
                            $result -join '|'
                            break
                        }
                    } catch {}
                }
            }
        }
        "#;

        let output = Command::new("powershell")
            .args(["-NoProfile", "-NonInteractive", "-Command", script])
            .output()
            .map_err(|e| format!("执行 PowerShell 失败: {}", e))?;

        if !output.status.success() {
            return Err(String::from_utf8_lossy(&output.stderr).to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();

        if stdout.is_empty() {
            return Ok(Vec::new());
        }

        let files: Vec<String> = stdout
            .split('|')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        logger_service::log_info("ClipboardService", &format!(
            "从资源管理器获取到 {} 个选中文件",
            files.len()
        ));

        Ok(files)
    }

    pub fn get_explorer_current_path(&self) -> Result<Option<String>, String> {
        logger_service::log_info("ClipboardService", "正在获取资源管理器当前路径...");

        let script = r#"
        Add-Type -AssemblyName Microsoft.Office.Interop.Shell32
        $shell = New-Object -ComObject Shell.Application
        $windows = $shell.Windows()

        if ($windows -ne $null) {
            foreach ($window in $windows) {
                if ($window -is [System.__ComObject]) {
                    try {
                        $path = $window.Document.Folder.Self.Path
                        if ($path) {
                            $path
                            break
                        }
                    } catch {}
                }
            }
        }
        "#;

        let output = Command::new("powershell")
            .args(["-NoProfile", "-NonInteractive", "-Command", script])
            .output()
            .map_err(|e| format!("执行 PowerShell 失败: {}", e))?;

        if !output.status.success() {
            return Err(String::from_utf8_lossy(&output.stderr).to_string());
        }

        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();

        if stdout.is_empty() || stdout == "::{...}" {
            return Ok(None);
        }

        logger_service::log_info("ClipboardService", &format!(
            "当前路径: {}",
            stdout
        ));

        Ok(Some(stdout))
    }

    pub fn get_primary_file_or_folder(&self) -> Result<Option<String>, String> {
        let files = self.get_files_from_clipboard()?;

        if !files.is_empty() {
            return Ok(Some(files[0].clone()));
        }

        let explorer_files = self.get_explorer_selection()?;
        if !explorer_files.is_empty() {
            return Ok(Some(explorer_files[0].clone()));
        }

        Ok(None)
    }
}

impl Default for ClipboardService {
    fn default() -> Self {
        Self::new()
    }
}
