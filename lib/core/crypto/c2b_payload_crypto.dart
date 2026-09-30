import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-256-GCM envelope encryption for C2B REST payloads.
final class C2bPayloadCrypto {
  C2bPayloadCrypto._();

  static const _ivLength = 12;
  static const _macBitLength = 128;

  static Map<String, dynamic> encryptPlaintext(
    String plaintext,
    Uint8List key,
    String keyId,
  ) {
    final iv = _secureRandomBytes(_ivLength);
    final packed = Uint8List.fromList([
      ...iv,
      ..._aesGcm(
        encrypt: true,
        key: key,
        iv: iv,
        input: Uint8List.fromList(utf8.encode(plaintext)),
      ),
    ]);
    return {
      'v': 1,
      'kid': keyId,
      'data': base64Encode(packed),
    };
  }

  static String decryptEnvelope(Map<String, dynamic> envelope, Uint8List key) {
    final data = envelope['data'];
    if (data is! String || data.isEmpty) {
      throw const FormatException('Missing encrypted data field');
    }

    final packed = base64Decode(data);
    if (packed.length < 13) {
      throw const FormatException('Encrypted payload too short');
    }

    final iv = packed.sublist(0, _ivLength);
    final cipherBytes = packed.sublist(_ivLength);
    final plain = _aesGcm(
      encrypt: false,
      key: key,
      iv: iv,
      input: cipherBytes,
    );
    return utf8.decode(plain);
  }

  static Uint8List _aesGcm({
    required bool encrypt,
    required Uint8List key,
    required Uint8List iv,
    required Uint8List input,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        encrypt,
        AEADParameters(KeyParameter(key), _macBitLength, iv, Uint8List(0)),
      );
    return cipher.process(input);
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
