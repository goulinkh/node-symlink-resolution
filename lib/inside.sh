#!/bin/sh
# Runs inside a container, started by ../run.sh. Not meant to be run on your
# machine: it copies files into /.
#
#   inside.sh about      prints the Node.js version, the target of
#                        /usr/share/node_modules, and the global folders
#   inside.sh EXAMPLE    copies EXAMPLE/files into / and prints one result
#                        line per check: "works" or "fails", a tab, and the
#                        first line of output (or the error line)

if [ "$1" = about ]; then
  node --version
  readlink /usr/share/node_modules || echo none
  node -p "require('module').globalPaths.filter(p => !p.includes('.node_')).join(' ')"
  exit
fi

example=$1
cp -R "$example/files/." /

title() { :; }
intro() { :; }
note() { :; }

step() {
  sh -c "$2" >/dev/null 2>&1 || echo "step failed: $1" >&2
}

check() {
  if output=$(sh -c "$3" 2>&1); then
    printf 'works\t%s\n' "$(printf '%s\n' "$output" | head -n 1)"
  else
    line=$(printf '%s\n' "$output" | grep -m 1 '^Error' || printf '%s\n' "$output" | head -n 1)
    printf 'fails\t%s\n' "$line"
  fi
}

. "$example/checks.sh"
