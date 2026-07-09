# Security Policy

## Supported Versions

Security fixes are handled for the latest public release of Mac Drag Scroll.

Current public release archives are Sparkle-signed and include GitHub build provenance. The app bundle is not Apple Developer ID signed or notarized, so the README documents the macOS first-launch bypass.

## Automated Scans

The repository runs these free security checks:

- **OpenSSF Scorecard:** checks open-source security posture and publishes the public Scorecard badge.
- **CodeQL:** runs static analysis for Swift security issues.
- **Gitleaks:** scans pushes, pull requests, and weekly scheduled runs for committed secrets.
- **Quality Gate:** builds, tests, and validates release metadata on macOS.
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

Do not include secrets, private Sparkle signing keys, Apple account material, or private crash reports in public issues or pull requests. Redact local paths, user names, and app-specific data when sharing diagnostics publicly.
