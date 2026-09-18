#!/bin/sh
# Regenerates Sources/CJanet from a Janet release tag.
# Usage: Scripts/vendor-janet.sh v1.42.1
set -eu
tag="${1:?usage: $0 <janet-git-tag>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git clone -q --depth 1 --branch "$tag" https://github.com/janet-lang/janet.git "$work/janet"
make -C "$work/janet" build/c/janet.c build/janet.h >/dev/null

dest="$root/Sources/CJanet"
mkdir -p "$dest/include"
cp "$work/janet/build/c/janet.c" "$dest/janet.c"
cp "$work/janet/build/janet.h" "$dest/include/janet.h"
cp "$work/janet/LICENSE" "$dest/LICENSE"
echo "$tag" > "$dest/VERSION"
echo "Vendored Janet $tag into $dest"
