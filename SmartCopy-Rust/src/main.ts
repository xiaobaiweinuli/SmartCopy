import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-dialog';

// =============================================
// Type Definitions
// =============================================

interface HotkeyDef {
    key: string;
    ctrl: boolean;
    shift: boolean;
    alt: boolean;
}

interface AppSettings {
    smartCopyHotkey: HotkeyDef;
    smartPasteHotkey: HotkeyDef;
    globalBlacklistFolders: string[];
    globalBlacklistFiles: string[];
    autoStart: boolean;
    minimizeToTray: boolean;
    showNotifications: boolean;
    rightClickMenuEnabled: boolean;
    mergeGlobalRules: boolean;
    robocopyThreads: number;
    themeMode: 'system' | 'light' | 'dark';
}

interface FolderProfile {
    id: string;
    name: string;
    folderPath: string;
    blacklistFolders: string[];
    blacklistFiles: string[];
    enabled: boolean;
    createdAt: string;
    updatedAt: string;
}

interface FileInfo {
    path: string;
    relativePath: string;
    size: number;
    modified: string;
}

interface DuplicateFile {
    source: FileInfo;
    dest: FileInfo;
    resolution: 'skip' | 'overwrite' | 'keepnewer';
}

interface ScanResult {
    allFiles: FileInfo[];
    duplicates: DuplicateFile[];
    totalBytes: number;
    totalFiles: number;
}

interface CopyTask {
    id: string;
    sourcePath: string;
    destPath: string;
    isDirectory: boolean;
    status: 'idle' | 'running' | 'success' | 'failed' | 'cancelled';
    totalFiles: number;
    copiedFiles: number;
    skippedFiles: number;
    failedFiles: number;
    currentFile: string | null;
    errorMessage: string | null;
    startedAt: string;
    finishedAt: string | null;
    bytesTotal: number;
    bytesCopied: number;
    appliedRules: string[];
    speedBytesPerSecond: number | null;
    estimatedRemainingSeconds: number | null;
}

// =============================================
// State
// =============================================

let currentSettings: AppSettings | null = null;
let currentProfiles: FolderProfile[] = [];
let copySource: string | null = null;
let destPath: string | null = null;
let isCopying = false;
let currentScanResult: ScanResult | null = null;
let taskHistory: CopyTask[] = [];

// =============================================
// Utility Functions
// =============================================

