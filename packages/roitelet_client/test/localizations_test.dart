import 'package:flutter_test/flutter_test.dart';
import 'package:roitelet_client/src/localizations.dart';

void main() {
  test('merge applies override on top of base', () {
    final base = {'hello': 'Hello', 'dose': 'Dose', 'bye': 'Goodbye'};
    final override = {'dose': 'Dose amount', 'new_key': 'New'};
    final merged = RoiteletLocalizations.merge(base, override);
    expect(merged['hello'], 'Hello');
    expect(merged['dose'], 'Dose amount');
    expect(merged['bye'], 'Goodbye');
    expect(merged['new_key'], 'New');
  });

  test('empty override leaves base unchanged', () {
    final base = {'hello': 'Hello'};
    final merged = RoiteletLocalizations.merge(base, {});
    expect(merged['hello'], 'Hello');
    expect(merged.length, 1);
  });
}