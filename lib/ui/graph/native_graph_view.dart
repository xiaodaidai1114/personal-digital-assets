import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/asset.dart';
import '../../domain/relation.dart';
import '../../theme/app_theme.dart';
import '../widgets/asset_type_badge.dart';

/// 原生夜纸图谱：力导向物理布局 + 可拖拽节点 + 细线邻域。
/// Web/桌面预览使用；Android 端由 WebView G6 实现（见 webview_graph_view.dart）。
class NativeGraphView extends StatefulWidget {
  const NativeGraphView({
    super.key,
    required this.assets,
    required this.relations,
    this.focusIds = const {},
    required this.onOpenNode,
  });

  final List<Asset> assets;
  final List<Relation> relations;
  final Set<String> focusIds;
  final ValueChanged<Asset> onOpenNode;

  @override
  State<NativeGraphView> createState() => _NativeGraphViewState();
}

class _NativeGraphViewState extends State<NativeGraphView>
    with SingleTickerProviderStateMixin {
  static const double _minIdealEdgeLength = 140;
  static const double _maxIdealEdgeLength = 540;
  static const double _repulsion = 26000;
  static const double _spring = .006;
  static const double _gravity = .004;
  double _idealEdgeLength = _minIdealEdgeLength;
  static const double _damping = .9;

  final Map<String, Offset> _positions = {};
  final Map<String, Offset> _velocities = {};
  late final AnimationController _tick;
  double _alpha = 1;
  String? _selectedId;
  Offset _center = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();
    _tick.addListener(_step);
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  void _step() {
    if (_positions.isEmpty) {
      return;
    }
    if (_alpha > .035) {
      _alpha *= .995;
    }
    final ids = _positions.keys.toList();
    final forces = <String, Offset>{for (final id in ids) id: Offset.zero};
    // 库仑斥力（两两）。
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final delta = _positions[ids[i]]! - _positions[ids[j]]!;
        var distance = delta.distance;
        if (distance < 1) {
          distance = 1;
        }
        final force = delta / distance * (_repulsion / (distance * distance));
        forces[ids[i]] = forces[ids[i]]! + force;
        forces[ids[j]] = forces[ids[j]]! - force;
      }
    }
    // 弹簧引力（沿边）。
    for (final relation in widget.relations) {
      final from = _positions[relation.fromAssetId];
      final to = _positions[relation.toAssetId];
      if (from == null || to == null) {
        continue;
      }
      final delta = to - from;
      final distance = delta.distance == 0 ? 1.0 : delta.distance;
      final stretch = distance - _idealEdgeLength;
      final force = delta / distance * (stretch * _spring);
      forces[relation.fromAssetId] =
          (forces[relation.fromAssetId] ?? Offset.zero) + force;
      forces[relation.toAssetId] =
          (forces[relation.toAssetId] ?? Offset.zero) - force;
    }
    for (final id in ids) {
      final toCenter = _center - _positions[id]!;
      forces[id] = forces[id]! + toCenter * _gravity;
      _velocities[id] =
          ((_velocities[id] ?? Offset.zero) + forces[id]!) * _damping * _alpha;
      _positions[id] = _positions[id]! + _velocities[id]!;
    }
    if (mounted) {
      setState(() {});
    }
    if (_alpha < .03 && _tick.isAnimating) {
      _tick.stop();
    }
  }

  void _reheat() {
    _alpha = .5;
    _tick.forward(from: 0);
  }

  void _layoutInitial(Size size) {
    _center = Offset(size.width / 2, size.height / 2);
    final radiusX = math.max(size.width / 2 - 100, 140.0);
    final radiusY = math.max(size.height / 2 - 85, 100.0);
    _idealEdgeLength = (size.width * .42).clamp(
      _minIdealEdgeLength,
      _maxIdealEdgeLength,
    );
    final count = math.max(widget.assets.length, 1);
    for (var i = 0; i < widget.assets.length; i++) {
      final asset = widget.assets[i];
      if (_positions.containsKey(asset.id)) {
        continue;
      }
      final angle = math.pi * 2 * i / count - math.pi / 2;
      _positions[asset.id] =
          _center +
          Offset(radiusX * math.cos(angle), radiusY * math.sin(angle));
      _velocities[asset.id] = Offset.zero;
    }
    _positions.removeWhere((id, _) => widget.assets.every((a) => a.id != id));
  }

  void _onNodeTap(Asset asset) {
    setState(() => _selectedId = asset.id);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted && _selectedId == asset.id) {
        setState(() => _selectedId = null);
      }
    });
    widget.onOpenNode(asset);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_positions.isEmpty && widget.assets.isNotEmpty) {
          setState(() => _layoutInitial(size));
          _reheat();
        }
      });
      return InteractiveViewer(
        maxScale: 2.4,
        minScale: .6,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: AnimatedBuilder(
            animation: _tick,
            builder: (context, child) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NebulaPainter(
                      relations: widget.relations,
                      positions: _positions,
                      selectedId: _selectedId,
                      focusIds: widget.focusIds,
                    ),
                  ),
                ),
                for (var index = 0; index < widget.assets.length; index++)
                  _buildNode(widget.assets[index], index),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildNode(Asset asset, int index) {
    final position = _positions[asset.id];
    if (position == null) {
      return const SizedBox.shrink();
    }
    final selected = _selectedId == asset.id;
    final dimmed =
        widget.focusIds.isNotEmpty && !widget.focusIds.contains(asset.id);
    return Positioned(
      left: position.dx - 34,
      top: position.dy - 42,
      width: 68,
      height: 86,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('entrance-${asset.id}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 320 + index * 55),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 5),
            child: child,
          ),
        ),
        child: Semantics(
          label: '${asset.type.label} ${asset.title}',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onNodeTap(asset),
            onPanStart: (_) => _reheat(),
            onPanUpdate: (details) {
              setState(() {
                _positions[asset.id] = _positions[asset.id]! + details.delta;
                _velocities[asset.id] = details.delta;
              });
            },
            onPanEnd: (_) => _reheat(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NodeBadge(asset: asset, selected: selected),
                const SizedBox(height: 5),
                Text(
                  asset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                        color: AppColors.graphNode,
                        fontSize: 11,
                        height: 1.2,
                      ).copyWith(
                        color: AppColors.graphNode.withValues(
                          alpha: dimmed ? .18 : 1,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 节点徽章：夜墨空心，按类型使用圆 / 方 / 菱。
class _NodeBadge extends StatelessWidget {
  const _NodeBadge({required this.asset, required this.selected});

  final Asset asset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final shape = _nodeShape(asset.type);
    final node = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: shape == _NodeShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: shape == _NodeShape.rect
            ? BorderRadius.circular(4)
            : null,
        border: Border.all(
          color: AppColors.graphNode,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: Icon(
        assetTypeIcon(asset.type),
        color: AppColors.graphNode,
        size: 15,
      ),
    );
    return shape == _NodeShape.diamond
        ? Transform.rotate(angle: math.pi / 4, child: node)
        : node;
  }
}

enum _NodeShape { circle, rect, diamond }

_NodeShape _nodeShape(AssetType type) => switch (type) {
  AssetType.email ||
  AssetType.subscription ||
  AssetType.password => _NodeShape.circle,
  AssetType.apiKey ||
  AssetType.device ||
  AssetType.item ||
  AssetType.other => _NodeShape.rect,
  _ => _NodeShape.diamond,
};

/// 夜纸关系绘制：非邻域降透明，选中邻域保持 1px 细线。
class _NebulaPainter extends CustomPainter {
  _NebulaPainter({
    required this.relations,
    required this.positions,
    required this.selectedId,
    required this.focusIds,
  });

  final List<Relation> relations;
  final Map<String, Offset> positions;
  final String? selectedId;
  final Set<String> focusIds;

  @override
  void paint(Canvas canvas, Size size) {
    _paintEdges(canvas);
  }

  void _paintEdges(Canvas canvas) {
    final selected = selectedId;
    for (final relation in relations) {
      final from = positions[relation.fromAssetId];
      final to = positions[relation.toAssetId];
      if (from == null || to == null) {
        continue;
      }
      final isSelected =
          selected != null &&
          (relation.fromAssetId == selected || relation.toAssetId == selected);
      final inFocus =
          focusIds.isEmpty ||
          focusIds.contains(relation.fromAssetId) ||
          focusIds.contains(relation.toAssetId);
      final isActive = isSelected || inFocus;
      final color = AppColors.graphNode.withValues(alpha: isActive ? .9 : .18);
      final paint = Paint()
        ..color = color
        ..strokeWidth = isActive ? 1.5 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from, to, paint);

      // 箭头。
      final direction = (to - from) / (to - from).distance;
      final arrowBase = to - direction * 30;
      final normal = Offset(-direction.dy, direction.dx) * 5;
      final arrowPaint = Paint()
        ..color = color
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(arrowBase, to - direction * 20, arrowPaint);
      canvas.drawLine(arrowBase + normal, to - direction * 20, arrowPaint);
      canvas.drawLine(arrowBase - normal, to - direction * 20, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) => true;
}
