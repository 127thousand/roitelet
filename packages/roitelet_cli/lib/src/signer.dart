import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:roitelet_cli/src/keys.dart';

class PatchSignature {
  final String signatureBase64;
  final String hashHex;
  PatchSignature(this.signatureBase64, this.hashHex);
}

PatchSignature signPatch(List<int> bytes, String privkeyBase64) {
  final priv = PrivateKey(base64Decode(privkeyBase64));
  final sig = signBytes(priv, bytes);
  final hash = sha256.convert(bytes).toString();
  return PatchSignature(sig, hash);
}