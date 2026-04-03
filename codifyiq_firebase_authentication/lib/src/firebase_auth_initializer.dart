import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:codifyiq_firebase_authentication/src/firebase_auth_config_validator.dart';

/// Handles Firebase initialization and platform-specific auth setup.
///
/// Call [initialize] once in your app's `main()` before `runApp()`.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await FirebaseAuthInitializer.initialize(
///     firebaseOptions: DefaultFirebaseOptions.currentPlatform,
///   );
///   runApp(MyApp());
/// }
/// ```
///
/// ## Configuration validation
///
/// In **debug mode**, [initialize] automatically runs
/// [FirebaseAuthConfigValidator.validate] and prints warnings for common
/// misconfigurations (missing API keys, unconfigured providers, etc.).
/// Set [skipValidation] to `true` to suppress these checks.
class FirebaseAuthInitializer {
  FirebaseAuthInitializer._();

  /// Initializes Firebase and platform-specific auth providers.
  ///
  /// [firebaseOptions] must be the platform-appropriate [FirebaseOptions],
  /// typically from a FlutterFire-generated `DefaultFirebaseOptions` class.
  ///
  /// On native platforms, this also initializes the Google Sign-In SDK.
  /// On web, no additional setup is needed.
  ///
  /// Args:
  ///   firebaseOptions: Platform-specific Firebase configuration.
  ///   skipValidation: Set to `true` to suppress debug-mode configuration
  ///     validation (default `false`).
  ///
  /// Returns:
  ///   The initialized [FirebaseApp] instance.
  static Future<FirebaseApp> initialize({
    required FirebaseOptions firebaseOptions,
    bool skipValidation = false,
  }) async {
    final app = await Firebase.initializeApp(options: firebaseOptions);

    if (!kIsWeb) {
      await _initNativeGoogleSignIn();
    }

    if (!skipValidation) {
      FirebaseAuthConfigValidator.validate(
        firebaseOptions: firebaseOptions,
      );
    }

    return app;
  }

  /// Returns the currently signed-in [User], or `null` if not authenticated.
  static User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Stream of auth state changes (sign-in / sign-out events).
  static Stream<User?> authStateChanges() =>
      FirebaseAuth.instance.authStateChanges();

  static Future<void> _initNativeGoogleSignIn() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();
  }
}
