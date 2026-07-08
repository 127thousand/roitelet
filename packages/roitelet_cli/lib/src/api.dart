import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:roitelet_cli/src/config.dart';
import 'package:roitelet_cli/src/signer.dart';

class PatchUploadResult {
  final int patchNumber;
  final String evcUrl;
  PatchUploadResult(this.patchNumber, this.evcUrl);
}

Future<PatchUploadResult> uploadPatch({
  required RoiteletConfigFile cfg,
  required File evcFile,
  required String privkeyBase64,
  required int patchNumber,
  required String adminKey,
}) async {
  final bytes = await evcFile.readAsBytes();
  final sig = signPatch(bytes, privkeyBase64);
  final req = http.MultipartRequest(
    'POST',
    Uri.parse('${cfg.workerUrl}/v1/admin/patch'),
  )
    ..headers['authorization'] = 'Bearer $adminKey'
    ..fields['app_id'] = cfg.appId
    ..fields['release_version'] = cfg.releaseVersion
    ..fields['patch_number'] = patchNumber.toString()
    ..fields['signature'] = sig.signatureBase64
    ..fields['hash'] = sig.hashHex
    ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'patch.evc'));
  final r = await req.send();
  if (r.statusCode != 200) {
    throw Exception('upload failed: ${r.statusCode} ${await r.stream.toBytes()}');
  }
  final body = await r.stream.toBytes();
  final json = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
  return PatchUploadResult(
    json['patch_number'] as int,
    json['evc_url'] as String,
  );
}