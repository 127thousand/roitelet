import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ed25519_edwards/ed25519_edwards.dart';

class RoiteletKeypair {
  final String pubkeyBase64;
  final String privkeyBase64;
  RoiteletKeypair(this.pubkeyBase64, this.privkeyBase64);
}

RoiteletKeypair generateKeypair() {
  final kp = generateKey();
  return RoiteletKeypair(
    base64Encode(kp.publicKey.bytes),
    base64Encode(kp.privateKey.bytes),
  );
}

RoiteletKeypair loadKeypair(File privKeyFile) {
  final privBase64 = privKeyFile.readAsStringSync().trim();
  final priv = PrivateKey(base64Decode(privBase64));
  final pub = public(priv);
  return RoiteletKeypair(base64Encode(pub.bytes), privBase64);
}

String signBytes(PrivateKey priv, List<int> bytes) {
  final sig = sign(priv, Uint8List.fromList(bytes));
  return base64Encode(sig);
}