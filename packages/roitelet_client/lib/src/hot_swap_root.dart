import 'dart:io';
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

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final r = await Roitelet.init(widget.config);
    await r.checkForUpdates();
    if (!mounted) return;
    setState(() => roitelet = r);
  }

  @override
  Widget build(BuildContext context) {
    if (roitelet == null) {
      return widget.loading ?? widget.child;
    }
    final patchN = roitelet!.currentPatchNumber;
    if (patchN == null) return widget.child;
    final evcFile = File('${roitelet!.storage.root.path}/patches/$patchN.evc');
    if (!evcFile.existsSync()) return widget.child;
    return HotSwapLoader(
      uri: evcFile.uri.toString(),
      child: widget.child,
    );
  }
}