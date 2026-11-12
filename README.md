# Node.js module resolution with symbolic links

Small, runnable examples of how Node.js finds packages that are installed
side by side in one shared directory, `/usr/share/nodejs/<name>`, instead of
in a project's `node_modules` directory.

Each example runs with several Node.js runtimes. Upstream Node.js and Debian's
build (also used by Ubuntu) behave differently here, and the results are
printed side by side so you can see where.

The JavaScript files are one or two lines each. You don't need to know
JavaScript to follow along.

## Quick start

```sh
./run.sh
```

This needs Linux or macOS, `curl` or `wget`, and `tar` with xz support. The
first run downloads Node.js from nodejs.org into `runtimes/`. Nothing is
installed on your system, and each example runs in a fresh temporary
directory.

To compare with Debian's Node.js, run it on Debian or Ubuntu with the `nodejs`
package installed:

```sh
sudo apt install nodejs
```

Part of the output:

```
01  NODE_PATH: require() honors it, import ignores it
    foo is installed in /usr/share/nodejs. The code that loads it is in
    /opt/app, outside /usr/share.

                                    Upstream    | Debian
                                    nodejs.org  | ubuntu-26.04
    require('foo')                  fails       | works
    require('foo') with NODE_PATH   works       | works
    import 'foo' with NODE_PATH     fails       | fails

    Every runtime finds foo through NODE_PATH, but only for require().
    Debian and Ubuntu's Node.js finds foo even without NODE_PATH: it is
    patched to search /usr/share/nodejs. That patch doesn't help import
    either.
```

The complete output is in [`docs/output.txt`](docs/output.txt).

## Background

When code loads a package by name, for example `require('foo')` or
`import foo from 'foo'`, Node.js looks for a directory called
`node_modules/foo`. It starts in the directory of the file doing the loading
and walks up through every parent directory to the filesystem root.

For a file at `/usr/share/nodejs/bar/index.js`, Node.js tries:

```
/usr/share/nodejs/bar/node_modules/foo
/usr/share/nodejs/node_modules/foo
/usr/share/node_modules/foo
/usr/node_modules/foo
/node_modules/foo
```

None of these is `/usr/share/nodejs/foo`, so a package installed there is not
found by default.

Node.js has two ways of loading code, and they follow slightly different rules:

| | CommonJS | ES modules (ESM) |
| :- | :- | :- |
| Loads a package with | `require('foo')` | `import foo from 'foo'` |
| File extension used here | `.cjs` | `.mjs` |
| Searches parent `node_modules` directories | Yes | Yes |
| Searches `NODE_PATH` directories | Yes | **No** |
| Searches the global folders (see below) | Yes | **No** |

## The runtimes

By default, `./run.sh` compares two runtimes:

| Runtime | Group | Where `node` comes from |
| :- | :- | :- |
| `nodejs.org` | Upstream | The official build of Node.js 24, downloaded from nodejs.org |
| `/usr/bin/node` | Debian | Your system's `nodejs` package, if it is installed. The column is named after your system, for example `ubuntu-26.04`. |

`./run.sh` tells the two groups apart by asking each `node` for a build
setting that only Debian's patch adds.

Debian's `nodejs` package changes two things:

1. **A patch to Node.js.** When `require()` finds nothing in any
   `node_modules` directory, it tries a few *global folders* as a last
   resort. Upstream, the last one is `<prefix>/lib/node`, where `<prefix>` is
   the directory above the `node` binary. Debian
   [patches Node.js](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/patches/dfsg/multilib_modules.patch)
   to search `<prefix>/lib/<architecture>/nodejs` and
   `<prefix>/share/nodejs` instead, which is `/usr/share/nodejs` for
   `/usr/bin/node`. This works like a `NODE_PATH=/usr/share/nodejs` that is
   always set, and like `NODE_PATH`, it only applies to `require()`.
2. **A symbolic link.** The package
   [ships](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/nodejs.links)
   `/usr/share/node_modules -> nodejs`, the link from
   [example 02](02-shared-node-modules). This is what makes `import` work
   between packages in `/usr/share/nodejs`.

`./run.sh` starts by showing the global folders of each runtime:

```
  Runtime       Group     Node.js    Binary
  nodejs.org    Upstream  v24.22.3   runtimes/nodejs.org/bin/node
  ubuntu-26.04  Debian    v22.22.1   /usr/bin/node

  Folders that require() searches as a last resort:

  nodejs.org    runtimes/nodejs.org/lib/node
  ubuntu-26.04  $ROOT/usr/lib/x86_64-linux-gnu/nodejs
                $ROOT/usr/share/nodejs
```

On your own machine, print them with:

```sh
node -p "require('module').globalPaths"
```

The first two entries, `~/.node_modules` and `~/.node_libraries`, are the
same everywhere.

