import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:roitelet_cli/src/config.dart';
import 'package:roitelet_cli/src/keys.dart';
import 'package:roitelet_cli/src/signer.dart';
import 'package:http/http.dart' as http;

class TranslateCommand extends Command {
  @override
  final name = 'translate';
  @override
  final description = 'Sign and upload a translation override JSON to the roitelet worker.';

  TranslateCommand() {
    argParser.addOption('config', defaultsTo: 'roitelet.yaml');
    argParser.addOption('private-key', defaultsTo: 'roitelet_private.key');
    argParser.addOption('locale', mandatory: true, help: 'e.g. en, es, fr');
    argParser.addOption('file', mandatory: true, help: 'Path to the JSON translation file.');
    argParser.addOption('admin-key-env', defaultsTo: 'ROITELET_ADMIN_KEY');
  }

  @override
  Future<void> run() async {
    final args = argResults!;
    final cfg = RoiteletConfigFile.fromFile(File(args['config']));
    final kp = loadKeypair(File(args['private-key']));
    final locale = args['locale'] as String;
    final jsonFile = File(args['file']);
    final adminKey = Platform.environment[args['admin-key-env']] ?? '';
    if (adminKey.isEmpty) {
      throw Exception('missing admin key env: ${args['admin-key-env']}');
    }

    final bytes = await jsonFile.readAsBytes();
    final sig = signPatch(bytes, kp.privkeyBase64);

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${cfg.workerUrl}/admin/v1/${cfg.appId}/translate'),
    )
      ..headers['authorization'] = 'Bearer $adminKey'
      ..fields['release_version'] = cfg.releaseVersion
      ..fields['locale'] = locale
      ..fields['signature'] = sig.signatureBase64
      ..fields['hash'] = sig.hashHex
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: '$locale.json'));

    final r = await req.send();
    if (r.statusCode != 200) {
      throw Exception('upload failed: ${r.statusCode} ${await r.stream.toBytes()}');
    }
    stdout.writeln('Uploaded translation override for $locale.');
    stdout.writeln('manifest: ${cfg.workerUrl}/v1/${cfg.appId}/translations/manifest/${cfg.releaseVersion}');
  }
}