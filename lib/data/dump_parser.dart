import 'dart:convert';

import '../domain/asset.dart';
import '../domain/asset_field_policy.dart';

/// 倾倒草稿（DESIGN.md 倾倒→检索→消费）：
/// 类型猜测 + 标题 + 普通字段（已过敏感校验）+ 封缄敏感内容。
class DumpDraft {
  const DumpDraft({
    required this.type,
    required this.title,
    this.fields = const {},
    this.tags = const ['导入'],
    this.secret,
  });

  final AssetType type;
  final String title;
  final Map<String, String> fields;
  final List<String> tags;

  /// 疑似完整凭据（密码 / API Key / Token）：只进封缄字段，绝不落普通字段。
  final String? secret;
}

/// 纯端侧解析倾倒文本：SSH 指令 → .env → JSON 凭证。
/// 识别不了返回 null，由调用方提示手动新增。
DumpDraft? parseDump(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  return _parseSsh(text) ?? _parseJson(text) ?? _parseEnv(text);
}

final _sshCommand = RegExp(r'^ssh\s+.+$');

DumpDraft? _parseSsh(String text) {
  if (!_sshCommand.hasMatch(text)) {
    return null;
  }
  final tokens = text.split(RegExp(r'\s+')).skip(1).toList();
  var host = '';
  var port = '';
  var user = '';
  var key = '';
  String? pending;
  for (final token in tokens) {
    if (pending != null) {
      if (pending == '-p') {
        port = token;
      } else if (pending == '-i') {
        key = token;
      }
      pending = null;
      continue;
    }
    if (token.startsWith('-')) {
      if (token == '-p' || token == '-i') {
        pending = token;
      } // 其余开关位（-v/-4 等）直接跳过
      continue;
    }
    final at = token.indexOf('@');
    if (at > 0 && at < token.length - 1) {
      user = token.substring(0, at);
      host = token.substring(at + 1);
    }
  }
  if (host.isEmpty) {
    return null;
  }
  return DumpDraft(
    type: AssetType.server,
    title: user.isEmpty ? host : '$user@$host',
    fields: {
      'host': host,
      if (user.isNotEmpty) 'user': user,
      if (port.isNotEmpty) 'port': port,
      if (key.isNotEmpty) 'key': key,
    },
    tags: ['导入', '服务器'],
  );
}

DumpDraft? _parseJson(String text) {
  if (!text.startsWith('{')) {
    return null;
  }
  final dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final flat = <String, String>{};
  decoded.forEach((key, value) {
    if (value != null) {
      flat[key.toLowerCase()] = value.toString().trim();
    }
  });
  if (flat.isEmpty) {
    return null;
  }
  final secret = _pickJsonSecret(flat);
  final fields = <String, String>{
    'host': ?_firstOf(flat, const ['host', 'server', 'ip']),
    'user': ?_firstOf(flat, const ['username', 'email', 'account', 'user']),
    'url': ?_firstOf(flat, const ['url', 'endpoint', 'baseurl']),
    'port': ?flat['port'],
  };
  final type = secret != null && _apiKeyLike(flat.keys)
      ? AssetType.apiKey
      : (fields.containsKey('host') && fields['host']!.isNotEmpty
            ? AssetType.server
            : AssetType.password);
  final title = _jsonTitle(fields, flat);
  return DumpDraft(type: type, title: title, fields: fields, secret: secret);
}

String _jsonTitle(Map<String, String> fields, Map<String, String> flat) {
  final url = fields['url'];
  if (url != null && url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return url;
  }
  final user = fields['user'];
  final host = fields['host'];
  if (user != null && user.isNotEmpty && host != null && host.isNotEmpty) {
    return '$user@$host';
  }
  if (host != null && host.isNotEmpty) {
    return host;
  }
  return flat.keys.first.toUpperCase();
}

String? _pickJsonSecret(Map<String, String> flat) {
  for (final key in const [
    'password',
    'pass',
    'pwd',
    'api_key',
    'apikey',
    'token',
    'access_token',
    'secret',
    'private_key',
    'privatekey',
  ]) {
    final value = flat[key];
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

bool _apiKeyLike(Iterable<String> keys) => keys.any(
  (key) => key.contains('api') || key.contains('token') || key.contains('key'),
);

final _envLine = RegExp(r'^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$');

DumpDraft? _parseEnv(String text) {
  final fields = <String, String>{};
  String? secret;
  var secretKey = '';
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final match = _envLine.firstMatch(line);
    if (match == null) {
      return null; // 不是 .env 形态就整体放弃，避免半猜半就
    }
    final key = match.group(1)!;
    var value = match.group(2)!.trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    if (value.isEmpty) {
      continue;
    }
    if (_sensitiveKey(key) ||
        AssetFieldPolicy.sensitivePlainTextError(value) != null) {
      // 设计红线：疑似完整凭据只进封缄内容，普通字段保持无敏感
      if (secret == null) {
        secret = value;
        secretKey = key;
      }
      continue;
    }
    fields[key] = value;
  }
  if (fields.isEmpty && secret == null) {
    return null;
  }
  final apiKeyish =
      secretKey.toLowerCase().contains('api') ||
      secretKey.toLowerCase().contains('token');
  return DumpDraft(
    type: apiKeyish ? AssetType.apiKey : AssetType.password,
    title: secretKey.isNotEmpty
        ? secretKey.replaceAll('_', ' ').toLowerCase()
        : fields.keys.first.replaceAll('_', ' ').toLowerCase(),
    fields: fields,
    secret: secret,
  );
}

bool _sensitiveKey(String key) {
  final lower = key.toLowerCase();
  return lower.contains('password') ||
      lower.contains('passwd') ||
      lower == 'pwd' ||
      lower == 'pass' ||
      lower.contains('secret') ||
      lower.contains('token') ||
      lower.contains('api_key') ||
      lower.contains('apikey') ||
      lower.contains('private_key');
}

String? _firstOf(Map<String, String> flat, List<String> keys) {
  for (final key in keys) {
    final value = flat[key];
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

/// 服务器资产的复制 SSH 动作：按字段拼出可执行的 ssh 指令。
String buildSshCommand(Asset asset) {
  final host = asset.fields['host']?.toString() ?? '';
  final user = asset.fields['user']?.toString() ?? '';
  final port = asset.fields['port']?.toString() ?? '';
  final key = asset.fields['key']?.toString() ?? '';
  final target = user.isEmpty ? host : '$user@$host';
  return [
    'ssh',
    if (port.isNotEmpty && port != '22') '-p $port',
    if (key.isNotEmpty) '-i $key',
    target,
  ].join(' ');
}
