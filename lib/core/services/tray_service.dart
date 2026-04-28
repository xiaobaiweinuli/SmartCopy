import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

typedef TrayActionCallback = void Function(String key);

class TrayService with TrayListener {
  TrayActionCallback? _onAction;
  bool _initialized = false;

  Future<void> init({required TrayActionCallback onAction}) async {
    _onAction = onAction;
    trayManager.addListener(this);

    await trayManager.setIcon('assets/icons/tray_icon.ico');
    await trayManager.setToolTip('SmartCopy - 智能过滤复制');
    await _rebuildMenu(hasSource: false);
    _initialized = true;
  }

  Future<void> setHasSource(bool hasSource, {String? sourceLabel}) async {
    if (!_initialized) return;
    await _rebuildMenu(hasSource: hasSource, sourceLabel: sourceLabel);
    if (hasSource) {
      await trayManager.setToolTip('SmartCopy - 已标记源：${sourceLabel ?? ""}');
    } else {
      await trayManager.setToolTip('SmartCopy - 智能过滤复制');
    }
  }

  Future<void> _rebuildMenu({
    required bool hasSource,
    String? sourceLabel,
  }) async {
    final items = <MenuItem>[];

    items.add(MenuItem(
      key: 'show',
      label: '显示主界面',
    ));

    items.add(MenuItem.separator());

    if (hasSource) {
      items.add(MenuItem(
        key: 'source_label',
        label: '源: ${_truncate(sourceLabel ?? '', 30)}',
        disabled: true,
      ));
      items.add(MenuItem(
        key: 'clear_source',
        label: '清除复制源',
      ));
      items.add(MenuItem.separator());
    }

    items.add(MenuItem(
      key: 'open_data_dir',
      label: '打开数据目录',
    ));

    items.add(MenuItem.separator());

    items.add(MenuItem(
      key: 'exit',
      label: '退出 SmartCopy',
    ));

    await trayManager.setContextMenu(Menu(items: items));
  }

  void dispose() {
    trayManager.removeListener(this);
  }

  // ─── TrayListener 回调 ────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    // 单击图标显示窗口
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key != null) {
      _onAction?.call(menuItem.key!);
    }
  }

  // ─── 工具 ─────────────────────────────────────────────────────

  String _truncate(String s, int max) =>
      s.length > max ? '...${s.substring(s.length - max)}' : s;
}
