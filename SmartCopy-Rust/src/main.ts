import { invoke } from "@tauri-apps/api/core";

interface AppSettings {
  smart_copy_hotkey: { key: string; ctrl: boolean; shift: boolean; alt: boolean };
  smart_paste_hotkey: { key: string; ctrl: boolean; shift: boolean; alt: boolean };
  global_blacklist_folders: string[];
  global_blacklist_files: string[];
  auto_start: boolean;
  minimize_to_tray: boolean;
  show_notifications: boolean;
  right_click_menu_enabled: boolean;
  merge_global_rules: boolean;
  robocopy_threads: number;
  theme_mode: string;
}

interface FolderProfile {
  id: string;
  name: string;
  folder_path: string;
  blacklist_folders: string[];
  blacklist_files: string[];
  enabled: boolean;
  created_at: string;
  updated_at: string;
}

interface CopyTask {
  id: string;
  source_path: string;
  dest_path: string;
  is_directory: boolean;
  status: "idle" | "running" | "success" | "failed" | "cancelled";
  total_files: number;
  copied_files: number;
  skipped_files: number;
  failed_files: number;
  current_file: string | null;
  error_message: string | null;
  bytes_total: number;
  bytes_copied: number;
  applied_rules: string[];
  speed_bytes_per_second: number | null;
  estimated_remaining_seconds: number | null;
}

interface ScanResult {
  all_files: Array<{
    path: string;
    relative_path: string;
    size: number;
    modified: string;
  }>;
  duplicates: Array<{
    source: { path: string; relative_path: string; size: number; modified: string };
    dest: { path: string; relative_path: string; size: number; modified: string };
    resolution: string;
  }>;
  total_bytes: number;
  total_files: number;
}

let currentSettings: AppSettings | null = null;
let currentProfiles: FolderProfile[] = [];
let copySource: string | null = null;
let isCopying = false;

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds} 秒`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)} 分钟`;
  return `${(seconds / 3600).toFixed(1)} 小时`;
}

function updateStatus(message: string) {
  const statusEl = document.getElementById("status-text");
  if (statusEl) statusEl.textContent = message;
}

async function loadSettings() {
  try {
    currentSettings = await invoke<AppSettings>("get_settings");
    renderRules();
    renderSettings();
    await checkContextMenuStatus();
  } catch (error) {
    console.error("加载设置失败:", error);
    updateStatus("加载设置失败");
  }
}

async function loadProfiles() {
  try {
    currentProfiles = await invoke<FolderProfile[]>("get_profiles");
    renderProfiles();
  } catch (error) {
    console.error("加载配置失败:", error);
  }
}

async function loadCopySource() {
  try {
    copySource = await invoke<string | null>("get_copy_source");
    if (copySource) {
      document.getElementById("source-path")!.value = copySource;
      await updateSourceInfo();
    }
  } catch (error) {
    console.error("获取复制源失败:", error);
  }
}

function renderRules() {
  if (!currentSettings) return;

  const folderRulesEl = document.getElementById("folder-rules")!;
  const fileRulesEl = document.getElementById("file-rules")!;

  folderRulesEl.innerHTML = currentSettings.global_blacklist_folders
    .map((rule, index) => `
      <span class="rule-tag">
        ${escapeHtml(rule)}
        <span class="remove" onclick="removeFolderRule(${index})">×</span>
      </span>
    `)
    .join("");

  fileRulesEl.innerHTML = currentSettings.global_blacklist_files
    .map((rule, index) => `
      <span class="rule-tag">
        ${escapeHtml(rule)}
        <span class="remove" onclick="removeFileRule(${index})">×</span>
      </span>
    `)
    .join("");
}

