import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:roitelet_cli/src/api.dart';
import 'package:roitelet_cli/src/config.dart';
import 'package:roitelet_cli/src/keys.dart';

class RollbackCommand extends Command {
  @override
  final name = 'rollback';
  @override
  final description = 'Re-upload a prior patch as a new patch number (effective rollback).';

  RollbackCommand() {
    argParser.addOption('config', defaultsTo: 'roitelet.yaml');
    argParser.addOption('private-key', defaultsTo: 'roitelet_private.key');
    argParser.addOption('to-patch-number', mandatory: true,
        help: 'The prior patch number to re-serve.');
    argParser.addOption('as-patch-number', mandatory: true,
        help: 'A new, higher patch number to publish it under.');
    argParser.addOption('admin-key-env', defaultsTo: 'ROITELET_ADMIN_KEY');
  }

  @override
  Future<void> run() async {
    final args = argResults!;
    final cfg = RoiteletConfigFile.fromFile(File(args['config']));
    final kp = loadKeypair(File(args['private-key']));
    final toPn = int.parse(args['to-patch-number']);
    final asPn = int.parse(args['as-patch-number']);
    final adminKey = Platform.environment[args['admin-key-env']] ?? '';
    if (adminKey.isEmpty) {
      throw Exception('missing admin key env: ${args['admin-key-env']}');
    }

    final evcUrl =
        '${cfg.workerUrl}/v1/evc/${cfg.appId}/${cfg.releaseVersion}/$toPn.evc';
    final r = await http.get(Uri.parse(evcUrl));
    if (r.statusCode != 200) {
      throw Exception('could not download prior patch $toPn: ${r.statusCode}');
    }
    final tmpEvc = File('/tmp/roitelet_rollback_$asPn.evc')
      ..writeAsBytesSync(r.bodyBytes);

    final res = await uploadPatch(
      cfg: cfg,
      evcFile: tmpEvc,
      privkeyBase64: kp.privkeyBase64,
      patchNumber: asPn,
      adminKey: adminKey,
    );
    stdout.writeln('Rolled back to patch $toPn, republished as $asPn.');
    stdout.writeln('evc_url = ${res.evcUrl}');
  }
}