function formatBytes(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

function formatDuration(seconds: number): string {
    if (seconds < 60) return `${seconds} 秒`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)} 分钟`;
    return `${(seconds / 3600).toFixed(1)} 小时`;
}

function formatTime(dateString(dateStr: string): string {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffSeconds = Math.floor(diffMs / 1000);
    
    if (diffSeconds < 60) return '刚刚';
    if (diffSeconds < 3600) return `${Math.floor(diffSeconds / 60)} 分钟前`;
    if (diffSeconds < 86400) return `${Math.floor(diffSeconds / 3600)} 小时前`;
    return `${date.getMonth() + 1}/${date.getDate()}`;
}

function getShortPath(path: string): string {
    const parts = path.replace(/\\/g, '/').split('/');
    return parts.length > 0 ? parts[parts.length - 1] : path;
}

function formatDestPath(path: string): string {
    const parts = path.replace(/\\/g, '/').split('/');
    return parts.length > 2 ? `.../${parts[parts.length - 2]}/${parts[parts.length - 1]}` : path;
}

function escapeHtml(text: string): string {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatHotkey(hotkey: HotkeyDef): string {
    const parts: string[] = [];
    if (hotkey.ctrl) parts.push('Ctrl');
    if (hotkey.shift) parts.push('Shift');
    if (hotkey.alt) parts.push('Alt');
    parts.push(hotkey.key.toUpperCase());
    return parts.join(' ');
}

// =============================================
// Data Loading
// =============================================

async function loadSettings(): Promise<void> {
    try {
        currentSettings = await invoke<AppSettings>('get_settings');
        renderRules();
        renderSettings();
        updateKbdHints();
    } catch (error) {
        console.error('Failed to load settings:', error);
    }
}

async function loadProfiles(): Promise<void> {
    try {
        currentProfiles = await invoke<FolderProfile[]>('get_profiles');
        renderProfiles();
        updateNavBadges();
    } catch (error) {
        console.error('Failed to load profiles:', error);
    }
}

async function loadCopySource(): Promise<void> {
    try {
        copySource = await invoke<string | null>('get_copy_source');
        updateSourceIndicator();
        updateSourceSelector();
        if (copySource) {
            await updateRulePreview();
        }
    } catch (error) {
        console.error('Failed to load copy source:', error);
    }
}

async function loadHistory(): Promise<void> {
    try {
        taskHistory = await invoke<CopyTask[]>('get_task_history');
        renderHistory();
    } catch (error) {
        console.error('Failed to load history:', error);
    }
}

// =============================================
// Navigation
// =============================================

function switchTab(tabName: string): void {
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    document.querySelectorAll('.page-section').forEach(page => {
        page.classList.remove('active');
    });

    const targetNav = document.querySelector(`.nav-item[data-tab="${tabName}"]`);
    const targetPage = document.getElementById(`page-${tabName}`);

    if (targetNav) {
        targetNav.classList.add('active');
    }
    if (targetPage) {
        targetPage.classList.add('active');
    }
}

function switchRulesTab(tabName: string): void {
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });

    const targetBtn = document.querySelector(`.tab-btn[data-rules-tab="${tabName}"]`);
    const targetContent = document.getElementById(`tab-${tabName}`);

    if (targetBtn) {
        targetBtn.classList.add('active');
    }
    if (targetContent) {
        targetContent.classList.add('active');
    }
}

// =============================================
// Rule Rendering
// =============================================

function renderRules(): void {
    if (!currentSettings) return;

    const folderTags = document.getElementById('folder-tags');
    const fileTags = document.getElementById('file-tags');

    if (folderTags) {
        folderTags.innerHTML = currentSettings.globalBlacklistFolders.map((rule, index) => `
            <span class="tag-chip warning">
                <svg class="chip-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
                </svg>
                ${escapeHtml(rule)}
                <button class="chip-remove" onclick="removeFolderRule(${index})">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </span>
        `).join('');
    }

    if (fileTags) {
        fileTags.innerHTML = currentSettings.globalBlacklistFiles.map((rule, index) => `
            <span class="tag-chip danger">
                <svg class="chip-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
                </svg>
                ${escapeHtml(rule)}
                <button class="chip-remove" onclick="removeFileRule(${index})">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </span>
        `).join('');
    }

    updateNavBadges();
    updateRulesStats();
}

async function addFolderRule(): Promise<void> {
    const input = document.getElementById('new-folder-input') as HTMLInputElement;
    const rule = input?.value.trim();

    if (!rule || !currentSettings) return;

    if (!currentSettings.globalBlacklistFolders.includes(rule)) {
        currentSettings.globalBlacklistFolders.push(rule);
        await saveSettings();
        renderRules();
        await updateRulePreview();
    }

    if (input) input.value = '';
}

async function addFileRule(): Promise<void> {
    const input = document.getElementById('new-file-input') as HTMLInputElement;
    const rule = input?.value.trim();

    if (!rule || !currentSettings) return;

    if (!currentSettings.globalBlacklistFiles.includes(rule)) {
        currentSettings.globalBlacklistFiles.push(rule);
        await saveSettings();
        renderRules();
        await updateRulePreview();
    }

    if (input) input.value = '';
}

async function removeFolderRule(index: number): Promise<void> {
    if (!currentSettings) return;
    currentSettings.globalBlacklistFolders.splice(index, 1);
    await saveSettings();
    renderRules();
    await updateRulePreview();
}

async function removeFileRule(index: number): Promise<void> {
    if (!currentSettings) return;
    currentSettings.globalBlacklistFiles.splice(index, 1);
    await saveSettings();
    renderRules();
    await updateRulePreview();
}

async function addPresetRule(rule: string, type: 'folder' | 'file'): Promise<void> {
    if (!currentSettings) return;

    const list = type === 'folder' ? currentSettings.globalBlacklistFolders : currentSettings.globalBlacklistFiles;

    if (!list.includes(rule)) {
        list.push(rule);
        await saveSettings();
        renderRules();
        await updateRulePreview();
    }
}

async function importGitignore(): Promise<void> {
    const textarea = document.getElementById('gitignore-input') as HTMLTextAreaElement;
    const content = textarea?.value;

    if (!content) return;

    try {
        await invoke('import_from_gitignore', { content });
        await loadSettings();
        if (textarea) textarea.value = '';
    } catch (error) {
        console.error('Failed to import gitignore:', error);
    }
}

async function saveSettings(): Promise<void> {
    if (!currentSettings) return;

    try {
        await invoke('save_settings', { settings: currentSettings });
    } catch (error) {
        console.error('Failed to save settings:', error);
    }
}

// =============================================
// Profile Rendering
// =============================================

function renderProfiles(): void {
    const profilesList = document.getElementById('profiles-list');

    if (!profilesList) return;

    if (currentProfiles.length === 0) {
        profilesList.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
                    </svg>
                </div>
                <h3>暂无文件夹配置</h3>
                <p>添加配置后可以为特定目录设置独立的过滤规则</p>
            </div>
        `;
        return;
    }

    profilesList.innerHTML = currentProfiles.map(profile => `
        <div class="profile-card">
            <div class="profile-card-info">
                <h3>${escapeHtml(profile.name)}</h3>
                <p>${escapeHtml(profile.folderPath)}</p>
                <p>规则: ${profile.blacklistFolders.length + profile.blacklistFiles.length} 条</p>
            </div>
            <div class="profile-card-actions">
                <button class="btn-outlined-small" onclick="editProfile('${profile.id}')">编辑</button>
                <button class="btn-outlined-small danger" onclick="deleteProfile('${profile.id}')">删除</button>
            </div>
        </div>
    `).join('');
}

