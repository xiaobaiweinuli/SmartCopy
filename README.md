# SmartCopy - Windows 智能过滤文件复制工具（Flutter Desktop）

**基于 Flutter + Robocopy 引擎构建的绿色便携文件复制工具，像 `.gitignore` 一样精准排除不需要的文件夹与文件。**

[![Platform](https://img.shields.io/badge/platform-Windows-blue?logo=windows)](https://github.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.22+-54C5F8?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## ✨ 核心特性

| 功能 | 描述 |
|------|------|
| 🚫 **智能过滤** | 支持 glob 通配符（`*.log`、`node_modules`），语法与 `.gitignore` 完全一致 |
| 📂 **文件夹 Profile** | 为不同项目目录设置独立过滤规则，自动匹配最深路径 |
| 🌍 **全局黑名单** | 全局规则可叠加到 Profile，一次配置处处生效 |
| ⚡ **Robocopy 引擎** | 内置 Windows Robocopy，多线程高速复制，支持断点续传 |
| 🖱️ **右键菜单集成** | 注册到 HKCU，无需管理员权限，文件夹右键出现 Smart Copy / Paste |
| ⌨️ **全局快捷键** | 可自定义 Ctrl+Shift+C/V，系统级监听不受窗口焦点限制 |
| 🔔 **系统托盘** | 最小化到托盘，支持开机自启（写 HKCU\\Run） |
| 📥 **.gitignore 导入** | 一键粘贴 .gitignore 内容自动解析导入 |
| 🔄 **重复文件处理** | 复制前预扫描检测重复，支持「跳过」「覆盖」「保留较新」三种策略 |
| 📊 **进度显示** | 实时显示字节级进度、复制速度和剩余时间，媲美系统原生 |
| 🟢 **绿色便携** | 所有数据和日志存程序目录，完全独立可迁移 |

---

## 🚀 快速使用

### 方式一：快捷键流程（推荐）

```
1. 在文件资源管理器中 Ctrl+C 复制文件夹
2. 按 Ctrl+Shift+C  →  SmartCopy 捕获复制源
3. 导航到目标目录
4. 按 Ctrl+Shift+V  →  唤起主窗口选择目标目录
5. 点击「开始智能复制」
```

### 方式二：右键菜单流程

```
1. 右键源文件夹 → "Smart Copy"
2. 右键目标目录空白处 → "Smart Paste Here"
   （或在主界面手动选择目标目录）
```

---

## 📐 架构说明

```
SmartCopy
├── lib/
│   ├── core/
│   │   ├── models/          # FolderProfile / AppSettings / CopyTask
│   │   ├── services/
│   │   │   ├── copy_engine.dart      # Robocopy 包装器 + 进度解析
│   │   │   ├── registry_service.dart # 注册表 Shell Verb 管理
│   │   │   ├── clipboard_service.dart# CF_HDROP 剪贴板读取
│   │   │   ├── storage_service.dart  # JSON 持久化
│   │   │   ├── tray_service.dart     # 系统托盘
│   │   │   └── ipc_service.dart      # 单实例 IPC
│   │   └── utils/
│   │       └── glob_matcher.dart     # .gitignore 风格规则匹配
│   ├── providers/
│   │   └── app_provider.dart         # 全局状态（Provider）
│   └── ui/
│       ├── theme/app_theme.dart      # 深色精美主题
│       ├── widgets/                  # 公共 Widget 库
│       └── screens/                  # 四个功能页面
└── windows/                          # Windows 平台代码
```
---

## 🛠️ 开发构建

```bash
# 环境要求
flutter --version   # >= 3.22
dart --version      # >= 3.3

# 安装依赖
flutter pub get

# 运行（开发模式）
flutter run -d windows

# 构建发布版
flutter build windows --release

# 输出路径
build/windows/x64/runner/Release/smartcopy.exe

# GitHub 自动发布
1. 创建并推送版本标签
```bash
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0
```

2. 或在 GitHub Actions 页面手动触发「Build and Release SmartCopy」工作流

---

## 📋 过滤规则语法

| 写法 | 含义 |
|------|------|
| `node_modules` | 精确匹配名为 node_modules 的文件/文件夹 |
| `*.log` | 匹配所有 .log 文件 |
| `*.tmp` | 匹配所有 .tmp 临时文件 |
| `build` | 匹配名为 build 的文件夹 |
| `Thumbs.db` | 精确匹配文件名 |

> 规则通过 `GlobMatcher`（lib/core/utils/glob_matcher.dart）解析，对文件夹黑名单传递给 Robocopy `/XD` 参数，文件黑名单传递给 `/XF` 参数。

---

## 依赖项

| 包 | 用途 |
|----|------|
| `window_manager` | 无边框窗口、拖拽、最小化控制 |
| `tray_manager` | 系统托盘图标与菜单 |
| `hotkey_manager` | 全局快捷键注册 |
| `provider` | 状态管理 |
| `win32` | CF_HDROP 剪贴板读取 |
| `local_notifier` | 系统通知 |
| `file_picker` | 目录/文件选择对话框 |
| `google_fonts` | Inter 字体 |
| `flutter_animate` | 精美动画效果 |
| `charset` | 多编码字符集解码（用于 Robocopy 输出解析） |

