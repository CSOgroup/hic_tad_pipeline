#!/usr/bin/env python3
import sys
import numpy as np
import cooler

src, dst = sys.argv[1], sys.argv[2]
weight_col = sys.argv[3] if len(sys.argv) > 3 else 'weight'

clr = cooler.Cooler(src)

bins = clr.bins()[['chrom', 'start', 'end']][:]
weights = clr.bins()[weight_col][:]

pixels = clr.pixels()[:]
pixels['balanced'] = (
    pixels['count']
    * weights.values[pixels['bin1_id'].values]
    * weights.values[pixels['bin2_id'].values]
)
pixels = (
    pixels[['bin1_id', 'bin2_id', 'balanced']]
    .dropna()
    .rename(columns={'balanced': 'count'})
)

cooler.create_cooler(dst, bins, pixels, dtypes={'count': np.float32})
print(f"[apply_weight] wrote {len(pixels)} pixels to {dst} (weight column: {weight_col})", file=sys.stderr)
