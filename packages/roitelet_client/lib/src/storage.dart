import 'dart:convert';
import 'dart:io';

class RoiteletStorage {
  final Directory root;
  RoiteletStorage(this.root);

  File get _stateFile => File('${root.path}/state.json');
  File get _blocklistFile => File('${root.path}/blocklist.json');
  Directory get _patchesDir => Directory('${root.path}/patches');

  Map<String, dynamic> _readJson(File f) {
    if (!f.existsSync()) return {};
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  void _writeJson(File f, Map<String, dynamic> m) {
    f.writeAsStringSync(jsonEncode(m));
  }

  int? get currentPatchNumber =>
      _readJson(_stateFile)['current'] as int?;
  int? get pendingPatchNumber =>
      _readJson(_stateFile)['pending'] as int?;

  void setCurrent(int n) {
    final s = _readJson(_stateFile);
    s['current'] = n;
    _writeJson(_stateFile, s);
  }

  void setPending(int n) {
    final s = _readJson(_stateFile);
    s['pending'] = n;
    _writeJson(_stateFile, s);
  }

  void promotePending() {
    final s = _readJson(_stateFile);
    final newCurrent = s['pending'] as int?;
    if (newCurrent == null) return;
    final oldCurrent = s['current'] as int?;
    if (oldCurrent != null) {
      _deletePatch(oldCurrent);
    }
    s['current'] = newCurrent;
    s['pending'] = null;
    _writeJson(_stateFile, s);
  }

  List<int>? readPatchBytes(int n) {
    final f = File('${_patchesDir.path}/$n.evc');
    if (!f.existsSync()) return null;
    return f.readAsBytesSync();
  }

  void writePatchBytes(int n, List<int> bytes) {
    _patchesDir.createSync(recursive: true);
    File('${_patchesDir.path}/$n.evc').writeAsBytesSync(bytes);
  }

  void _deletePatch(int n) {
    final f = File('${_patchesDir.path}/$n.evc');
    if (f.existsSync()) f.deleteSync();
  }

  bool isBlocked(int n) {
    final m = _readJson(_blocklistFile);
    final list = (m['blocked'] as List?) ?? [];
    return list.contains(n);
  }

  void blocklist(int n) {
    final m = _readJson(_blocklistFile);
    final list = (m['blocked'] as List?) ?? [];
    if (!list.contains(n)) list.add(n);
    m['blocked'] = list;
    _writeJson(_blocklistFile, m);
  }
}