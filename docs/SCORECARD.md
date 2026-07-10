# OpenSSF Scorecard Notes

This repository publishes an OpenSSF Scorecard badge and runs Scorecard on a schedule. Some Scorecard checks are fully automated from repository settings and workflows. Others depend on external project metadata that cannot be fixed by editing source files alone.

## CII Best Practices

Scorecard's `CII-Best-Practices` check is based on the OpenSSF Best Practices BadgeApp. It looks up this repository's Git URL in the BadgeApp API and scores the project only after a BadgeApp project entry exists.

Current state:

- BadgeApp project `13546` exists for Mac Drag Scroll.
- The project earned the Passing badge on July 9, 2026, which Scorecard awards 5/10.
- The README badge points to `https://www.bestpractices.dev/projects/13546`.
- The repository includes `.bestpractices.json` so BadgeApp can prefill evidence-backed proposed answers.

To improve the check:

1. Open [BadgeApp project 13546](https://www.bestpractices.dev/en/projects/13546/passing).
2. Sign in with the GitHub account that owns or maintains this repository.
3. Review the proposed answers imported from `.bestpractices.json`.
4. Fill in any remaining self-certification criteria honestly.
5. Complete Silver for 7/10 before pursuing Gold for 10/10.

```markdown
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/13546/badge)](https://www.bestpractices.dev/projects/13546)
```

Do not replace the numeric badge URL with a query-only badge URL. Scorecard and readers should be able to resolve the concrete BadgeApp project entry directly.

## Contributors

Scorecard's `Contributors` check is based on recent commit authors and the `Company` field on their GitHub profiles. It is not based on a `CONTRIBUTORS` file, README text, or local git author names.

If Scorecard reports contributions from `soupmasters`, that value is coming from the maintainer's GitHub profile company field. The field has been cleared for the primary maintainer account; if it reappears, remove it with:

```sh
gh auth refresh -h github.com -s user
gh api --method PATCH user -f company=''
```

The extra `user` OAuth scope is required because this changes the authenticated GitHub account profile globally, not just this repository.

Clearing the company field removes the unwanted organization label, but it does not make the Contributors score high by itself. Scorecard rewards real contributor diversity across multiple GitHub profile company values.

The maximum score requires substantive recent work from at least three real organizations, with at least five commits per organization in Scorecard's recent-commit window. Do not create cosmetic commits or inaccurate company affiliations for this check.

## Token Permissions

Workflow-level permissions stay read-only. Jobs that publish security results declare only their required write permission at job scope. This preserves least privilege and prevents a future job from inheriting write access accidentally.

## Packaging

Mac Drag Scroll is packaged through GitHub Releases, Sparkle appcasts, the CLI installer, and the public Homebrew tap at [martincalander/homebrew-tap](https://github.com/martincalander/homebrew-tap).

The release workflow uses a pinned GoReleaser action to publish the `.zip`, `.dmg`, `appcast.xml`, and checksum files produced by the existing Xcode and Sparkle pipeline. This keeps GitHub Releases as the source of truth while making the real packaging workflow recognizable to Scorecard. Scorecard requires at least one successful run of that workflow before the `Packaging` check passes.

## Signed Releases

Release ZIPs are signed with the same Sparkle EdDSA key trusted by the app. The workflow publishes that detached signature as `MacDragScroll.zip.sig`, generates GitHub build provenance, and attaches the portable bundle as `MacDragScroll.intoto.jsonl`.

OpenSSF Scorecard checks filenames in the five most recent GitHub releases. A detached signature on every release earns 8/10; provenance on every release earns 10/10. Historic releases should only be backfilled with signatures or provenance that genuinely exists. Do not generate misleading provenance or delete valid releases solely to raise the score.

Signed-Releases scores 10/10. Each release from `v1.0.3` through `v1.0.7` includes both `MacDragScroll.zip.sig` and genuine `MacDragScroll.intoto.jsonl` provenance, so every release in the current five-release window is covered.

This check is independent of Apple Developer ID signing and notarization. It does not require a paid Apple Developer Program account.

## Code Review

Changes to `main` require a pull request, resolved review conversations, and the build/test and secret-scan checks. Required approval remains at zero while Mac Drag Scroll has only one maintainer because GitHub does not allow a pull request author to approve their own pull request.

When two trusted reviewers are available, add them as collaborators and code owners, then require two approvals, code-owner review, stale-review dismissal, and approval after the latest push. Recent changes must accumulate genuine human review before the Code-Review score can rise; historical changes are not rewritten or backfilled.
