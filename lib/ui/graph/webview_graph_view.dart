import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/asset.dart';
import '../../domain/relation.dart';

/// Android 端 G6 图谱容器：WebView 内嵌离线 G6 页面，原生侧只传 JSON 数据。
/// 节点点击经 GraphTap 通道回传，其余交互（拖拽/缩放/力导布局）由 G6 完成。
class WebViewGraphView extends StatefulWidget {
  const WebViewGraphView({
    super.key,
    required this.assets,
    required this.relations,
    required this.onOpenNode,
  });

  final List<Asset> assets;
  final List<Relation> relations;
  final ValueChanged<Asset> onOpenNode;

  @override
  State<WebViewGraphView> createState() => _WebViewGraphViewState();
}

class _WebViewGraphViewState extends State<WebViewGraphView> {
  late final WebViewController _controller;
  bool _loaded = false;

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
          onPageFinished: (_) {
            _loaded = true;
            _pushData();
          },
        ),
      )
      ..loadFlutterAsset('assets/graph/g6.html');
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
          },
      ],
      'edges': [
        for (final relation in widget.relations)
          {
            'from': relation.fromAssetId,
            'to': relation.toAssetId,
            'label': relation.type.label,
            'kind': relation.type.name,
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
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
