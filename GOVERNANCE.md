# Governance

Mac Drag Scroll is maintained in public through GitHub issues and pull requests. This document defines who can merge changes and how project decisions are made.

## Roles

- **Project lead and release owner:** [Martin Calander](https://github.com/martincalander) sets product direction, manages releases and signing material, and handles private security reports.
- **Maintainers:** [uglykatsuki](https://github.com/uglykatsuki) and [freddell97](https://github.com/freddell97) provide independent review and help maintain project quality. Repository write access does not grant access to private signing material or user diagnostics.
- **Contributors:** anyone may propose issues or pull requests under the Code of Conduct and contribution guidelines.

## Changes

All changes to `main` go through a pull request. Merging requires two approvals, code-owner review, approval of the latest push, passing required checks, and resolved review conversations. The pull request author cannot approve their own work.

Maintainers evaluate changes for user safety, trackpad isolation, permission scope, persistence compatibility, test coverage, localization impact, and release risk. Product and architecture disagreements should be discussed on the pull request or a linked issue; the project lead makes the final decision when consensus is not reached.

## Security And Releases

Suspected vulnerabilities follow the private process in [Security](SECURITY.md). The project lead coordinates disclosure and releases. Release archives are produced by the public workflow and verified with checksums, Sparkle signatures, and GitHub provenance.

## Role Changes

Maintainer access is based on sustained, trustworthy contributions and may be changed when responsibilities or availability change. Governance should be revisited as the maintainer group grows, especially to reduce release-key and security-response concentration.
