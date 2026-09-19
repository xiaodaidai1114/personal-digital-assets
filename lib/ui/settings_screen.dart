import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final VaultController controller;

  Future<void> _confirmLock(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('立即锁定'),
        content: const Text('锁定后会丢弃内存中的密钥，需要主密码重新解锁。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('锁定'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.lock();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('安全'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: () => _confirmLock(context),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('立即锁定'),
                ),
              ),
            ),
            Card(
              child: Column(
                children: const [
                  ListTile(
                    enabled: false,
                    leading: Icon(Icons.timer_outlined),
                    title: Text('自动锁定时长'),
                    subtitle: Text('规划中'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  Divider(height: 1),
                  ListTile(
                    enabled: false,
                    leading: Icon(Icons.fingerprint),
                    title: Text('生物识别解锁'),
                    subtitle: Text('规划中'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const _SectionTitle('数据'),
            const Card(
              child: ListTile(
                enabled: false,
                leading: Icon(Icons.backup_outlined),
                title: Text('加密备份导出'),
                subtitle: Text('规划中 · 只导出密文'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const _SectionTitle('关于'),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('当前版本'),
                subtitle: Text('v1.0.0 · MVP 设计迭代'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.route_outlined),
                title: Text('路线图阶段'),
                subtitle: Text('设计系统落地 → 加密持久化 → G6 图谱 → 关系编辑'),
              ),
            ),
          ],
        ),
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
