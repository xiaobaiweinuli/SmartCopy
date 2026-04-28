import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/folder_profile.dart';
import '../models/app_settings.dart';
import '../models/copy_task.dart';
import '../utils/app_dir.dart';

class StorageService {
  static const _profilesFileName = 'profiles.json';
  static const _settingsFileName = 'settings.json';
  static const _tasksFileName = 'tasks.json';
  static const _maxTaskHistory = 50;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // 确保数据目录存在
    AppDir.dataDirectory;
    _initialized = true;
  }

  String get _profilesPath => p.join(AppDir.dataDirectory.path, _profilesFileName);
  String get _settingsPath => p.join(AppDir.dataDirectory.path, _settingsFileName);
  String get _tasksPath => p.join(AppDir.dataDirectory.path, _tasksFileName);

  // ─── Profiles ───────────────────────────────────────────────

  Future<List<FolderProfile>> loadProfiles() async {
    _assertInit();
    final file = File(_profilesPath);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => FolderProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfiles(List<FolderProfile> profiles) async {
    _assertInit();
    final json = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await File(_profilesPath).writeAsString(json);
  }

  Future<FolderProfile> addProfile(FolderProfile profile) async {
    final profiles = await loadProfiles();
    final newProfile = FolderProfile(
      id: const Uuid().v4(),
      name: profile.name,
      folderPath: profile.folderPath,
      blacklistFolders: profile.blacklistFolders,
      blacklistFiles: profile.blacklistFiles,
      enabled: profile.enabled,
    );
    profiles.add(newProfile);
    await saveProfiles(profiles);
    return newProfile;
  }

  Future<void> updateProfile(FolderProfile updated) async {
    final profiles = await loadProfiles();
    final idx = profiles.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      profiles[idx] = updated;
      await saveProfiles(profiles);
    }
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);
    await saveProfiles(profiles);
  }

  // ─── Settings ───────────────────────────────────────────────

  Future<AppSettings> loadSettings() async {
    _assertInit();
    final file = File(_settingsPath);
    if (!await file.exists()) return AppSettings();
    try {
      final content = await file.readAsString();
      return AppSettings.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    _assertInit();
    await File(_settingsPath).writeAsString(settings.toJsonString());
  }

  // ─── Task History ────────────────────────────────────────────

  Future<List<CopyTask>> loadTaskHistory() async {
    _assertInit();
    final file = File(_tasksPath);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => CopyTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendTask(CopyTask task) async {
    _assertInit();
    final tasks = await loadTaskHistory();
    tasks.insert(0, task);
    // 只保留最近 N 条
    final trimmed = tasks.take(_maxTaskHistory).toList();
    await File(_tasksPath)
        .writeAsString(jsonEncode(trimmed.map((t) => t.toJson()).toList()));
  }

  Future<void> clearTaskHistory() async {
    _assertInit();
    await File(_tasksPath).writeAsString('[]');
  }

  // ─── Utility ─────────────────────────────────────────────────

  String get dataDirectory => AppDir.dataDirectory.path;

  void _assertInit() {
    if (!_initialized) throw StateError('StorageService not initialized');
  }
}
