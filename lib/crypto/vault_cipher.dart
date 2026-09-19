import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// 加密信封：带版本号，便于将来升级算法而不破坏旧数据。
class EncryptedPayload {
  const EncryptedPayload({
    required this.version,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final int version;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) =>
      EncryptedPayload(
        version: json['version'] as int,
        nonce: base64Decode(json['nonce'] as String),
        cipherText: base64Decode(json['cipherText'] as String),
        mac: base64Decode(json['mac'] as String),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(cipherText),
        'mac': base64Encode(mac),
      };

  String serialize() => jsonEncode(toJson());

  static EncryptedPayload deserialize(String source) =>
      EncryptedPayload.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// AES-256-GCM 加解密器。密钥只驻内存，保险库锁定时丢弃。
class VaultCipher {
  VaultCipher(List<int> key) : _key = SecretKey(key);

  static const int keyLengthBytes = 32;

  final SecretKey _key;

  Future<EncryptedPayload> encrypt(String plaintext) async {
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _key,
    );
    return EncryptedPayload(
      version: 1,
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  Future<String> decrypt(EncryptedPayload payload) async {
    final algorithm = AesGcm.with256bits();
    final clearText = await algorithm.decrypt(
      SecretBox(
        payload.cipherText,
        nonce: payload.nonce,
        mac: Mac(payload.mac),
      ),
      secretKey: _key,
    );
    return utf8.decode(clearText);
  }
}
