import 'dart:io';

class CompileResult {
  final File evcFile;
  final int bytes;
  CompileResult(this.evcFile, this.bytes);
}

Future<CompileResult> compileHotUpdatePackage(
  Directory projectDir, {
  required String outputPath,
}) async {
  final pkgConfig =
      File('${projectDir.path}/.dart_tool/package_config.json');
  if (!pkgConfig.existsSync()) {
    final get = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: projectDir.path,
    );
    if (get.exitCode != 0) {
      throw Exception(
        'dart pub get failed in ${projectDir.path} (exit ${get.exitCode}): ${get.stderr}',
      );
    }
  }
  final pr = await Process.run(
    'dart_eval',
    ['compile', '-o', outputPath],
    workingDirectory: projectDir.path,
  );
  if (pr.exitCode != 0) {
    throw Exception(
      'dart_eval compile failed (exit ${pr.exitCode}): ${pr.stderr}',
    );
  }
  final f = File('${projectDir.path}/$outputPath');
  return CompileResult(f, f.lengthSync());
}