function openProfileModal(profileId: FolderProfile | null = null): void {
    const modal = document.getElementById('profile-modal');
    const nameInput = document.getElementById('profile-name-input') as HTMLInputElement;
    const pathInput = document.getElementById('profile-path-input') as HTMLInputElement;
    const foldersInput = document.getElementById('profile-folders-input') as HTMLTextAreaElement;
    const filesInput = document.getElementById('profile-files-input') as HTMLTextAreaElement;

    if (profileId) {
        const profile = currentProfiles.find(p => p.id === profileId.id);
        if (profile) {
            if (nameInput) nameInput.value = profile.name;
            if (pathInput) pathInput.value = profile.folderPath;
            if (foldersInput) foldersInput.value = profile.blacklistFolders.join('\n');
            if (filesInput) filesInput.value = profile.blacklistFiles.join('\n');
        }
    } else {
        if (nameInput) nameInput.value = '';
        if (pathInput) pathInput.value = '';
        if (foldersInput) foldersInput.value = '';
        if (filesInput) filesInput.value = '';
    }

    if (modal) modal.classList.remove('hidden');
}

function closeProfileModal(): void {
    const modal = document.getElementById('profile-modal');
    if (modal) modal.classList.add('hidden');
}

async function browseProfilePath(): Promise<void> {
    try {
        const selected = await open({
            multiple: false,
            directory: true,
        });
        if (selected) {
            const input = document.getElementById('profile-path-input') as HTMLInputElement;
            if (input) input.value = selected as string;
        }
    } catch (error) {
        console.error('Failed to select path:', error);
    }
}

async function saveProfile(): Promise<void> {
    const nameInput = document.getElementById('profile-name-input') as HTMLInputElement;
    const pathInput = document.getElementById('profile-path-input') as HTMLInputElement;
    const foldersInput = document.getElementById('profile-folders-input') as HTMLTextAreaElement;
    const filesInput = document.getElementById('profile-files-input') as HTMLTextAreaElement;

    const name = nameInput?.value.trim();
    const path = pathInput?.value.trim();
    const folders = foldersInput?.value.split('\n').map(s => s.trim()).filter(s => s);
    const files = filesInput?.value.split('\n').map(s => s.trim()).filter(s => s);

    if (!name || !path) return;

    try {
        await invoke('add_profile', {
            profile: {
                name,
                folderPath: path,
                blacklistFolders: folders,
                blacklistFiles: files,
                enabled: true,
            },
        });

        closeProfileModal();
        await loadProfiles();
        await updateRulePreview();
    } catch (error) {
        console.error('Failed to save profile:', error);
    }
}

function editProfile(id: string): void {
    const profile = currentProfiles.find(p => p.id === id);
    if (profile) {
        openProfileModal(profile);
    }
}

async function deleteProfile(id: string): Promise<void> {
    if (!confirm('确定要删除这个配置吗？')) return;

    try {
        await invoke('delete_profile', { id });
        await loadProfiles();
        await updateRulePreview();
    } catch (error) {
        console.error('Failed to delete profile:', error);
    }
}

const templates: Record<string, string[]> = {
    nodejs: ['node_modules', 'dist', '.next', '.nuxt'],
    python: ['__pycache__', '.venv', 'venv', '.pytest_cache'],
    android: ['.gradle', 'build', '.idea', 'captures'],
    git: ['.git', '.svn', '.hg'],
    flutter: ['.dart_tool', 'build', '.flutter-plugins'],
};

async function applyTemplate(templateName: string): Promise<void> {
    if (!currentSettings) return;
    const rules = templates[templateName];
    if (!rules) return;

    let added = false;
    for (const rule of rules) {
        if (!currentSettings.globalBlacklistFolders.includes(rule)) {
            currentSettings.globalBlacklistFolders.push(rule);
            added = true;
        }
    }

    if (added) {
        await saveSettings();
        renderRules();
        await updateRulePreview();
    }
}

// =============================================
// Settings Rendering
// =============================================

