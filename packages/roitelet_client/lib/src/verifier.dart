import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

bool verifyPatch({
  required Uint8List bytecode,
  required String signatureBase64,
  required String pubkeyBase64,
}) {
  try {
    final sig = base64Decode(signatureBase64);
    final pub = ed.PublicKey(base64Decode(pubkeyBase64));
    return ed.verify(pub, bytecode, sig);
  } catch (_) {
    return false;
  }
}

bool verifyHash({
  required Uint8List bytecode,
  required String hashHex,
}) {
  final h = sha256.convert(bytecode).toString();
  return h == hashHex.toLowerCase();
}