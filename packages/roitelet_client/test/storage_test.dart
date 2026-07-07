import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:roitelet_client/roitelet.dart';

void main() {
  late Directory dir;
  late RoiteletStorage storage;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('roitelet_storage_');
    storage = RoiteletStorage(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('state starts empty', () {
    expect(storage.currentPatchNumber, isNull);
    expect(storage.pendingPatchNumber, isNull);
  });

  test('setPending / promotePending roundtrip', () {
    storage.setPending(5);
    expect(storage.pendingPatchNumber, 5);
    expect(storage.currentPatchNumber, isNull);

    storage.promotePending();
    expect(storage.currentPatchNumber, 5);
    expect(storage.pendingPatchNumber, isNull);
  });

  test('blocklist rejects a failed patch', () {
    storage.blocklist(7);
    expect(storage.isBlocked(7), isTrue);
    expect(storage.isBlocked(8), isFalse);
  });

  test('writePatchBytes + readPatchBytes roundtrip', () {
    storage.writePatchBytes(5, [1, 2, 3, 4]);
    expect(storage.readPatchBytes(5), [1, 2, 3, 4]);
    expect(storage.readPatchBytes(6), isNull);
  });

  test('promotePending deletes prior patch bytes', () {
    storage.writePatchBytes(3, [10]);
    storage.setCurrent(3);
    storage.writePatchBytes(4, [20]);
    storage.setPending(4);
    storage.promotePending();
    expect(storage.readPatchBytes(3), isNull);
    expect(storage.readPatchBytes(4), [20]);
  });
}