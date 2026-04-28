import 'dart:io';
import 'dart:convert';
import 'logger_service.dart';

/// 从系统剪贴板读取文件路径列表
/// 使用 Shell.Application COM 方案获取 Explorer 当前选中的文件
class ClipboardService {
  /// 检测是否有选中文件
  static Future<bool> hasFiles() async {
    final files = await getFiles();
    return files.isNotEmpty;
  }

  /// 获取当前文件管理器窗口的路径
  static Future<String?> getCurrentWindowPath() async {
    if (!Platform.isWindows) return null;
    
    final logger = _Logger();
    try {
      logger.log('尝试获取当前窗口路径');
      
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

$foregroundHWnd = [Win32]::GetForegroundWindow()
$objShell = New-Object -ComObject "Shell.Application"
$windows = $objShell.Windows()

if ($windows.Count -gt 0) {
    # 获取所有打开的文件管理器窗口
    $explorerWindows = $windows | Where-Object { $_.Name -eq "Windows Explorer" -or $_.Name -eq "文件资源管理器" }
    if ($explorerWindows) {
        # 优先找与前台窗口匹配的窗口
        foreach ($win in $explorerWindows) {
            try {
                if ($win.HWND -ne $null -and $win.HWND -eq $foregroundHWnd.ToInt32()) {
                    $path = $win.Document.Folder.Self.Path
                    if ($path -and (Test-Path $path)) {
                        Write-Output $path
                        exit 0
                    }
                }
            } catch {}
        }
        
        # 如果前台窗口不匹配，再找有选中文件的窗口
        foreach ($win in $explorerWindows) {
            try {
                $selectedItems = $win.Document.SelectedItems()
                if ($selectedItems -and $selectedItems.Count -gt 0) {
                    $path = $win.Document.Folder.Self.Path
                    if ($path -and (Test-Path $path)) {
                        Write-Output $path
                        exit 0
                    }
                }
            } catch {}
        }
        
        # 最后尝试任意窗口
        foreach ($win in $explorerWindows) {
            try {
                $path = $win.Document.Folder.Self.Path
                if ($path -and (Test-Path $path)) {
                    Write-Output $path
                    exit 0
                }
            } catch {}
        }
    }
}

# 如果没找到，尝试获取最后一个窗口
if ($windows.Count -gt 0) {
    $lastWin = $windows | Select-Object -Last 1
    try {
        $path = $lastWin.Document.Folder.Self.Path
        if ($path -and (Test-Path $path)) {
            Write-Output $path
        }
    } catch {}
}
''',
        ],
        runInShell: false,
      );
      
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        logger.log('获取到窗口路径：$path');
        if (path.isNotEmpty && Directory(path).existsSync()) {
          return path;
        }
      } else {
        logger.log('PowerShell 退出码：${result.exitCode}');
        logger.log('PowerShell stderr：${result.stderr}');
      }
      
      logger.log('未获取到窗口路径');
      return null;
    } catch (e) {
      logger.log('获取窗口路径异常：$e');
      return null;
    }
  }

  /// 读取当前文件路径列表（异步）
  static Future<List<String>> getFiles() async {
    if (!Platform.isWindows) return [];
    
    final logger = _Logger();
    try {
      logger.log('开始获取 Explorer 选中文件（Shell.Application 方案）');
      
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

$foregroundHWnd = [Win32]::GetForegroundWindow()
$shellApp = New-Object -ComObject Shell.Application
$explorerWindows = $shellApp.Windows() | Where-Object { $_.Name -eq "Windows Explorer" -or $_.Name -eq "文件资源管理器" }

$files = @()
if ($explorerWindows) {
    # 优先找与前台窗口匹配的窗口
    foreach ($window in $explorerWindows) {
        try {
            if ($window.HWND -ne $null -and $window.HWND -eq $foregroundHWnd.ToInt32()) {
                $selectedItems = $window.Document.SelectedItems()
                foreach ($item in $selectedItems) {
                    $files += $item.Path
                }
                if ($files.Count -gt 0) {
                    break
                }
            }
        } catch {}
    }
    
    # 如果没找到，再找任意有选中文件的窗口
    if ($files.Count -eq 0) {
        foreach ($window in $explorerWindows) {
            try {
                $selectedItems = $window.Document.SelectedItems()
                foreach ($item in $selectedItems) {
                    $files += $item.Path
                }
                if ($files.Count -gt 0) {
                    break
                }
            } catch {}
        }
    }
}

if ($files.Count -gt 0) {
    $json = $files | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $base64 = [System.Convert]::ToBase64String($bytes)
    Write-Output $base64
}
''',
        ],
        runInShell: false,
      );
      
