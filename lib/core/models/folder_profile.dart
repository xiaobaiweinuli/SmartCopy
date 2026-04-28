import 'dart:convert';

class FolderProfile {
  final String id;
  String name;
  String folderPath;
  List<String> blacklistFolders;
  List<String> blacklistFiles;
  bool enabled;
  final DateTime createdAt;
  DateTime updatedAt;

  FolderProfile({
    required this.id,
    required this.name,
    required this.folderPath,
    List<String>? blacklistFolders,
    List<String>? blacklistFiles,
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : blacklistFolders = blacklistFolders ?? [],
        blacklistFiles = blacklistFiles ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalRules => blacklistFolders.length + blacklistFiles.length;

  FolderProfile copyWith({
    String? name,
    String? folderPath,
    List<String>? blacklistFolders,
    List<String>? blacklistFiles,
    bool? enabled,
  }) {
    return FolderProfile(
      id: id,
      name: name ?? this.name,
      folderPath: folderPath ?? this.folderPath,
      blacklistFolders: blacklistFolders ?? List.from(this.blacklistFolders),
      blacklistFiles: blacklistFiles ?? List.from(this.blacklistFiles),
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folderPath': folderPath,
        'blacklistFolders': blacklistFolders,
        'blacklistFiles': blacklistFiles,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FolderProfile.fromJson(Map<String, dynamic> json) => FolderProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        folderPath: json['folderPath'] as String,
        blacklistFolders: List<String>.from(json['blacklistFolders'] ?? []),
        blacklistFiles: List<String>.from(json['blacklistFiles'] ?? []),
        enabled: json['enabled'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      );

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => 'FolderProfile($id, $name, $folderPath)';
}
