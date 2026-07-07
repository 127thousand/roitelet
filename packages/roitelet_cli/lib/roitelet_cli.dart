library roitelet_cli;

import 'package:args/command_runner.dart';
import 'src/commands/init.dart';

CommandRunner buildRunner() {
  return CommandRunner('roitelet', 'Self-hosted Flutter code-push.')
    ..addCommand(InitCommand());
}