#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/publish-release.sh <version>

Example:
  scripts/publish-release.sh 1.0.0

This command verifies release readiness, creates tag v<version>, and pushes main
plus the tag. The GitHub Release workflow applies the stable project signing
identity, packages the app, generates the Sparkle appcast, and publishes release
artifacts from that tag.
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

version="${1#v}"
tag="v${version}"

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use SemVer, for example 1.0.0. Got: $version" >&2
  exit 64
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git worktree" >&2
  exit 69
fi

branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
  echo "Release must be published from main. Current branch: ${branch:-detached}" >&2
  exit 65
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree has uncommitted changes. Commit or stash them before publishing." >&2
  git status --short >&2
  exit 65
fi

git fetch origin main --tags

local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse origin/main)"
if [[ "$local_head" != "$remote_head" ]]; then
  echo "Local main is not equal to origin/main. Push or pull before publishing." >&2
  echo "Local:  $local_head" >&2
  echo "Remote: $remote_head" >&2
  exit 65
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Local tag already exists: $tag" >&2
  exit 65
fi

if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  echo "Remote tag already exists: $tag" >&2
  exit 65
fi

bash -n scripts/*.sh
scripts/check-release-readiness.sh "$version"

git tag -a "$tag" -m "Mac Drag Scroll $version"
git push origin main "$tag"

echo "Published $tag. Watch the Release workflow:"
echo "  gh run list --repo martincalander/MacDragScroll --workflow Release --limit 1"
