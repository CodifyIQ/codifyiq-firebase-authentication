import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

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
/// | Firebase app initialized | Missing `Firebase.initializeApp()` call |
/// | Project ID present | Empty or placeholder project IDs |
/// | API key present | Missing API key in `FirebaseOptions` |
/// | App ID present | Missing app ID in `FirebaseOptions` |
/// | Auth domain (web) | Missing `authDomain` which breaks popup/redirect OAuth |
/// | Auth enabled | Firebase Auth not enabled in the console |
///
/// ### Warnings (setup reminders)
///
/// | Check | Detects |
/// |-------|---------|
/// | Apple provider config | Services ID and OAuth code flow URL needed |
/// | Google provider config | SHA fingerprints and google-services.json per flavor |
class FirebaseAuthConfigValidator {
  FirebaseAuthConfigValidator._();

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
  ///   validateAppleSignIn: Whether to include Apple Sign-In configuration
  ///     hints (default `true`).
  ///   validateGoogleSignIn: Whether to include Google Sign-In configuration
  ///     hints (default `true`).
  ///
  /// Returns:
  ///   A list of [ConfigIssue]s for any problems detected.
  static Future<List<ConfigIssue>> validate({
    required FirebaseOptions firebaseOptions,
    bool validateAppleSignIn = true,
    bool validateGoogleSignIn = true,
  }) async {
    // Only validate in debug mode
    if (!_isDebugMode) return const [];

    final issues = <ConfigIssue>[];

    _validateFirebaseApp(issues);
    _validateFirebaseOptions(firebaseOptions, issues);

    if (kIsWeb) {
      _validateWebAuthDomain(firebaseOptions, issues);
    }

    await _validateSignInProviders(
      issues,
      validateAppleSignIn: validateAppleSignIn,
      validateGoogleSignIn: validateGoogleSignIn,
    );

    _printIssues(issues);

    return issues;
  }

  static void _printIssues(List<ConfigIssue> issues) {
    final errors = issues
        .where((i) => i.severity == ConfigIssueSeverity.error)
        .toList();
    final warnings = issues
        .where((i) => i.severity == ConfigIssueSeverity.warning)
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

    if (warnings.isNotEmpty) {
      debugPrint('');
      debugPrint('[FirebaseAuth] Configuration hints:');
      for (final warning in warnings) {
        debugPrint('  - ${warning.message}');
      }
      debugPrint('');
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

  static void _validateFirebaseApp(List<ConfigIssue> issues) {
    try {
      Firebase.app();
    } catch (_) {
      issues.add(
        const ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase is not initialized. '
              'Call Firebase.initializeApp() before using auth.',
        ),
      );
    }
  }

  static void _validateFirebaseOptions(
    FirebaseOptions options,
    List<ConfigIssue> issues,
  ) {
    if (options.projectId.isEmpty || options.projectId == 'YOUR_PROJECT_ID') {
      issues.add(
        const ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase projectId is empty or placeholder. '
              'Check your FirebaseOptions / firebase_options file.',
        ),
      );
    }

    if (options.apiKey.isEmpty || options.apiKey == 'YOUR_API_KEY') {
      issues.add(
        const ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase apiKey is empty or placeholder. '
              'Check your FirebaseOptions / firebase_options file.',
        ),
      );
    }

    if (options.appId.isEmpty) {
      issues.add(
        const ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message:
              'Firebase appId is empty. '
              'Check your FirebaseOptions / firebase_options file.',
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

  /// Validates that Firebase Auth is reachable and emits setup reminders
  /// for enabled providers.
  static Future<void> _validateSignInProviders(
    List<ConfigIssue> issues, {
    required bool validateAppleSignIn,
    required bool validateGoogleSignIn,
  }) async {
    try {
      // Attempt a lightweight auth operation to confirm the Auth
      // instance is properly linked to the Firebase app.
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        'probe@validation.test',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'configuration-not-found') {
        issues.add(
          const ConfigIssue(
            severity: ConfigIssueSeverity.error,
            message:
                'Firebase Auth is not configured for this project. '
                'Enable Authentication in the Firebase Console.',
          ),
        );
      }
      // Other codes (e.g. 'invalid-email') are expected and mean
      // Auth is reachable — no issue to report.
    } catch (e) {
      debugPrint('Config validation probe skipped: $e');
    }

    if (validateAppleSignIn) {
      issues.addAll(_appleProviderHints());
    }
    if (validateGoogleSignIn) {
      issues.addAll(_googleProviderHints());
    }
  }

  /// Returns setup reminders for Apple Sign-In that cannot be validated
  /// programmatically at init time.
  static List<ConfigIssue> _appleProviderHints() {
    if (kIsWeb) return const [];

    return const [
      ConfigIssue(
        severity: ConfigIssueSeverity.warning,
        message:
            'Apple Sign-In requires configuration in the Firebase Console: '
            'Authentication > Sign-in method > Apple. '
            'Ensure the Services ID and OAuth code flow URL are configured.',
      ),
    ];
  }

  /// Returns setup reminders for Google Sign-In that cannot be validated
  /// programmatically at init time.
  static List<ConfigIssue> _googleProviderHints() {
    if (kIsWeb) return const [];

    return const [
      ConfigIssue(
        severity: ConfigIssueSeverity.warning,
        message:
            'Google Sign-In requires: '
            '(1) Enable Google in Firebase Console > Authentication > '
            'Sign-in method. '
            '(2) Add SHA-1/SHA-256 fingerprints for each Android build '
            'variant. '
            '(3) Download the updated google-services.json per flavor.',
      ),
    ];
  }
}
