import 'dart:convert';
import 'dart:io';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:flutter_eval/flutter_eval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate flutter_eval.json from vendored plugin', () {
    final serializer = BridgeSerializer();
    serializer.addPlugin(flutterEvalPlugin);
    final json = serializer.serialize();
    final outputPath = '.dart_eval/bindings/flutter_eval.json';
    File(outputPath).writeAsStringSync(
      JsonEncoder.withIndent('  ').convert(json),
    );
    print('Generated $outputPath with ${json.length} entries');
  });
}