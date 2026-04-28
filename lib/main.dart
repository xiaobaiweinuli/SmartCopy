import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/ipc_service.dart';
import 'core/services/logger_service.dart';
import 'core/services/storage_service.dart';
import 'core/models/app_settings.dart';
import 'providers/app_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/profiles_screen.dart';
import 'ui/screens/global_rules_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/side_nav.dart';

final _ipcService = IpcService();
final _logger = LoggerService();

/// 移除字符串首尾的引号（如果有）
String? _unquote(String? s) {
  if (s == null) return null;
  if (s.length >= 2) {
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      return s.substring(1, s.length - 1);
    }
  }
  return s;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _logger.init();
  _logger.log('程序启动，命令行参数：${args.join(', ')}', prefix: 'Main');

  // ── 解析命令行参数（必须在单实例检测之前） ─────────────────
  String? cliAction;
  String? cliSrc;
  String? cliDest;
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--action=')) {
      cliAction = arg.substring('--action='.length);
    } else if (arg.startsWith('--src=')) {
      cliSrc = _unquote(arg.substring('--src='.length));
    } else if (arg.startsWith('--dest=')) {
      cliDest = _unquote(arg.substring('--dest='.length));
    } else if (arg == '--action' && i + 1 < args.length) {
      cliAction = args[++i];
    } else if (arg == '--src' && i + 1 < args.length) {
      cliSrc = _unquote(args[++i]);
    } else if (arg == '--dest' && i + 1 < args.length) {
      cliDest = _unquote(args[++i]);
    }
  }
  _logger.log('解析结果：action=$cliAction, src=$cliSrc, dest=$cliDest', prefix: 'Main');
  final minimized = args.contains('--minimized');

  // ── 单实例检测 ─────────────────────────────────────────────
  // 修复：右键触发时需将实际动作转发给已运行实例，而不是仅发 show
  final isFirst = await _ipcService.tryAcquireLock();
  if (!isFirst) {
    if (cliAction == 'copy' && cliSrc != null) {
      // 将 Smart Copy 操作转发给已运行实例
      await _ipcService.sendCommand({'action': 'copy', 'src': cliSrc});
    } else if (cliAction == 'paste' && cliDest != null) {
      // 将 Smart Paste 操作转发给已运行实例
      await _ipcService.sendCommand({'action': 'paste', 'dest': cliDest});
    } else {
      // 普通激活：显示主窗口
      await _ipcService.sendCommand({'action': 'show'});
    }
    exit(0);
  }

  // ── 窗口管理器初始化 ────────────────────────────────────────
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1000, 680),
    minimumSize: Size(800, 560),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'SmartCopy',
  );

  // 修复：必须 setPreventClose(true) 才能让 onWindowClose 回调生效
  // 否则系统直接关闭窗口，不触发 Dart 侧回调
  await windowManager.setPreventClose(true);

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (!minimized) {
      await windowManager.show();
      await windowManager.focus();
    }
    // 确保窗口可见性（防止窗口状态保存问题）
    await Future.delayed(const Duration(milliseconds: 100));
    if (!minimized) {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  // ── 全局热键管理器 ─────────────────────────────────────────
  await hotKeyManager.unregisterAll();

  // ── 通知服务 ───────────────────────────────────────────────
  await localNotifier.setup(appName: 'SmartCopy');

  // ── 存储服务 ───────────────────────────────────────────────
  final storage = StorageService();
  await storage.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(
        storageService: storage,
      ),
      child: SmartCopyApp(
        cliAction: cliAction,
        cliSrc: cliSrc,
        cliDest: cliDest,
        ipcService: _ipcService,
      ),
    ),
  );
}

class SmartCopyApp extends StatelessWidget {
  final String? cliAction;
  final String? cliSrc;
  final String? cliDest;
  final IpcService ipcService;

  const SmartCopyApp({
    super.key,
    this.cliAction,
    this.cliSrc,
    this.cliDest,
    required this.ipcService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final mode = provider.settings.themeMode;
        final themeMode = mode == ThemeModeSetting.light
            ? ThemeMode.light
            : mode == ThemeModeSetting.dark
                ? ThemeMode.dark
                : ThemeMode.system;
        
        return MaterialApp(
          title: 'SmartCopy',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          home: _AppShell(
            cliAction: cliAction,
            cliSrc: cliSrc,
            cliDest: cliDest,
            ipcService: ipcService,
          ),
        );
      },
    );
  }
}

class _AppShell extends StatefulWidget {
  final String? cliAction;
  final String? cliSrc;
  final String? cliDest;
  final IpcService ipcService;

