import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';

import '../../domain/asset.dart';
import '../../domain/relation.dart';
import 'native_graph_view.dart';
import 'webview_graph_view.dart';

/// Android 使用 WebView + G6；桌面等 io 平台回退到原生动态图谱。
Widget buildGraphView({
  required List<Asset> assets,
  required List<Relation> relations,
  Set<String> focusIds = const {},
  required ValueChanged<Asset> onOpenNode,
}) {
  if (defaultTargetPlatform == TargetPlatform.android &&
      WebViewPlatform.instance != null) {
    return WebViewGraphView(
      assets: assets,
      relations: relations,
      focusIds: focusIds,
      onOpenNode: onOpenNode,
    );
  }
  return NativeGraphView(
    assets: assets,
    relations: relations,
    focusIds: focusIds,
    onOpenNode: onOpenNode,
  );
}
