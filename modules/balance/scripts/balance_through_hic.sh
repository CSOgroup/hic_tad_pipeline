#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:?Usage: balance_through_hic.sh <INPUT> <RESOLUTION> [OUTDIR] [SAMPLE] [NORM_TYPE] [NPROC] [PRESERVE_SOURCE]}"
RESOLUTION="${2:?RESOLUTION is required (e.g. 25000)}"
OUTDIR="${3:-/output/00_balanced_hic}"
SAMPLE="${4:-input}"
NORM_TYPE="${5:-KR}"
NPROC="${6:-4}"
PRESERVE_SOURCE="${7:-true}"
CONVERT_THREADS=$(( NPROC < 2 ? 2 : NPROC ))

mkdir -p "$OUTDIR"
OUT="${OUTDIR}/${SAMPLE}.hic"

ext="${INPUT##*.}"
ext="${ext,,}"

case "$ext" in
    hic)
        HIC_VERSION="$(hictk metadata "$INPUT" -f json 2>/dev/null | python3 -c "
import json, sys
print(json.load(sys.stdin).get('format-version', 0))
" || echo 0)"
        if [[ "$HIC_VERSION" -ge 9 ]]; then
            if [[ "$PRESERVE_SOURCE" == "true" ]]; then
                cp "$INPUT" "$OUT"
                echo "[to_hic] copied $INPUT (v${HIC_VERSION}) → $OUT"
            else
                ln -s "$(readlink -f "$INPUT")" "$OUT"
                echo "[to_hic] symlinked $INPUT (v${HIC_VERSION}) → $OUT"
            fi
        else
            TMP_MCOOL="./${SAMPLE}.hictk_tmp.mcool"
            hictk convert -r "$RESOLUTION" --output-fmt mcool --threads "$CONVERT_THREADS" --force "$INPUT" "$TMP_MCOOL"
            hictk convert --output-fmt hic --threads "$CONVERT_THREADS" --force "$TMP_MCOOL" "$OUT"
            rm -f "$TMP_MCOOL"
            echo "[to_hic] upgraded ${INPUT} (v${HIC_VERSION} → v9) → $OUT"
        fi
        ;;
    cool|mcool)
        hictk convert -r "$RESOLUTION" --threads "$CONVERT_THREADS" --force "$INPUT" "$OUT"
        echo "[to_hic] converted ${INPUT} @ ${RESOLUTION}bp → $OUT"
        ;;
    *)
        echo "[to_hic] ERROR: unsupported extension '.${ext}'; expected .cool .mcool or .hic" >&2
        exit 1
        ;;
esac

case "$NORM_TYPE" in
    NONE)
        echo "[to_hic] NORM_TYPE=NONE, skipping normalization"
        ;;
    KR)
        if hictk metadata "$OUT" -f json --recursive 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
sys.exit(0 if 'KR' in data.get('$RESOLUTION', {}).get('normalizations', []) else 1)
"; then
            echo "[to_hic] KR normalization already present, skipping"
        else
            echo "[to_hic] Computing KR normalization for $OUT"
            java -jar /juicer_tools.jar addNorm -k KR -r "$RESOLUTION" -j "$NPROC" "$OUT"
            echo "[to_hic] KR normalization added → $OUT"
        fi
        ;;
    *)
        echo "[to_hic] ERROR: NORM_TYPE '$NORM_TYPE' is not supported for .hic output (only KR or NONE)." >&2
        exit 1
        ;;
esac
