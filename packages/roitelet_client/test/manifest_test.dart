import 'package:flutter_test/flutter_test.dart';
import 'package:roitelet_client/roitelet.dart';

void main() {
  test('PatchManifest parses a full manifest', () {
    final json = {
      'patch_number': 3,
      'evc_url': 'https://patches.roitelet.dev/evc/app-v1-3.evc',
      'signature': 'base64signature==',
      'hash': 'sha256hex',
      'created_at': '2026-07-07T12:00:00Z',
    };
    final m = PatchManifest.fromJson(json);
    expect(m.patchNumber, 3);
    expect(m.evcUrl, json['evc_url']);
    expect(m.signature, 'base64signature==');
    expect(m.hash, 'sha256hex');
  });

  test('PatchManifest throws on missing patch_number', () {
    expect(() => PatchManifest.fromJson({'evc_url': 'x'}),
        throwsA(isA<FormatException>()));
  });

  test('PatchManifest parses min_store_version when present', () {
    final m = PatchManifest.fromJson({
      'patch_number': 1,
      'evc_url': 'x',
      'signature': 'x',
      'hash': 'x',
      'created_at': '2026-07-07T12:00:00Z',
      'min_store_version': '2.0.0',
    });
    expect(m.minStoreVersion, '2.0.0');
  });

  test('PatchManifest min_store_version is null when absent', () {
    final m = PatchManifest.fromJson({
      'patch_number': 1,
      'evc_url': 'x',
      'signature': 'x',
      'hash': 'x',
      'created_at': '2026-07-07T12:00:00Z',
    });
    expect(m.minStoreVersion, isNull);
  });
}