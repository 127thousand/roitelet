import 'package:flutter_test/flutter_test.dart';
import 'package:roitelet_client/src/manifest.dart';

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
}