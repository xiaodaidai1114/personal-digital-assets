import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/asset.dart';
import '../../domain/relation.dart';
import '../../theme/app_theme.dart';
import '../widgets/asset_type_badge.dart';

/// Android 端 G6 图谱容器：WebView 内嵌离线 G6 页面，原生侧只传 JSON 数据。
/// 节点点击经 GraphTap 通道回传，其余交互（拖拽/缩放/力导布局）由 G6 完成。
class WebViewGraphView extends StatefulWidget {
  const WebViewGraphView({
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
  State<WebViewGraphView> createState() => _WebViewGraphViewState();
}

class _WebViewGraphViewState extends State<WebViewGraphView> {
  late final WebViewController _controller;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'GraphTap',
        onMessageReceived: (message) {
          final asset = widget.assets.where((a) => a.id == message.message);
          if (asset.isNotEmpty) {
            widget.onOpenNode(asset.first);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
          onPageFinished: (_) {
            _loaded = true;
            _pushData();
          },
        ),
      )
      ..loadFlutterAsset('assets/graph/g6.html');
    // 夜墨画布不会被系统深色模式加暗，无需在此处理：
    // 算法加暗需要 App 显式开启（本应用与 webview_flutter_android 4.14.1
    // 均未开启）；旧版 force-dark 仅在原生主题为深色时触发，而本应用
    // values-night 也钉死为 Theme.Light（见 android res/styles）。白色
    // 背景仅设为透明，画布颜色完全由 Flutter 夜墨底与 G6 自绘。
  }

  @override
  void didUpdateWidget(covariant WebViewGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assets != widget.assets ||
        oldWidget.relations != widget.relations) {
      _pushData();
    }
  }

  void _pushData() {
    if (!_loaded) {
      return;
    }
    final payload = {
      'focusIds': widget.focusIds.toList(),
      'nodes': [
        for (final asset in widget.assets)
          {
            'id': asset.id,
            'title': asset.title,
            'color': _typeColor(asset.type),
            'shape': _nodeShape(asset.type),
            'degree': widget.relations
                .where(
                  (relation) =>
                      relation.fromAssetId == asset.id ||
                      relation.toAssetId == asset.id,
                )
                .length,
            'pinned': asset.isPinned,
            'focused':
                widget.focusIds.isEmpty || widget.focusIds.contains(asset.id),
          },
      ],
      'edges': [
        for (final relation in widget.relations)
          {
            'from': relation.fromAssetId,
            'to': relation.toAssetId,
            'label': relation.type.label,
            'kind': relation.type.name,
            'focused':
                widget.focusIds.isEmpty ||
                widget.focusIds.contains(relation.fromAssetId) ||
                widget.focusIds.contains(relation.toAssetId),
            'strength': switch (relation.type) {
              RelationType.paidWith ||
              RelationType.registeredWith ||
              RelationType.belongsTo => .8,
              RelationType.storedOn || RelationType.recovers => .55,
              _ => .32,
            },
          },
      ],
    };
    final jsonText = jsonEncode(payload);
    _controller.runJavaScript('loadGraph(${jsonEncode(jsonText)})');
  }

  String _typeColor(AssetType type) => '#EDE8DC';

  String _nodeShape(AssetType type) => switch (type) {
    AssetType.email || AssetType.subscription || AssetType.password => 'circle',
    AssetType.apiKey ||
    AssetType.device ||
    AssetType.item ||
    AssetType.other => 'rect',
    _ => 'diamond',
  };

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _GraphFailureList(
        assets: widget.assets,
        relations: widget.relations,
        focusIds: widget.focusIds,
        onOpenNode: widget.onOpenNode,
      );
    }
    return WebViewWidget(controller: _controller);
  }
}

class _GraphFailureList extends StatelessWidget {
  const _GraphFailureList({
    required this.assets,
    required this.relations,
    required this.focusIds,
    required this.onOpenNode,
  });

  final List<Asset> assets;
  final List<Relation> relations;
  final Set<String> focusIds;
  final ValueChanged<Asset> onOpenNode;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.nightBackground,
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: assets.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: AppColors.nightTextPrimary.withValues(alpha: .12),
      ),
      itemBuilder: (context, index) {
        final asset = assets[index];
        final relationCount = relations
            .where(
              (relation) =>
                  relation.fromAssetId == asset.id ||
                  relation.toAssetId == asset.id,
            )
            .length;
        final dimmed = focusIds.isNotEmpty && !focusIds.contains(asset.id);
        return Opacity(
          opacity: dimmed ? .18 : 1,
          child: ListTile(
            dense: true,
            leading: AssetTypeBadge(type: asset.type, size: 30),
            title: Text(
              asset.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.nightTextPrimary),
            ),
            subtitle: Text(
              '$relationCount 条关系',
              style: const TextStyle(color: AppColors.nightTextSecondary),
            ),
            onTap: () => onOpenNode(asset),
          ),
        );
      },
    ),
  );
}
