#!/usr/bin/env bash
set -euo pipefail
RESULTS_DIR="${1:?Usage: run_clean_results.sh <RESULTS_DIR> <RESOLUTION> [OUTDIR] [CALLERS] [CHROMS]}"
RESOLUTION="${2:?Error: RESOLUTION is required}"
OUTDIR="${3:-03_clean_results}"
CALLERS="${4:-}"
CHROMS="${5:-}"

mkdir -p "$OUTDIR"
echo "[clean] Cleaning and combining TAD results..."
Rscript /scripts/clean_tad_results.R \
    "$RESULTS_DIR" "$RESOLUTION" "$OUTDIR" "$CALLERS" "$CHROMS"
echo "[clean] Done. Results in $OUTDIR"
