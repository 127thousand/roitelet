import 'dart:io';
import 'package:roitelet_cli/roitelet_cli.dart';

void main(List<String> arguments) {
  buildRunner().run(arguments).catchError((e) {
    stderr.writeln(e);
    exit(64);
  });
}