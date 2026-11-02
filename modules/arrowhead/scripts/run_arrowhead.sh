#!/usr/bin/env bash
set -euo pipefail
HIC_FILE="${1:?Usage: run_arrowhead.sh <HIC_FILE> <RESOLUTION> [OUTDIR] [CHROM] [NORM_TYPE]}"
RESOLUTION="${2:?Error: RESOLUTION is required}"
OUTDIR="${3:-arrowhead}"
CHROM="${4:-}"
NORM_TYPE="${5:-NONE}"

case "$NORM_TYPE" in
    NONE|KR) ;;
    *) echo "[arrowhead] ERROR: NORM_TYPE must be NONE or KR, got: $NORM_TYPE" >&2; exit 1 ;;
esac

mkdir -p "$OUTDIR"
echo "[arrowhead] input=$HIC_FILE  res=$RESOLUTION  norm=$NORM_TYPE"
[[ -n "$CHROM" ]] && echo "[arrowhead] chrom=$CHROM"

CHROM_OPT=()
[[ -n "$CHROM" ]] && CHROM_OPT=(-c "$CHROM")

java -Xmx16g -jar /juicer_tools.jar arrowhead -k "$NORM_TYPE" \
    -r "$RESOLUTION" \
    "${CHROM_OPT[@]}" \
    "$HIC_FILE" \
    "$OUTDIR"

echo "[arrowhead] Done. Results in $OUTDIR"
