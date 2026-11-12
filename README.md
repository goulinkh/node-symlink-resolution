# Node.js module resolution with symbolic links

Node.js finds a package by looking for `node_modules/<name>` in the directory
of the file that loads it, then in each parent directory. Packages installed
side by side in `/usr/share/nodejs/<name>`, as Debian does, are therefore
not found by default.

This case study tries four ways of making them visible, and compares how
upstream Node.js and Debian's build handle each one. The examples share this
layout, where `bar` depends on `foo`. Each uses part of it and adds its own
links:

```
/
├── usr/share/
│   ├── node_modules -> nodejs        link added by example 2
│   └── nodejs/
│       ├── foo/
│       └── bar/                      loads foo
│           └── node_modules/
│               └── foo -> ../../foo  link added by example 3
├── opt/app/                          loads foo (examples 1 and 2)
└── app/                              loads foo and bar (example 4)
    └── node_modules/                 links added by example 4
        ├── foo -> /usr/share/nodejs/foo
        └── bar -> /usr/share/nodejs/bar
```

When `bar` loads `foo`, Node.js looks in `bar/node_modules`,
`/usr/share/nodejs/node_modules`, `/usr/share/node_modules`,
`/usr/node_modules` and `/node_modules`, but never in `/usr/share/nodejs`
itself.

```sh
./run.sh
```

This runs every example with upstream Node.js and with Debian's, and prints
the results side by side, as in [`docs/output.txt`](docs/output.txt).

## The examples

1. **[`NODE_PATH`](01-node-path).** Point the `NODE_PATH` environment variable
   at `/usr/share/nodejs`. `require('foo')` then works from anywhere, but
   `import 'foo'` ignores `NODE_PATH`, so ES modules still can't load `foo`.

2. **[One shared link](02-shared-node-modules).** Add a single link,
   `/usr/share/node_modules -> nodejs`. Every file under `/usr/share` now
   finds every package, with both `require()` and `import`. Code elsewhere,
   such as an application in `/opt`, still doesn't.

3. **[Links in each package](03-per-package-links).** Each package links the
   packages it depends on into its own `node_modules`, for example
   `bar/node_modules/foo -> ../../foo`. Both `require()` and `import` work,
   and a package only sees the packages it links.

4. **[Links in an application](04-application-links).** An application in
   `/app` links the packages it uses into `/app/node_modules`. It finds them,
   but Node.js follows the link back to `/usr/share/nodejs/bar`, so `bar`
   can't find its own dependency, `foo`.

## Why Debian differs

Debian's `nodejs` package, which Ubuntu also uses, makes two changes:

- It [patches Node.js](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/patches/dfsg/multilib_modules.patch)
  so that `require()` also searches `/usr/share/nodejs`, as if `NODE_PATH`
  were always set. Like `NODE_PATH`, this doesn't help `import`.
- It [installs](https://salsa.debian.org/js-team/nodejs/-/blob/master/debian/nodejs.links)
  the link from example 2, `/usr/share/node_modules -> nodejs`.

As a result, several cases that fail upstream work on Debian. Because of the
shipped link, every package in `/usr/share/nodejs` can load every other one
there, linked or not, which hides missing links in examples 3 and 4.
