import 'dart:io';
import 'package:test/test.dart';
import 'package:roitelet_cli/src/keys.dart';
import 'package:roitelet_cli/src/config.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('roitelet_cli_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('generate and load keypair roundtrip', () {
    final kp = generateKeypair();
    final f = File('${dir.path}/priv.key')..writeAsStringSync(kp.privkeyBase64);
    final loaded = loadKeypair(f);
    expect(loaded.pubkeyBase64, kp.pubkeyBase64);
  });

  test('config yaml roundtrip', () {
    final cfg = RoiteletConfigFile(
      appId: 'app-1',
      workerUrl: 'https://x.workers.dev',
      releaseVersion: '1.0.0',
      pubkeyBase64: 'pk',
    );
    final f = File('${dir.path}/roitelet.yaml')..writeAsStringSync(cfg.toYaml());
    final back = RoiteletConfigFile.fromFile(f);
    expect(back.appId, 'app-1');
    expect(back.pubkeyBase64, 'pk');
  });
}