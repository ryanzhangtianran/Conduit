import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/package_models.dart';

void main() {
  test('includes Homebrew as a user-level package manager', () {
    expect(PackageManager.values, contains(PackageManager.brew));
    expect(PackageManager.brew.label, 'Homebrew');
    expect(PackageManager.brew.requiresElevation, isFalse);
  });
}
