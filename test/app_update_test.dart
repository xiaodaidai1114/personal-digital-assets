import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_digital_assets/data/app_update.dart';

void main() {
  test('解析可用的新版本 Release 与 APK 资产', () {
    final release = AppReleaseInfo.fromGitHub({
      'tag_name': 'v1.3.0',
      'html_url': 'https://github.com/example/repo/releases/tag/v1.3.0',
      'published_at': '2026-09-20T08:00:00Z',
      'assets': [
        {
          'name': 'checksums.txt',
          'browser_download_url': 'https://github.com/example/repo/releases/download/v1.3.0/checksums.txt',
        },
        {
          'name': 'old-app.apk',
          'browser_download_url': 'https://github.com/example/repo/releases/download/v1.3.0/old-app.apk',
        },
        {
          'name': 'app-release.apk',
          'browser_download_url': 'https://github.com/example/repo/releases/download/v1.3.0/app-release.apk',
        },
      ],
    }, '1.2.0');

    expect(release.isUpdateAvailable, isTrue);
    expect(release.version, '1.3.0');
    expect(release.apkUrl?.path, endsWith('/app-release.apk'));
    expect(release.publishedAt, isNotNull);
  });

  test('同版本或旧版本不提示更新', () {
    const data = {
      'tag_name': 'v1.2.0',
      'html_url': 'https://github.com/example/repo/releases/tag/v1.2.0',
      'assets': [
        {
          'name': 'app-release.apk',
          'browser_download_url': 'https://github.com/example/repo/app.apk',
        },
      ],
    };

    expect(AppReleaseInfo.fromGitHub(data, '1.2.0').isUpdateAvailable, isFalse);
    expect(AppReleaseInfo.fromGitHub(data, '1.3.0').isUpdateAvailable, isFalse);
  });

  test('GitHub 请求失败时不提示更新', () async {
    final checker = GitHubUpdateChecker(
      currentVersion: '1.2.0',
      client: MockClient((request) async => http.Response('error', 500)),
    );

    expect(await checker.checkLatest(), isNull);
  });
}
