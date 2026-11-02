#!/usr/bin/env bash
set -euo pipefail
INDIR="${1:?Usage: run_topdom.sh <INDIR> [WINDOW_SIZE] [OUTDIR]}"
WINDOW="${2:-5}"
OUTDIR="${3:-topdom}"

mkdir -p "$OUTDIR"
shopt -s nullglob
for f in "$INDIR"/*.matrix; do
    Rscript /scripts/run_topdom.R "$f" "$WINDOW" "$OUTDIR"
done
