import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/memory_asset_repository.dart';
import '../domain/asset.dart';
import '../domain/relation.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'asset_edit_screen.dart';
import 'widgets/asset_type_badge.dart';
import 'widgets/empty_state.dart';

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    super.key,
    required this.controller,
    required this.repository,
    required this.assetId,
  });

  final VaultController controller;
  final MemoryAssetRepository repository;
  final String assetId;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  Asset? _asset;
  List<Relation> _relations = [];
  Map<String, Asset> _relatedAssets = {};
  String? _revealedSecret;
  String? _secretError;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final asset = await widget.repository.getAsset(widget.assetId);
    final relations = asset == null
        ? const <Relation>[]
        : await widget.repository.relationsOf(asset.id);
    final relatedAssets = <String, Asset>{};
    for (final relation in relations) {
      final otherId = relation.fromAssetId == asset?.id
          ? relation.toAssetId
          : relation.fromAssetId;
      final other = await widget.repository.getAsset(otherId);
      if (other != null) {
        relatedAssets[relation.id] = other;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _asset = asset;
      _relations = relations;
      _relatedAssets = relatedAssets;
      _revealedSecret = null;
      _secretError = null;
      _loaded = true;
    });
  }

  Future<void> _revealSecret() async {
    final encrypted = _asset?.encryptedSecret;
    if (encrypted == null) {
      return;
    }
    setState(() {
      _busy = true;
      _secretError = null;
    });
    try {
      final plain = await widget.controller.decryptSecret(encrypted);
      if (mounted) {
        setState(() => _revealedSecret = plain);
      }
    } on Exception {
      if (mounted) {
        setState(() => _secretError = '无法解密：保险库状态异常');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copySecret() async {
    final secret = _revealedSecret;
    if (secret == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: secret));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制，请注意剪贴板安全')));
    }
  }

  Future<void> _delete() async {
    final asset = _asset;
    if (asset == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除资产'),
        content: Text('确定删除「${asset.title}」吗？相关关联也会一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteAsset(asset.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资产详情')),
        body: EmptyState(
          icon: Icons.search_off,
          title: '资产不存在或已删除',
          actionLabel: '返回',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(asset.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssetEditScreen(
                    controller: widget.controller,
                    repository: widget.repository,
                    asset: asset,
                  ),
                ),
              );
              await _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AssetTypeBadge(type: asset.type, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          asset.type.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.nightTextSecondary
                                    : AppColors.dayTextSecondary,
                              ),
                        ),
                        if (asset.tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in asset.tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: .10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(tag),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (asset.fields.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final entry in asset.fields.entries) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.nightTextSecondary
                                          : AppColors.dayTextSecondary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SelectableText(
                                '${entry.value}',
                                textAlign: TextAlign.right,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (entry.key != asset.fields.entries.last.key)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
          if (asset.encryptedSecret != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.nightSurface.withValues(alpha: .72)
                    : Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.password_outlined),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('敏感内容（已加密）')),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _revealedSecret == null
                                ? _revealSecret()
                                : setState(() {
                                    _revealedSecret = null;
                                    _secretError = null;
                                  }),
                        child: Text(_revealedSecret == null ? '显示' : '隐藏'),
                      ),
                      if (_revealedSecret != null)
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: '复制',
                          onPressed: _copySecret,
                        ),
                    ],
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else if (_secretError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _secretError!,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.controller.lock,
                            child: const Text('重新解锁'),
                          ),
                        ],
                      ),
                    )
                  else if (_revealedSecret != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SelectableText(
                        _revealedSecret!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          height: 1.45,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('显示后在本地解密，内容不会写入文件。'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('关联', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_relations.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.link_outlined, size: 32),
                    const SizedBox(height: 8),
                    const Text('资产之间还没有关联'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: null,
                      child: const Text('添加关联（下一迭代）'),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final relation in _relations) ...[
                    ListTile(
                      leading: AssetTypeBadge(
                        type: _relatedAssets[relation.id]?.type ??
                            AssetType.other,
                        size: 34,
                      ),
                      title: Text(
                        '${relation.type.label}：${_relatedAssets[relation.id]?.title ?? '未知资产'}',
                      ),
                      subtitle: Text(
                        relation.fromAssetId == asset.id
                            ? '当前资产 → 关联资产'
                            : '关联资产 → 当前资产',
                      ),
                    ),
                    if (relation != _relations.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
