#!/usr/bin/env bash
set -euo pipefail
INPUT_TSV="${1:?Usage: run_consensus_tads.sh <INPUT_TSV> [OUTDIR] [THRESHOLD] [STEP] [WORKERS]}"
OUTDIR="${2:-04_consensus_tads}"
THRESHOLD="${3:-0}"
STEP="${4:--0.05}"
WORKERS="${5:-1}"

mkdir -p "$OUTDIR"
echo "[consensus] Computing consensus TADs..."
Rscript /scripts/run_consensus_tads.R \
    "$INPUT_TSV" "$OUTDIR" "$THRESHOLD" "$STEP" "$WORKERS"
echo "[consensus] Done. Results in $OUTDIR"
