library roitelet_cli;

import 'package:args/command_runner.dart';
import 'src/commands/init.dart';
import 'src/commands/patch.dart';
import 'src/commands/rollback.dart';

CommandRunner buildRunner() {
  return CommandRunner('roitelet', 'Self-hosted Flutter code-push.')
    ..addCommand(InitCommand())
    ..addCommand(PatchCommand())
    ..addCommand(RollbackCommand());
}