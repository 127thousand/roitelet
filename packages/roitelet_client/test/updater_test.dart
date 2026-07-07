import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:roitelet_client/roitelet.dart';

class FakeHttp implements PatchHttpClient {
  String? manifestBody;
  Uint8List? patchBytes;
  @override
  Future<String?> getJson(String url) async => manifestBody;
  @override
  Future<Uint8List?> getBytes(String url) async => patchBytes;
}

(String, String, Uint8List, String) _makeSigned(int n) {
  final kp = ed.generateKey();
  final bytes = Uint8List.fromList(List.generate(64, (i) => i + n));
  final sig = ed.sign(kp.privateKey, bytes);
  return (
    base64Encode(kp.publicKey.bytes),
    base64Encode(sig),
    bytes,
    sha256.convert(bytes).toString(),
  );
}

void main() {
  late Directory dir;
  late RoiteletStorage storage;
  late FakeHttp http;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('roitelet_updater_');
    storage = RoiteletStorage(dir);
    http = FakeHttp();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('returns upToDate when manifest patch <= current', () async {
    storage.setCurrent(5);
    http.manifestBody = jsonEncode({
      'patch_number': 5,
      'evc_url': 'x',
      'signature': 'x',
      'hash': 'x',
      'created_at': '2026-07-07T00:00:00Z',
    });
    final u = RoiteletUpdater(
        manifestUrl: 'm', pubkeyBase64: 'k', storage: storage, http: http);
    expect(await u.checkAndDownload(), UpdateResult.upToDate);
  });

  test('downloads, verifies, and sets pending', () async {
    final (pub, sig, bytes, hash) = _makeSigned(7);
    http.manifestBody = jsonEncode({
      'patch_number': 7,
      'evc_url': 'https://x/7.evc',
      'signature': sig,
      'hash': hash,
      'created_at': '2026-07-07T00:00:00Z',
    });
    http.patchBytes = bytes;
    final u = RoiteletUpdater(
        manifestUrl: 'm', pubkeyBase64: pub, storage: storage, http: http);
    expect(await u.checkAndDownload(), UpdateResult.downloaded);
    expect(storage.pendingPatchNumber, 7);
    expect(storage.readPatchBytes(7), bytes);
  });

  test('rejects bad signature and blocklists', () async {
    final (pub, _, bytes, hash) = _makeSigned(8);
    http.manifestBody = jsonEncode({
      'patch_number': 8,
      'evc_url': 'x',
      'signature': base64Encode(List.filled(64, 0)),
      'hash': hash,
      'created_at': '2026-07-07T00:00:00Z',
    });
    http.patchBytes = bytes;
    final u = RoiteletUpdater(
        manifestUrl: 'm', pubkeyBase64: pub, storage: storage, http: http);
    expect(await u.checkAndDownload(), UpdateResult.badSignature);
    expect(storage.isBlocked(8), isTrue);
    expect(storage.pendingPatchNumber, isNull);
  });

  test('rejects bad hash', () async {
    final (pub, sig, bytes, _) = _makeSigned(9);
    http.manifestBody = jsonEncode({
      'patch_number': 9,
      'evc_url': 'x',
      'signature': sig,
      'hash': 'deadbeef',
      'created_at': '2026-07-07T00:00:00Z',
    });
    http.patchBytes = bytes;
    final u = RoiteletUpdater(
        manifestUrl: 'm', pubkeyBase64: pub, storage: storage, http: http);
    expect(await u.checkAndDownload(), UpdateResult.badHash);
    expect(storage.isBlocked(9), isTrue);
  });

  test('returns networkFailed when manifest fetch fails', () async {
    http.manifestBody = null;
    final u = RoiteletUpdater(
        manifestUrl: 'm', pubkeyBase64: 'k', storage: storage, http: http);
    expect(await u.checkAndDownload(), UpdateResult.networkFailed);
  });
}