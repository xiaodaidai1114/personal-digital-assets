import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

// 预览专用 Web shim:仅经条件导出(dart.library.html)编译进 Web 构建。
// 不引入 package:web 新依赖,此处保留 dart:html 是最小实现。
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// 启动时把 `web/fonts/` 下的 Noto Sans SC 注册进引擎(仅 Web 预览生效)。
///
/// CanvasKit 渲染中文时若字体未注册,会向 fonts.gstatic.com 在线拉取分片,
/// 本机网络不可达时无限重试导致整页空白;`--no-web-resources-cdn` 不覆盖字体 CDN。
/// Android 构建不包含 web/ 目录,系统自带 CJK 字体,不受影响。
///
/// 每个字重独立 FontLoader(与 google_fonts 的 Web 用法一致);实测单 Loader
/// 挂多个 addFont 时注册不生效,文字仍走 gstatic 回退。
Future<void> registerWebFonts() async {
  for (final weight in const ['Regular', 'Medium', 'Bold']) {
    final path = 'fonts/NotoSansSC-$weight.otf';
    final ByteData data;
    try {
      data = await _fetch(path);
    } catch (_) {
      // 字体缺失时退回引擎在线拉取行为,不阻断启动。
      continue;
    }
    final loader = FontLoader('NotoSansSC'); // 与 app_theme.dart 一致
    loader.addFont(Future<ByteData>.value(data));
    await loader.load();
  }
}

Future<ByteData> _fetch(String path) async {
  final completer = Completer<ByteData>();
  final request = html.HttpRequest();
  request.open('GET', path);
  request.responseType = 'arraybuffer';
  request.onLoad.listen((_) {
    if (request.status == 200) {
      completer.complete(ByteData.view(request.response as ByteBuffer));
    } else {
      completer.completeError(StateException('HTTP ${request.status}'));
    }
  });
  request.onError.listen((_) => completer.completeError(StateException('XHR')));
  request.send();
  return completer.future;
}

final class StateException implements Exception {
  StateException(this.message);
  final String message;
  @override
  String toString() => message;
}
