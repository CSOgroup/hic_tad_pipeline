#!/usr/bin/env python3
import sys
import os
import argparse
import numpy as np
import cooler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from utils_tad_writers import (
    write_dense_matrix_with_coords,
    write_dense_matrix_no_coords,
    write_sparse_matrix_bin1_dedoc,
    write_sparse_matrix_coords,
)
def fetch_matrix(clr, chrom, balance=True):
    mat = clr.matrix(balance=balance, sparse=True).fetch(chrom).toarray()
    np.nan_to_num(mat, copy=False)
    return mat
def main():
    parser = argparse.ArgumentParser(
        description="Convert .cool to per-chromosome TAD caller input files"
    )
    parser.add_argument("cool_path", help="Path to .cool file")
    parser.add_argument("outdir", nargs="?", default="/output/01_tad_input",
                        help="Output directory (default: /output/01_tad_input)")
    parser.add_argument("--chroms", default=None,
                        help="Comma-separated chromosomes to process (default: all)")
    parser.add_argument("--formats", default="dense_matrix_with_coords,dense_matrix_no_coords",
                        help="Comma-separated formats to generate: "
                             "dense_matrix_with_coords, dense_matrix_no_coords, "
                             "sparse_matrix_bin1_dedoc, sparse_matrix_coords "
                             "(default: dense_matrix_with_coords,dense_matrix_no_coords)")
    parser.add_argument("--normalization", choices=("ICE", "ICE_cis", "NONE"), default="ICE",
                        help="Normalization mode: ICE uses the cooler's 'weight' column; "
                             "ICE_cis uses the cooler's 'ICE_cis' column (cis-only iterative "
                             "correction); NONE uses raw counts (default: ICE)")
    parser.add_argument("--weight_col", default=None,
                        help="Override which column to read weights from, ignoring "
                             "--normalization's default column mapping (e.g. when the "
                             "cooler was balanced with a non-default column name)")
    args = parser.parse_args()
    cool_path = args.cool_path
    outdir = args.outdir
    chroms_filter = set(args.chroms.split(",")) if args.chroms else None
    formats = set(args.formats.split(","))
    balance = args.weight_col or {"ICE": True, "ICE_cis": "ICE_cis", "NONE": False}[args.normalization]
    for fmt in formats:
        os.makedirs(os.path.join(outdir, fmt), exist_ok=True)
    clr = cooler.Cooler(cool_path)
    res = clr.binsize
    for chrom in clr.chromnames:
        if chroms_filter and chrom not in chroms_filter:
            continue
        print(f"[prep] {chrom} ({args.normalization})", flush=True)
        bins = clr.bins().fetch(chrom)
        mat = fetch_matrix(clr, chrom, balance)
        stem = f"{chrom}_{res}"
        if "dense_matrix_with_coords" in formats:
            path = os.path.join(outdir, "dense_matrix_with_coords", f"{stem}.matrix")
            write_dense_matrix_with_coords(mat, bins, path)
            print(f"[prep]   dense_matrix_with_coords → {path}", flush=True)
        if "dense_matrix_no_coords" in formats:
            path = os.path.join(outdir, "dense_matrix_no_coords", f"{stem}.matrix")
            write_dense_matrix_no_coords(mat, path)
            print(f"[prep]   dense_matrix_no_coords   → {path}", flush=True)
        if "sparse_matrix_bin1_dedoc" in formats:
            graph_path = os.path.join(outdir, "sparse_matrix_bin1_dedoc", f"{stem}.hicGraph")
            write_sparse_matrix_bin1_dedoc(mat, graph_path)
            print(f"[prep]   sparse_matrix_bin1_dedoc → {graph_path}", flush=True)
        if "sparse_matrix_coords" in formats:
            path = os.path.join(outdir, "sparse_matrix_coords", f"{stem}.txt")
            write_sparse_matrix_coords(mat, bins, path)
            print(f"[prep]   sparse_matrix_coords → {path}", flush=True)
if __name__ == "__main__":
    main()
