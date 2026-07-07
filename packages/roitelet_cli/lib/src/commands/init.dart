import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:roitelet_cli/src/config.dart';
import 'package:roitelet_cli/src/keys.dart';

class InitCommand extends Command {
  @override
  final name = 'init';
  @override
  final description = 'Generate roitelet.yaml + an ed25519 keypair in the current dir.';

  InitCommand() {
    argParser.addOption('app-id', mandatory: true);
    argParser.addOption('worker-url', mandatory: true);
    argParser.addOption('release-version', mandatory: true);
  }

  @override
  void run() {
    final args = argResults!;
    final kp = generateKeypair();
    final cfg = RoiteletConfigFile(
      appId: args['app-id'],
      workerUrl: args['worker-url'],
      releaseVersion: args['release-version'],
      pubkeyBase64: kp.pubkeyBase64,
    );
    File('roitelet.yaml').writeAsStringSync(cfg.toYaml());
    File('roitelet_private.key').writeAsStringSync(kp.privkeyBase64);
    stdout.writeln('Created roitelet.yaml and roitelet_private.key.');
    stdout.writeln('Public key (bake into app): ${kp.pubkeyBase64}');
    stdout.writeln('Keep roitelet_private.key secret. Use it in CI.');
  }
}