function renderSettings(): void {
    if (!currentSettings) return;

    const autoStartToggle = document.getElementById('autostart-toggle');
    const trayToggle = document.getElementById('tray-toggle');
    const notificationsToggle = document.getElementById('notifications-toggle');
    const mergeRulesToggle = document.getElementById('merge-rules-toggle');
    const threadSlider = document.getElementById('thread-slider') as HTMLInputElement;
    const threadCount = document.getElementById('thread-count');

    if (autoStartToggle) {
        autoStartToggle.classList.toggle('active', currentSettings.autoStart);
    }
    if (trayToggle) {
        trayToggle.classList.toggle('active', currentSettings.minimizeToTray);
    }
    if (notificationsToggle) {
        notificationsToggle.classList.toggle('active', currentSettings.showNotifications);
    }
    if (mergeRulesToggle) {
        mergeRulesToggle.classList.toggle('active', currentSettings.mergeGlobalRules);
    }
    if (threadSlider) {
        threadSlider.value = String(currentSettings.robocopyThreads);
    }
    if (threadCount) {
        threadCount.textContent = `${currentSettings.robocopyThreads} 线程`;
    }

    updateThemeButtons();
}

function updateKbdHints(): void {
    if (!currentSettings) return;
}

function updateThemeButtons(): void {
    if (!currentSettings) return;
    document.querySelectorAll('.theme-option').forEach(btn => {
        const theme = btn.getAttribute('data-theme');
        btn.classList.toggle('active', theme === currentSettings?.themeMode);
    });

    const modeLabel = document.getElementById('theme-mode-label');
    if (modeLabel) {
        const labels: Record<string, string> = {
            'light': '浅色主题',
            'dark': '深色主题',
            'system': '跟随系统设置',
        };
        modeLabel.textContent = labels[currentSettings.themeMode];
    }
}

async function setThemeMode(mode: 'light' | 'dark' | 'system'): Promise<void> {
    if (!currentSettings) return;
    currentSettings.themeMode = mode;
    await saveSettings();
    updateThemeButtons();
}

async function toggleAutoStart(): Promise<void> {
    try {
        const enabled = currentSettings ? !currentSettings.autoStart : false;
        await invoke('set_auto_start', { enabled });
        await loadSettings();
    } catch (error) {
        console.error('Failed to toggle auto start:', error);
    }
}

async function toggleMinimizeToTray(enabled: boolean): Promise<void> {
    if (!currentSettings) return;
    currentSettings.minimizeToTray = enabled;
    await saveSettings();
}

async function toggleNotifications(enabled: boolean): Promise<void> {
    if (!currentSettings) return;
    currentSettings.showNotifications = enabled;
    await saveSettings();
}

async function toggleMergeRules(enabled: boolean): Promise<void> {
    if (!currentSettings) return;
    currentSettings.mergeGlobalRules = enabled;
    await saveSettings();
}

async function setRobocopyThreads(threads: number): Promise<void> {
    if (!currentSettings) return;
    currentSettings.robocopyThreads = threads;
    await saveSettings();

    const threadCount = document.getElementById('thread-count');
    if (threadCount) threadCount.textContent = `${threads} 线程`;
}

async function toggleRightClickMenu(): Promise<void> {
    try {
        await invoke('toggle_right_click_menu');
        await loadSettings();
    } catch (error) {
        console.error('Failed to toggle right click menu:', error);
    }
}

// =============================================
// UI Updates
// =============================================

function updateNavBadges(): void {
    const profilesCount = document.getElementById('profiles-count');
    const rulesCount = document.getElementById('rules-count');

    if (profilesCount) {
        if (currentProfiles.length > 0) {
            profilesCount.textContent = String(currentProfiles.length);
            profilesCount.classList.remove('hidden');
        } else {
            profilesCount.classList.add('hidden');
        }
    }

    if (rulesCount) {
        const totalRules = currentSettings ? 
            currentSettings.globalBlacklistFolders.length + 
            currentSettings.globalBlacklistFiles.length : 0;
        if (totalRules > 0) {
            rulesCount.textContent = String(totalRules);
            rulesCount.classList.remove('hidden');
        } else {
            rulesCount.classList.add('hidden');
        }
    }
}

function updateRulesStats(): void {
    const foldersCount = document.getElementById('folders-count');
    const filesCount = document.getElementById('files-count');

    if (foldersCount) {
        foldersCount.textContent = String(currentSettings?.globalBlacklistFolders.length ?? 0);
    }
    if (filesCount) {
        filesCount.textContent = String(currentSettings?.globalBlacklistFiles.length ?? 0);
    }
}

function updateSourceIndicator(): void {
    const indicator = document.getElementById('source-indicator');
    const sourcePathShort = document.getElementById('source-path-short');

    if (indicator && sourcePathShort) {
        if (copySource) {
            indicator.classList.remove('hidden');
            sourcePathShort.textContent = getShortPath(copySource);
        } else {
            indicator.classList.add('hidden');
        }
    }
}

