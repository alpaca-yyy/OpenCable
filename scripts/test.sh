#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
regression_dir=$(mktemp -d "${TMPDIR:-/tmp}/opencable-regression.XXXXXX")
trap 'rm -rf "$regression_dir"' EXIT HUP INT TERM
xcrun swiftc -parse-as-library "$project_dir"/Sources/OpenCableCore/*.swift "$project_dir/scripts/regression.swift" -o "$regression_dir/regression"
"$regression_dir/regression"
