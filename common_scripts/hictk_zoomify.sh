#!/usr/bin/env bash
set -euo pipefail

SRC_URI="${1:?Usage: hictk_zoomify.sh <SRC_URI> <SRC_RESOLUTION> <TARGET_RESOLUTION> <OUT> [THREADS]}"
SRC_RESOLUTION="${2:?SRC_RESOLUTION is required (e.g. 25000)}"
TARGET_RESOLUTION="${3:?TARGET_RESOLUTION is required (e.g. 50000)}"
OUT="${4:?OUT path is required}"
THREADS="${5:-4}"

if ! hictk zoomify "$SRC_URI" "$OUT" \
    --resolutions "$TARGET_RESOLUTION" \
    --no-copy-base-resolution \
    --threads "$THREADS" \
    --force; then
    echo "[zoomify] hictk zoomify failed, retrying with zero-count pixel filtering" >&2
    FILTERED_SRC="$(dirname "$OUT")/$(basename "$OUT" .cool).zoomify_src_filtered.cool"
    bash "$(dirname "$0")/hictk_filter_zero_pixels.sh" "$SRC_URI" "$SRC_RESOLUTION" "$FILTERED_SRC" "$THREADS"
    hictk zoomify "$FILTERED_SRC" "$OUT" \
        --resolutions "$TARGET_RESOLUTION" \
        --no-copy-base-resolution \
        --threads "$THREADS" \
        --force
    rm -f "$FILTERED_SRC"
fi
