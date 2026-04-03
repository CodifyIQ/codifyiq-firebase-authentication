import 'dart:io' as io;

/// Native implementation backed by `dart:io`.
bool get isAndroid => io.Platform.isAndroid;
