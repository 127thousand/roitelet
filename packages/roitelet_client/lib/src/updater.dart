import 'dart:convert';
import 'dart:typed_data';
import 'package:roitelet_client/src/manifest.dart';
import 'package:roitelet_client/src/storage.dart';
import 'package:roitelet_client/src/verifier.dart';

abstract class PatchHttpClient {
  Future<String?> getJson(String url);
  Future<Uint8List?> getBytes(String url);
}

enum UpdateResult { upToDate, downloaded, blocked, badSignature, badHash, networkFailed }

class RoiteletUpdater {
  final String manifestUrl;
  final String pubkeyBase64;
  final RoiteletStorage storage;
  final PatchHttpClient http;

  RoiteletUpdater({
    required this.manifestUrl,
    required this.pubkeyBase64,
    required this.storage,
    required this.http,
  });

  Future<UpdateResult> checkAndDownload() async {
    final body = await http.getJson(manifestUrl);
    if (body == null) return UpdateResult.networkFailed;
    PatchManifest manifest;
    try {
      manifest = PatchManifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      return UpdateResult.networkFailed;
    }
    if (manifest.patchNumber <= (storage.currentPatchNumber ?? 0)) {
      return UpdateResult.upToDate;
    }
    if (storage.isBlocked(manifest.patchNumber)) {
      return UpdateResult.blocked;
    }
    final bytes = await http.getBytes(manifest.evcUrl);
    if (bytes == null) return UpdateResult.networkFailed;
    if (!verifyHash(bytecode: bytes, hashHex: manifest.hash)) {
      storage.blocklist(manifest.patchNumber);
      return UpdateResult.badHash;
    }
    if (!verifyPatch(
        bytecode: bytes,
        signatureBase64: manifest.signature,
        pubkeyBase64: pubkeyBase64)) {
      storage.blocklist(manifest.patchNumber);
      return UpdateResult.badSignature;
    }
    storage.writePatchBytes(manifest.patchNumber, bytes);
    storage.setPending(manifest.patchNumber);
    return UpdateResult.downloaded;
  }
}