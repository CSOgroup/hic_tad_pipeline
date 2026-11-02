#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:?Usage: hic2cool.sh <INPUT> <RESOLUTION> <OUT> [NPROC]}"
RESOLUTION="${2:?RESOLUTION is required (e.g. 25000)}"
OUT="${3:?OUT path is required}"
NPROC="${4:-4}"

CONVERT_THREADS=$(( NPROC < 2 ? 2 : NPROC ))

if hictk convert -r "$RESOLUTION" --threads "$CONVERT_THREADS" --force "$INPUT" "$OUT"; then
    echo "[hic2cool] converted ${INPUT} @ ${RESOLUTION}bp → $OUT"
    exit 0
fi

echo "[hic2cool] hictk convert failed, retrying with zero-count pixel filtering" >&2
bash "$(dirname "$0")/hictk_filter_zero_pixels.sh" "$INPUT" "$RESOLUTION" "$OUT" "$CONVERT_THREADS"
echo "[hic2cool] converted ${INPUT} @ ${RESOLUTION}bp → $OUT (dropped zero-count pixels)"
