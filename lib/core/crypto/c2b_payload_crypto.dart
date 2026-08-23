import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

/// AES-256-GCM envelope encryption for C2B REST payloads.
final class C2bPayloadCrypto {
  C2bPayloadCrypto._();

  static Map<String, dynamic> encryptPlaintext(
    String plaintext,
    enc.Key key,
    String keyId,
  ) {
    final iv = enc.IV.fromSecureRandom(12);
    final aes = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = aes.encrypt(plaintext, iv: iv);
    final packed = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return {
      'v': 1,
      'kid': keyId,
      'data': base64Encode(packed),
    };
  }

  static String decryptEnvelope(Map<String, dynamic> envelope, enc.Key key) {
    final data = envelope['data'];
    if (data is! String || data.isEmpty) {
      throw const FormatException('Missing encrypted data field');
    }

    final packed = base64Decode(data);
    if (packed.length < 13) {
      throw const FormatException('Encrypted payload too short');
    }

    final iv = enc.IV(packed.sublist(0, 12));
    final cipherBytes = enc.Encrypted(packed.sublist(12));
    final aes = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return aes.decrypt(cipherBytes, iv: iv);
  }
}
