#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(tibble)
  library(dplyr)
  library(stringr)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: clean_tad_results.R <results_dir> <resolution> [outdir] [callers] [chroms]")

results_dir <- args[1]
resolution  <- as.integer(args[2])
outdir      <- if (length(args) >= 3 && nchar(args[3]) > 0) args[3] else "/output/03_clean_results"
callers_arg <- if (length(args) >= 4) args[4] else ""
chroms_arg  <- if (length(args) >= 5) args[5] else ""

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

ALL_CALLERS    <- c("arrowhead", "topdom", "di", "mstd", "ontad", "spectraltad", "dedoc", "lpad")
active_callers <- if (nchar(callers_arg) > 0) trimws(strsplit(callers_arg, ",")[[1]]) else ALL_CALLERS

detect_chroms <- function(results_dir, resolution) {
  patterns <- list(
    topdom       = list(dir = "topdom",       rx = paste0("^(.+)_", resolution, "\\.bed$")),
    mstd         = list(dir = "mstd",         rx = paste0("^(.+)_", resolution, "\\.bed$")),
    spectraltad = list(dir = "spectraltad", rx = paste0("^(.+)_", resolution, "\\.bed$")),
    lpad         = list(dir = "lpad",         rx = paste0("^(.+)_", resolution, "\\.out$")),
    ontad        = list(dir = "ontad",        rx = paste0("^(.+)_", resolution, "\\.tad$")),
    di           = list(dir = "di",           rx = paste0("^(.+)_", resolution, "_finaldomaincalls\\.txt$")),
    dedoc        = list(dir = "dedoc",        rx = paste0("^(.+)_", resolution, "\\.hicGraph\\.deDoc\\(E\\)$"))
  )
  chroms <- character(0)
  for (p in patterns) {
    d <- file.path(results_dir, p$dir)
    if (!dir.exists(d)) next
    for (f in list.files(d)) {
      if (grepl(p$rx, f, perl = TRUE)) {
        chroms <- c(chroms, sub(p$rx, "\\1", f, perl = TRUE))
      }
    }
  }
  if (length(chroms) == 0) {
    bedpe_files <- list.files(file.path(results_dir, "arrowhead"), pattern = "\\.bedpe$", full.names = TRUE)
    if (length(bedpe_files) > 0) {
      bedpe <- tryCatch(
        read_tsv(bedpe_files[1], comment = "#", col_names = FALSE, show_col_types = FALSE),
        error = function(e) NULL
      )
      if (!is.null(bedpe) && ncol(bedpe) >= 1) {
        raw <- unique(as.character(bedpe$X1))
        chroms <- ifelse(grepl("^chr", raw), raw, paste0("chr", raw))
      }
    }
  }
  unique(sort(chroms))
}

if (nchar(chroms_arg) > 0) {
  chroms <- trimws(strsplit(chroms_arg, ",")[[1]])
} else {
  chroms <- detect_chroms(results_dir, resolution)
}

cat(sprintf("[clean] Resolution:  %d\n", resolution))
cat(sprintf("[clean] Callers:     %s\n", paste(active_callers, collapse = ", ")))
cat(sprintf("[clean] Chromosomes: %s\n",
            if (length(chroms) > 0) paste(chroms, collapse = ", ") else "(none detected)"))

empty_tbl <- function(tool) tibble(chr = character(), start = double(), end = double(), meta.tool = tool)

arrowhead_clean <- function(path, chromosome) {
  bedpe_files <- list.files(path, full.names = TRUE, pattern = "\\.bedpe$")
  if (length(bedpe_files) == 0) return(empty_tbl("arrowhead"))
  chrom_bare <- gsub("^chr", "", chromosome)
  tb <- read_tsv(bedpe_files[1], comment = "#", col_names = FALSE, show_col_types = FALSE) %>%
    filter(as.character(X1) == chrom_bare | as.character(X1) == chromosome) %>%
    select(X2, X3) %>%
    arrange(X2)
  tibble(chr = chromosome, start = tb$X2 + 1, end = tb$X3, meta.tool = "arrowhead") %>%
    arrange(chr, start) %>% filter(start < end)
}

dedoc_clean <- function(path, resol, chromosome) {
  if (!file.exists(path)) return(empty_tbl("deDoc"))
  lines <- read_lines(path)
  lines <- lines[nchar(trimws(lines)) > 0]
  bin_start <- as.double(str_extract(lines, "\\d+"))
  bin_end   <- as.double(str_extract(lines, "\\d+$"))
  tibble(
    chr = chromosome,
    start = (bin_start - 1) * resol + 1,
    end   = bin_end * resol,
    meta.tool = "deDoc"
  ) %>% arrange(chr, start) %>% filter(start < end)
}

topdom_clean <- function(path, chromosome) {
  tmp_file <- paste0(path, ".bed")
  if (!file.exists(tmp_file)) return(empty_tbl("TopDom"))
  read_tsv(tmp_file, col_names = FALSE, show_col_types = FALSE) %>%
    transmute(chr = chromosome, start = X2 + 1, end = X3, meta.tool = "TopDom") %>%
    arrange(chr, start) %>% filter(start < end)
}

