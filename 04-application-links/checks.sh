# Read by ../lib/main.sh and ../lib/run-checks.sh. The commands used here are
# explained in ../README.md, under "How an example is written".

title 'Application links: an application links the packages it uses'
intro 'foo and bar are installed in /usr/share/nodejs, and bar loads foo.'
intro 'An application in /app links both into /app/node_modules.'

step 'ln -s /usr/share/nodejs/foo /usr/share/nodejs/bar /app/node_modules/' \
  'mkdir -p $ROOT/app/node_modules && ln -s $ROOT/usr/share/nodejs/foo $ROOT/usr/share/nodejs/bar $ROOT/app/node_modules/'

check "app: import 'foo'" works \
  'node $ROOT/app/uses-foo.mjs'
check "app: import 'bar' (needs foo)" 'debian=works upstream=fails' \
  'node $ROOT/app/uses-bar.mjs'
check 'same, with --preserve-symlinks' works \
  'node --preserve-symlinks $ROOT/app/uses-bar.mjs'

note "Node.js follows /app/node_modules/bar to /usr/share/nodejs/bar, and"
note "looks for bar's own dependencies from there, not from /app. Upstream"
note "Node.js doesn't find foo from there, unless --preserve-symlinks keeps"
note "the search in /app. On Debian and Ubuntu, the shipped"
note "/usr/share/node_modules link finds it."
