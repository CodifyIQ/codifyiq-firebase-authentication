import 'package:firebase_auth/firebase_auth.dart' show UserCredential;

/// The outcome of a Firebase authentication attempt.
///
/// Use pattern matching to handle success, failure, and cancellation:
///
/// ```dart
/// final result = await authService.signInWithGoogle();
/// switch (result) {
///   case FirebaseAuthSuccess():
///     // Navigate to home
///   case FirebaseAuthFailure(:final message):
///     // Show error
///   case FirebaseAuthCancelled():
///     // User dismissed — do nothing
/// }
/// ```
sealed class FirebaseAuthResult {
  const FirebaseAuthResult();
}

/// Authentication succeeded.
class FirebaseAuthSuccess extends FirebaseAuthResult {
  /// Creates a [FirebaseAuthSuccess] with the Firebase [credential].
  const FirebaseAuthSuccess({required this.credential});

  /// The Firebase user credential from the successful sign-in.
  final UserCredential credential;
}

/// Authentication failed with an error.
class FirebaseAuthFailure extends FirebaseAuthResult {
  /// Creates a [FirebaseAuthFailure] with a user-facing [message].
  const FirebaseAuthFailure({required this.message});

  /// A user-facing error message describing what went wrong.
  final String message;
}

/// The user cancelled the authentication flow.
class FirebaseAuthCancelled extends FirebaseAuthResult {
  /// Creates a [FirebaseAuthCancelled].
  const FirebaseAuthCancelled();
}
