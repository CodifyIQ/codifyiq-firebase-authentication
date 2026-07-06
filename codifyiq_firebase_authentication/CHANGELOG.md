## 1.0.0

- Initial release.
- Google Sign-In (native SDK on iOS/Android, popup/redirect OAuth on web).
- Apple Sign-In (native on iOS, OAuthProvider popup on Android/web).
- Email/password authentication for reviewer login.
- Debug-mode configuration validation via `FirebaseAuthConfigValidator`.
- Upgraded `sign_in_with_apple` to `^8.0.0`, which adds Swift Package Manager
  support and mitigates upcoming CocoaPods deprecation issues.
- Requires Dart `^3.11.0` and Flutter `>=3.41.0` (imposed by
  `sign_in_with_apple` 8.x).
