#!/usr/bin/env bash
#
# Write a throwaway Lake package pinned to a given Lean, for the action to be
# pointed at.  This repository holds no Lean code — it is a GitHub action — so
# every test has to bring its own library, and the toolchain it pins is the
# input under test: `trust-ref: auto` reads it to decide which exporter to run.
#
# The package needs no content.  What gets exported is a module of Lean's own,
# which `lake env` puts on LEAN_PATH by virtue of the toolchain alone, so what
# has to exist is a toolchain, a lakefile, and a manifest.
#
# The manifest is written by hand because `lake update` would generate it and
# lake is not installed yet — the action installs the toolchain itself, later,
# via lean-action, which in turn refuses a package that has no manifest.  A
# package with no dependencies has an empty one.
#
# Usage: scratch-package.sh <directory> <toolchain>
set -euo pipefail

DIR="${1:?usage: scratch-package.sh <directory> <toolchain>}"
TOOLCHAIN="${2:?usage: scratch-package.sh <directory> <toolchain>}"

mkdir -p "$DIR"
printf 'leanprover/lean4:%s\n' "$TOOLCHAIN" > "$DIR/lean-toolchain"

cat > "$DIR/lakefile.toml" <<'EOF'
name = "library"
version = "0.1.0"
defaultTargets = ["Library"]

[[lean_lib]]
name = "Library"
EOF

cat > "$DIR/lake-manifest.json" <<'EOF'
{"version": "1.2.0",
 "packagesDir": ".lake/packages",
 "packages": [],
 "name": "library",
 "lakeDir": ".lake"}
EOF

printf 'def hello : String := "world"\n' > "$DIR/Library.lean"

echo "wrote a Lake package in '$DIR' pinned to $TOOLCHAIN"