  const _AppShell({
    this.cliAction,
    this.cliSrc,
    this.cliDest,
    required this.ipcService,
  });

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WindowListener {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.init();

    // 处理右键菜单触发的 CLI 操作
    if (widget.cliAction == 'copy' && widget.cliSrc != null) {
      // Smart Copy：静默标记源，不强制显示窗口
      provider.setCopySource(widget.cliSrc!);
    } else if (widget.cliAction == 'paste' && widget.cliDest != null) {
      // Smart Paste Here：有源则直接执行（不打开窗口），否则显示窗口让用户选
      if (provider.hasCopySource) {
        await provider.executePaste(widget.cliDest!);
      } else {
        await windowManager.show();
        await windowManager.focus();
        provider.navigate(AppScreen.home);
      }
    }

    // 监听来自其他实例的 IPC 命令（右键菜单第二次触发时走这里）
    widget.ipcService.startListening((cmd) async {
      _logger.log('收到 IPC 命令：$cmd', prefix: 'Main');
      if (!mounted) return;
      final action = cmd['action'] as String?;
      switch (action) {
        case 'show':
          await windowManager.show();
          await windowManager.focus();
          break;
        case 'copy':
          final src = _unquote(cmd['src'] as String?);
          if (src != null) {
            provider.setCopySource(src);
            // Smart Copy 静默标记，不弹出窗口（托盘图标会高亮提示）
          }
          break;
        case 'paste':
          final dest = _unquote(cmd['dest'] as String?);
          if (dest != null) {
            if (provider.hasCopySource) {
              // 有源则直接执行（不打开窗口）
              await provider.executePaste(dest);
            } else {
              // 无源则显示窗口
              await windowManager.show();
              await windowManager.focus();
              provider.navigate(AppScreen.home);
            }
          }
          break;
      }
    });

    if (!mounted) return;
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.ipcService.releaseLock();
    super.dispose();
  }

  // 修复：setPreventClose(true) 后此回调才会被触发
  // 根据设置决定最小化到托盘还是真正退出
  @override
  void onWindowClose() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    if (provider.settings.minimizeToTray) {
      // 最小化到托盘：仅隐藏窗口，程序继续运行
      await windowManager.hide();
    } else {
      // 真正退出
      provider.dispose();
      await widget.ipcService.releaseLock();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (!_initialized) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(
          child: _AppLoader(),
        ),
      );
    }
    return const _MainLayout();
  }
}

// ─── 加载界面 ────────────────────────────────────────────────
class _AppLoader extends StatelessWidget {
  const _AppLoader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppLoaderLogo(),
        const SizedBox(height: 16),
        Text(
          'SmartCopy',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _AppLoaderLogo extends StatelessWidget {
  const _AppLoaderLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.content_copy_rounded, color: Colors.white, size: 24),
    );
  }
}

// ─── 主布局 ───────────────────────────────────────────────────
class _MainLayout extends StatelessWidget {
  const _MainLayout();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          const _TitleBar(),
          Expanded(
            child: Row(
              children: [
                const SideNav(),
                Expanded(
                  child: Stack(
                    children: [
                      _PageContent(screen: provider.currentScreen),
                      if (provider.errorMessage != null ||
                          provider.successMessage != null)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: _GlobalMessageBar(
                            message: provider.errorMessage ??
                                provider.successMessage!,
                            isError: provider.errorMessage != null,
                            onDismiss: provider.clearMessages,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 页面内容切换器 ─────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final AppScreen screen;

  const _PageContent({required this.screen});

  @override
  Widget build(BuildContext context) {
    // 修复 AXTree 错误：用 IndexedStack 保持所有页面状态
    // 避免页面切换时 Widget 树大量重建导致 Accessibility 节点不同步
    return IndexedStack(
      index: screen.index,
      children: const [
        HomeScreen(),
        ProfilesScreen(),
        GlobalRulesScreen(),
        SettingsScreen(),
      ],
    );
  }
}

// ─── 自定义标题栏 ─────────────────────────────────────────────
class _TitleBar extends StatefulWidget {
  const _TitleBar();

  @override
  State<_TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<_TitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  Future<void> _checkMaximized() async {
    final isMax = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = isMax);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      // 拖拽标题栏移动窗口
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 38,
        color: colors.surface,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'SmartCopy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ),
            _WinBtn(icon: Icons.minimize_rounded, onTap: windowManager.minimize),
            const SizedBox(width: 2),
            _WinBtn(
              icon: _isMaximized ? Icons.crop_3_2_rounded : Icons.crop_square_rounded,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            const SizedBox(width: 2),
            // X 按钮：触发 onWindowClose（由 setPreventClose(true) 拦截）
            _WinBtn(
              icon: Icons.close_rounded,
              isClose: true,
              onTap: () => windowManager.close(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WinBtn({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bgColor = widget.isClose ? AppTheme.error : colors.border;
    final iconColor = _hovered && widget.isClose ? Colors.white : colors.textMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 34,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? bgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 14,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 全局消息条 ───────────────────────────────────────────────
class _GlobalMessageBar extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _GlobalMessageBar({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.error : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
