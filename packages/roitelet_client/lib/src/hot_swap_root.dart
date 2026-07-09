import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_eval/flutter_eval.dart';
import 'package:roitelet_client/src/roitelet.dart';

class RoiteletRoot extends StatefulWidget {
  final RoiteletConfig config;
  final Widget child;
  final Widget? loading;

  const RoiteletRoot({
    super.key,
    required this.config,
    required this.child,
    this.loading,
  });

  @override
  State<RoiteletRoot> createState() => _RoiteletRootState();
}

class _RoiteletRootState extends State<RoiteletRoot> {
  Roitelet? roitelet;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final r = await Roitelet.init(widget.config);
      if (r.pendingPatchNumber != null) {
        r.promotePending();
      }
      await r.checkForUpdates();
      if (!mounted) return;
      setState(() => roitelet = r);
    } catch (e, st) {
      debugPrint('RoiteletRoot boot error: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Don't block the app — just render without patches and log the error
      debugPrint('RoiteletRoot rendering without patches due to: $_error');
    }
    if (roitelet == null) {
      return widget.loading ?? widget.child;
    }
    final patchN = roitelet!.currentPatchNumber;
    if (patchN == null) return widget.child;
    final evcFile = File('${roitelet!.storage.root.path}/patches/$patchN.evc');
    if (!evcFile.existsSync()) return widget.child;
    return HotSwapLoader(
      key: ValueKey('roitelet_patch_$patchN'),
      uri: evcFile.uri.toString(),
      strategy: HotSwapStrategy.immediate,
      child: widget.child,
    );
  }
}