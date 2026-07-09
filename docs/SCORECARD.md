# OpenSSF Scorecard Notes

This repository publishes an OpenSSF Scorecard badge and runs Scorecard on a schedule. Some Scorecard checks are fully automated from repository settings and workflows. Others depend on external project metadata that cannot be fixed by editing source files alone.

## CII Best Practices

Scorecard's `CII-Best-Practices` check is based on the OpenSSF Best Practices BadgeApp. It looks up this repository's Git URL in the BadgeApp API and scores the project only after a BadgeApp project entry exists.

Current state:

- BadgeApp project `13546` exists for Mac Drag Scroll.
- The project is currently in progress and not yet passing.
- The README badge points to `https://www.bestpractices.dev/projects/13546`.
- The repository includes `.bestpractices.json` so BadgeApp can prefill evidence-backed proposed answers.

To improve the check:

1. Open [BadgeApp project 13546](https://www.bestpractices.dev/en/projects/13546/passing).
2. Sign in with the GitHub account that owns or maintains this repository.
3. Review the proposed answers imported from `.bestpractices.json`.
4. Fill in any remaining self-certification criteria honestly.
5. Aim for at least the passing badge first.

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