function renderProfiles() {
  const profilesListEl = document.getElementById("profiles-list")!;

  if (currentProfiles.length === 0) {
    profilesListEl.innerHTML = `
      <div class="profile-card">
        <div class="profile-info">
          <p style="color: var(--text-secondary);">暂无配置，点击上方按钮添加</p>
        </div>
      </div>
    `;
    return;
  }

  profilesListEl.innerHTML = currentProfiles
    .map((profile) => `
      <div class="profile-card">
        <div class="profile-info">
          <h3>${escapeHtml(profile.name)}</h3>
          <p>路径: ${escapeHtml(profile.folder_path)}</p>
          <p>规则: ${profile.blacklist_folders.length + profile.blacklist_files.length} 条</p>
        </div>
        <div class="profile-actions">
          <button class="btn btn-secondary btn-small" onclick="editProfile('${profile.id}')">编辑</button>
          <button class="btn btn-danger btn-small" onclick="deleteProfile('${profile.id}')">删除</button>
        </div>
      </div>
    `)
    .join("");
}

async function renderSettings() {
  if (!currentSettings) return;

  document.getElementById("hotkey-copy")!.textContent =
    `${currentSettings.smart_copy_hotkey.ctrl ? "Ctrl + " : ""}${currentSettings.smart_copy_hotkey.shift ? "Shift + " : ""}${currentSettings.smart_copy_hotkey.alt ? "Alt + " : ""}${currentSettings.smart_copy_hotkey.key.toUpperCase()}`;

  document.getElementById("hotkey-paste")!.textContent =
    `${currentSettings.smart_paste_hotkey.ctrl ? "Ctrl + " : ""}${currentSettings.smart_paste_hotkey.shift ? "Shift + " : ""}${currentSettings.smart_paste_hotkey.alt ? "Alt + " : ""}${currentSettings.smart_paste_hotkey.key.toUpperCase()}`;

  (document.getElementById("setting-auto-start") as HTMLInputElement).checked = currentSettings.auto_start;
  (document.getElementById("setting-minimize-tray") as HTMLInputElement).checked = currentSettings.minimize_to_tray;
  (document.getElementById("setting-notifications") as HTMLInputElement).checked = currentSettings.show_notifications;
  (document.getElementById("setting-merge-rules") as HTMLInputElement).checked = currentSettings.merge_global_rules;
  (document.getElementById("setting-threads") as HTMLInputElement).value = String(currentSettings.robocopy_threads);
}

async function checkContextMenuStatus() {
  try {
    const isRegistered = await invoke<boolean>("is_context_menu_registered");
    const btn = document.getElementById("btn-toggle-context-menu")!;
    btn.textContent = isRegistered ? "取消右键菜单" : "注册右键菜单";
    btn.className = isRegistered ? "btn btn-danger" : "btn btn-secondary";
  } catch (error) {
    console.error("检查右键菜单状态失败:", error);
  }
}

