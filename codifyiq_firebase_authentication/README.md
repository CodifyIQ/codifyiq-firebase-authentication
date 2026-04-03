# CodifyIQ Firebase Authentication

Firebase-backed sign-in implementations for Flutter apps. Provides Google,
Apple, and email/password authentication with multi-environment Firebase
support.

## Features

- **Google Sign-In** -- native SDK on iOS/Android, popup or redirect OAuth on web
- **Apple Sign-In** -- native Sign in with Apple (iOS), OAuthProvider popup (Android/web)
- **Email/Password** -- for reviewer or test account login
- **Config validation** -- catches common Firebase misconfigurations in debug mode

## Getting started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  codifyiq_firebase_authentication: ^1.0.0
```

### Initialize in `main()`

Call `FirebaseAuthInitializer.initialize` before `runApp()`. This initializes
Firebase, sets up the Google Sign-In SDK on native platforms, and runs
configuration validation in debug mode.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseAuthInitializer.initialize(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

For multi-flavor apps, generate a `FirebaseOptions` file per environment with
`flutterfire configure` and select the correct one at startup:

```dart
final options = switch (F.appFlavor) {
  Flavor.dev     => dev.DefaultFirebaseOptions.currentPlatform,
  Flavor.staging => staging.DefaultFirebaseOptions.currentPlatform,
  Flavor.prod    => prod.DefaultFirebaseOptions.currentPlatform,
};
await FirebaseAuthInitializer.initialize(firebaseOptions: options);
```

> **Web note:** On web, `firebase_core_web` loads the Firebase JS SDK
> automatically when `Firebase.initializeApp()` is called from Dart. You do
> **not** need to add `<script>` tags or call JavaScript `initializeApp()` in
> `index.html`.

**Optional parameters:**

| Parameter            | Default | Description                                      |
|----------------------|---------|--------------------------------------------------|
| `validateAppleSignIn`  | `true`  | Include Apple Sign-In config hints in debug validation  |
| `validateGoogleSignIn` | `true`  | Include Google Sign-In config hints in debug validation |
| `skipValidation`     | `false` | Suppress debug-mode configuration checks          |

### Platform configuration

**Google Sign-In (Android):**
1. Enable Google in Firebase Console > Authentication > Sign-in method.
2. Add SHA-1 and SHA-256 fingerprints for each build variant.
3. Download the updated `google-services.json` per flavor.

**Apple Sign-In (iOS):**
1. Enable the "Sign in with Apple" capability in Xcode.
2. Configure the Services ID and OAuth code flow URL in Firebase Console >
   Authentication > Sign-in method > Apple.

**Apple Sign-In (Android):**
Uses the Firebase OAuthProvider popup flow -- no deep link callback required.
This avoids issues with flavored builds where the `applicationId` changes
per environment.

## Usage

### Sign in

```dart
final authService = FirebaseAuthService();
final result = await authService.signInWithGoogle();

switch (result) {
  case FirebaseAuthSuccess(:final credential):
    // Navigate to home -- credential.user contains the Firebase User
  case FirebaseAuthFailure(:final message):
    // Show error message to the user
  case FirebaseAuthCancelled():
    // User dismissed the sign-in flow -- do nothing
}
```

### Web redirect domains

On web, Google sign-in defaults to popup OAuth. For custom Firebase Hosting
domains where popups are blocked, configure redirect-based OAuth:

```dart
final authService = FirebaseAuthService(
  webRedirectDomains: ['myapp.firebaseapp.com', 'login.myapp.com'],
);
```

### Track auth state

Access auth state directly via `FirebaseAuthInitializer`:

```dart
final user = FirebaseAuthInitializer.currentUser;

