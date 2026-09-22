// 按平台选择 Web 字体注册实现:Web 端注册本地字体,其余平台为空操作。
export 'web_fonts_stub.dart' if (dart.library.html) 'web_fonts_html.dart';
