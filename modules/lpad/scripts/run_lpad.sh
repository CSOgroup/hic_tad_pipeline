#!/usr/bin/env bash
set -euo pipefail
INDIR="${1:?Usage: run_lpad.sh <INDIR> [OUTDIR]}"
OUTDIR="${2:-lpad}"

mkdir -p "$OUTDIR"
shopt -s nullglob
for f in "$INDIR"/*.matrix; do
    stem=$(basename "$f" .matrix)
    python /opt/lpad/PLA_2.py -f "$f" -o "$OUTDIR/${stem}.out"
done
