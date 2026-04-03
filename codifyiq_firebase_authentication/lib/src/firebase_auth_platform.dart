import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether the current platform is Android.
///
/// Safe to call on web — avoids importing `dart:io` directly in files
/// that must compile for all platforms.
bool get isAndroid => !kIsWeb && io.Platform.isAndroid;
