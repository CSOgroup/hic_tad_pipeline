#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:?Usage: choose_resolution.sh <INPUT> <RESOLUTION> [OUTDIR] [SAMPLE] [THREADS] [PRESERVE_SOURCE]}"
RESOLUTION="${2:?RESOLUTION is required (e.g. 25000)}"
OUTDIR="${3:-/output/00_cleaned}"
SAMPLE="${4:-input}"
THREADS="${5:-4}"
PRESERVE_SOURCE="${6:-true}"

mkdir -p "$OUTDIR"
OUT="${OUTDIR}/${SAMPLE}.cool"

ext="${INPUT##*.}"
ext="${ext,,}"

case "$ext" in
    cool|mcool|hic) ;;
    *)
        echo "[zoomify] ERROR: unsupported extension '.${ext}'; expected .cool .mcool or .hic" >&2
        exit 1
        ;;
esac

list_resolutions() {
    case "$ext" in
        cool)
            python3 -c "
import sys, cooler
print(cooler.Cooler(sys.argv[1]).binsize)
" "$INPUT"
            ;;
        mcool)
            python3 -c "
import sys, cooler
path = sys.argv[1]
for grp in cooler.fileops.list_coolers(path):
    print(cooler.Cooler(path + '::' + grp).binsize)
" "$INPUT"
            ;;
        hic)
            hictk metadata "$INPUT" -f json --recursive | python3 -c "
import json, sys
for key in json.load(sys.stdin):
    if key.isdigit():
        print(key)
"
            ;;
    esac
}

pick_source_resolution() {
    python3 -c "
import sys
target = int(sys.argv[1])
available = sorted(int(x) for x in sys.argv[2:])
usable = [r for r in available if r <= target and target % r == 0]
if not usable:
    sys.stderr.write(
        '[zoomify] ERROR: cannot reach {}bp from available resolutions {}; '
        'need one that divides it evenly\n'.format(target, available))
    sys.exit(1)
print(max(usable))
" "$RESOLUTION" $(list_resolutions)
}

SRC_RES="$(pick_source_resolution)"

if [[ "$SRC_RES" -eq "$RESOLUTION" ]]; then
    case "$ext" in
        cool)
            if [[ "$PRESERVE_SOURCE" == "true" ]]; then
                cp "$INPUT" "$OUT"
                echo "[zoomify] copied $INPUT @ ${SRC_RES}bp → $OUT"
            else
                ln -s "$(readlink -f "$INPUT")" "$OUT"
                echo "[zoomify] symlinked $INPUT @ ${SRC_RES}bp → $OUT"
            fi
            ;;
        mcool)
            cooler cp "${INPUT}::/resolutions/${SRC_RES}" "$OUT"
            echo "[zoomify] extracted ${INPUT}::${SRC_RES}bp → $OUT"
            ;;
        hic)
            bash /common_scripts/hic2cool.sh "$INPUT" "$SRC_RES" "$OUT" "$THREADS"
            ;;
    esac
else
    BASE_COOL=""
    case "$ext" in
        cool)
            SRC_URI="$INPUT"
            ;;
        mcool)
            SRC_URI="${INPUT}::/resolutions/${SRC_RES}"
            ;;
        hic)
            BASE_COOL="${OUTDIR}/${SAMPLE}.zoomify_base.cool"
            bash /common_scripts/hic2cool.sh "$INPUT" "$SRC_RES" "$BASE_COOL" "$THREADS"
            SRC_URI="$BASE_COOL"
            ;;
    esac

    bash /common_scripts/hictk_zoomify.sh "$SRC_URI" "$SRC_RES" "$RESOLUTION" "$OUT" "$THREADS"
    [[ -n "$BASE_COOL" ]] && rm -f "$BASE_COOL"
    echo "[zoomify] zoomified ${SRC_RES}bp → ${RESOLUTION}bp → $OUT"
fi
