import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../app_version.dart';
import '../vault/vault_controller.dart';
import '../data/backup/backup_service.dart';
import '../data/settings_store.dart';
import '../domain/asset_attachment.dart';
import '../domain/asset_note.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart';

/// 设置：安全（锁定/自动锁定/生物识别）、数据（加密备份导出与恢复）、关于。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.services,
    required this.onThemeModeChanged,
  });

  final AppServices services;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  // 一键锁定（DESIGN.md）：瞬间锁死，禁止任何二次确认弹窗。
  void _lockNow() => widget.services.controller.lock();

  Future<void> _pickAutoLock() async {
    final store = widget.services.settingsStore;
    final current = await store.autoLockDelay();
    if (!mounted) {
      return;
    }
    _AutoLockOption? currentOption;
    for (final option in _AutoLockOption.values) {
      if (option.delay == current) {
        currentOption = option;
        break;
      }
    }
    final selected = await showModalBottomSheet<_AutoLockOption>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: RadioGroup<_AutoLockOption>(
          groupValue: currentOption,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in _AutoLockOption.values)
                RadioListTile<_AutoLockOption>(
                  title: Text(option.label),
                  value: option,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await store.setAutoLockDelay(selected.delay);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _exportBackup() async {
    final cipher = widget.services.controller.cipher;
    if (cipher == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final assets = await widget.services.repository.listAssets();
      final relations = await widget.services.repository.listRelations();
      final notes = <AssetNote>[];
      final attachments = <AssetAttachment>[];
      final attachmentBytes = <String, List<int>>{};
      for (final asset in assets) {
        notes.addAll(await widget.services.repository.listNotes(asset.id));
        for (final attachment
            in await widget.services.repository.listAttachments(asset.id)) {
          attachments.add(attachment);
          final bytes = await widget.services.repository.attachmentBytes(
            attachment.id,
          );
          if (bytes != null) {
            attachmentBytes[attachment.id] = bytes;
          }
        }
      }
      final content = await BackupService(cipher).exportEncrypted(
        assets,
        relations,
        notes: notes,
        attachments: attachments,
        attachmentBytes: attachmentBytes,
      );
      final filename =
          'airy-vault-backup-${DateFormat('yyyyMMdd').format(DateTime.now())}.avbak';
      await widget.services.backupFileStore.exportFile(content, filename);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加密备份已导出：$filename（仅含密文）')));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('备份导出失败')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    final cipher = widget.services.controller.cipher;
    if (cipher == null) {
      return;
    }
    final content = await widget.services.backupFileStore.pickAndRead();
    if (content == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从备份恢复'),
        content: const Text('将把备份中的资产、关联、备注与图片合并进当前数据（同 ID 覆盖）。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final backup = await BackupService(cipher).importEncrypted(content);
      for (final asset in backup.assets) {
        await widget.services.repository.saveAsset(asset);
      }
      for (final relation in backup.relations) {
        await widget.services.repository.saveRelation(relation);
      }
      for (final note in backup.notes) {
        await widget.services.repository.addNote(note);
      }
      for (final attachment in backup.attachments) {
        await widget.services.repository.addAttachment(
          attachment,
          backup.attachmentBytes[attachment.id] ?? const [],
        );
      }
      await widget.services.syncReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已恢复 ${backup.assets.length} 条资产、'
              '${backup.relations.length} 条关联、'
              '${backup.notes.length} 条备注、'
              '${backup.attachments.length} 张图片',
            ),
          ),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('恢复失败：备份文件无效或主密码不匹配')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('外观'),
          _SkinCard(
            child: _AppearanceTile(
              services: widget.services,
              onThemeModeChanged: widget.onThemeModeChanged,
            ),
          ),
          const _SectionTitle('安全'),
          _SkinCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GFButton(
                onPressed: _lockNow,
                text: '立即锁定',
                type: GFButtonType.outline,
                color: skin.danger,
                textColor: skin.danger,
                icon: Icon(Icons.lock_outline, color: skin.danger),
                blockButton: true,
              ),
            ),
          ),
          _SkinCard(
            child: Column(
              children: [
                FutureBuilder<Duration?>(
                  future: widget.services.settingsStore.autoLockDelay(),
                  builder: (context, snapshot) {
                    final delay = snapshot.data;
                    return ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('自动锁定时长'),
                      subtitle: Text(_describeDelay(delay)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickAutoLock,
                    );
                  },
                ),
                const Divider(height: 1),
                _BiometricTile(controller: widget.services.controller),
              ],
            ),
          ),
          const _SectionTitle('提醒'),
          _SkinCard(
            child: Builder(
              builder: (context) => ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('到期与扣款清单'),
                subtitle: const Text('临期订阅与账单日历（原哨所，入口藏于此）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(
                      controller: widget.services.controller,
                      repository: widget.services.repository,
                      onDataChanged: widget.services.syncReminders,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const _SectionTitle('数据'),
          _SkinCard(
            child: Column(
              children: [
                ListTile(
                  enabled: !_busy,
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('导出加密备份'),
                  subtitle: const Text('仅导出密文，不含任何明文'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: !_busy,
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('从备份恢复'),
                  subtitle: const Text('选择 .avbak 备份文件合并恢复'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _restoreBackup,
                ),
              ],
            ),
          ),
          const _SectionTitle('关于'),
          _SkinCard(
            child: GFListTile(
              color: Colors.transparent,
              listItemTextColor: skin.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              avatar: const Icon(Icons.info_outline),
              title: const Text('当前版本'),
              subTitleText: 'v${AppVersion.current} · 青穹资产云',
            ),
          ),
          _SkinCard(
            child: GFListTile(
              color: Colors.transparent,
              listItemTextColor: skin.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              avatar: const Icon(Icons.route_outlined),
              title: const Text('路线图阶段'),
              subTitleText: 'SQLCipher 持久化 ✓ · 命令面板 ✓ · 倾倒入库 ✓ · 加密备份 ✓',
            ),
          ),
        ],
      ),
    );
  }

  String _describeDelay(Duration? delay) {
    if (delay == null) {
      return '永不自动锁定';
    }
    if (delay == Duration.zero) {
      return '立即锁定';
    }
    if (delay.inMinutes >= 1) {
      return '${delay.inMinutes} 分钟无操作后锁定';
    }
    return '${delay.inSeconds} 秒无操作后锁定';
  }
}

class _AppearanceTile extends StatefulWidget {
  const _AppearanceTile({
    required this.services,
    required this.onThemeModeChanged,
  });

  final AppServices services;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  @override
  State<_AppearanceTile> createState() => _AppearanceTileState();
}

class _AppearanceTileState extends State<_AppearanceTile> {
  late Future<AppThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.services.settingsStore.themeMode();
  }

  Future<void> _select(Set<AppThemeMode> selection) async {
    final mode = selection.first;
    await widget.services.settingsStore.setThemeMode(mode);
    widget.onThemeModeChanged(mode);
    if (mounted) {
      setState(() {
        _themeMode = Future.value(mode);
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppThemeMode>(
    future: _themeMode,
    builder: (context, snapshot) {
      final mode = snapshot.data ?? AppThemeMode.light;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.contrast),
              title: const Text('界面模式'),
              subtitle: const Text('原生亮暗双主题，跟随系统时自动切换'),
            ),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.light, label: Text('亮色')),
                ButtonSegment(value: AppThemeMode.dark, label: Text('暗色')),
                ButtonSegment(value: AppThemeMode.system, label: Text('跟随系统')),
              ],
              selected: {mode},
              onSelectionChanged: _select,
            ),
          ],
        ),
      );
    },
  );
}