DI_clean <- function(path, resol, chromosome) {
  if (!file.exists(path)) return(empty_tbl("DI"))
  inDT <- read_tsv(path, col_names = FALSE, show_col_types = FALSE)
  tibble(chr = chromosome, start = inDT$X2 + 1, end = inDT$X3, meta.tool = "DI") %>%
    arrange(chr, start) %>% filter(start < end)
}

MSTD_clean <- function(path, resol, chromosome) {
  if (!file.exists(path)) return(empty_tbl("MSTD"))
  inDT <- read_tsv(path, show_col_types = FALSE)
  tibble(
    chr = chromosome,
    start = inDT$Start * resol + 1,
    end   = inDT$End   * resol,
    meta.tool = "MSTD"
  ) %>% arrange(chr, start) %>% filter(start < end)
}

SpectralTAD_clean <- function(path, resol, chromosome) {
  if (!file.exists(path)) return(empty_tbl("SpectralTAD"))
  inDT <- read_tsv(path, col_names = FALSE, show_col_types = FALSE)
  tibble(
    chr = chromosome,
    start = inDT$X2 + 1,
    end   = inDT$X3,
    meta.tool = "SpectralTAD"
  ) %>% arrange(chr, start) %>% filter(start < end)
}

OnTAD_clean <- function(path, resol, chromosome) {
  tmp_file <- paste0(path, ".tad")
  if (!file.exists(tmp_file)) return(empty_tbl("OnTAD"))
  inDT <- read_tsv(tmp_file, col_names = FALSE, show_col_types = FALSE) %>%
    filter(X3 == 2)
  tibble(
    chr = chromosome,
    start = (inDT$X1 - 1) * resol + 1,
    end   = (inDT$X2 - 1) * resol,
    meta.tool = "OnTAD"
  ) %>% arrange(chr, start) %>% filter(start < end)
}

LPAD_clean <- function(path, resol, chromosome) {
  if (!file.exists(path)) return(empty_tbl("LPAD"))
  inDT <- read_tsv(path, col_names = FALSE, show_col_types = FALSE)
  tibble(
    chr = chromosome,
    start = inDT$X1 * resol + 1,
    end   = inDT$X2 * resol + resol,
    meta.tool = "LPAD"
  ) %>% arrange(chr, start) %>% filter(start < end)
}

collect <- function(caller, chrom, results_dir, resolution) {
  cdir <- file.path(results_dir, caller)
  if (!dir.exists(cdir)) {
    cat(sprintf("[clean] SKIP   %-14s / %-8s (output directory missing)\n", caller, chrom))
    return(empty_tbl(caller))
  }
  stem <- paste0(chrom, "_", resolution)
  tryCatch(
    switch(caller,
      arrowhead    = arrowhead_clean(cdir, chrom),
      topdom       = topdom_clean(file.path(cdir, stem), chrom),
      di           = DI_clean(file.path(cdir, paste0(stem, "_finaldomaincalls.txt")), resolution, chrom),
      mstd         = MSTD_clean(file.path(cdir, paste0(stem, ".bed")), resolution, chrom),
      ontad        = OnTAD_clean(file.path(cdir, stem), resolution, chrom),
      spectraltad  = SpectralTAD_clean(file.path(cdir, paste0(stem, ".bed")), resolution, chrom),
      dedoc        = dedoc_clean(file.path(cdir, paste0(stem, ".hicGraph.deDoc(M)")), resolution, chrom),
      lpad         = LPAD_clean(file.path(cdir, paste0(stem, ".out")), resolution, chrom),
      { cat(sprintf("[clean] WARNING: unknown caller '%s'\n", caller)); empty_tbl(caller) }
    ),
    error = function(e) {
      cat(sprintf("[clean] SKIP   %-14s / %-8s (read error: %s)\n", caller, chrom, conditionMessage(e)))
      empty_tbl(caller)
    }
  )
}

all_results <- list()

for (caller in active_callers) {
  for (chrom in chroms) {
    res <- collect(caller, chrom, results_dir, resolution)
    n   <- if (!is.null(res)) nrow(res) else 0L
    if (n > 0) {
      cat(sprintf("[clean] OK     %-14s / %-8s → %d TADs\n", caller, chrom, n))
      all_results[[length(all_results) + 1]] <- res
    } else if (dir.exists(file.path(results_dir, caller))) {
      cat(sprintf("[clean] EMPTY  %-14s / %-8s (0 TADs found)\n", caller, chrom))
    }
  }
}

if (length(all_results) > 0) {
  combined <- bind_rows(all_results) %>%
    arrange(meta.tool, chr, start)
  outfile <- file.path(outdir, "combined_tads.tsv")
  write_tsv(combined, outfile)
  cat(sprintf("\n[clean] %d total TAD records → %s\n", nrow(combined), outfile))
} else {
  cat("[clean] WARNING: no TAD results found — combined_tads.tsv not written\n")
}
