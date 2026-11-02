#!/usr/bin/env bash
set -euo pipefail

SRC_URI="${1:?Usage: hictk_filter_zero_pixels.sh <SRC_URI> <BIN_SIZE> <OUT> [THREADS]}"
BIN_SIZE="${2:?BIN_SIZE is required (e.g. 25000)}"
OUT="${3:?OUT path is required}"
THREADS="${4:-4}"

LOAD_THREADS=$(( THREADS < 2 ? 2 : THREADS ))

WORKDIR="$(mktemp -d -p "$(dirname "$OUT")" ".hictk_tmp.$(basename "$OUT").XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
CHROMSIZES="${WORKDIR}/chrom.sizes"

res_flag=()
[[ "${SRC_URI%%::*}" == *.[Hh][Ii][Cc] ]] && res_flag=(--resolution "$BIN_SIZE")

hictk dump "$SRC_URI" "${res_flag[@]}" --table=chroms > "$CHROMSIZES"
hictk dump "$SRC_URI" "${res_flag[@]}" --join \
    | awk -F'\t' '$7 != 0' \
    | hictk load - "$OUT" --chrom-sizes="$CHROMSIZES" --format=bg2 \
        --bin-size="$BIN_SIZE" --tmpdir="$WORKDIR" --threads "$LOAD_THREADS" --force

rm -rf "$WORKDIR"
trap - EXIT
