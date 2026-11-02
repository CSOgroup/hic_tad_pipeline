#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(consensusTADs)
  library(future)
  library(furrr)
})

args       <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: run_consensus_tads.R <input_tsv> [outdir] [threshold] [step] [workers]")

input_tsv  <- args[1]
outdir     <- if (length(args) >= 2 && nchar(args[2]) > 0) args[2] else "/output/04_consensus_tads"
threshold  <- if (length(args) >= 3 && nchar(args[3]) > 0) as.numeric(args[3]) else 0
step       <- if (length(args) >= 4 && nchar(args[4]) > 0) as.numeric(args[4]) else -0.05
workers    <- if (length(args) >= 5 && nchar(args[5]) > 0) as.integer(args[5]) else 1L

if (!file.exists(input_tsv)) stop(sprintf("Input file not found: %s", input_tsv))

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

cat(sprintf("[consensus] Input:     %s\n", input_tsv))
cat(sprintf("[consensus] Output:    %s\n", outdir))
cat(sprintf("[consensus] Threshold: %g\n", threshold))
cat(sprintf("[consensus] Step:      %g\n", step))
cat(sprintf("[consensus] Workers:   %d\n", workers))

df_tools <- read_tsv(input_tsv, show_col_types = FALSE) %>%
  dplyr::mutate(chr = as.character(chr))
cat(sprintf("[consensus] Loaded %d TAD records from %d callers across %s\n",
            nrow(df_tools),
            length(unique(df_tools$meta.tool)),
            paste(sort(unique(df_tools$chr)), collapse = ", ")))

if (workers > 1L) {
  options(future.globals.maxSize = 10 * 1024^3)
  future::plan(future::multisession(workers = workers))
  on.exit(future::plan(future::sequential), add = TRUE)
}

cat("[consensus] Running generate_tad_consensus_hierarchy()...\n")
consensus <- generate_tad_consensus_hierarchy(
  df_tools,
  threshold = threshold,
  step      = step,
  max_round = NULL
)

cat(sprintf("[consensus] %d consensus TADs found\n", nrow(consensus)))

outfile <- file.path(outdir, "consensus_tads.tsv")
write_tsv(consensus, outfile)
cat(sprintf("[consensus] Written → %s\n", outfile))

df_tools_merged <- consensus %>%
  dplyr::select(chr, start, end, meta.tool = round) %>%
  dplyr::mutate(meta.tool = paste0("consensus_round", meta.tool)) %>%
  dplyr::bind_rows(df_tools)
merged_outfile <- file.path(outdir, "consensus_tads_merged.tsv")
write_tsv(df_tools_merged, merged_outfile)
cat(sprintf("[consensus] Written → %s\n", merged_outfile))
