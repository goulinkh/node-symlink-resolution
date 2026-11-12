#!/bin/sh
# Downloads the latest Node.js 24 release from nodejs.org into DIR, after
# checking it against the published checksums.
#
# Usage: lib/download-nodejs-org.sh DIR

set -eu

dir=$1
major=24
base=https://nodejs.org/dist/latest-v$major.x

case $(uname -s) in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) echo "No nodejs.org download for $(uname -s)." >&2; exit 1 ;;
esac
case $(uname -m) in
  x86_64 | amd64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "No nodejs.org download for $(uname -m)." >&2; exit 1 ;;
esac

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  else
    wget -qO- "$1"
  fi
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

# Each line of SHASUMS256.txt is "<checksum>  <file name>".
line=$(fetch "$base/SHASUMS256.txt" | grep -- "-$os-$arch\.tar\.xz\$" | head -n 1)
checksum=${line%% *}
file=${line##* }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $file from nodejs.org..." >&2
fetch "$base/$file" >"$tmp/$file"
if [ "$(sha256 "$tmp/$file")" != "$checksum" ]; then
  echo "The checksum of $file doesn't match SHASUMS256.txt." >&2
  exit 1
fi

mkdir "$tmp/node"
tar -xJf "$tmp/$file" -C "$tmp/node" --strip-components=1
rm -rf "$dir"
mkdir -p "$(dirname "$dir")"
mv "$tmp/node" "$dir"
