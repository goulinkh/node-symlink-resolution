#!/bin/sh
# One link, usr/share/node_modules -> nodejs, exposes every package to
# require() and import, but only for files under usr/share.
here=$(dirname "$0")
. "$here/../lib.sh"
cd "$here/root" || exit 1

# Searching upwards from usr/share/nodejs/bar reaches usr/share/node_modules.
check works 'node usr/share/nodejs/bar/index.cjs'
check works 'node usr/share/nodejs/bar/index.mjs'

# Searching upwards from home/user never reaches usr/share/node_modules.
check fails 'node home/user/script.mjs'

finish
