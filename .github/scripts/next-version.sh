#!/usr/bin/env bash
# Prints the next semantic version (vMAJOR.MINOR.PATCH) for a release, or
# nothing if there are no commits since the last release tag.
#
# Usage: next-version.sh <auto|patch|minor|major> <initial-version>
#
# auto derives the bump from Conventional Commit messages since the last tag:
#   "type!: ..." or "BREAKING CHANGE" -> major
#   "feat: ..."                       -> minor
#   anything else                     -> patch
# If no release tag exists yet, <initial-version> is used as is.
set -euo pipefail

bump="${1:-auto}"
initial="${2:?initial version required}"

last=$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' --exclude '*-*' 2>/dev/null || true)
if [ -z "$last" ]; then
  echo "$initial"
  exit 0
fi

if [ -z "$(git rev-list "$last..HEAD")" ]; then
  echo "No commits since $last, nothing to release." >&2
  exit 0
fi

if [ "$bump" = auto ]; then
  log=$(git log --format='%s%n%b' "$last..HEAD")
  if grep -qE '^[a-zA-Z]+(\([^)]*\))?!:|^BREAKING[ -]CHANGE' <<<"$log"; then
    bump=major
  elif grep -qE '^feat(\([^)]*\))?:' <<<"$log"; then
    bump=minor
  else
    bump=patch
  fi
fi

version="${last#v}"
version="${version%%[-+]*}"
IFS=. read -r major minor patch <<<"$version"
case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  *) echo "invalid bump: $bump" >&2; exit 1 ;;
esac
echo "v$major.$minor.$patch"
