#!/usr/bin/env python3

import argparse
import os

import cooler
import pandas as pd

HUMAN_CHROMS = ["chr" + str(x) for x in range(1, 23)] + ["chrX"]
MM_CHROMS = ["chr" + str(x) for x in range(1, 20)] + ["chrX"]
SPECIES_CHROMS = {
    "human": HUMAN_CHROMS,
    "mouse": MM_CHROMS,
}

def detect_species(chromnames):
    return "human" if "chr20" in chromnames else "mouse"

def process_arguments():
    parser = argparse.ArgumentParser(description="Extract a subset of chromosomes from a .cool file")
    parser.add_argument("input_cool", type=str, help="Path to the input .cool file")
    parser.add_argument("output_cool", type=str, help="Path to write the subset .cool file")
    parser.add_argument("--species", choices=sorted(SPECIES_CHROMS), help="Use a built-in chrom list (human/mouse)")
    parser.add_argument("--chroms", type=str, help="Comma-separated chrom names, overrides --species")
    return parser.parse_args()

def main():
    args = process_arguments()
    clr = cooler.Cooler(args.input_cool)

    if args.chroms:
        chroms = args.chroms.split(",")
    else:
        species = args.species or detect_species(clr.chromnames)
        chroms = SPECIES_CHROMS[species]

    bins = clr.bins()[:]
    keep_mask = bins["chrom"].isin(chroms)

    missing = set(chroms) - set(bins.loc[keep_mask, "chrom"])
    if missing:
        raise ValueError(f"chroms not found in input: {sorted(missing)}")

    if keep_mask.all():
        os.symlink(os.path.realpath(args.input_cool), args.output_cool)
        print(f"[extract_chroms] input already matches {len(chroms)} chrom(s), symlinked -> {args.output_cool}")
        return

    new_bins = bins.loc[keep_mask].reset_index(drop=True)
    old_to_new = pd.Series(new_bins.index, index=bins.index[keep_mask])

    pixels = clr.pixels()[:]
    pixels = pixels[pixels.bin1_id.isin(old_to_new.index) & pixels.bin2_id.isin(old_to_new.index)]
    pixels = pixels.assign(
        bin1_id=pixels.bin1_id.map(old_to_new).astype(pixels.bin1_id.dtype),
        bin2_id=pixels.bin2_id.map(old_to_new).astype(pixels.bin2_id.dtype),
    )

    cooler.create_cooler(args.output_cool, new_bins, pixels, ordered=True)
    print(f"[extract_chroms] kept {len(chroms)} chrom(s), {len(new_bins)} bins, {len(pixels)} pixels -> {args.output_cool}")

if __name__ == "__main__":
    main()
