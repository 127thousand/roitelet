library roitelet.src.roitelet;

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:roitelet_client/src/io_http.dart';
import 'package:roitelet_client/src/storage.dart';
import 'package:roitelet_client/src/updater.dart';

class RoiteletConfig {
  final String appId;
  final String releaseVersion;
  final String manifestUrl;
  final String pubkeyBase64;
  const RoiteletConfig({
    required this.appId,
    required this.releaseVersion,
    required this.manifestUrl,
    required this.pubkeyBase64,
  });
}

class Roitelet {
  final RoiteletConfig config;
  final RoiteletStorage storage;
  final RoiteletUpdater updater;

  Roitelet._(this.config, this.storage, this.updater);

  static Future<Roitelet> init(RoiteletConfig config) async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/roitelet');
    root.createSync(recursive: true);
    final storage = RoiteletStorage(root);
    final http = IoPatchHttpClient();
    final updater = RoiteletUpdater(
      manifestUrl: config.manifestUrl,
      pubkeyBase64: config.pubkeyBase64,
      storage: storage,
      http: http,
    );
    return Roitelet._(config, storage, updater);
  }

  Future<void> checkForUpdates() => updater.checkAndDownload();

  int? get currentPatchNumber => storage.currentPatchNumber;
  int? get pendingPatchNumber => storage.pendingPatchNumber;

  void promotePending() => storage.promotePending();
}