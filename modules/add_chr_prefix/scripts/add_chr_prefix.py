#!/usr/bin/env python3

import argparse

import cooler

def process_arguments():
    parser = argparse.ArgumentParser(description="Add 'chr' prefix to chromosome names in a .cool file")
    parser.add_argument("cool_file", type=str, help="Path to the .cool file to rename in place")
    return parser.parse_args()

def main():
    args = process_arguments()

    clr = cooler.Cooler(args.cool_file)
    rename_map = {name: f"chr{name}" for name in clr.chromnames if not name.startswith("chr")}

    if rename_map:
        cooler.rename_chroms(clr, rename_map)
        print(f"[add_chr_prefix] renamed {len(rename_map)} chrom(s): {rename_map}")
    else:
        print("[add_chr_prefix] all chrom names already have 'chr' prefix, nothing to rename")

if __name__ == "__main__":
    main()
