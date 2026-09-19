import 'package:flutter/material.dart';

import '../vault/vault_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final VaultController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('立即锁定'),
              subtitle: const Text('丢弃内存中的密钥，返回解锁页'),
              onTap: controller.lock,
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('当前版本'),
              subtitle: Text('MVP 迭代一：加密核心 + 资产管理'),
            ),
          ],
        ),
      );
}
