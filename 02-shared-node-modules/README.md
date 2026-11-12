# 02: Shared `node_modules` directory

A single symbolic link turns the whole shared directory into a `node_modules`
directory:

```sh
ln -s nodejs /usr/share/node_modules
```

Any file under `/usr/share` now finds every package in `/usr/share/nodejs`,
with both `require` and `import`.

Debian and Ubuntu's `nodejs` package ships this exact link.

## Layout

```
root/
├── usr/share/
│   ├── nodejs/
│   │   ├── foo/
│   │   │   ├── package.json
│   │   │   └── index.js       module.exports = 'hello from foo';
│   │   └── bar/
│   │       ├── index.cjs      const foo = require('foo');
│   │       └── index.mjs      import foo from 'foo';
│   └── node_modules -> nodejs
└── home/user/
    └── script.mjs             import foo from 'foo';
```

## Run

```sh
./run.sh
```

```
$ node usr/share/nodejs/bar/index.cjs
  bar (CommonJS) loaded: hello from foo
  => works, as expected

$ node usr/share/nodejs/bar/index.mjs
  bar (ESM) loaded: hello from foo
  => works, as expected

$ node home/user/script.mjs
  Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'foo' imported from .../home/user/script.mjs
  => fails, as expected
```

## What it shows

- From `usr/share/nodejs/bar`, the upward search reaches
  `usr/share/node_modules/foo`, which the link turns into `usr/share/nodejs/foo`.
  This works for both CommonJS and ESM, with no environment variable.
- From `home/user`, the upward search never passes through `usr/share`, so
  `foo` is not found. The link only helps files that live under `usr/share`.

## Trade-offs

- One link covers every package, including packages added later.
- Every package sees every other package, not only the ones it depends on.
- All packages share one name space, so only one version of `foo` can live
  there.
- Code elsewhere on the system (home directories, `/opt`, containers) needs
  its own way to find the packages.
