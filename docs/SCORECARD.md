# OpenSSF Scorecard Notes

This repository publishes an OpenSSF Scorecard badge and runs Scorecard on a schedule. Some Scorecard checks are fully automated from repository settings and workflows. Others depend on external project metadata that cannot be fixed by editing source files alone.

## CII Best Practices

Scorecard's `CII-Best-Practices` check is based on the OpenSSF Best Practices BadgeApp. It looks up this repository's Git URL in the BadgeApp API and scores the project only after a BadgeApp project entry exists.

Current state:

- No BadgeApp entry exists yet for `https://github.com/martincalander/MacDragScroll`.
- Because there is no entry, Scorecard reports `no effort to earn an OpenSSF best practices badge detected`.

To improve the check:

1. Open [bestpractices.dev](https://www.bestpractices.dev/en).
2. Sign in with the GitHub account that owns or maintains this repository.
3. Create a new project for `https://github.com/martincalander/MacDragScroll`.
4. Fill in the self-certification criteria honestly.
5. Aim for at least the passing badge first.
6. After the project has a numeric BadgeApp id, add the generated badge to the README badge block:

```markdown
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/PROJECT_ID/badge)](https://www.bestpractices.dev/projects/PROJECT_ID)
```

Do not add a fake or query-only Best Practices badge before the BadgeApp project exists. A broken badge looks worse than a clear pending state, and it will not improve the Scorecard result.

## Contributors

Scorecard's `Contributors` check is based on recent commit authors and the `Company` field on their GitHub profiles. It is not based on a `CONTRIBUTORS` file, README text, or local git author names.

If Scorecard reports contributions from `soupmasters`, that value is coming from the maintainer's GitHub profile company field. To remove it:

1. Open [GitHub profile settings](https://github.com/settings/profile).
2. Clear or update the **Company** field.
3. Wait for Scorecard to refresh its cached report, or rerun the repository Scorecard workflow.

Using the GitHub CLI, the equivalent profile update is:

```sh
gh auth refresh -h github.com -s user
gh api --method PATCH user -f company=''
```

The extra `user` OAuth scope is required because this changes the authenticated GitHub account profile globally, not just this repository.
