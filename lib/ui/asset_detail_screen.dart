import 'package:flutter/material.dart';

import '../data/memory_asset_repository.dart';
import '../domain/asset.dart';
import '../domain/relation.dart';
import '../vault/vault_controller.dart';
import 'asset_edit_screen.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final asset = await widget.repository.getAsset(widget.assetId);
    final relations = await widget.repository.relationsOf(widget.assetId);
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
    });
  }

  Future<void> _revealSecret() async {
    final encrypted = _asset?.encryptedSecret;
    if (encrypted == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final plain = await widget.controller.decryptSecret(encrypted);
      if (mounted) {
        setState(() => _revealedSecret = plain);
      }
    } on Exception {
      if (mounted) {
        setState(() => _revealedSecret = '（无法解密：保险库状态异常）');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
    if (asset == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
          Text(asset.type.label, style: Theme.of(context).textTheme.labelLarge),
          if (asset.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [for (final tag in asset.tags) Chip(label: Text(tag))],
            ),
          ],
          const SizedBox(height: 8),
          for (final entry in asset.fields.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              subtitle: Text('${entry.value}'),
            ),
          if (asset.encryptedSecret != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('敏感内容（已加密）')),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _revealedSecret == null
                                  ? _revealSecret()
                                  : setState(() => _revealedSecret = null),
                          child: Text(
                            _revealedSecret == null ? '显示' : '隐藏',
                          ),
                        ),
                      ],
                    ),
                    if (_revealedSecret != null)
                      SelectableText(
                        _revealedSecret!,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('关联', style: Theme.of(context).textTheme.titleMedium),
          if (_relations.isEmpty)
            const ListTile(
              dense: true,
              title: Text('暂无关联'),
            )
          else
            for (final relation in _relations)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(
                  '${relation.type.label}: ${_relatedAssets[relation.id]?.title ?? '未知资产'}',
                ),
                subtitle: Text(
                  relation.fromAssetId == asset.id ? '当前资产 → 关联资产' : '关联资产 → 当前资产',
                ),
              ),
        ],
      ),
    );
  }
}
