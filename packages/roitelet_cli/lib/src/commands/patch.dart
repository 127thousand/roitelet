import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:roitelet_cli/src/api.dart';
import 'package:roitelet_cli/src/config.dart';
import 'package:roitelet_cli/src/compiler.dart';
import 'package:roitelet_cli/src/keys.dart';

class PatchCommand extends Command {
  @override
  final name = 'patch';
  @override
  final description = 'Compile, sign, and upload a patch to the roitelet worker.';

  PatchCommand() {
    argParser.addOption('hot-update-dir', mandatory: true,
        help: 'Path to the hot update package (contains .dart_eval/bindings).');
    argParser.addOption('config', defaultsTo: 'roitelet.yaml',
        help: 'Path to roitelet.yaml.');
    argParser.addOption('private-key', defaultsTo: 'roitelet_private.key',
        help: 'Path to the ed25519 private key.');
    argParser.addOption('patch-number', mandatory: true,
        help: 'Integer patch number; must be greater than the last uploaded patch.');
    argParser.addOption('admin-key-env', defaultsTo: 'ROITELET_ADMIN_KEY',
        help: 'Env var holding the worker admin key.');
    argParser.addOption('out', defaultsTo: 'patch.evc',
        help: 'Output filename inside hot-update-dir.');
    argParser.addOption('min-store-version',
        help: 'Minimum store version required. Apps below this show upgrade screen.');
  }

  @override
  Future<void> run() async {
    final args = argResults!;
    final cfg = RoiteletConfigFile.fromFile(File(args['config']));
    final privFile = File(args['private-key']);
    final kp = loadKeypair(privFile);
    final projectDir = Directory(args['hot-update-dir']);
    final patchNumber = int.parse(args['patch-number']);
    final adminKey = Platform.environment[args['admin-key-env']] ?? '';
    if (adminKey.isEmpty) {
      throw Exception('missing admin key env: ${args['admin-key-env']}');
    }

    stdout.writeln('Compiling ${projectDir.path}…');
    final compiled = await compileHotUpdatePackage(projectDir, outputPath: args['out']);
    stdout.writeln('Compiled ${compiled.bytes} bytes -> ${compiled.evcFile.path}');

    stdout.writeln('Uploading as patch $patchNumber…');
    final res = await uploadPatch(
      cfg: cfg,
      evcFile: compiled.evcFile,
      privkeyBase64: kp.privkeyBase64,
      patchNumber: patchNumber,
      adminKey: adminKey,
      minStoreVersion: args['min-store-version'] as String?,
    );
    stdout.writeln('Uploaded. evc_url = ${res.evcUrl}');
  }
}