#!/usr/bin/env bash
set -euo pipefail
INDIR="${1:?Usage: run_dedoc.sh <INDIR> [OUTDIR]}"
OUTDIR="${2:-dedoc}"
DEDOC_JAR=/opt/dedoc/deDoc.jar

mkdir -p "$OUTDIR"
shopt -s nullglob
for graph_file in "$INDIR"/*.hicGraph; do
    fname=$(basename "$graph_file")
    link="$OUTDIR/$fname"
    ln -s "$(readlink -f "$graph_file")" "$link"
    echo "[deDoc] Running: $graph_file"
    java -jar "$DEDOC_JAR" "$link"
    rm -f "$link"
    echo "[deDoc] Done: $graph_file"
done
