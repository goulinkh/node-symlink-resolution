# Node.js module resolution with symbolic links

Small, runnable examples of how Node.js finds packages that are installed
side by side in one shared directory, such as `/usr/share/nodejs/<name>`,
instead of in a project's `node_modules` directory.

Each example contains a tiny fake filesystem under `root/`, so you don't need
root access and nothing gets installed on your system. The JavaScript files are
one or two lines each. You don't need to know JavaScript to follow along.

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

## The examples

| Example | How `foo` is made visible | CommonJS | ESM |
| :- | :- | :- | :- |
| [01-node-path](01-node-path) | `NODE_PATH` environment variable | Works | Fails |
| [02-shared-node-modules](02-shared-node-modules) | One link: `/usr/share/node_modules -> nodejs` | Works | Works |
| [03-per-package-links](03-per-package-links) | Each package links its own dependencies | Works | Works |
| [04-application-links](04-application-links) | An application links the packages it uses | Works | Works, with a catch |

In every example, `foo` is a package with no dependencies, and `bar` loads
`foo`.

## Running

You need Node.js and a POSIX shell, on Linux or macOS. The examples rely on
symbolic links stored in Git, which Windows doesn't check out by default.

Run everything:

```sh
./run-all.sh
```

Or run a single example:

```sh
./02-shared-node-modules/run.sh
```

Each step prints the command, its output (or the error message), and whether
it worked or failed as expected. The scripts exit with an error if any outcome
is different, so you can also use them to compare Node.js versions.

CI runs the examples on Node.js 20, 22, 24, and 26, and on Ubuntu's `nodejs`
package.

## Debian and Ubuntu's Node.js

The `nodejs` package in Debian and Ubuntu installs JavaScript packages in
`/usr/share/nodejs` and handles the problem in two ways:

1. It ships the link from [example 02](02-shared-node-modules):
   `/usr/share/node_modules -> nodejs`
   ([`debian/nodejs.links`](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/nodejs.links)).
2. It patches Node.js so that `require()` also searches `/usr/share/nodejs`
   from any location
   ([`dfsg/multilib_modules.patch`](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/patches/dfsg/multilib_modules.patch)).
   This works like a `NODE_PATH` that is always set, and like `NODE_PATH`, it
   only applies to CommonJS.

You can see the difference by printing the directories that `require()`
searches as a last resort:

```sh
node -p "require('module').globalPaths"
```

Node.js from nodejs.org or the snap ends with `<prefix>/lib/node`. Debian and
Ubuntu's ends with `/usr/lib/<architecture>/nodejs` and `/usr/share/nodejs`.

## Further reading

- [Node.js: CommonJS modules, "All together"](https://nodejs.org/api/modules.html#all-together):
  the exact `require()` lookup steps.
- [Node.js: Loading from the global folders](https://nodejs.org/api/modules.html#loading-from-the-global-folders):
  `NODE_PATH` and the global folders.
- [Node.js: ES modules, resolution algorithm](https://nodejs.org/api/esm.html#resolution-algorithm).
- [Node.js: `--preserve-symlinks`](https://nodejs.org/api/cli.html#--preserve-symlinks).
