import 'package:flutter/material.dart';
import 'package:flutter_eval/flutter_eval.dart';
import 'package:roitelet_client/roitelet.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return RoiteletRoot(
      config: RoiteletConfig(
        appId: 'sandbox-app',
        releaseVersion: '1.0.0',
        manifestUrl:
            'http://localhost:8787/v1/manifest/sandbox-app/1.0.0',
        pubkeyBase64: const String.fromEnvironment(
          'ROITELET_PUBKEY',
          defaultValue: 'ARNSHnxj8a3oCOQhDyP+eZCPlJt7wcnGbyPbMwnAsqM=',
        ),
      ),
      child: MaterialApp(
        title: 'Roitelet sandbox',
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return HotSwap(
      id: '#home',
      args: const [],
      childBuilder: (_) => Scaffold(
        appBar: AppBar(title: const Text('v1')),
        body: const Center(child: Text('original')),
      ),
    );
  }
}