function updateSourceSelector(): void {
    const sourceSelector = document.getElementById('source-selector');
    const sourceHint = document.getElementById('source-hint');
    const clearSourceLabel = document.getElementById('clear-source-label');

    if (sourceSelector && sourceHint) {
        if (copySource) {
            sourceSelector.classList.add('set');
            sourceHint.textContent = copySource;
        } else {
            sourceSelector.classList.remove('set');
            sourceHint.textContent = '点击选择文件或文件夹，或使用 Ctrl+Shift+C';
        }
    }

    if (clearSourceLabel) {
        if (copySource) {
            clearSourceLabel.classList.remove('hidden');
        } else {
            clearSourceLabel.classList.add('hidden');
        }
    }
}

function updateDestSelector(): void {
    const destSelector = document.getElementById('dest-selector');
    const destHint = document.getElementById('dest-hint');
    const clearDestLabel = document.getElementById('clear-dest-label');

    if (destSelector && destHint) {
        if (destPath) {
            destSelector.classList.add('set', 'secondary');
            destHint.textContent = destPath;
        } else {
            destSelector.classList.remove('set', 'secondary');
            destHint.textContent = '点击选择粘贴目标目录';
        }
    }

    if (clearDestLabel) {
        if (destPath) {
            clearDestLabel.classList.remove('hidden');
        } else {
            clearDestLabel.classList.add('hidden');
        }
    }
}

async function updateRulePreview(): Promise<void> {
    const preview = document.getElementById('rule-preview');
    const ruleTags = document.getElementById('rule-tags');
    const profileTag = document.getElementById('profile-tag');

    if (!preview || !copySource || !currentSettings) {
        if (preview) preview.classList.add('hidden');
        return;
    }

    if (preview && ruleTags) {
        const folders = [...currentSettings.globalBlacklistFolders];
        const files = [...currentSettings.globalBlacklistFiles];

        // Find matching profile
        let matchingProfile: FolderProfile | null = null;
        const normalizedSource = copySource.replace(/\\/g, '/').toLowerCase();

        for (const profile of currentProfiles) {
            if (!profile.enabled) continue;
            const normalizedProfilePath = profile.folderPath.replace(/\\/g, '/').toLowerCase();
            if (normalizedSource.startsWith(normalizedProfilePath)) {
                if (!matchingProfile || 
                    normalizedProfilePath.length > matchingProfile.folderPath.replace(/\\/g, '/').length) {
                    matchingProfile = profile;
                }
            }
        }

        // Merge rules if needed
        if (matchingProfile && currentSettings.mergeGlobalRules) {
            folders.push(...matchingProfile.blacklistFolders);
            files.push(...matchingProfile.blacklistFiles);
        }

        // Remove duplicates
        const uniqueFolders = [...new Set(folders)];
        const uniqueFiles = [...new Set(files)];

        // Render tags
        ruleTags.innerHTML = [
            ...uniqueFolders.slice(0, 6).map(rule => `
                <span class="tag-chip warning">
                    <svg class="chip-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
                    </svg>
                    ${escapeHtml(rule)}
                </span>
            `),
            ...uniqueFiles.slice(0, 6).map(rule => `
                <span class="tag-chip danger">
                    <svg class="chip-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
                    </svg>
                    ${escapeHtml(rule)}
                </span>
            `),
        ].join('');

        // Show profile tag
        if (profileTag) {
            if (matchingProfile) {
                profileTag.textContent = `+ ${matchingProfile.name}`;
                profileTag.classList.remove('hidden');
            } else {
                profileTag.classList.add('hidden');
            }
        }

        preview.classList.remove('hidden');
    }
}

// =============================================
// File Selection
// =============================================

async function selectSourceFile(): Promise<void> {
    try {
        const selected = await open({
            multiple: false,
            filters: [{ name: 'All Files', extensions: ['*'] }],
        });
        if (selected) {
            copySource = selected as string;
            await invoke('set_copy_source', { path: copySource });
            updateSourceIndicator();
            updateSourceSelector();
            await updateRulePreview();
        }
    } catch (error) {
        console.error('Failed to select source:', error);
    }
}

async function selectSourceFolder(): Promise<void> {
    try {
        const selected = await open({
            multiple: false,
            directory: true,
        });
        if (selected) {
            copySource = selected as string;
            await invoke('set_copy_source', { path: copySource });
            updateSourceIndicator();
            updateSourceSelector();
            await updateRulePreview();
        }
    } catch (error) {
        console.error('Failed to select source:', error);
    }
}

async function selectDest(): Promise<void> {
    try {
        const selected = await open({
            multiple: false,
            directory: true,
        });
        if (selected) {
            destPath = selected as string;
            updateDestSelector();
        }
    } catch (error) {
        console.error('Failed to select destination:', error);
    }
}

