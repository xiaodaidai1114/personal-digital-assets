import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/data/dump_parser.dart';
import 'package:personal_digital_assets/domain/asset.dart';

void main() {
  group('parseDump · SSH 指令', () {
    test('完整形态：端口 + 用户主机 + 密钥', () {
      final draft = parseDump(
        'ssh -p 2222 deploy@example.com -i ~/.ssh/id_ed25519',
      );
      expect(draft, isNotNull);
      expect(draft!.type, AssetType.server);
      expect(draft.title, 'deploy@example.com');
      expect(draft.fields['host'], 'example.com');
      expect(draft.fields['user'], 'deploy');
      expect(draft.fields['port'], '2222');
      expect(draft.fields['key'], '~/.ssh/id_ed25519');
      expect(draft.tags, contains('导入'));
    });

    test('最简形态：仅 user@host', () {
      final draft = parseDump('ssh root@10.0.0.1');
      expect(draft, isNotNull);
      expect(draft!.fields.containsKey('port'), isFalse);
      expect(draft.fields.containsKey('key'), isFalse);
    });

    test('没有 user@host 的 ssh 不是服务器倾倒', () {
      expect(parseDump('ssh-keygen -t ed25519'), isNull);
    });
  });

  group('parseDump · .env', () {
    test('API Key 进封缄内容，普通键进字段', () {
      final draft = parseDump('''
# workspace config
OPENAI_API_KEY="sk-FAKE1234567890abcdef"
REGION=us-east-1
''');
      expect(draft, isNotNull);
      expect(draft!.type, AssetType.apiKey);
      expect(draft.secret, 'sk-FAKE1234567890abcdef');
      expect(draft.fields['REGION'], 'us-east-1');
      // 红线：疑似完整 Key 绝不落普通字段
      expect(draft.fields.values, everyElement(isNot(contains('sk-FAKE'))));
    });

    test('PASSWORD 键名的值进封缄内容', () {
      final draft = parseDump(
        'DB_PASSWORD=hunter2secret\nDB_HOST=db.example.com',
      );
      expect(draft, isNotNull);
      expect(draft!.secret, 'hunter2secret');
      expect(draft.fields['DB_HOST'], 'db.example.com');
      expect(draft.type, AssetType.password);
    });

    test('非 .env 形态整体放弃', () {
      expect(parseDump('hello world'), isNull);
      expect(parseDump('随便一段中文文本'), isNull);
    });
  });

  group('parseDump · JSON 凭证', () {
    test('用户名 + 密码 + 主机 → 服务器草稿', () {
      final draft = parseDump(
        '{"username": "admin", "password": "s3cretpass", "host": "10.0.0.5"}',
      );
      expect(draft, isNotNull);
      expect(draft!.type, AssetType.server);
      expect(draft.title, 'admin@10.0.0.5');
      expect(draft.fields['host'], '10.0.0.5');
      expect(draft.fields['user'], 'admin');
      expect(draft.secret, 's3cretpass');
    });

    test('api_key + url → API Key 草稿，标题取域名', () {
      final draft = parseDump(
        '{"api_key": "sk-FAKE987654321", "url": "https://api.example.com"}',
      );
      expect(draft, isNotNull);
      expect(draft!.type, AssetType.apiKey);
      expect(draft.title, 'api.example.com');
      expect(draft.secret, 'sk-FAKE987654321');
    });

    test('坏 JSON 返回 null', () {
      expect(parseDump('{"broken": '), isNull);
    });
  });

  group('buildSshCommand', () {
    test('端口与密钥齐全', () {
      final asset = Asset(
        id: 'srv',
        type: AssetType.server,
        title: 'deploy@example.com',
        fields: {
          'host': 'example.com',
          'user': 'deploy',
          'port': '2222',
          'key': '/home/k/id_rsa',
        },
      );
      expect(
        buildSshCommand(asset),
        'ssh -p 2222 -i /home/k/id_rsa deploy@example.com',
      );
    });

    test('默认端口 22 省略 -p', () {
      final asset = Asset(
        id: 'srv',
        type: AssetType.server,
        title: 'root@10.0.0.1',
        fields: {'host': '10.0.0.1', 'user': 'root', 'port': '22'},
      );
      expect(buildSshCommand(asset), 'ssh root@10.0.0.1');
    });
  });
}
