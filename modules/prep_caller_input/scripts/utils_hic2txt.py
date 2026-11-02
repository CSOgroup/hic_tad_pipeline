#!/usr/bin/env python3
import sys
import os
import math
import argparse
import numpy as np
import pandas as pd
import hicstraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from utils_tad_writers import (
    write_dense_matrix_with_coords,
    write_dense_matrix_no_coords,
    write_sparse_matrix_bin1_dedoc,
    write_sparse_matrix_coords,
)
def make_bins(chrom, length, resolution):
    n_bins = math.ceil(length / resolution)
    starts = np.arange(n_bins) * resolution
    ends = np.minimum(starts + resolution, length)
    bins = pd.DataFrame({"chrom": chrom, "start": starts, "end": ends})
    return bins, n_bins
def fetch_matrix(hic_path, resolution, chrom, n_bins, normalization):
    records = hicstraw.straw("observed", normalization, hic_path, chrom, chrom, "BP", resolution)
    mat = np.zeros((n_bins, n_bins))
    for r in records:
        i, j = r.binX // resolution, r.binY // resolution
        mat[i, j] = r.counts
        mat[j, i] = r.counts
    np.nan_to_num(mat, copy=False)
    return mat
def main():
    parser = argparse.ArgumentParser(
        description="Convert .hic directly to per-chromosome TAD caller input files "
                     "(no .cool intermediate)"
    )
    parser.add_argument("hic_path", help="Path to .hic file")
    parser.add_argument("resolution", type=int, help="Bin size in bp, e.g. 25000")
    parser.add_argument("outdir", nargs="?", default="/output/01_tad_input",
                        help="Output directory (default: /output/01_tad_input)")
    parser.add_argument("--chroms", default=None,
                        help="Comma-separated chromosomes to process (default: all)")
    parser.add_argument("--formats", default="dense_matrix_with_coords,dense_matrix_no_coords",
                        help="Comma-separated formats to generate: "
                             "dense_matrix_with_coords, dense_matrix_no_coords, "
                             "sparse_matrix_bin1_dedoc, sparse_matrix_coords "
                             "(default: dense_matrix_with_coords,dense_matrix_no_coords)")
    parser.add_argument("--normalization", choices=("NONE", "VC", "VC_SQRT", "KR", "SCALE"),
                        default="NONE",
                        help="Normalization vector to read from the .hic file; must "
                             "already exist in the file (e.g. computed by juicer_tools "
                             "addNorm, see balance_through_hic.sh) — NONE uses raw counts "
                             "(default: NONE)")
    args = parser.parse_args()
    outdir = args.outdir
    chroms_filter = set(args.chroms.split(",")) if args.chroms else None
    formats = set(args.formats.split(","))
    for fmt in formats:
        os.makedirs(os.path.join(outdir, fmt), exist_ok=True)
    hic = hicstraw.HiCFile(args.hic_path)
    if args.resolution not in hic.getResolutions():
        sys.exit(f"[hic2txt] ERROR: resolution {args.resolution} not found in "
                  f"{args.hic_path}; available: {hic.getResolutions()}")
    for chrom_obj in hic.getChromosomes():
        chrom, length = chrom_obj.name, chrom_obj.length
        if chrom.lower() == "all":
            continue
        if chroms_filter and chrom not in chroms_filter:
            continue
        print(f"[hic2txt] {chrom} ({args.normalization})", flush=True)
        bins, n_bins = make_bins(chrom, length, args.resolution)
        mat = fetch_matrix(args.hic_path, args.resolution, chrom, n_bins, args.normalization)
        stem = f"{chrom}_{args.resolution}"
        if "dense_matrix_with_coords" in formats:
            path = os.path.join(outdir, "dense_matrix_with_coords", f"{stem}.matrix")
            write_dense_matrix_with_coords(mat, bins, path)
            print(f"[hic2txt]   dense_matrix_with_coords → {path}", flush=True)
        if "dense_matrix_no_coords" in formats:
            path = os.path.join(outdir, "dense_matrix_no_coords", f"{stem}.matrix")
            write_dense_matrix_no_coords(mat, path)
            print(f"[hic2txt]   dense_matrix_no_coords   → {path}", flush=True)
        if "sparse_matrix_bin1_dedoc" in formats:
            graph_path = os.path.join(outdir, "sparse_matrix_bin1_dedoc", f"{stem}.hicGraph")
            write_sparse_matrix_bin1_dedoc(mat, graph_path)
            print(f"[hic2txt]   sparse_matrix_bin1_dedoc → {graph_path}", flush=True)
        if "sparse_matrix_coords" in formats:
            path = os.path.join(outdir, "sparse_matrix_coords", f"{stem}.txt")
            write_sparse_matrix_coords(mat, bins, path)
            print(f"[hic2txt]   sparse_matrix_coords → {path}", flush=True)
if __name__ == "__main__":
    main()
