import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:roitelet_client/roitelet.dart';

void main() {
  late ed.KeyPair kp;

  setUp(() {
    kp = ed.generateKey();
  });

  test('verifyPatch returns true for a correctly signed patch', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final sig = ed.sign(kp.privateKey, bytes);
    final ok = verifyPatch(
      bytecode: bytes,
      signatureBase64: base64Encode(sig),
      pubkeyBase64: base64Encode(kp.publicKey.bytes),
    );
    expect(ok, isTrue);
  });

  test('verifyPatch returns false for tampered bytecode', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final sig = ed.sign(kp.privateKey, bytes);
    final ok = verifyPatch(
      bytecode: Uint8List.fromList([1, 2, 3, 4, 6]),
      signatureBase64: base64Encode(sig),
      pubkeyBase64: base64Encode(kp.publicKey.bytes),
    );
    expect(ok, isFalse);
  });

  test('verifyHash returns true for matching sha256', () {
    final bytes = Uint8List.fromList([9, 9, 9]);
    final h = sha256.convert(bytes).toString();
    expect(verifyHash(bytecode: bytes, hashHex: h), isTrue);
    expect(verifyHash(bytecode: bytes, hashHex: 'deadbeef'), isFalse);
  });
}