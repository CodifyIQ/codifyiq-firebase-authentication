import 'dart:convert';
import 'dart:math';

import 'package:codifyiq_firebase_authentication/src/firebase_auth_platform.dart';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:codifyiq_firebase_authentication/src/firebase_auth_result.dart';

/// Firebase-backed authentication service for social and email/password
/// sign-in.
///
/// Provides platform-aware implementations of Google, Apple, and
/// email/password authentication that return a unified
/// [FirebaseAuthResult].
///
/// ## Configuration
///
/// [webRedirectDomains] — When the current web host matches one of these
/// domains, Google sign-in uses redirect-based OAuth instead of a popup.
/// This is necessary for custom Firebase Hosting domains where popups are
/// blocked. Defaults to an empty list (popup for all domains).
///
/// ```dart
/// final authService = FirebaseAuthService(
///   webRedirectDomains: ['myapp.firebaseapp.com', 'login.myapp.com'],
/// );
/// ```
class FirebaseAuthService {
  /// Creates a [FirebaseAuthService].
  ///
  /// Args:
  ///   auth: Optional [FirebaseAuth] instance (defaults to
  ///     [FirebaseAuth.instance]).
  ///   webRedirectDomains: Web domains where Google sign-in should use
  ///     redirect-based OAuth instead of popup.
  FirebaseAuthService({FirebaseAuth? auth, this.webRedirectDomains = const []})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Web domains where Google sign-in uses redirect instead of popup.
  final List<String> webRedirectDomains;

