#!/usr/bin/env bash
set -euo pipefail
INDIR="${1:?Usage: run_ontad.sh <INDIR> [OUTDIR]}"
OUTDIR="${2:-ontad}"

mkdir -p "$OUTDIR"

ONTAD_BIN="/usr/local/bin/OnTAD"
[ -x "$ONTAD_BIN" ] || { echo "[ontad] ERROR: OnTAD binary not found"; exit 1; }

shopt -s nullglob
for f in "$INDIR"/*.matrix; do
    stem=$(basename "${f%.matrix}")
    echo "[ontad] Processing: $f"
    "$ONTAD_BIN" "$f" -o "$OUTDIR/$stem"
    echo "[ontad] Done: $OUTDIR/$stem"
done
