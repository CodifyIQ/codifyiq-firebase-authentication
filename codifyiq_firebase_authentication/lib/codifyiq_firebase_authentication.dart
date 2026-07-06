/// CodifyIQ Firebase Authentication — Firebase-backed sign-in implementations
/// for Flutter apps.
///
/// This library provides ready-to-use Google and Apple sign-in. Consuming
/// apps supply their own [FirebaseOptions] and branding assets; this library
/// handles the platform-specific authentication flows.
///
/// ## Quick start
///
/// ```dart
/// import 'package:codifyiq_firebase_authentication/codifyiq_firebase_authentication.dart';
///
/// // In main(), before runApp():
/// WidgetsFlutterBinding.ensureInitialized();
/// await FirebaseAuthInitializer.initialize(
///   firebaseOptions: DefaultFirebaseOptions.currentPlatform,
/// );
///
/// // Anywhere in your app:
/// final authService = FirebaseAuthService();
///
/// final result = await authService.signInWithGoogle(); // or signInWithApple()
/// switch (result) {
///   case FirebaseAuthSuccess(:final credential):
///     print('Signed in as ${credential.user?.email}');
///   case FirebaseAuthFailure(:final message):
///     print('Sign-in failed: $message');
///   case FirebaseAuthCancelled():
///     print('Sign-in cancelled');
/// }
///
/// // Drive your UI from auth state changes:
/// StreamBuilder<User?>(
///   stream: FirebaseAuthInitializer.authStateChanges(),
///   builder: (context, snapshot) => snapshot.data == null
///       ? const SignInScreen()
///       : const HomeScreen(),
/// );
/// ```
///
/// See `example/example.dart` for a complete, runnable app.
library;

export 'src/firebase_auth_config_validator.dart';
export 'src/firebase_auth_initializer.dart';
export 'src/firebase_auth_service.dart';
export 'src/firebase_auth_result.dart';