  /// Signs in the user with their Google account.
  ///
  /// On web, uses popup or redirect OAuth depending on
  /// [webRedirectDomains]. On native platforms, uses the Google Sign-In
  /// SDK.
  ///
  /// Returns:
  ///   A [FirebaseAuthResult] indicating success, failure, or
  ///   cancellation.
  Future<FirebaseAuthResult> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      }
      return await _signInWithGoogleNative();
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthFailure(message: _userFacingMessage(e.code));
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      debugPrint('Unexpected Google sign-in error: $e');
      return const FirebaseAuthFailure(
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Signs in the user with their Apple account.
  ///
  /// Handles platform differences automatically:
  /// - **Web:** Firebase OAuthProvider popup.
  /// - **Android:** Firebase OAuthProvider via `signInWithProvider`
  ///   (Chrome Custom Tab). User may need to manually return to the app.
  /// - **iOS:** Native Sign in with Apple with PKCE nonce security.
  ///
  /// Returns:
  ///   A [FirebaseAuthResult] indicating success, failure, or
  ///   cancellation.
  Future<FirebaseAuthResult> signInWithApple() async {
    try {
      if (kIsWeb) {
        return await _signInWithApplePopup();
      }
      if (isAndroid) {
        return await _signInWithAppleAndroid();
      }
      return await _signInWithAppleIos();
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthFailure(message: _userFacingMessage(e.code));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const FirebaseAuthCancelled();
      }
      return const FirebaseAuthFailure(
        message: 'An error occurred during Apple sign-in.',
      );
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    } catch (e) {
      debugPrint('Unexpected Apple sign-in error: $e');
      return const FirebaseAuthFailure(
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Signs in with email and password using Firebase Authentication.
  ///
  /// Intended for reviewer login flows.
  ///
  /// Args:
  ///   email: The reviewer's email address.
  ///   password: The reviewer's password.
  ///
  /// Returns:
  ///   A [FirebaseAuthResult] indicating success or failure.
  Future<FirebaseAuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return FirebaseAuthSuccess(credential: credential);
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthFailure(message: _userFacingMessage(e.code));
    } catch (e) {
      debugPrint('Unexpected email sign-in error: $e');
      return const FirebaseAuthFailure(
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Signs out the current user from Firebase and Google.
  ///
  /// Clears the Google Sign-In SDK session so the account picker is
  /// shown on the next sign-in attempt.
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore — Google Sign-In may not have been used this session.
      }
    }
    await _auth.signOut();
  }

  // -- Google sign-in (platform-specific) ----------------------------------

  /// Checks for a pending redirect sign-in result on web.
  ///
  /// Call this once on app startup (after Firebase initialization) when
  /// using redirect-based OAuth. If the user is returning from a
  /// redirect, this completes the flow and returns a [FirebaseAuthSuccess].
  /// Otherwise returns `null`.
  ///
  /// No-op on non-web platforms.
  Future<FirebaseAuthResult?> getRedirectResult() async {
    if (!kIsWeb) return null;
    try {
      final redirectResult = await _auth.getRedirectResult();
      if (redirectResult.user != null) {
        return FirebaseAuthSuccess(credential: redirectResult);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthFailure(message: _userFacingMessage(e.code));
    } catch (e) {
      debugPrint('Unexpected redirect result error: $e');
      return null;
    }
  }

  Future<FirebaseAuthResult> _signInWithGoogleWeb() async {
    final googleProvider = GoogleAuthProvider();

    if (webRedirectDomains.contains(Uri.base.host)) {
      // Initiate the redirect. The browser navigates away; execution
      // does not continue past this point. On return, the consuming
      // app should call getRedirectResult() to complete the flow.
      await _auth.signInWithRedirect(googleProvider);

      // Unreachable after redirect, but satisfies the analyzer.
      return const FirebaseAuthFailure(
        message:
            'Redirect initiated. Complete sign-in after '
            'the browser returns.',
      );
    }

    final credential = await _auth.signInWithPopup(googleProvider);
    return FirebaseAuthSuccess(credential: credential);
  }

  Future<FirebaseAuthResult> _signInWithGoogleNative() async {
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;

    final oauthCredential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final credential = await _auth.signInWithCredential(oauthCredential);
    return FirebaseAuthSuccess(credential: credential);
  }

  // -- Apple sign-in (platform-specific) -----------------------------------

  /// Signs in with Apple using the Firebase OAuthProvider popup flow.
  ///
  /// Web only — `signInWithPopup` is not available on native platforms.
  Future<FirebaseAuthResult> _signInWithApplePopup() async {
    final appleProvider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    final credential = await _auth.signInWithPopup(appleProvider);
    return FirebaseAuthSuccess(credential: credential);
  }

  /// Signs in with Apple on Android using the Firebase OAuthProvider flow.
  ///
  /// Uses `signInWithProvider` which opens a Chrome Custom Tab for Apple's
  /// OAuth page. The auth completes successfully but the Chrome Custom Tab
  /// may not automatically redirect back to the app — the user may need to
  /// manually switch back. Firebase still receives the credential.
  Future<FirebaseAuthResult> _signInWithAppleAndroid() async {
    final appleProvider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    final credential = await _auth.signInWithProvider(appleProvider);
    return FirebaseAuthSuccess(credential: credential);
  }

  Future<FirebaseAuthResult> _signInWithAppleIos() async {
    final rawNonce = _createNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final credential = await _auth.signInWithCredential(oauthCredential);
    return FirebaseAuthSuccess(credential: credential);
  }

  // -- Helpers -------------------------------------------------------------

  /// Generates a cryptographically secure random nonce for Apple sign-in
  /// PKCE flow.
  String _createNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        'abcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Returns the SHA-256 hash of [input] as a hex string.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Returns a user-facing message for a Firebase error code.
  ///
  /// Maps known error codes to friendly messages and falls back to a
  /// generic message for unknown codes — never exposes raw Firebase
  /// error strings to the UI.
  String _userFacingMessage(String? errorCode) {
    return switch (errorCode) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-email' => 'Invalid email or password.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' =>
        'Too many sign-in attempts. Please try again later.',
      'email-already-in-use' => 'An account already exists with this email.',
      'account-exists-with-different-credential' =>
        'An account already exists with this email using a different sign-in method.',
      'network-request-failed' =>
        'Network error. Please check your connection and try again.',
      'popup-closed-by-user' ||
      'web-context-cancelled' => 'Sign-in was cancelled.',
      _ => 'An error occurred. Please try again.',
    };
  }

  FirebaseAuthResult _handlePlatformException(PlatformException e) {
    if (e.code == 'sign_in_canceled' || e.code == 'popup_closed_by_user') {
      return const FirebaseAuthCancelled();
    }

    if (e.code == 'network_error') {
      return const FirebaseAuthFailure(
        message: 'Network error. Please check your connection and try again.',
      );
    }

    return const FirebaseAuthFailure(
      message: 'An error occurred during sign-in.',
    );
  }
}
