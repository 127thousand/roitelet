import 'package:eval_annotation/eval_annotation.dart';
import 'package:flutter/material.dart';

@RuntimeOverride('#home')
Widget homeUpdate() {
  return Scaffold(
    appBar: AppBar(title: const Text('v2 (patched)')),
    body: const Center(child: Text('patched via roitelet')),
  );
}