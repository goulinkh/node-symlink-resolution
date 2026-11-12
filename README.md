# Node.js module resolution with symbolic links

Node.js finds a package by looking for `node_modules/<name>` in each parent
directory, so packages installed side by side in `/usr/share/nodejs/<name>`
aren't found by default. These examples try ways around that, with upstream
Node.js and with Debian's build, which behaves differently.

```sh
./run.sh
```

It needs Linux with glibc 2.38 or later, and Python 3. The first run
downloads Node.js from nodejs.org and Debian 13's `nodejs` package into
`runtimes/`, about 60 MB, without installing anything.

```
02  Shared node_modules directory: one link for every package
    foo and bar are installed in /usr/share/nodejs, and bar loads foo.
    The link turns /usr/share/nodejs into /usr/share/node_modules.

                                    Upstream    │ Debian
                                    nodejs.org  │ debian-13
    bar: require('foo')             ✗ fails     │ ✓ works
    bar: import 'foo'               ✗ fails     │ ✓ works
    ── $ ln -s nodejs /usr/share/node_modules ───────────────
    bar: require('foo')             ✓ works     │ ✓ works
    bar: import 'foo'               ✓ works     │ ✓ works
    /opt/app: import 'foo'          ✗ fails     │ ✗ fails
```

## Examples

`foo` is a package, and `bar` loads it.

| Example | Makes `foo` visible with | Upstream | Debian |
| :- | :- | :- | :- |
| [01](01-node-path) | `NODE_PATH` | For `require()` only | For `require()` only, even without `NODE_PATH` |
| [02](02-shared-node-modules) | One link, `/usr/share/node_modules -> nodejs` | To code under `/usr/share` | The same, and the link is already there |
| [03](03-per-package-links) | A link in `bar/node_modules` | `bar` sees only what it links | `bar` sees every package |
| [04](04-application-links) | Links in `/app/node_modules` | `/app` finds `foo`, but `bar` doesn't | Both find it |

## Why Debian differs

Debian's `nodejs` package, which Ubuntu also uses:

- [patches Node.js](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/patches/dfsg/multilib_modules.patch)
  so that `require()`, but not `import`, also searches `/usr/share/nodejs`;
- [installs](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/nodejs.links)
  the link `/usr/share/node_modules -> nodejs` from example 02.

## Options

- `./run.sh -v` also prints each command and its output.
- `./run.sh nodejs.org-20 debian-13` compares the same Node.js version.
- `NO_COLOR=1 ./run.sh` turns colors off.
