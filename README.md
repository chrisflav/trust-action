# trust-action

Export a Lean library as a static [trust](https://github.com/chrisflav/trust)
index — the definitional dependency graph the trust web UI and CLI read — from
the library's own CI.

An index is only worth as much as it is current, and re-exporting one by hand is
a thing people stop doing. So the export belongs where the library is already
built:

```yaml
name: Trust index

on: [push, workflow_dispatch]

jobs:
  index:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - id: trust
        uses: chrisflav/trust-action@v1
        with:
          module: MyLibrary
      - uses: actions/upload-artifact@v4
        with:
          name: trust-index
          path: ${{ steps.trust.outputs.index-root }}
```

`module` is the only input you have to give: the root module whose import
closure is indexed. Everything else has a default — the index is named after the
repository, written to `trust-index/<name>/`, and the library is built first,
since the export reads `.olean` files and something has to have produced them.

## Which exporter runs

`trust` reads `.olean` files, and only the Lean that wrote one can read it. So a
release of `trust` is a release *for* a toolchain, and its tag is named after
the Lean it indexes: `v4.31.0`, `v4.32.0`. That makes the version you need one
you have already written down, in `lean-toolchain` — which is where this action
reads it, by default:

```
library/lean-toolchain    leanprover/lean4:v4.32.0
                                            ↓
chrisflav/trust           tag v4.32.0 → commit fc94653 → built, then run
```

The tag is resolved to the commit it points at, so a moved tag cannot be served
a stale cached binary, and a Lean nobody has released a trust for fails here,
naming the releases that exist:

```
::error::no trust release for Lean v4.99.0.  Released: v4.31.0 v4.32.0
```

**What this buys** is that bumping Lean is one edit rather than two: this
workflow keeps working. **What it costs** is that the exporter is whichever one
your toolchain maps to, so a Lean bump can bring a new index schema without
anyone choosing it — `meta.json` records `schemaVersion` for the reader who has
to notice. Pass `trust-ref` to pin an exporter exactly, or to run one that has
not been released:

```yaml
        with:
          module: MyLibrary
          trust-ref: v4.32.0     # or a branch, or a commit
```

## Inputs

| input | default | |
|---|---|---|
| `module` | — | **Required.** The root module to export. Its whole import closure is indexed. One module per run; a library with several unrelated roots wants several runs with different `index-name`s. |
| `index-name` | the repository's name | Output subdirectory, and the `?repo=` value the frontend selects the index by. |
| `output-dir` | `trust-index` | Where to write; the index lands in `<output-dir>/<index-name>`. Relative paths are from the workspace root, not from `working-directory`. |
| `working-directory` | `.` | The Lake package to export, for a package that is not at the repository root. |
| `with-bodies` | `true` | Export the edges that come from definition bodies. Without them definitions do not unfold in the UI. Proof terms are never exported either way. |
| `with-code` | `true` | Export rendered, clickable declaration source. The largest part of an index by far — but without it the UI shows names and no statements. |
| `with-hashes` | `false` | Record each declaration's semantic hash, so the index can be matched against trust certificates. A whole-environment pass, so off unless you need it. |
| `fast-prop` | `false` | Treat exactly the theorems as proofs instead of asking `MetaM`. Faster, and wrong for a definition whose type happens to be a `Prop`. |
| `module-filter` | every module | Restrict exported declarations to matching modules: a comma-separated list of `A.B.C`, `A.B.*`, `*`. Empty includes the dependencies' modules, which for a Mathlib-based library means Mathlib. |
| `marks` | `trust-marks.json` | Marks file to carry into the index, relative to `working-directory` — the *indexed* repository's file. |
| `rev` | read from git | Revision recorded in `meta.json`. Set it when the checkout is not the commit you mean, as for a pull request, whose checked-out commit is a merge that exists nowhere else. |
| `build-library` | `true` | Build the library before exporting it. Turn off only if an earlier step already did. |
| `trust-ref` | `auto` | Which `trust` to build: `auto` for the release matching your toolchain, or any ref in `chrisflav/trust`. |
| `require-matching-toolchain` | `true` | Fail when the library and `trust` name different Lean toolchains. Under `auto` they agree by construction; what this then catches is a release tagged for a Lean it was not built on. |
| `cache` | `true` | Cache the built `trust` binary between runs, keyed on a hash of its sources and the toolchain. |

## Outputs

| output | |
|---|---|
| `index-path` | The index directory — the one containing `meta.json`. |
| `index-root` | The directory holding it. This is what to upload and what to copy to `web/public/index`, since the frontend expects `<root>/<name>/meta.json`. |
| `index-name` | The name the index was written under, i.e. the `?repo=` value. |
| `rev` | The revision recorded in the index, as `meta.json` reports it. |
| `decl-count` | How many declarations the index holds. |
| `trust-bin` | The `trust` binary that was built, so a later step can run `trust check` or `trust cert issue` without building it twice. |

Every run also writes a summary — declarations, edges, revision, size — to the
job page.

## Gating a build on protected declarations

`trust check` reports protected declarations whose content has changed. Because
the binary is an output, that costs a step rather than a second build:

```yaml
      - id: trust
        uses: chrisflav/trust-action@v1
        with:
          module: MyLibrary
          with-hashes: 'true'
      - run: lake env ${{ steps.trust.outputs.trust-bin }} check MyLibrary
```

## Looking at the result

The frontend reads `<root>/<name>/meta.json` and `?repo=` selects the name, so
an artifact downloaded from CI is unpacked and served as it stands:

```bash
gh run download -n trust-index -D index
cp -r index/* /path/to/trust/web/public/index/
cd /path/to/trust/web && npm run dev     # http://localhost:5173/?repo=mylibrary
```

## Versioning

This action is versioned by its own inputs and outputs, not by Lean: `v1` is a
moving tag that follows the latest `v1.x`, and breaking changes to the inputs
above would be `v2`. The Lean version is `trust-ref`'s business, which is the
point of the two being separate repositories — a library bumping Lean should not
have to edit a `uses:` line that has nothing to say about Lean.

Every release is tested against every `trust` release, by building a throwaway
Lake package pinned to that Lean and indexing a module of Lean's own
(`.github/workflows/test.yml`).

## License

Apache 2.0, as `trust` is.