async function clearSource(): Promise<void> {
    copySource = null;
    await invoke('clear_copy_source');
    updateSourceIndicator();
    updateSourceSelector();
    const preview = document.getElementById('rule-preview');
    if (preview) preview.classList.add('hidden');
}

async function clearDest(): Promise<void> {
    destPath = null;
    updateDestSelector();
}

async function clearAll(): Promise<void> {
    await clearSource();
    await clearDest();
}

// =============================================
// Copy Execution
// =============================================

async function startCopy(): Promise<void> {
    if (!copySource || !destPath) return;

    const executeBtn = document.getElementById('execute-btn');
    const executeLabel = document.getElementById('execute-label');

    try {
        // First scan
        if (executeBtn) executeBtn.disabled = true;
        if (executeLabel) executeLabel.textContent = '正在扫描...';

        currentScanResult = await invoke<ScanResult>('scan_source', {
            sourcePath: copySource,
            destPath,
        });

        // Check for duplicates
        if (currentScanResult.duplicates.length > 0) {
            openDuplicateModal(currentScanResult.duplicates);
            if (executeBtn) executeBtn.disabled = false;
            if (executeLabel) executeLabel.textContent = '开始智能复制';
            return;
        }

        // No duplicates, start copy directly
        await executeCopy('skip');
    } catch (error) {
        console.error('Copy failed:', error);
        if (executeBtn) executeBtn.disabled = false;
        if (executeLabel) executeLabel.textContent = '开始智能复制';
    }
}

async function executeCopy(resolution: 'skip' | 'overwrite' | 'keepnewer'): Promise<void> {
    if (!copySource || !destPath) return;

    const executeBtn = document.getElementById('execute-btn');
    const executeLabel = document.getElementById('execute-label');
    const activeTaskPanel = document.getElementById('active-task-panel');

    isCopying = true;

    if (executeBtn) executeBtn.disabled = true;
    if (executeLabel) executeLabel.textContent = '复制中...';
    if (activeTaskPanel) activeTaskPanel.classList.remove('hidden');

    try {
        const task = await invoke<CopyTask>('execute_copy', {
            destPath,
            resolution,
        });

        showResult(task);
    } catch (error) {
        console.error('Copy failed:', error);
    } finally {
        isCopying = false;
        if (executeBtn) executeBtn.disabled = false;
        if (executeLabel) executeLabel.textContent = '开始智能复制';
        await loadHistory();
    }
}

async function cancelCopy(): Promise<void> {
    try {
        await invoke('cancel_copy');
    } catch (error) {
        console.error('Failed to cancel copy:', error);
    }
}

// =============================================
// Task Panel
// =============================================

function updateActiveTask(task: CopyTask): void {
    const taskName = document.getElementById('task-name');
    const taskCurrentFile = document.getElementById('task-current-file');
    const progressBar = document.getElementById('progress-bar');
    const copiedCount = document.getElementById('copied-count');
    const skippedCount = document.getElementById('skipped-count');
    const failedCount = document.getElementById('failed-count');
    const failedPill = document.getElementById('failed-pill');
    const progressText = document.getElementById('progress-text');
    const speedSection = document.getElementById('speed-section');
    const speedText = document.getElementById('speed-text');
    const etaItem = document.getElementById('eta-item');
    const etaText = document.getElementById('eta-text');

    if (taskName) taskName.textContent = getShortPath(task.sourcePath);

    if (taskCurrentFile) {
        if (task.currentFile) {
            taskCurrentFile.textContent = task.currentFile;
            taskCurrentFile.classList.remove('hidden');
        } else {
            taskCurrentFile.classList.add('hidden');
        }
    }

    if (progressBar) {
        const progress = task.bytesTotal > 0 ? (task.bytesCopied / task.bytesTotal) * 100 :
            task.totalFiles > 0 ? (task.copiedFiles / task.totalFiles) * 100 : 0;
        progressBar.style.width = `${progress}%`;
    }

    if (copiedCount) copiedCount.textContent = String(task.copiedFiles);
    if (skippedCount) skippedCount.textContent = String(task.skippedFiles);
    if (failedCount) failedCount.textContent = String(task.failedFiles);
    if (failedPill) {
        failedPill.classList.toggle('hidden', task.failedFiles === 0);
    }

    if (progressText) {
        if (task.bytesTotal > 0) {
            progressText.textContent = `${Math.round(task.progress)}% • ${formatBytes(task.bytesCopied)}/${formatBytes(task.bytesTotal)}`;
        } else {
            progressText.textContent = '';
        }
    }

    if (speedSection) {
        speedSection.classList.toggle('hidden', task.speedBytesPerSecond === null);
    }
    if (speedText && task.speedBytesPerSecond) {
        speedText.textContent = `${formatBytes(task.speedBytesPerSecond)}/秒`;
    }

    if (etaItem) {
        etaItem.classList.toggle('hidden', task.estimatedRemainingSeconds === null);
    }
    if (etaText && task.estimatedRemainingSeconds) {
        etaText.textContent = `剩余约 ${formatDuration(task.estimatedRemainingSeconds)}`;
    }
}

