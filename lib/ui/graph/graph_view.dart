import 'package:flutter/material.dart';

import '../../domain/asset.dart';
import '../../domain/relation.dart';
import 'graph_view_stub.dart'
    if (dart.library.html) 'graph_view_web.dart'
    if (dart.library.io) 'graph_view_io.dart'
    as impl;

/// 平台对应的图谱视图：Android 走 WebView G6，其余平台走原生动态图谱。
Widget buildGraphView({
  required List<Asset> assets,
  required List<Relation> relations,
  required ValueChanged<Asset> onOpenNode,
}) => impl.buildGraphView(
  assets: assets,
  relations: relations,
  onOpenNode: onOpenNode,
);
