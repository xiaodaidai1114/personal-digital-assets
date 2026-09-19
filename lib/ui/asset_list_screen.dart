import 'package:flutter/material.dart';

import '../data/memory_asset_repository.dart';
import '../domain/asset.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'asset_detail_screen.dart';
import 'asset_edit_screen.dart';
import 'widgets/asset_type_badge.dart';
import 'widgets/empty_state.dart';

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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (_error != null) {
      setState(() => _loading = true);
    }
    try {
      final assets = await widget.repository.listAssets();
      if (!mounted) {
        return;
      }
      setState(() {
        _assets = assets;
        _loading = false;
        _error = null;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '读取资产失败';
      });
    }
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

  int get _currentMonthBills => _assets
      .where(
        (asset) =>
            asset.type == AssetType.bill &&
            DateTime.tryParse(asset.fields['date'] ?? '')?.month ==
                DateTime.now().month,
      )
      .length;

  int get _upcomingSubscriptions => _assets
      .where((asset) {
        if (asset.type != AssetType.subscription) {
          return false;
        }
        final dueDate = DateTime.tryParse(
          asset.fields['nextRenewalDate'] ?? asset.fields['dueDate'] ?? '',
        );
        return dueDate != null &&
            dueDate.isAfter(DateTime.now()) &&
            dueDate.isBefore(DateTime.now().add(const Duration(days: 30)));
      })
      .length;

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
          if (_loading)
            const Expanded(child: _LoadingAssets())
          else if (_error != null)
            Expanded(
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: '读取资产失败',
                actionLabel: '重试',
                onAction: _reload,
              ),
            )
          else ...[
            SizedBox(
              height: 128,
              child: PageView(
                children: [
                  _HeroStatCard(
                    label: '资产总数',
                    value: '${_assets.length}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _HeroStatCard(
                    label: '本月账单',
                    value: '$_currentMonthBills',
                    icon: Icons.receipt_long_outlined,
                  ),
                  _HeroStatCard(
                    label: '30 天临期提醒',
                    value: '$_upcomingSubscriptions',
                    icon: Icons.notifications_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      type: type,
                      selected: _typeFilter == type,
                      onTap: () => setState(() => _typeFilter = type),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _typeFilter == null
                      ? EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: '还没有资产',
                          actionLabel: '新增第一条资产',
                          onAction: () => _openEditor(),
                        )
                      : EmptyState(
                          icon: assetTypeIcon(_typeFilter!),
                          title: '该类型暂无资产',
                          actionLabel: '清除筛选',
                          onAction: () =>
                              setState(() => _typeFilter = null),
                        )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final asset = filtered[index];
                        return _AssetCard(
                          asset: asset,
                          onTap: () => _openDetail(asset.id),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.hero,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A4FD8).withValues(alpha: .16),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white.withAlpha(220), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onTap,
  });

  final Asset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = asset.fields['amount'];
    final typeColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.typeLight(asset.type)
        : AppColors.typeDeep(asset.type);
    final meta = [
      asset.type.label,
      if (asset.tags.isNotEmpty) asset.tags.join(' · '),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                AssetTypeBadge(type: asset.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.nightTextSecondary
                                  : AppColors.dayTextSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (amount != null)
                  SizedBox(
                    width: 88,
                    child: Text(
                      amount,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.type,
  });

  final String label;
  final AssetType? type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = type == null
        ? AppColors.primary
        : Theme.of(context).brightness == Brightness.dark
            ? AppColors.typeLight(type!)
            : AppColors.typeDeep(type!);
    final borderColor = selected ? color : Theme.of(context).dividerColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? color.withValues(alpha: .12)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingAssets extends StatelessWidget {
  const _LoadingAssets();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(5, (_) => _SkeletonCard()),
      );
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDEFF6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 14,
                      color: const Color(0xFFEDEFF6),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      margin: const EdgeInsets.only(right: 60),
                      color: const Color(0xFFEDEFF6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