FirebaseAuthInitializer.authStateChanges().listen((user) {
  // React to sign-in / sign-out
});
```

### Sign out

```dart
await authService.signOut();
```

## Riverpod integration

The library is framework-agnostic, but many Flutter apps use Riverpod.
Three providers form the standard wiring:

```dart
final authServiceProvider = Provider<FirebaseAuthService>(
  (ref) => FirebaseAuthService(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, _) => false,
  );
});
```

Wire `isSignedInProvider` into a GoRouter `redirect` to protect routes:

```dart
return GoRouter(
  redirect: (context, state) {
    final isOnSignIn = state.matchedLocation == '/sign-in';
    if (!isSignedIn && !isOnSignIn) return '/sign-in';
    if (isSignedIn && isOnSignIn) return '/';
    return null;
  },
  routes: [ /* ... */ ],
);
```

## Configuration validation

In debug mode, `FirebaseAuthInitializer.initialize` automatically validates
your Firebase configuration and logs issues to the console:

- **Errors** (will break sign-in): missing API key, empty project ID,
  missing auth domain on web, Firebase Auth not enabled
- **Warnings** (setup reminders): Apple/Google provider console configuration
  steps

To suppress validation:

```dart
await FirebaseAuthInitializer.initialize(
  firebaseOptions: options,
  skipValidation: true,
);
```

## API reference

| Class                          | Purpose                                            |
|--------------------------------|----------------------------------------------------|
| `FirebaseAuthInitializer`      | Firebase setup, current user, auth state stream    |
| `FirebaseAuthService`          | Google, Apple, and email/password sign-in + sign-out|
| `FirebaseAuthResult`           | Sealed result type: Success, Failure, Cancelled    |
| `FirebaseAuthConfigValidator`  | Debug-mode configuration validation                |

## Sign-in page composition

Pair `FirebaseAuthService` with `SocialSignInScreen` (from
`codifyiq_core_components`). The key pattern is a reusable `_handleSignIn`
wrapper that manages loading/error state and pattern-matches the result:

```dart
Future<void> _handleSignIn(Future<FirebaseAuthResult> Function() signIn) async {
  setState(() { _errorMessage = null; _isLoading = true; });
  final result = await signIn();
  if (!mounted) return;
  switch (result) {
    case FirebaseAuthSuccess():
      break; // Auth state change triggers router redirect automatically
    case FirebaseAuthFailure(:final message):
      setState(() { _errorMessage = message; _isLoading = false; });
    case FirebaseAuthCancelled():
      setState(() => _isLoading = false);
  }
}
```

Then wire it into `SocialSignInScreen`:

```dart
SocialSignInScreen(
  logo: Image.asset('assets/logo.png', height: 96),
  errorMessage: _errorMessage,
  signInButtons: [
    SocialSignInButton(
      label: 'Continue with Apple',
      icon: Icon(Icons.apple),
      onPressed: _isLoading ? null : () => _handleSignIn(authService.signInWithApple),
    ),
    SocialSignInButton(
      label: 'Continue with Google',
      icon: Icon(Icons.g_mobiledata, size: 24),
      onPressed: _isLoading ? null : () => _handleSignIn(authService.signInWithGoogle),
    ),
  ],
)
```

Pass `null` to `onPressed` during loading to prevent double-taps. No explicit
navigation is needed — successful sign-in triggers `authStateProvider`, which
causes the router redirect to fire automatically.

### Apple Sign-In on Android — redirect warning

On Android, Apple Sign-In opens a Chrome Custom Tab that may not automatically
redirect back to the app. Show a confirmation dialog before launching the flow
so users know to switch back manually:

```dart
SocialSignInButton(
  label: 'Continue with Apple',
  icon: Icon(Icons.apple),
  onPressed: _isLoading ? null : () async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Apple Sign In'),
          content: const Text(
            'After signing in with Apple, you may need to manually '
            'return to the app. This is a known Android limitation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    _handleSignIn(authService.signInWithApple);
  },
)
```

## API client with auth headers

Inject the Firebase ID token as a `Bearer` header on backend requests:

```dart
Future<Map<String, String>> _getHeaders() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
```

## Integration checklist

1. Add `firebase_core`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple`,
   `codifyiq_firebase_authentication`, and `codifyiq_core_components` to `pubspec.yaml`
2. Create `firebase_options.dart` flavor router and per-flavor stubs
3. Run `flutterfire configure` to replace stubs with real config
4. Call `FirebaseAuthInitializer.initialize()` in `main.dart`
5. Create Riverpod providers (`authServiceProvider`, `authStateProvider`, `isSignedInProvider`)
6. Add GoRouter redirect guard watching `isSignedInProvider`
7. Create sign-in page with `SocialSignInScreen` and `_handleSignIn` wrapper
8. Wire `ApiClient` to inject Firebase ID token via `Authorization: Bearer` header
9. Enable Google and Apple providers in Firebase Console > Authentication > Sign-in method
10. Configure platform-specific settings (SHA fingerprints for Android, Sign in with Apple capability for iOS)

## Works with

| Task | Guide |
|------|-------|
| Social sign-in UI (`SocialSignInScreen`, `SocialSignInButton`) | [codifyiq_core_components README](https://github.com/CodifyIQ/codifyiq-core-components/blob/dev/codifyiq_core_components/README.md) |
| Firebase JWT verification (FastAPI backend) | [fastapi-cloudauth-lenient README](https://github.com/CodifyIQ/fastapi-cloudauth-lenient#readme) |

## Additional information

- [API documentation](https://pub.dev/documentation/codifyiq_firebase_authentication/latest/)
- [GitHub repository](https://github.com/CodifyIQ/codifyiq-firebase-authentication)
- [Issue tracker](https://github.com/CodifyIQ/codifyiq-firebase-authentication/issues)