function showResult(task: CopyTask): void {
    const activeTaskPanel = document.getElementById('active-task-panel');
    if (activeTaskPanel) activeTaskPanel.classList.add('hidden');

    renderHistory();
}

// =============================================
// History Panel
// =============================================

function renderHistory(): void {
    const historySection = document.getElementById('history-section');
    const historyList = document.getElementById('history-list');

    if (!historySection || !historyList) return;

    if (taskHistory.length === 0) {
        historySection.classList.add('hidden');
        return;
    }

    historySection.classList.remove('hidden');

    historyList.innerHTML = taskHistory.slice(0, 10).map(task => {
        const isSuccess = task.status === 'success';
        const isFailed = task.status === 'failed';
        const statusColor = isSuccess ? 'success' : isFailed ? 'error' : 'success';

        return `
            <div class="history-item">
                <div class="history-item-icon ${statusColor}">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        ${isSuccess ? `
                            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                            <polyline points="22 4 12 14.01 9 11.01"/>
                        ` : isFailed ? `
                            <circle cx="12" cy="12" r="10"/>
                            <line x1="15" y1="9" x2="9" y2="15"/>
                            <line x1="9" y1="9" x2="15" y2="15"/>
                        ` : `
                            <circle cx="12" cy="12" r="10"/>
                            <line x1="15" y1="9" x2="9" y2="15"/>
                            <line x1="9" y1="9" x2="15" y2="15"/>
                        `}
                    </svg>
                </div>
                <div class="history-item-info">
                    <span class="history-item-name">${escapeHtml(getShortPath(task.sourcePath))}</span>
                    <span class="history-item-dest">${escapeHtml(formatDestPath(task.destPath))}</span>
                </div>
                <div class="history-item-meta">
                    <span class="history-item-count ${statusColor}">${task.copiedFiles} 个文件</span>
                    <span class="history-item-time">${formatTimeString(task.finishedAt || task.startedAt)}</span>
                </div>
            </div>
        `;
    }).join('');
}

async function clearHistory(): Promise<void> {
    if (!confirm('确定要清空历史记录吗？')) return;

    try {
        await invoke('clear_task_history');
        taskHistory = [];
        renderHistory();
    } catch (error) {
        console.error('Failed to clear history:', error);
    }
}

// =============================================
// Duplicate File Modal
// =============================================

function openDuplicateModal(duplicates: DuplicateFile[]): void {
    const modal = document.getElementById('duplicate-modal');
    const countText = document.getElementById('duplicate-count-text');
    const duplicateList = document.getElementById('duplicate-list');

    if (!modal || !countText || !duplicateList) return;

    countText.textContent = `有 ${duplicates.length} 个文件已存在于目标目录`;

    duplicateList.innerHTML = duplicates.map(dup => `
        <div class="duplicate-item">
            <div class="duplicate-item-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
                </svg>
            </div>
            <div class="duplicate-item-info">
                <span class="duplicate-item-name">${escapeHtml(dup.source.relativePath)}</span>
                <span class="duplicate-item-meta">
                    源: ${formatBytes(dup.source.size)} · ${new Date(dup.source.modified).toLocaleString()}
                </span>
            </div>
        </div>
    `).join('');

    modal.classList.remove('hidden');
}

function closeDuplicateModal(): void {
    const modal = document.getElementById('duplicate-modal');
    if (modal) modal.classList.add('hidden');
}

async function confirmDuplicate(): Promise<void> {
    const selected = document.querySelector('input[name="resolution"]:checked') as HTMLInputElement;
    const resolution = selected?.value as 'skip' | 'overwrite' | 'keepnewer' || 'skip';

    closeDuplicateModal();
    await executeCopy(resolution);
}

// =============================================
// Event Listeners
// =============================================

