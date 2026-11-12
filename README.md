# Node.js module resolution with symbolic links

Small, runnable examples of how Node.js finds packages that are installed
side by side in one shared directory, `/usr/share/nodejs/<name>`, instead of
in a project's `node_modules` directory.

Each example runs on several Node.js runtimes. Upstream Node.js and Debian's
build (also used by Ubuntu) behave differently here, and the results are
printed side by side so you can see where.

The JavaScript files are one or two lines each. You don't need to know
JavaScript to follow along.

## Quick start

You need [Podman](https://podman.io) or [Docker](https://www.docker.com).

```sh
./run.sh
```

Each example runs in a fresh container for each runtime, so nothing is
installed on your machine. Part of the output:

```
01  NODE_PATH: require() honors it, import ignores it
    foo is installed in /usr/share/nodejs. The code that loads it is in
    /opt/app, outside /usr/share.

                                    Upstream               | Debian
                                    nodejs.org  fedora-43  | debian-13  ubuntu-26.04
    require('foo')                  fails       fails      | works      works
    require('foo') with NODE_PATH   works       works      | works      works
    import 'foo' with NODE_PATH     fails       fails      | fails      fails

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

| Runtime | Group | Where `node` comes from |
| :- | :- | :- |
| `nodejs.org` | Upstream | The official `node` image: the unmodified build from nodejs.org |
| `fedora-43` | Upstream | Fedora's `nodejs` package |
| `debian-13` | Debian | Debian's `nodejs` package |
| `ubuntu-26.04` | Debian | Ubuntu's `nodejs` package, which Ubuntu takes from Debian |

Each one is defined by a small file in [`runtimes/`](runtimes).

Debian's `nodejs` package changes two things:

1. **A patch to Node.js.** When `require()` finds nothing in any
   `node_modules` directory, it tries a few *global folders* as a last
   resort. Upstream, the last one is `<prefix>/lib/node`, where `<prefix>` is
   the directory above the `node` binary. Debian
   [patches Node.js](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/patches/dfsg/multilib_modules.patch)
   to search `/usr/lib/<architecture>/nodejs` and `/usr/share/nodejs`
   instead. This works like a `NODE_PATH=/usr/share/nodejs` that is always
   set, and like `NODE_PATH`, it only applies to `require()`.
2. **A symbolic link.** The package
   [ships](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/nodejs.links)
   `/usr/share/node_modules -> nodejs`, the link from
   [example 02](02-shared-node-modules). This is what makes `import` work
   between packages in `/usr/share/nodejs`.

`./run.sh` starts by showing both for every runtime:

```
  Runtime        Group     Node.js    /usr/share/node_modules  require() also searches
  nodejs.org     Upstream  v24.22.3   none                     /usr/local/lib/node
  fedora-43      Upstream  v22.22.2   none                     /usr/lib/node
  debian-13      Debian    v20.19.2   -> nodejs                /usr/lib/x86_64-linux-gnu/nodejs
                                                               /usr/share/nodejs
  ubuntu-26.04   Debian    v22.22.1   -> nodejs                /usr/lib/x86_64-linux-gnu/nodejs
                                                               /usr/share/nodejs
```

On your own machine, print the global folders with:

```sh
node -p "require('module').globalPaths"
```

The first two entries, `~/.node_modules` and `~/.node_libraries`, are the
same everywhere. The `node` snap behaves like the upstream build: its list
ends with the `lib/node` directory inside the snap.

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
- `RUNTIME` picks runtimes by name, for example `./run.sh nodejs.org ubuntu-26.04`.
- `CONTAINER_ENGINE=docker` picks the container engine, if you have both.
- `NO_COLOR=1` turns colors off.

`./run.sh` exits with an error, and marks the results with `!`, if any
outcome differs from what the example expects. You can use it to check new
Node.js versions: add a file in `runtimes/` and pass its name.

### Exploring by hand

After a first `./run.sh`, the images are on your machine. Start a shell in
one and copy an example's files into `/`:

```sh
docker run --rm -it -v "$PWD:/examples:ro" node-resolution-examples:ubuntu-26.04 bash
cp -R /examples/02-shared-node-modules/files/. /
node /usr/share/nodejs/bar/index.mjs
```

Use `podman` instead of `docker` if that's what you have.

### How an example is written

Each example directory has:

- `files/`: copied into `/` inside the container before the checks run.
- `checks.sh`: the checks, written with five commands:
  - `title` and `intro`: the heading and the description.
  - `step LABEL COMMAND`: changes the system, for example by creating a link.
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