function escapeHtml(text: string): string {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

async function updateSourceInfo() {
  if (!copySource) {
    document.getElementById("source-info")!.innerHTML = "";
    return;
  }

  try {
    const sourceInput = document.getElementById("source-path") as HTMLInputElement;
    const result = await invoke<ScanResult>("scan_source", {
      sourcePath: copySource,
      destPath: "dummy",
    });

    document.getElementById("source-info")!.innerHTML = `
      文件数: ${result.total_files} |
      总大小: ${formatBytes(result.total_bytes)} |
      重复文件: ${result.duplicates.length}
    `;
  } catch (error) {
    console.error("扫描源目录失败:", error);
  }
}

async function selectSource() {
  try {
    const selected = await open({
      multiple: false,
      directory: true,
    });

    if (selected) {
      copySource = selected as string;
      document.getElementById("source-path")!.value = copySource;
      await invoke("set_copy_source", { path: copySource });
      await updateSourceInfo();
      updateStatus("已选择复制源");
    }
  } catch (error) {
    console.error("选择源失败:", error);
    updateStatus("选择源失败");
  }
}

async function selectDest() {
  try {
    const selected = await open({
      multiple: false,
      directory: true,
    });

    if (selected) {
      document.getElementById("dest-path")!.value = selected as string;
      updateStatus("已选择目标位置");
    }
  } catch (error) {
    console.error("选择目标失败:", error);
    updateStatus("选择目标失败");
  }
}

async function startCopy() {
  if (!copySource) {
    updateStatus("请先选择复制源");
    return;
  }

  const destPath = (document.getElementById("dest-path") as HTMLInputElement).value;
  if (!destPath) {
    updateStatus("请先选择目标位置");
    return;
  }

  const resolution = (document.getElementById("conflict-resolution") as HTMLSelectElement).value;
  isCopying = true;

  document.getElementById("btn-start-copy")!.disabled = true;
  document.getElementById("btn-cancel-copy")!.disabled = false;
  document.getElementById("progress-section")!.style.display = "block";
  document.getElementById("result-section")!.style.display = "none";

  updateStatus("正在复制...");

  try {
    const resolutionMap: Record<string, string> = {
      keep_newer: "keepnewer",
      skip: "skip",
      overwrite: "overwrite",
    };

    const task = await invoke<CopyTask>("execute_copy", {
      destPath: destPath,
      resolution: resolutionMap[resolution],
    });

    showResult(task);
  } catch (error) {
    console.error("复制失败:", error);
    updateStatus(`复制失败: ${error}`);
    showResult({
      status: "failed",
      error_message: String(error),
    } as CopyTask);
  } finally {
    isCopying = false;
    document.getElementById("btn-start-copy")!.disabled = false;
    document.getElementById("btn-cancel-copy")!.disabled = true;
  }
}

async function cancelCopy() {
  try {
    await invoke("cancel_copy");
    updateStatus("已取消复制");
  } catch (error) {
    console.error("取消失败:", error);
  }
}

function showResult(task: CopyTask) {
  const resultSection = document.getElementById("result-section")!;
  const resultCard = document.getElementById("result-card")!;
  const progressSection = document.getElementById("progress-section")!;

  progressSection.style.display = "none";
  resultSection.style.display = "block";

  const isSuccess = task.status === "success";
  resultCard.className = `result-card ${isSuccess ? "success" : "error"}`;

  if (isSuccess) {
    resultCard.innerHTML = `
      <h3>✓ 复制完成</h3>
      <p>成功复制 ${task.copied_files} 个文件</p>
      ${task.skipped_files > 0 ? `<p>跳过 ${task.skipped_files} 个文件</p>` : ""}
      ${task.failed_files > 0 ? `<p>失败 ${task.failed_files} 个文件</p>` : ""}
      <p>总大小: ${formatBytes(task.bytes_copied)}</p>
    `;
    updateStatus("复制完成");
  } else {
    resultCard.innerHTML = `
      <h3>✗ 复制失败</h3>
      <p>${task.error_message || "未知错误"}</p>
    `;
    updateStatus("复制失败");
  }
}

function clearResult() {
  document.getElementById("result-section")!.style.display = "none";
  copySource = null;
  (document.getElementById("source-path") as HTMLInputElement).value = "";
  (document.getElementById("dest-path") as HTMLInputElement).value = "";
  document.getElementById("source-info")!.innerHTML = "";
  invoke("clear_copy_source");
  updateStatus("就绪");
}

async function addFolderRule() {
  const input = document.getElementById("new-folder-rule") as HTMLInputElement;
  const rule = input.value.trim();

  if (!rule || !currentSettings) return;

  if (!currentSettings.global_blacklist_folders.includes(rule)) {
    currentSettings.global_blacklist_folders.push(rule);
    await saveSettings();
    renderRules();
  }

  input.value = "";
}

async function addFileRule() {
  const input = document.getElementById("new-file-rule") as HTMLInputElement;
  const rule = input.value.trim();

  if (!rule || !currentSettings) return;

  if (!currentSettings.global_blacklist_files.includes(rule)) {
    currentSettings.global_blacklist_files.push(rule);
    await saveSettings();
    renderRules();
  }

  input.value = "";
}

async function removeFolderRule(index: number) {
  if (!currentSettings) return;
  currentSettings.global_blacklist_folders.splice(index, 1);
  await saveSettings();
  renderRules();
}

async function removeFileRule(index: number) {
  if (!currentSettings) return;
  currentSettings.global_blacklist_files.splice(index, 1);
  await saveSettings();
  renderRules();
}

async function saveSettings() {
  if (!currentSettings) return;

  try {
    await invoke("save_settings", { settings: currentSettings });
    updateStatus("设置已保存");
  } catch (error) {
    console.error("保存设置失败:", error);
    updateStatus("保存设置失败");
  }
}

function openProfileModal() {
  document.getElementById("profile-modal")!.style.display = "flex";
}

function closeProfileModal() {
  document.getElementById("profile-modal")!.style.display = "none";
  (document.getElementById("profile-name") as HTMLInputElement).value = "";
  (document.getElementById("profile-path") as HTMLInputElement).value = "";
  (document.getElementById("profile-folders") as HTMLTextAreaElement).value = "";
  (document.getElementById("profile-files") as HTMLTextAreaElement).value = "";
}

async function browseProfilePath() {
  try {
    const selected = await open({
      multiple: false,
      directory: true,
    });

    if (selected) {
      (document.getElementById("profile-path") as HTMLInputElement).value = selected as string;
    }
  } catch (error) {
    console.error("选择路径失败:", error);
  }
}

async function saveProfile() {
  const name = (document.getElementById("profile-name") as HTMLInputElement).value.trim();
  const path = (document.getElementById("profile-path") as HTMLInputElement).value.trim();
  const foldersText = (document.getElementById("profile-folders") as HTMLTextAreaElement).value;
  const filesText = (document.getElementById("profile-files") as HTMLTextAreaElement).value;

  if (!name || !path) {
    updateStatus("请填写名称和路径");
    return;
  }

  const folders = foldersText.split("\n").map((s) => s.trim()).filter((s) => s);
  const files = filesText.split("\n").map((s) => s.trim()).filter((s) => s);

  try {
    await invoke("add_profile", {
      profile: {
        name,
        folder_path: path,
        blacklist_folders: folders,
        blacklist_files: files,
        enabled: true,
      },
    });

    closeProfileModal();
    await loadProfiles();
    updateStatus("配置已保存");
  } catch (error) {
    console.error("保存配置失败:", error);
    updateStatus("保存配置失败");
  }
}

async function deleteProfile(id: string) {
  if (!confirm("确定要删除这个配置吗？")) return;

  try {
    await invoke("delete_profile", { id });
    await loadProfiles();
    updateStatus("配置已删除");
  } catch (error) {
    console.error("删除配置失败:", error);
  }
}

function editProfile(id: string) {
  const profile = currentProfiles.find((p) => p.id === id);
  if (!profile) return;

  (document.getElementById("profile-name") as HTMLInputElement).value = profile.name;
  (document.getElementById("profile-path") as HTMLInputElement).value = profile.folder_path;
  (document.getElementById("profile-folders") as HTMLTextAreaElement).value = profile.blacklist_folders.join("\n");
  (document.getElementById("profile-files") as HTMLTextAreaElement).value = profile.blacklist_files.join("\n");

  document.getElementById("profile-modal")!.style.display = "flex";
}

async function importGitignore() {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".gitignore";

  input.onchange = async (e) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;

    const content = await file.text();

    try {
      const count = await invoke<number>("import_from_gitignore", { content });
      await loadSettings();
      updateStatus(`已导入 ${count} 条规则`);
    } catch (error) {
      console.error("导入失败:", error);
      updateStatus("导入失败");
    }
  };

  input.click();
}

