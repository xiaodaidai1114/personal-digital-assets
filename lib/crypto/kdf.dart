import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 主密码派生密钥器接口。将来替换为 Argon2id 实现时上层不受影响。
abstract interface class KeyDeriver {
  Future<Uint8List> derive(
    String masterPassword,
    List<int> salt, {
    int keyLength = 32,
  });
}

/// PBKDF2-HMAC-SHA256，210000 次迭代（OWASP 推荐下限）。
/// MVP 过渡实现；录入真实数据前替换为 Argon2id。
class Pbkdf2Deriver implements KeyDeriver {
  Pbkdf2Deriver({this.iterations = 210000});

  final int iterations;

  @override
  Future<Uint8List> derive(
    String masterPassword,
    List<int> salt, {
    int keyLength = 32,
  }) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: keyLength * 8,
    );
    final secretKey = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(masterPassword)),
      nonce: salt,
    );
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
