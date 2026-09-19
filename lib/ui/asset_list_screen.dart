import 'package:flutter/material.dart';

import '../data/memory_asset_repository.dart';
import '../domain/asset.dart';
import '../vault/vault_controller.dart';
import 'asset_detail_screen.dart';
import 'asset_edit_screen.dart';

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({
    super.key,
    required this.controller,
    required this.repository,
  });

  final VaultController controller;
  final MemoryAssetRepository repository;

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> {
  List<Asset> _assets = [];
  AssetType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final assets = await widget.repository.listAssets();
    if (!mounted) {
      return;
    }
    setState(() => _assets = assets);
  }

  Future<void> _openEditor([Asset? asset]) async {
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
  }

  Future<void> _openDetail(String assetId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          controller: widget.controller,
          repository: widget.repository,
          assetId: assetId,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _typeFilter == null
        ? _assets
        : _assets.where((asset) => asset.type == _typeFilter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('我的资产')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _TypeFilterChip(
                  label: '全部',
                  selected: _typeFilter == null,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                for (final type in AssetType.values)
                  _TypeFilterChip(
                    label: type.label,
                    selected: _typeFilter == type,
                    onTap: () => setState(() => _typeFilter = type),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('暂无资产，点击右下角新增'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final asset = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(asset.type.label.characters.first),
                        ),
                        title: Text(asset.title),
                        subtitle: Text(asset.type.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDetail(asset.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
