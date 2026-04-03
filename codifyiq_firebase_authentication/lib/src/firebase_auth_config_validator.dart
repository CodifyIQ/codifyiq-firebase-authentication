import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// The severity of a configuration validation issue.
enum ConfigIssueSeverity {
  /// A misconfiguration that will cause sign-in to fail at runtime.
  error,

  /// A setup reminder that may or may not apply depending on the
  /// consuming app's console configuration.
  warning,
}

/// A single configuration validation issue.
class ConfigIssue {
  /// Creates a [ConfigIssue].
  const ConfigIssue({required this.severity, required this.message});

  /// Whether this is an error or a warning.
  final ConfigIssueSeverity severity;

  /// A human-readable description of the issue.
  final String message;
}

/// Validates Firebase Authentication configuration at initialization time.
///
/// Catches common misconfiguration issues early — before a user taps
/// "Sign in" and gets a cryptic error. Call [validate] from
/// [FirebaseAuthInitializer.initialize] or directly in your `main()`.
///
/// Validation runs only in **debug mode** to avoid impacting production
/// performance or leaking configuration details.
///
/// ## Checks performed
///
/// ### Errors (will break sign-in)
///
/// | Check | Detects |
/// |-------|---------|
/// | Project ID present | Empty or placeholder project IDs |
/// | API key present | Missing API key in `FirebaseOptions` |
/// | App ID present | Missing app ID in `FirebaseOptions` |
/// | Auth domain (web) | Missing `authDomain` which breaks popup/redirect OAuth |
///
/// Provider-specific sign-in configuration (Apple Services ID, Google SHA
/// fingerprints) cannot be validated programmatically — those values live
/// in the Firebase Console or platform files like google-services.json.
class FirebaseAuthConfigValidator {
  FirebaseAuthConfigValidator._();

  static const _rerunFlutterfireConfigure =
      'You probably need to re-run `flutterfire configure`.';

  /// Runs all configuration checks and logs issues found.
  ///
  /// **Errors** are logged with `developer.log` at level 1000 (warning)
  /// so they surface prominently in the debug console. **Warnings** use
  /// `debugPrint` for informational hints.
  ///
  /// Returns the full list of [ConfigIssue]s (empty if everything looks
  /// good). In release mode, returns an empty list without performing any
  /// checks.
  ///
  /// Args:
  ///   firebaseOptions: The [FirebaseOptions] used to initialize Firebase.
  ///
  /// Returns:
  ///   A list of [ConfigIssue]s for any problems detected.
  static List<ConfigIssue> validate({
    required FirebaseOptions firebaseOptions,
  }) {
    // Only validate in debug mode
    if (!_isDebugMode) return const [];

    final issues = <ConfigIssue>[];

    _validateFirebaseOptions(firebaseOptions, issues);

    if (kIsWeb) {
      _validateWebAuthDomain(firebaseOptions, issues);
    }

    _printIssues(issues);

    return issues;
  }

  static void _printIssues(List<ConfigIssue> issues) {
    final errors = issues
        .where((i) => i.severity == ConfigIssueSeverity.error)
        .toList();

    if (errors.isNotEmpty) {
      final buffer = StringBuffer()
        ..writeln()
        ..writeln(
          '╔══════════════════════════════════════════════'
          '══════════════════════════════╗',
        )
        ..writeln(
          '║  FIREBASE AUTH CONFIGURATION ERRORS'
          '                                      ║',
        )
        ..writeln(
          '╠══════════════════════════════════════════════'
          '══════════════════════════════╣',
        );
      for (final error in errors) {
        buffer.writeln('║  ERROR: ${error.message}');
      }
      buffer.writeln(
        '╚══════════════════════════════════════════════'
        '══════════════════════════════╝',
      );

      // Log at warning level (1000) so errors stand out in the console
      developer.log(buffer.toString(), name: 'FirebaseAuth', level: 1000);
    }
  }

  static bool get _isDebugMode {
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug;
  }

  static void _validateFirebaseOptions(
    FirebaseOptions options,
    List<ConfigIssue> issues,
  ) {
    if (options.projectId.isEmpty || options.projectId == 'YOUR_PROJECT_ID') {
      issues.add(
        ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase projectId is empty or placeholder. '
              '$_rerunFlutterfireConfigure',
        ),
      );
    }

    if (options.apiKey.isEmpty || options.apiKey == 'YOUR_API_KEY') {
      issues.add(
        ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase apiKey is empty or placeholder. '
              '$_rerunFlutterfireConfigure',
        ),
      );
    }

    if (options.appId.isEmpty) {
      issues.add(
        ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase appId is empty. '
              '$_rerunFlutterfireConfigure',
        ),
      );
    }
  }

  static void _validateWebAuthDomain(
    FirebaseOptions options,
    List<ConfigIssue> issues,
  ) {
    final authDomain = options.authDomain;
    if (authDomain == null || authDomain.isEmpty) {
      issues.add(
        const ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase authDomain is not set for web. '
              'OAuth popup/redirect sign-in will fail. '
              'Set authDomain in your web FirebaseOptions.',
        ),
      );
    }
  }

  /// Provider-specific sign-in configuration (Apple Services ID, Google
  /// SHA fingerprints, etc.) cannot be validated programmatically at init
  /// time — those values live in the Firebase Console or in platform files
  /// like google-services.json. Errors surface at sign-in time instead.
}
