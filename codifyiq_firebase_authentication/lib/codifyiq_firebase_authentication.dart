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
/// // In main():
/// await FirebaseAuthInitializer.initialize(
///   firebaseOptions: DefaultFirebaseOptions.currentPlatform,
/// );
///
/// // In your sign-in screen (uses SocialSignInScreen from
/// // codifyiq_core_components):
/// final authService = FirebaseAuthService();
///
/// SocialSignInScreen(
///   logo: Image.asset('assets/logo.png', height: 120),
///   signInButtons: [
///     SocialSignInButton(
///       label: 'Continue with Google',
///       icon: SvgPicture.asset('assets/google-logo.svg', width: 18),
///       onPressed: () => authService.signInWithGoogle(),
///     ),
///     SocialSignInButton(
///       label: 'Continue with Apple',
///       icon: Icon(Icons.apple),
///       onPressed: () => authService.signInWithApple(),
///     ),
///   ],
///   reviewerLoginEnabled: true,
///   onReviewerSignIn: (email, password) =>
///       authService.signInWithEmailAndPassword(email: email, password: password),
/// )
/// ```
library;

export 'src/firebase_auth_config_validator.dart';
export 'src/firebase_auth_initializer.dart';
export 'src/firebase_auth_service.dart';
export 'src/firebase_auth_result.dart';
