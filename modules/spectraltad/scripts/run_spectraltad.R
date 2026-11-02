#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(SpectralTAD))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: run_spectraltad.R <matrix_file> [chr] [resolution] [outdir]")

matrix_file <- args[1]
chr         <- if (length(args) >= 2) args[2] else sub("_[^_]+$", "", basename(matrix_file))
resolution  <- if (length(args) >= 3) as.integer(args[3]) else 250000L
outdir      <- if (length(args) >= 4) args[4] else "/output/02_tad_results/spectraltad"

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

cat(sprintf("[SpectralTAD] Processing: %s  chr=%s  res=%d\n", matrix_file, chr, resolution))

mat  <- as.matrix(read.table(matrix_file, header = FALSE, sep = "\t"))
n    <- ncol(mat)
bins <- as.character(seq(0, by = resolution, length.out = n))
colnames(mat) <- bins
rownames(mat) <- bins

result <- SpectralTAD(mat, chr = chr, resolution = resolution)

tads    <- result[[1]]
stem    <- sub("\\.matrix$", "", basename(matrix_file))
outfile <- file.path(outdir, paste0(stem, ".bed"))

write.table(tads, file = outfile, sep = "\t", quote = FALSE,
            row.names = FALSE, col.names = FALSE)

cat(sprintf("[SpectralTAD] %d TADs → %s\n", nrow(tads), outfile))