function initEventListeners(): void {
    // Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => {
            const tabName = (item as HTMLElement).dataset.tab;
            if (tabName) switchTab(tabName);
        });
    });

    // Rules tabs
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const tabName = (btn as HTMLElement).dataset.rulesTab;
            if (tabName) switchRulesTab(tabName);
        });
    });

    // Source indicator
    document.getElementById('clear-source-btn')?.addEventListener('click', clearSource);

    // Source selection
    document.getElementById('select-file-btn')?.addEventListener('click', selectSourceFile);
    document.getElementById('select-folder-btn')?.addEventListener('click', selectSourceFolder);
    document.getElementById('source-selector')?.addEventListener('click', (e) => {
        if (!(e.target as HTMLElement).closest('.path-selector-actions')) {
            selectSourceFolder();
        }
    });
    document.getElementById('clear-source-label')?.addEventListener('click', clearSource);

    // Dest selection
    document.getElementById('dest-selector')?.addEventListener('click', selectDest);
    document.getElementById('clear-dest-label')?.addEventListener('click', clearDest);

    // Execute buttons
    document.getElementById('execute-btn')?.addEventListener('click', startCopy);
    document.getElementById('clear-btn')?.addEventListener('click', clearAll);
    document.getElementById('cancel-task-btn')?.addEventListener('click', cancelCopy);

    // History
    document.getElementById('clear-history-btn')?.addEventListener('click', clearHistory);

    // Profiles
    document.getElementById('add-profile-btn')?.addEventListener('click', () => openProfileModal());
    document.getElementById('close-modal-btn')?.addEventListener('click', closeProfileModal);
    document.getElementById('cancel-modal-btn')?.addEventListener('click', closeProfileModal);
    document.getElementById('save-profile-btn')?.addEventListener('click', saveProfile);
    document.getElementById('browse-profile-btn')?.addEventListener('click', browseProfilePath);

    // Templates
    document.querySelectorAll('.template-chip').forEach(chip => {
        chip.addEventListener('click', () => {
            const template = (chip as HTMLElement).dataset.template;
            if (template) applyTemplate(template);
        });
    });

    // Rules
    document.getElementById('add-folder-btn')?.addEventListener('click', addFolderRule);
    document.getElementById('add-file-btn')?.addEventListener('click', addFileRule);
    document.getElementById('import-gitignore-btn')?.addEventListener('click', importGitignore);

    document.getElementById('new-folder-input')?.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') addFolderRule();
    });
    document.getElementById('new-file-input')?.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') addFileRule();
    });

    document.querySelectorAll('.preset-chip').forEach(chip => {
        chip.addEventListener('click', () => {
            const rule = (chip as HTMLElement).dataset.preset;
            if (rule) addPresetRule(rule, (chip as HTMLElement).closest('.tab-content')?.id === 'tab-folders' ? 'folder' : 'file');
        });
    });

    // Settings toggles
    document.getElementById('autostart-toggle')?.addEventListener('click', toggleAutoStart);
    document.getElementById('tray-toggle')?.addEventListener('click', () => {
        const toggle = document.getElementById('tray-toggle');
        if (toggle) {
            const isActive = !toggle.classList.contains('active');
            toggle.classList.toggle('active', !isActive);
            toggleMinimizeToTray(!isActive);
        }
    });
    document.getElementById('notifications-toggle')?.addEventListener('click', () => {
        const toggle = document.getElementById('notifications-toggle');
        if (toggle) {
            const isActive = !toggle.classList.contains('active');
            toggle.classList.toggle('active', !isActive);
            toggleNotifications(!isActive);
        }
    });
    document.getElementById('merge-rules-toggle')?.addEventListener('click', () => {
        const toggle = document.getElementById('merge-rules-toggle');
        if (toggle) {
            const isActive = !toggle.classList.contains('active');
            toggle.classList.toggle('active', !isActive);
            toggleMergeRules(!isActive);
        }
    });

    document.getElementById('thread-slider')?.addEventListener('input', (e) => {
        const value = parseInt((e.target as HTMLInputElement).value);
        setRobocopyThreads(value);
    });

    document.querySelectorAll('.theme-option').forEach(btn => {
        btn.addEventListener('click', () => {
            const theme = (btn as HTMLElement).dataset.theme as 'light' | 'dark' | 'system';
            if (theme) setThemeMode(theme);
        });
    });

    // Duplicate modal
    document.getElementById('cancel-duplicate-btn')?.addEventListener('click', closeDuplicateModal);
    document.getElementById('confirm-duplicate-btn')?.addEventListener('click', confirmDuplicate);

    // Close modals on overlay click
    document.querySelectorAll('.modal-overlay').forEach(overlay => {
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) {
                (overlay as HTMLElement).classList.add('hidden');
            }
        });
    });
}

// =============================================
// Expose functions to global scope for inline handlers
// =============================================

(window as any).removeFolderRule = removeFolderRule;
(window as any).removeFileRule = removeFileRule;
(window as any).editProfile = editProfile;
(window as any).deleteProfile = deleteProfile;
(window as any).closeProfileModal = closeProfileModal;

// =============================================
// Init
// =============================================

async function init(): Promise<void> {
    console.log('SmartCopy initializing...');

    try {
        await Promise.all([
            loadSettings(),
            loadProfiles(),
            loadCopySource(),
            loadHistory(),
        ]);

        initEventListeners();

        console.log('SmartCopy initialized');
    } catch (error) {
        console.error('Initialization failed:', error);
    }
}

init();
