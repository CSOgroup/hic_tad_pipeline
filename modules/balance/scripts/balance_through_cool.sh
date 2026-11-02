#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:?Usage: balance_through_cool.sh <INPUT> <RESOLUTION> [OUTDIR] [SAMPLE] [NORM_TYPE] [NPROC] [PRESERVE_SOURCE] [WEIGHT_COL]}"
RESOLUTION="${2:?RESOLUTION is required (e.g. 25000)}"
OUTDIR="${3:-/output/00_balanced_cool}"
SAMPLE="${4:-input}"
NORM_TYPE="${5:-ICE}"
NPROC="${6:-4}"
PRESERVE_SOURCE="${7:-true}"
WEIGHT_COL_OVERRIDE="${8:-}"

mkdir -p "$OUTDIR"
OUT="${OUTDIR}/${SAMPLE}.cool"

ext="${INPUT##*.}"
ext="${ext,,}"

case "$ext" in
    cool)
        if [[ "$PRESERVE_SOURCE" == "true" ]]; then
            cp "$INPUT" "$OUT"
            echo "[to_cool] copied $INPUT → $OUT"
        else
            ln -s "$(readlink -f "$INPUT")" "$OUT"
            echo "[to_cool] symlinked $INPUT → $OUT"
        fi
        ;;
    mcool)
        cooler cp "${INPUT}::resolutions/${RESOLUTION}" "$OUT"
        echo "[to_cool] extracted ${INPUT}::${RESOLUTION}bp → $OUT"
        ;;
    hic)
        bash /common_scripts/hic2cool.sh "$INPUT" "$RESOLUTION" "$OUT" "$NPROC"
        ;;
    *)
        echo "[to_cool] ERROR: unsupported extension '.${ext}'; expected .cool .mcool or .hic" >&2
        exit 1
        ;;
esac

case "$NORM_TYPE" in
    NONE)
        echo "[to_cool] NORM_TYPE=NONE, skipping normalization"
        ;;
    ICE|ICE_cis|ICE_trans)
        case "$NORM_TYPE" in
            ICE_cis)
                DEFAULT_WEIGHT_COL="ICE_cis"
                BALANCE_OPTS=(--cis-only)
                ;;
            ICE_trans)
                DEFAULT_WEIGHT_COL="ICE_trans"
                BALANCE_OPTS=(--trans-only --ignore-diags 1 --min-nnz 10 --tol 1e-09)
                ;;
            *)
                DEFAULT_WEIGHT_COL="weight"
                BALANCE_OPTS=()
                ;;
        esac
        WEIGHT_COL="${WEIGHT_COL_OVERRIDE:-$DEFAULT_WEIGHT_COL}"
        BALANCE_OPTS+=(--max-iters 1000 --name "$WEIGHT_COL")
        cooler balance --force --nproc "$NPROC" "${BALANCE_OPTS[@]}" "$OUT"
        python3 - "$OUT" "$WEIGHT_COL" <<'PY'
import sys
import h5py
import numpy as np

path, col = sys.argv[1], sys.argv[2]
with h5py.File(path, "r+") as f:
    ds = f["bins"][col]
    scale = np.atleast_1d(ds.attrs["scale"]).astype(float)
    n_chroms = len(f["chroms/name"])
    if scale.size == 1:
        factor = np.sqrt(scale[0])
    elif scale.size == n_chroms:
        factor = np.sqrt(scale)[f["bins/chrom"][:]]
    else:
        sys.exit(f"ERROR: {col} has {scale.size} scale values but the file has {n_chroms} chromosomes")
    ds[...] = ds[...] * factor
    ds.attrs["rescaled_to_counts"] = True
print(f"[to_cool] {col} rescaled by sqrt(scale={np.array2string(scale, precision=6)}) to raw-count magnitude")
PY
        echo "[to_cool] ${NORM_TYPE} balanced → $OUT (${WEIGHT_COL} column)"
        ;;
    *)
        echo "[to_cool] ERROR: NORM_TYPE '$NORM_TYPE' is not supported for .cool output (only ICE, ICE_cis, ICE_trans or NONE)." >&2
        exit 1
        ;;
esac
