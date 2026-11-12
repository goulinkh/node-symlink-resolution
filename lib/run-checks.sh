#!/bin/sh
# Runs one example's checks. Started by ../run.sh, which sets ROOT to a fresh
# root directory for the example and puts $ROOT/usr/bin/node first on PATH.
#
#   run-checks.sh about     prints the Node.js version, then the folders that
#                           require() searches as a last resort
#   run-checks.sh EXAMPLE   prints one line per check: "works" or "fails", a
#                           tab, and the first line of output or the error

# Shows paths as $ROOT/... and relative to this repository.
short_paths() {
  sed -e "s|$ROOT|\$ROOT|g" -e "s|$PWD/||g"
}

if [ "$1" = about ]; then
  node --version
  node -p "require('module').globalPaths.filter(p => !p.includes('.node_')).join(' ')" | short_paths
  exit
fi

title() { :; }
intro() { :; }
note() { :; }

step() {
  sh -c "$2" >/dev/null 2>&1 || echo "step failed: $1" >&2
}

check() {
  if output=$(sh -c "$3" 2>&1); then
    printf 'works\t%s\n' "$(printf '%s\n' "$output" | head -n 1 | short_paths)"
  else
    line=$(printf '%s\n' "$output" | grep -m 1 '^Error' || printf '%s\n' "$output" | head -n 1)
    printf 'fails\t%s\n' "$(printf '%s\n' "$line" | short_paths)"
  fi
}

. "./$1/checks.sh"