### How the examples stand in for `/`

The examples need files in places like `/usr/share/nodejs`, which you can't
write to without root access. Instead, each example gets a fresh temporary
directory, `$ROOT`, which stands in for `/`:

- The example's [`files/`](01-node-path/files) are copied into `$ROOT`.
- The runtime's `node` is placed in `$ROOT/usr/bin/node`. Because Debian's
  global folders are relative to the `node` binary, they become
  `$ROOT/usr/share/nodejs`, the same as `/usr/share/nodejs` for an installed
  `/usr/bin/node`. For this to work, Debian's `node` has to be a real file in
  `$ROOT/usr/bin`: Node.js follows a symbolic link back to `/usr/bin`, and
  would search `/usr/share/nodejs` instead.
- For Debian runtimes, `$ROOT` also gets the `usr/share/node_modules -> nodejs`
  link, the way the `nodejs` package installs it.

Debian's `node` can't be downloaded like the nodejs.org one: it loads some of
its built-in modules from fixed paths in your system's `/usr/share/nodejs`,
and stops at startup if they are missing. That's why the Debian column comes
from your system's `nodejs` package.

## The examples

In every example, `foo` is a package with no dependencies, and `bar` loads
`foo`.

| Example | How `foo` is made visible | Upstream | Debian |
| :- | :- | :- | :- |
| [01-node-path](01-node-path) | `NODE_PATH` environment variable | `require()` only | `require()` only, even without `NODE_PATH` |
| [02-shared-node-modules](02-shared-node-modules) | One link: `/usr/share/node_modules -> nodejs` | Both, from `/usr/share` only | Both, from `/usr/share` only; the link already exists |
| [03-per-package-links](03-per-package-links) | Each package links its own dependencies | Both; only linked packages are visible | Both; every package is visible |
| [04-application-links](04-application-links) | An application links the packages it uses | Linked packages can't find their own dependencies | Works, through the shipped link |

## Running

```
./run.sh [-v] [RUNTIME...]
```

- `-v` also prints each command and its output, or the error message.
- `RUNTIME` is `nodejs.org`, or the path of any other `node` binary, optionally
  with a name: `NAME=PATH`. For example, to add a Node.js installed with nvm:

  ```sh
  ./run.sh nodejs.org nvm=$HOME/.nvm/versions/node/v22.22.1/bin/node /usr/bin/node
  ```

- `NO_COLOR=1` turns colors off.

`./run.sh` exits with an error, and marks the results with `!`, if any
outcome differs from what the example expects. Each runtime's group decides
what to expect, so you can use it to check other Node.js builds.

### Exploring by hand

Make a root directory, copy an example's files into it, and run `node` on
them:

```sh
ROOT=$(mktemp -d)
cp -R 02-shared-node-modules/files/. "$ROOT"
runtimes/nodejs.org/bin/node "$ROOT/usr/share/nodejs/bar/index.mjs"
```

This fails with `Cannot find package 'foo'`. Add the link from example 02 and
try again:

```sh
ln -s nodejs "$ROOT/usr/share/node_modules"
runtimes/nodejs.org/bin/node "$ROOT/usr/share/nodejs/bar/index.mjs"
```

To try Debian's `node`, copy it into the root, so that its global folders
point inside the root, and check them:

```sh
mkdir -p "$ROOT/usr/bin"
cp /usr/bin/node "$ROOT/usr/bin/node"
"$ROOT/usr/bin/node" -p "require('module').globalPaths"
```

### How an example is written

Each example directory has:

- `files/`: copied into `$ROOT` before the checks run.
- `checks.sh`: the checks, written with five commands:
  - `title` and `intro`: the heading and the description.
  - `step LABEL COMMAND`: changes the files, for example by creating a link.
  - `check LABEL EXPECTED COMMAND`: runs `COMMAND` and records whether it
    `works` or `fails`. `EXPECTED` is either one outcome for every runtime, or
    one per group, such as `'debian=works upstream=fails'`.
  - `note`: the explanation printed after the results.
- `README.md`: the layout, the results, and the trade-offs.

## Further reading

- [Node.js: CommonJS modules, "All together"](https://nodejs.org/api/modules.html#all-together):
  the exact `require()` lookup steps.
- [Node.js: Loading from the global folders](https://nodejs.org/api/modules.html#loading-from-the-global-folders):
  `NODE_PATH` and the global folders.
- [Node.js: ES modules, resolution algorithm](https://nodejs.org/api/esm.html#resolution-algorithm).
- [Node.js: `--preserve-symlinks`](https://nodejs.org/api/cli.html#--preserve-symlinks).
- [nodejs/node#22745](https://github.com/nodejs/node/issues/22745): Debian's
  request to search these directories upstream, closed in 2018.
