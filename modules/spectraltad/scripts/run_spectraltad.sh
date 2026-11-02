#!/usr/bin/env bash
set -euo pipefail
INDIR="${1:?Usage: run_spectraltad.sh <INDIR> [OUTDIR]}"
OUTDIR="${2:-spectraltad}"

mkdir -p "$OUTDIR"
shopt -s nullglob
for f in "$INDIR"/*.matrix; do
    stem=$(basename "${f%.matrix}")
    chrom="${stem%_*}"
    resolution="${stem##*_}"
    echo "[spectraltad] Processing: $f  chr=$chrom  res=$resolution"
    Rscript /scripts/run_spectraltad.R "$f" "$chrom" "$resolution" "$OUTDIR"
done
