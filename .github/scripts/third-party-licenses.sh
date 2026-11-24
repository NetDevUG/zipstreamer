#!/usr/bin/env bash
# Prints the license texts of all code compiled into the zipstreamer binary:
# the Go standard library/runtime and every vendored module. Binary
# distributions (release archives, Docker image) must include these notices
# (e.g. required by the BSD-3-Clause licenses of Go and gorilla).
#
# Usage: third-party-licenses.sh > THIRD_PARTY_LICENSES.md
set -euo pipefail

section() {
  printf '## %s\n\n```\n' "$1"
  cat "$2"
  printf '\n```\n\n'
}

echo "# Third-party licenses"
echo
echo "The zipstreamer binary includes the following third-party software."
echo

section "Go standard library and runtime ($(go env GOVERSION))" "$(go env GOROOT)/LICENSE"

found=0
while read -r module; do
  dir="vendor/$module"
  license=$(find "$dir" -maxdepth 1 -type f \( -iname 'licen[cs]e*' -o -iname 'copying*' \) | sort | head -1)
  if [ -z "$license" ]; then
    echo "error: no license file found for $module" >&2
    exit 1
  fi
  version=$(awk -v m="$module" '$1 == "#" && $2 == m { print $3 }' vendor/modules.txt)
  section "$module $version" "$license"
  found=$((found + 1))
done < <(awk '$1 == "#" && $2 !~ /^=>/ { print $2 }' vendor/modules.txt)

if [ "$found" -eq 0 ]; then
  echo "error: no vendored modules found, run 'go mod vendor' first" >&2
  exit 1
fi
