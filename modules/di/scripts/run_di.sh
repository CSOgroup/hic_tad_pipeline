#!/usr/bin/env bash
set -euo pipefail

INDIR="${1:?Usage: run_di.sh <INDIR> [BINSIZE] [WINDOW] [OUTDIR]}"
BINSIZE="${2:-}"
WINDOW="${3:-2000000}"
OUTDIR="${4:-di}"

DI_SCRIPTS=/opt/di_scripts
MATLAB_WD=/home/work/DI/domaincall_software

export MATLAB_PREFDIR="$(pwd)/.matlab_prefs"
mkdir -p "$MATLAB_PREFDIR"

mkdir -p "$OUTDIR"

shopt -s nullglob
matrix_files=("$INDIR"/*.matrix)
if [ "${#matrix_files[@]}" -eq 0 ]; then
    echo "ERROR: no *.matrix files found in $INDIR" >&2
    exit 1
fi

for matrix_file in "${matrix_files[@]}"; do
    base=$(basename "$matrix_file" .matrix)
    chrom=$(echo "$base" | sed 's/_[0-9]*$//')

    if [ -z "$BINSIZE" ] || [ "$BINSIZE" -eq 0 ] 2>/dev/null; then
        read -r s1 s2 < <(awk 'NR==1{a=$2} NR==2{print a,$2; exit}' "$matrix_file")
        bs=$(( s2 - s1 ))
    else
        bs="$BINSIZE"
    fi

    chrsize_file=$(mktemp /tmp/chrsize.XXXXXX)
    chrom_size=$(awk 'END{print $3}' "$matrix_file")
    printf '%s\t%s\n' "$chrom" "$chrom_size" > "$chrsize_file"

    tmp_di="${OUTDIR}/${base}_DI"
    tmp_hmm="${OUTDIR}/${base}_HMM_results.txt"
    tmp_7col="${OUTDIR}/${base}_7col"
    log_matlab="${OUTDIR}/${base}_step2_matlab.log"
    outfile="${OUTDIR}/${base}_finaldomaincalls.txt"

    echo "────────────────────────────────────────────"
    echo "  chrom   : $chrom"
    echo "  binsize : ${bs} bp"
    echo "  window  : ${WINDOW} bp"
    echo "  matrix  : $matrix_file"
    echo "────────────────────────────────────────────"

    echo "[1/4] Calculating DI..."
    perl "$DI_SCRIPTS/DI_from_matrix.pl" \
        "$matrix_file" "$bs" "$WINDOW" "$chrsize_file" \
        > "$tmp_di"
    echo "      $(wc -l < "$tmp_di") bins → $(basename "$tmp_di")"

    echo "[2/4] Fitting HMM with MATLAB (HMM_calls_v2.m)..."
    rm -f "$tmp_hmm"

    input_abs=$(readlink -m "$tmp_di")
    output_abs=$(readlink -m "$tmp_hmm")

    matlab -nodisplay -nosplash -nodesktop -r \
        "try, \
            cd('${MATLAB_WD}'); \
            input_file='${input_abs}'; \
            output_file='${output_abs}'; \
            run('HMM_calls_v2.m'); \
         end, exit" \
        > "$log_matlab" 2>&1

    if [[ ! -f "$tmp_hmm" ]]; then
        echo "ERROR: MATLAB did not produce $tmp_hmm" >&2
        cat "$log_matlab" >&2
        exit 1
    fi

    echo "[3/4] Post-processing HMM output..."
    perl "$DI_SCRIPTS/file_ends_cleaner.pl" "$tmp_hmm" "$tmp_di" \
        | perl "$DI_SCRIPTS/converter_7col.pl" \
        > "$tmp_7col"

    echo "[4/4] Calling TADs..."
    perl "$DI_SCRIPTS/hmm_probablity_correcter_pm.pl" \
            "$tmp_7col" 2 0.99 "$bs" \
        | perl "$DI_SCRIPTS/hmm-state_caller.pl" \
            "$chrsize_file" "$chrom" \
        | perl "$DI_SCRIPTS/hmm-state_domains_mz.pl" \
        > "$outfile"

    rm -f "$chrsize_file" "$tmp_di" "$tmp_hmm" "$tmp_7col" "$log_matlab"

    echo "  → $(wc -l < "$outfile") TADs  →  $outfile"
done

echo ""
echo "Done. Results in $OUTDIR"
