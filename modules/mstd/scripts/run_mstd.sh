#!/usr/bin/env bash
set -euo pipefail
INDIR="${1:?Usage: run_mstd.sh <INDIR> [OUTDIR]}"
OUTDIR="${2:-mstd}"

mkdir -p "$OUTDIR"
shopt -s nullglob
for f in "$INDIR"/*.matrix; do
    python3 /scripts/run_mstd.py "$f" "$OUTDIR"
done
