// Platform detection via conditional imports.
//
// Uses `dart:io` on native platforms and a stub on web, resolved at
// compile time — no runtime `kIsWeb` guard needed.
export 'firebase_auth_platform_stub.dart'
    if (dart.library.io) 'firebase_auth_platform_io.dart';
