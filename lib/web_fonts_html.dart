import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
Future<void> registerWebFonts() async {
  const paths = [
    'fonts/NotoSansSC-Regular.otf',
    'fonts/NotoSansSC-Medium.otf',
    'fonts/NotoSansSC-Bold.otf',
  ];
  final loader = FontLoader('NotoSansSC'); // 与 app_theme.dart 的 fontFamily 一致
  for (final path in paths) {
    final ByteData data;
    try {
      data = await _fetch(path);
    } catch (error) {
      // 字体缺失时退回引擎在线拉取行为,不阻断启动。
      debugPrint('web font unavailable: $path ($error)');
      continue;
    }
    loader.addFont(Future<ByteData>.value(data));
  }
  await loader.load();
}

Future<ByteData> _fetch(String path) async {
  final request =
      await html.HttpRequest.request(path, responseType: 'arraybuffer');
  return ByteData.view(request.response as ByteBuffer);
}
