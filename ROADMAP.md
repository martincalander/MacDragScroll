# Roadmap

Mac Drag Scroll follows a reliability-first roadmap. Work should make external-mouse drag scrolling more predictable without expanding the app into a general input remapper.

## Current Priorities

- Harden mouse-source detection, trigger cancellation, and synthetic-event isolation.
- Keep preferences stable across updates, reinstalls, development builds, and malformed stored values.
- Improve permission recovery and crash diagnostics without collecting telemetry.
- Keep the visualizer responsive, restrained, and faithful to user animation settings.
- Publish every release with the pinned project signing identity, Sparkle signatures, checksums, and GitHub build provenance.
- Keep installation, localization, support, privacy, architecture, and release documentation aligned with shipped behavior.

## Next 12 Months

From July 2026 through July 2027, the project intends to:

- Add regression tests whenever a real input, persistence, permission, or update edge case is found.
- Continue accessibility and keyboard-navigation audits for Settings and onboarding.
- Raise meaningful automated test coverage beyond the current core-logic focus.
- Complete evidence-backed OpenSSF Best Practices Silver criteria.
- Evaluate Apple Developer ID signing and notarization only if sustainable distribution funding becomes available.

## Collaboration Milestones

With independent maintainers now reviewing changes:

- Document maintainer succession and release-key recovery procedures.
- Reduce the remaining release-key and private-security-response bus factor.
- Pursue OpenSSF Best Practices Gold criteria that require broader maintenance continuity and stronger coverage.

## Non-Goals

- Recording user activity, document contents, browsing, or telemetry.
- Replacing macOS trackpad gestures or intercepting trackpad clicks.
- Becoming a general-purpose macro or input-remapping tool.
- Publishing empty releases, fabricated provenance, or inaccurate certification evidence.
- Adding background services that are not required for drag scrolling, updates, or diagnostics.
