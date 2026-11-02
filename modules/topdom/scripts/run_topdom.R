#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(TopDom))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: run_topdom.R <matrix_file> [window_size] [outdir]")

matrix_file <- args[1]
window_size  <- if (length(args) >= 2) as.integer(args[2]) else 5L
outdir       <- if (length(args) >= 3) args[3] else "/output/02_tad_results/topdom"

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

cat(sprintf("[TopDom] Processing: %s  window=%d\n", matrix_file, window_size))

result  <- TopDom(data = matrix_file, window.size = window_size)

domains <- result$domain[result$domain$tag == "domain", , drop = FALSE]

stem    <- tools::file_path_sans_ext(basename(matrix_file))
outfile <- file.path(outdir, paste0(stem, ".bed"))

write.table(domains[, c("chr", "from.coord", "to.coord")],
            file = outfile, sep = "\t", quote = FALSE,
            row.names = FALSE, col.names = FALSE)

cat(sprintf("[TopDom] %d domains → %s\n", nrow(domains), outfile))
