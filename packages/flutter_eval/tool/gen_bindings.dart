import 'dart:convert';
import 'dart:io';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:flutter_eval/flutter_eval.dart';

void main() {
  final serializer = BridgeSerializer();
  serializer.addPlugin(flutterEvalPlugin);
  final json = serializer.toJson();
  File('.dart_eval/bindings/flutter_eval.json').writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(json),
  );
  print('Generated flutter_eval.json with ${json.length} entries');
}