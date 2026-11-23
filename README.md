# Password Manager

A local-first password manager built with Flutter. Vault data is encrypted on
the device with a master password; nothing is sent to a server in the current
phase.

## Features (Phase 1)

- Encrypted vault: AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC), PBKDF2-HMAC-SHA256.
- Master password setup, verification, and password rotation (vault re-encryption).
- Biometric unlock with the master password stored in platform secure storage.
- Auto-lock after an idle timeout or a long stay in the background.
- Clipboard auto-clear after copying passwords, usernames, or TOTP codes.
- Cryptographically secure password generator with length/charset options and a strength indicator.
- TOTP (2FA) secrets with live codes.
- Settings: theme, auto-lock timeout, clipboard timeout, biometrics, change master password.
- Search vault entries by title, username, or URL.

See [docs/PRD.md](docs/PRD.md) for the full product requirements and roadmap
(Phases 2–3: TOTP QR, categories, password health, import/export, sync,
autofill, and more).

## Architecture

Clean Architecture with a composition root in `lib/app.dart`:

```
data (secure storage, encryption, settings, models, repositories)
  → domain (entities, repository interfaces, use cases)
    → presentation (ChangeNotifier providers, screens, widgets)
```

Presentation never touches storage or encryption directly.

## Getting started

```bash
flutter pub get
flutter run
```

Run checks:

```bash
flutter analyze
flutter test
```

## Security notes

- There is **no master password recovery**. If the master password is lost,
  the vault cannot be decrypted.
- Biometric unlock stores the master password in `flutter_secure_storage`
  behind an app-level `local_auth` check. See PRD FR-03 for platform limits.
- The vault encryption key is derived separately from the stored password
  verifier, so a leaked verifier is not a vault key.
- Derived keys are cached in memory only while the vault is unlocked and are
  cleared on lock/logout.
