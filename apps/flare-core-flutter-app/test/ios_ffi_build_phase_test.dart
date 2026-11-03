import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS build phase uses the standalone FFI script', () {
    final pbxproj = File(
      '${Directory.current.path}/ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(pbxproj, contains('scripts/ensure_ios_ffi_staticlib.sh'));
    expect(pbxproj, isNot(contains('cargo xtask build ios-verify')));
  });

  test('iOS FFI script builds the FFI crate directly', () {
    final script = File(
      '${Directory.current.path}/scripts/ensure_ios_ffi_staticlib.sh',
    ).readAsStringSync();

    expect(script, contains(r'-p "$FFI_PACKAGE"'));
    expect(script, contains('flare-im-core-sdk-ffi'));
    expect(script, contains('FLARE_IOS_SKIP_RUST_BUILD'));
    expect(script, isNot(contains('cargo xtask')));
  });
}