async function toggleContextMenu() {
  if (!currentSettings) return;

  try {
    const isRegistered = await invoke<boolean>("is_context_menu_registered");

    if (isRegistered) {
      await invoke("unregister_context_menu");
      updateStatus("右键菜单已注销");
    } else {
      await invoke("register_context_menu");
      updateStatus("右键菜单已注册");
    }

    await checkContextMenuStatus();
  } catch (error) {
    console.error("切换右键菜单失败:", error);
    updateStatus(`操作失败: ${error}`);
  }
}

function switchTab(tabName: string) {
  document.querySelectorAll(".nav-tab").forEach((tab) => {
    tab.classList.remove("active");
  });
  document.querySelectorAll(".page").forEach((page) => {
    page.classList.remove("active");
  });

  document.querySelector(`[data-tab="${tabName}"]`)?.classList.add("active");
  document.getElementById(`page-${tabName}`)?.classList.add("active");
}

function initEventListeners() {
  document.getElementById("btn-select-source")?.addEventListener("click", selectSource);
  document.getElementById("btn-select-dest")?.addEventListener("click", selectDest);
  document.getElementById("btn-start-copy")?.addEventListener("click", startCopy);
  document.getElementById("btn-cancel-copy")?.addEventListener("click", cancelCopy);
  document.getElementById("btn-clear-result")?.addEventListener("click", clearResult);

  document.getElementById("btn-add-profile")?.addEventListener("click", openProfileModal);
  document.getElementById("btn-browse-profile-path")?.addEventListener("click", browseProfilePath);
  document.getElementById("btn-save-profile")?.addEventListener("click", saveProfile);

  document.getElementById("btn-add-folder-rule")?.addEventListener("click", addFolderRule);
  document.getElementById("btn-add-file-rule")?.addEventListener("click", addFileRule);
  document.getElementById("btn-import-gitignore")?.addEventListener("click", importGitignore);

  document.getElementById("btn-toggle-context-menu")?.addEventListener("click", toggleContextMenu);

  document.querySelectorAll(".nav-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      const tabName = (tab as HTMLElement).dataset.tab;
      if (tabName) switchTab(tabName);
    });
  });

  document.getElementById("new-folder-rule")?.addEventListener("keypress", (e) => {
    if (e.key === "Enter") addFolderRule();
  });

  document.getElementById("new-file-rule")?.addEventListener("keypress", (e) => {
    if (e.key === "Enter") addFileRule();
  });

  document.getElementById("setting-auto-start")?.addEventListener("change", async (e) => {
    try {
      await invoke("set_auto_start", { enabled: (e.target as HTMLInputElement).checked });
      updateStatus("开机自启设置已保存");
    } catch (error) {
      console.error("设置开机自启失败:", error);
    }
  });

  document.getElementById("setting-minimize-tray")?.addEventListener("change", async (e) => {
    if (currentSettings) {
      currentSettings.minimize_to_tray = (e.target as HTMLInputElement).checked;
      await saveSettings();
    }
  });

  document.getElementById("setting-notifications")?.addEventListener("change", async (e) => {
    if (currentSettings) {
      currentSettings.show_notifications = (e.target as HTMLInputElement).checked;
      await saveSettings();
    }
  });

  document.getElementById("setting-merge-rules")?.addEventListener("change", async (e) => {
    if (currentSettings) {
      currentSettings.merge_global_rules = (e.target as HTMLInputElement).checked;
      await saveSettings();
    }
  });

  document.getElementById("setting-threads")?.addEventListener("change", async (e) => {
    if (currentSettings) {
      currentSettings.robocopy_threads = parseInt((e.target as HTMLInputElement).value) || 8;
      await saveSettings();
    }
  });
}

(window as any).removeFolderRule = removeFolderRule;
(window as any).removeFileRule = removeFileRule;
(window as any).editProfile = editProfile;
(window as any).deleteProfile = deleteProfile;
(window as any).closeProfileModal = closeProfileModal;

async function init() {
  console.log("SmartCopy 初始化中...");

  try {
    await loadSettings();
    await loadProfiles();
    await loadCopySource();
    initEventListeners();
    updateStatus("就绪");
    console.log("SmartCopy 初始化完成");
  } catch (error) {
    console.error("初始化失败:", error);
    updateStatus("初始化失败");
  }
}

init();