      logger.log('PowerShell 退出码：${result.exitCode}');
      if (result.exitCode != 0) {
        logger.log('PowerShell stderr：${result.stderr}');
        return [];
      }
      
      final base64 = result.stdout.toString().trim();
      logger.log('收到 Base64 内容：${base64.isNotEmpty ? '有数据' : '空'}');
      
      if (base64.isEmpty) {
        logger.log('未找到选中文件');
        return [];
      }
      
      // 解码 Base64
      final bytes = base64Decode(base64);
      final json = utf8.decode(bytes);
      logger.log('解码后的 JSON：$json');
      
      // 解析 JSON
      final dynamic parsed = jsonDecode(json);
      
      List<String> files;
      if (parsed is List) {
        files = parsed.cast<String>();
      } else if (parsed is String) {
        files = [parsed];
      } else {
        logger.log('无法解析 JSON：$parsed');
        return [];
      }
      
      logger.log('找到 ${files.length} 个文件');
      return files;
    } catch (e) {
      logger.log('获取选中文件异常：$e');
      return [];
    }
  }

  /// 同步版本
  static List<String> getFilesSync() {
    if (!Platform.isWindows) return [];
    
    final logger = _Logger();
    try {
      logger.log('开始获取 Explorer 选中文件（同步，Shell.Application 方案）');
      
      final result = Process.runSync(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

$foregroundHWnd = [Win32]::GetForegroundWindow()
$shellApp = New-Object -ComObject Shell.Application
$explorerWindows = $shellApp.Windows() | Where-Object { $_.Name -eq "Windows Explorer" -or $_.Name -eq "文件资源管理器" }

$files = @()
if ($explorerWindows) {
    # 优先找与前台窗口匹配的窗口
    foreach ($window in $explorerWindows) {
        try {
            if ($window.HWND -ne $null -and $window.HWND -eq $foregroundHWnd.ToInt32()) {
                $selectedItems = $window.Document.SelectedItems()
                foreach ($item in $selectedItems) {
                    $files += $item.Path
                }
                if ($files.Count -gt 0) {
                    break
                }
            }
        } catch {}
    }
    
    # 如果没找到，再找任意有选中文件的窗口
    if ($files.Count -eq 0) {
        foreach ($window in $explorerWindows) {
            try {
                $selectedItems = $window.Document.SelectedItems()
                foreach ($item in $selectedItems) {
                    $files += $item.Path
                }
                if ($files.Count -gt 0) {
                    break
                }
            } catch {}
        }
    }
}

if ($files.Count -gt 0) {
    $json = $files | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $base64 = [System.Convert]::ToBase64String($bytes)
    Write-Output $base64
}
''',
        ],
        runInShell: false,
      );
      
      logger.log('PowerShell 退出码：${result.exitCode}');
      if (result.exitCode != 0) {
        logger.log('PowerShell stderr：${result.stderr}');
        return [];
      }
      
      final base64 = result.stdout.toString().trim();
      logger.log('收到 Base64 内容：${base64.isNotEmpty ? '有数据' : '空'}');
      
      if (base64.isEmpty) {
        logger.log('未找到选中文件');
        return [];
      }
      
      final bytes = base64Decode(base64);
      final json = utf8.decode(bytes);
      logger.log('解码后的 JSON：$json');
      
      final dynamic parsed = jsonDecode(json);
      
      List<String> files;
      if (parsed is List) {
        files = parsed.cast<String>();
      } else if (parsed is String) {
        files = [parsed];
      } else {
        logger.log('无法解析 JSON：$parsed');
        return [];
      }
      
      logger.log('找到 ${files.length} 个文件');
      return files;
    } catch (e) {
      logger.log('获取选中文件异常：$e');
      return [];
    }
  }
}

/// 简单的临时日志记录器
class _Logger {
  final List<String> _messages = [];
  final LoggerService? _realLogger;

  _Logger() : _realLogger = _initLogger();

  static LoggerService? _initLogger() {
    try {
      return LoggerService();
    } catch (_) {
      return null;
    }
  }

  void log(String message) {
    try {
      _realLogger?.log(message, prefix: 'Clipboard');
    } catch (_) {
      // 忽略
    }
    _messages.add(message);
  }
}
