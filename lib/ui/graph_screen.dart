import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/memory_asset_repository.dart';
import '../domain/asset.dart';
import '../domain/relation.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'asset_detail_screen.dart';
import 'asset_edit_screen.dart';
import 'widgets/asset_type_badge.dart';
import 'widgets/empty_state.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({
    super.key,
    required this.controller,
    required this.repository,
    required this.onManageAssets,
  });

  final VaultController controller;
  final MemoryAssetRepository repository;
  final VoidCallback onManageAssets;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  List<Asset> _assets = [];
  List<Relation> _relations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final assets = await widget.repository.listAssets();
      final relations = await widget.repository.listRelations();
      if (!mounted) {
        return;
      }
      setState(() {
        _assets = assets;
        _relations = relations;
        _loading = false;
        _error = null;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '图谱读取失败';
      });
    }
  }

  void _openNode(Asset asset) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.nightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AssetTypeBadge(type: asset.type, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          asset.type.label,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.nightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => AssetDetailScreen(
                          controller: widget.controller,
                          repository: widget.repository,
                          assetId: asset.id,
                        ),
                      ),
                    );
                  },
                  child: const Text('查看'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: AppTheme.night(),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppGradients.nebula),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '资产图谱',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Expanded(
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: _error!,
        actionLabel: '重试',
        onAction: _reload,
        dark: true,
      );
    }
    if (_assets.isEmpty) {
      return EmptyState(
        icon: Icons.hub_outlined,
        title: '先添加资产，星图会在这里点亮',
        actionLabel: '新增资产',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AssetEditScreen(
              controller: widget.controller,
              repository: widget.repository,
            ),
          ),
        ),
        dark: true,
      );
    }
    if (_relations.isEmpty) {
      return EmptyState(
        icon: Icons.link_outlined,
        title: '资产之间还没有关联',
        actionLabel: '去资产页添加关联',
        onAction: widget.onManageAssets,
        dark: true,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final center = Offset(size.width / 2, size.height / 2);
        final radius = math.min(size.width, size.height) / 2 - 76;
        final positions = <String, Offset>{};
        for (var index = 0; index < _assets.length; index++) {
          final angle =
              (math.pi * 2 * index / _assets.length) - math.pi / 2;
          positions[_assets[index].id] = Offset(
            center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle),
          );
        }
        return InteractiveViewer(
          maxScale: 2.4,
          minScale: .65,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: size,
                  painter: _NebulaGraphPainter(
                    relations: _relations,
                    positions: positions,
                  ),
                ),
                for (final asset in _assets)
                  _GraphNode(
                    asset: asset,
                    position: positions[asset.id] ?? center,
                    onTap: () => _openNode(asset),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({
    required this.asset,
    required this.position,
    required this.onTap,
  });

  final Asset asset;
  final Offset position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
        left: position.dx - 34,
        top: position.dy - 37,
        width: 68,
        height: 78,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AssetTypeBadge(type: asset.type, size: 28),
              const SizedBox(height: 5),
              Text(
                asset.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.graphNode,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
}

class _NebulaGraphPainter extends CustomPainter {
  const _NebulaGraphPainter({
    required this.relations,
    required this.positions,
  });

  final List<Relation> relations;
  final Map<String, Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white.withValues(alpha: .08);
    final random = math.Random(7);
    for (var index = 0; index < 48; index++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        random.nextDouble() * 1.4 + .4,
        starPaint,
      );
    }

    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: .28)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final relation in relations) {
      final from = positions[relation.fromAssetId];
      final to = positions[relation.toAssetId];
      if (from == null || to == null) {
        continue;
      }
      canvas.drawLine(from, to, edgePaint);
      final direction = (to - from) / (to - from).distance;
      final arrowBase = to - direction * 30;
      final normal = Offset(-direction.dy, direction.dx) * 5;
      final arrowPaint = Paint()
        ..color = Colors.white.withValues(alpha: .52)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(arrowBase, to - direction * 20, arrowPaint);
      canvas.drawLine(arrowBase + normal, to - direction * 20, arrowPaint);
      canvas.drawLine(arrowBase - normal, to - direction * 20, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaGraphPainter oldDelegate) =>
      oldDelegate.relations != relations || oldDelegate.positions != positions;
}
