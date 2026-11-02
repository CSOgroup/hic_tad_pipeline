#!/usr/bin/env python3
import MSTDlib.MSTD_v1 as MSTD_v1
import sys
import os

matrix_file = sys.argv[1]
outdir      = sys.argv[2]

os.makedirs(outdir, exist_ok=True)
stem        = os.path.splitext(os.path.basename(matrix_file))[0]
output_file = os.path.join(outdir, f"{stem}.bed")

print(f"[MSTD] {matrix_file} → {output_file}", flush=True)
MSTD_v1.MSTD2(matrix_file, output_file, visualization=0)
