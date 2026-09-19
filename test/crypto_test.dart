import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_digital_assets/crypto/kdf.dart';
import 'package:personal_digital_assets/crypto/vault_cipher.dart';

void main() {
  group('Pbkdf2Deriver', () {
    test('相同密码与盐值派生出相同密钥', () async {
      final deriver = Pbkdf2Deriver(iterations: 1000);
      final key1 = await deriver.derive('主密码-test', List.filled(16, 7));
      final key2 = await deriver.derive('主密码-test', List.filled(16, 7));
      expect(key1, key2);
      expect(key1.length, 32);
    });

    test('不同盐值派生出不同密钥', () async {
      final deriver = Pbkdf2Deriver(iterations: 1000);
      final key1 = await deriver.derive('password', List.filled(16, 1));
      final key2 = await deriver.derive('password', List.filled(16, 2));
      expect(key1, isNot(equals(key2)));
    });
  });

  group('VaultCipher', () {
    test('AES-GCM 加密后可解密还原', () async {
      final deriver = Pbkdf2Deriver(iterations: 1000);
      final key = await deriver.derive('test-password', List.filled(16, 9));
      final cipher = VaultCipher(key);
      final plaintext = 'sk-FAKE-secret-123';
      final payload = await cipher.encrypt(plaintext);
      expect(payload.cipherText, isNot(equals(utf8.encode(plaintext))));
      expect(await cipher.decrypt(payload), plaintext);
    });

    test('密文被篡改时解密失败', () async {
      final deriver = Pbkdf2Deriver(iterations: 1000);
      final key = await deriver.derive('test-password', List.filled(16, 9));
      final cipher = VaultCipher(key);
      final payload = await cipher.encrypt('sk-FAKE-secret-123');
      final tampered = EncryptedPayload(
        version: payload.version,
        nonce: payload.nonce,
        cipherText: [
          payload.cipherText.first ^ 1,
          ...payload.cipherText.skip(1),
        ],
        mac: payload.mac,
      );
      expect(cipher.decrypt(tampered), throwsA(isA<Exception>()));
    });

    test('EncryptedPayload 序列化往返不变', () async {
      final deriver = Pbkdf2Deriver(iterations: 1000);
      final key = await deriver.derive('test-password', List.filled(16, 9));
      final cipher = VaultCipher(key);
      final payload = await cipher.encrypt('测试密码123');
      final restored = EncryptedPayload.deserialize(payload.serialize());
      expect(restored.version, payload.version);
      expect(restored.nonce, payload.nonce);
      expect(restored.cipherText, payload.cipherText);
      expect(restored.mac, payload.mac);
      expect(await cipher.decrypt(restored), '测试密码123');
    });
  });
}
