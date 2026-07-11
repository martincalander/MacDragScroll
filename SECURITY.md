# Security Policy

## Supported Versions

Security fixes are handled for the latest public release of Mac Drag Scroll.

Current public release archives are Sparkle-signed and include GitHub build provenance. App bundles use a pinned self-issued signing identity for update continuity, but they are not Apple Developer ID signed or notarized, so the README documents the macOS first-launch bypass.

## Security Expectations

- Mac Drag Scroll runs locally and does not send telemetry, input history, document contents, or browsing activity to the project.
- Accessibility and Input Monitoring are required to observe the configured mouse trigger and emit scroll events. The app rejects trackpad/tablet input by default and marks synthetic events to prevent feedback loops.
- Ignored apps, trigger safety checks, permission loss, duplicate instances, and target-window changes fail closed by cancelling drag scrolling.
- Sparkle verifies update archives with the public EdDSA key bundled in the app. GitHub Releases also publish checksums and build provenance for independent verification.
- Every release bundle is signed with the same project-held identity and checked against the public certificate fingerprint `8496d972dae09a9b540399562e9d2385f16bd8bd`. This keeps the macOS designated requirement stable across updates.
- The freely distributed app is not Apple Developer ID signed or notarized. Users should treat the documented Finder Open bypass as a distribution tradeoff, not as equivalent to Apple notarization.

The self-issued identity establishes continuity between Mac Drag Scroll releases; it does not establish Apple trust or replace Sparkle archive verification. Rotating or losing its private key would require users to grant protected permissions again, so the encrypted key is stored outside the repository and supplied to releases only through GitHub Actions secrets.

Mac Drag Scroll is an input convenience utility, not a security boundary. macOS can revoke its permissions at any time, and users can disable or quit the app from the menu bar.

## Automated Scans

The repository runs these free security checks:

- **OpenSSF Scorecard:** checks open-source security posture and publishes the public Scorecard badge.
- **CodeQL:** runs static analysis for Swift security issues.
- **Gitleaks and GitHub secret scanning:** scan committed secrets, while push protection blocks recognized credentials before they enter the repository.
- **Dependency Review:** blocks pull requests that introduce dependencies with moderate-or-higher known vulnerabilities.
- **Quality Gate:** treats compiler warnings as errors, runs tests with coverage, executes the preference fuzzer corpus under macOS Guard Malloc heap checking, performs Xcode static analysis, and validates a universal macOS 14+ release build.
- **Swift fuzz harnesses:** exercise preference-style parsers and normalization paths.

Scan results are advisory and do not replace manual review, but they help catch common repository, workflow, and secret-handling risks before release.

Scorecard checks that depend on external profile or badge-program metadata are documented in [OpenSSF Scorecard Notes](docs/SCORECARD.md).

## Reporting A Vulnerability

Please do not open a public issue for a suspected vulnerability.

Use GitHub's private vulnerability reporting if it is enabled for this repository. If that is not available, contact Martin Calander through [martincalander.com](https://martincalander.com) with:

- A short description of the problem.
- Steps to reproduce it.
- The macOS version and Mac Drag Scroll version.
- Any relevant logs or screenshots.

You should receive a response after the report has been reviewed. Confirmed issues will be fixed and disclosed responsibly.

## Sensitive Material

Do not include secrets, private Sparkle or app-signing keys, Apple account material, or private crash reports in public issues or pull requests. Redact local paths, user names, and app-specific data when sharing diagnostics publicly.
