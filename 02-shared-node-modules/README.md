# 02: Shared `node_modules` directory

One symbolic link, `/usr/share/node_modules -> nodejs`, gives the shared
directory the name that Node.js looks for. A file anywhere under `/usr/share`
then finds every package in `/usr/share/nodejs` through the normal upward
search.

```sh
ln -s nodejs /usr/share/node_modules
```

## Layout

The contents of [`files/`](files), as installed on a system, plus the link:

```
/
├── opt/app/
│   └── index.mjs      import foo from 'foo';
└── usr/share/
    ├── node_modules -> nodejs        (created by the step)
    └── nodejs/
        ├── foo/
        │   ├── package.json
        │   └── index.js   module.exports = 'hello from foo';
        └── bar/
            ├── index.cjs  const foo = require('foo');
            └── index.mjs  import foo from 'foo';
```

## Results

`./run.sh` copies [`files/`](files) into a fresh directory, `$ROOT`, which
stands in for `/`, and runs the commands there:

| Command | nodejs.org | ubuntu-26.04 |
| :- | :- | :- |
| `node $ROOT/usr/share/nodejs/bar/index.cjs` | fails | works |
| `node $ROOT/usr/share/nodejs/bar/index.mjs` | fails | works |
| *Step: `ln -s nodejs $ROOT/usr/share/node_modules`* | | |
| `node $ROOT/usr/share/nodejs/bar/index.cjs` | works | works |
| `node $ROOT/usr/share/nodejs/bar/index.mjs` | works | works |
| `node $ROOT/opt/app/index.mjs` | fails | fails |

## What it shows

- From `/usr/share/nodejs/bar`, the upward search reaches
  `/usr/share/node_modules/foo`, which the link turns into
  `/usr/share/nodejs/foo`. This works for both `require()` and `import`, with
  no environment variable, on every runtime.
- From `/opt/app`, the upward search never passes through `/usr/share`, so
  `import` doesn't find `foo`. The link only helps files under `/usr/share`.
- Debian and Ubuntu's `nodejs` package already ships this link, which is why
  `bar` finds `foo` there before the step. `./run.sh` adds the link to the
  root of Debian runtimes, the way the package installs it in `/usr/share`.

## Trade-offs

- One link covers every package, including packages added later.
- Every package sees every other package, not only the ones it depends on.
- All packages share one name space, so only one version of `foo` can live
  there.
- Code elsewhere on the system, such as home directories or `/opt`, needs its
  own way to find the packages.
- The link belongs to the shared directory, not to any package. Something has
  to own it: on Debian and Ubuntu, that's the `nodejs` package.