enum _AutoLockOption {
  never('永不自动锁定', null),
  immediate('立即锁定', Duration.zero),
  oneMinute('1 分钟后', Duration(minutes: 1)),
  fiveMinutes('5 分钟后', Duration(minutes: 5)),
  fifteenMinutes('15 分钟后', Duration(minutes: 15));

  const _AutoLockOption(this.label, this.delay);

  final String label;
  final Duration? delay;
}

/// 生物识别开关：读取可用性与开启状态，切换时托管/清除密钥。
class _BiometricTile extends StatefulWidget {
  const _BiometricTile({required this.controller});

  final VaultController controller;

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  @override
  Widget build(BuildContext context) => FutureBuilder<(bool, bool)>(
    future: () async {
      final available = await widget.controller.canUseBiometric();
      final enabled = available && await widget.controller.isBiometricEnabled();
      return (available, enabled);
    }(),
    builder: (context, snapshot) {
      final available = snapshot.data?.$1 ?? false;
      final enabled = snapshot.data?.$2 ?? false;
      return ListTile(
        leading: const Icon(Icons.fingerprint),
        title: const Text('生物识别解锁'),
        subtitle: Text(
          !available
              ? '当前设备或系统不支持'
              : enabled
              ? '已开启'
              : '开启后可用指纹/面容快速解锁',
        ),
        trailing: available
            ? GFToggle(
                value: enabled,
                type: GFToggleType.ios,
                enabledThumbColor: context.skin.surface,
                enabledTrackColor: context.skin.primary,
                disabledThumbColor: context.skin.surface,
                disabledTrackColor: context.skin.outline,
                onChanged: (value) async {
                  await widget.controller.setBiometricEnabled(value ?? false);
                  if (mounted) {
                    setState(() {});
                  }
                },
              )
            : null,
        onTap: available
            ? () async {
                await widget.controller.setBiometricEnabled(!enabled);
                if (mounted) {
                  setState(() {});
                }
              }
            : null,
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// GFCard 皮肤适配：GF 不读 ThemeData，显式传 surface/outline/零边距。
class _SkinCard extends StatelessWidget {
  const _SkinCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GFCard(
    color: context.skin.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: context.skin.outline),
    ),
    margin: EdgeInsets.zero,
    padding: EdgeInsets.zero,
    content: child,
  );
}
