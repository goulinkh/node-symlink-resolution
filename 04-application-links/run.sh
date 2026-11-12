#!/bin/sh
# An application outside usr/share links the packages it uses into its own
# node_modules directory.
here=$(dirname "$0")
. "$here/../lib.sh"
cd "$here/root" || exit 1

# foo has no dependencies, so the link is enough.
check works 'node app/uses-foo.mjs'

# bar imports foo. Node.js follows the app/node_modules/bar link to the real
# directory, usr/share/nodejs/bar, and searches for foo from there. No
# node_modules directory above usr/share/nodejs/bar has foo, so this fails,
# even though app/node_modules/foo exists.
check fails 'node app/uses-bar.mjs'

# --preserve-symlinks makes Node.js search from the link's location,
# app/node_modules/bar, instead. The search then reaches app/node_modules/foo.
check works 'node --preserve-symlinks app/uses-bar.mjs'

finish
