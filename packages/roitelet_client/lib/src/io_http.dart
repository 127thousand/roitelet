import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:roitelet_client/src/updater.dart';

class IoPatchHttpClient implements PatchHttpClient {
  final Duration timeout;
  IoPatchHttpClient({this.timeout = const Duration(seconds: 10)});

  @override
  Future<String?> getJson(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(timeout);
      if (r.statusCode == 204) return null;
      if (r.statusCode != 200) return null;
      return r.body;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> getBytes(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(timeout);
      if (r.statusCode != 200) return null;
      return r.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}