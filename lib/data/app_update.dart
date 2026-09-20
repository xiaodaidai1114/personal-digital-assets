import 'dart:convert';

import 'package:http/http.dart' as http;

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.releaseUrl,
    required this.apkUrl,
    required this.publishedAt,
  });

  static AppReleaseInfo fromGitHub(
    Map<String, dynamic> data,
    String currentVersion,
  ) {
    final tagName = data['tag_name'] as String?;
    final releaseUrl = data['html_url'] as String?;
    if (tagName == null || releaseUrl == null) {
      return const AppReleaseInfo.disabled();
    }

    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    if (_compareVersions(version, currentVersion) <= 0) {
      return const AppReleaseInfo.disabled();
    }

    final assets = data['assets'];
    String? apkUrl;
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) {
          continue;
        }
        final name = asset['name'] as String?;
        final url = asset['browser_download_url'] as String?;
        if (name != null && name.endsWith('.apk') && url != null) {
          apkUrl = url;
          if (name == 'app-release.apk') {
            break;
          }
        }
      }
    }
    if (apkUrl == null) {
      return const AppReleaseInfo.disabled();
    }

    return AppReleaseInfo(
      version: version,
      releaseUrl: Uri.parse(releaseUrl),
      apkUrl: Uri.parse(apkUrl),
      publishedAt: DateTime.tryParse(data['published_at'] as String? ?? ''),
    );
  }

  const AppReleaseInfo.disabled()
    : version = '',
      releaseUrl = null,
      apkUrl = null,
      publishedAt = null;

  final String version;
  final Uri? releaseUrl;
  final Uri? apkUrl;
  final DateTime? publishedAt;

  bool get isUpdateAvailable => apkUrl != null;
}

abstract interface class AppUpdateChecker {
  Future<AppReleaseInfo?> checkLatest();
}

class NoopUpdateChecker implements AppUpdateChecker {
  const NoopUpdateChecker();

  @override
  Future<AppReleaseInfo?> checkLatest() async => null;
}

class GitHubUpdateChecker implements AppUpdateChecker {
  GitHubUpdateChecker({required this.currentVersion, http.Client? client})
    : _client = client ?? http.Client();

  static const apiUrl =
      'https://api.github.com/repos/xiaodaidai1114/personal-digital-assets/releases/latest';

  final String currentVersion;
  final http.Client _client;

  @override
  Future<AppReleaseInfo?> checkLatest() async {
    try {
      final response = await _client.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (response.statusCode != 200) {
        return null;
      }
      return AppReleaseInfo.fromGitHub(
        jsonDecode(response.body) as Map<String, dynamic>,
        currentVersion,
      );
    } on Exception {
      return null;
    }
  }
}

int _compareVersions(String left, String right) {
  final leftParts = _versionParts(left);
  final rightParts = _versionParts(right);
  for (var index = 0; index < 3; index++) {
    final result = leftParts[index].compareTo(rightParts[index]);
    if (result != 0) {
      return result;
    }
  }
  return 0;
}

List<int> _versionParts(String version) {
  final parts = version
      .split(RegExp('[+.+]'))
      .take(3)
      .map(int.tryParse)
      .toList();
  return [
    parts.isNotEmpty ? parts[0] ?? 0 : 0,
    parts.length > 1 ? parts[1] ?? 0 : 0,
    parts.length > 2 ? parts[2] ?? 0 : 0,
  ];
}
