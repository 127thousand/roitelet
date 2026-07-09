import 'dart:convert';
import 'package:roitelet_client/src/verifier.dart';
import 'package:roitelet_client/src/io_http.dart';

typedef TranslationOverride = Map<String, String>;

class RoiteletLocalizations {
  final String manifestUrl;
  final String pubkeyBase64;
  final Map<String, TranslationOverride> _overrides = {};

  RoiteletLocalizations({required this.manifestUrl, required this.pubkeyBase64});

  Future<void> loadOverrides() async {
    final http = IoPatchHttpClient();
    final manifestBody = await http.getJson(manifestUrl);
    if (manifestBody == null) return;

    Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(manifestBody) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    for (final entry in manifest.entries) {
      final locale = entry.key;
      final info = entry.value as Map<String, dynamic>;
      final url = info['url'] as String;
      final signature = info['signature'] as String;
      final hash = info['hash'] as String;

      final bytes = await http.getBytes(url);
      if (bytes == null) continue;
      if (!verifyHash(bytecode: bytes, hashHex: hash)) continue;
      if (!verifyPatch(bytecode: bytes, signatureBase64: signature, pubkeyBase64: pubkeyBase64)) continue;

      try {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        _overrides[locale] = json.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }
  }

  TranslationOverride overrideFor(String locale) => _overrides[locale] ?? {};

  static Map<String, String> merge(
    Map<String, String> base,
    TranslationOverride override,
  ) {
    return {...base, ...override};
  }
}