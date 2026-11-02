# hic_tad_pipeline

A Nextflow pipeline that takes raw Hi-C contact matrices (`.cool` / `.mcool` / `.hic`), calls TADs with up to
eight TAD callers, merges their results into one table, and computes consensus TADs across callers with
[consensusTADs](https://github.com/CSOgroup/consensusTADs).

```
raw Hi-C ──► target resolution ──► add chr prefix ──► subset chroms ──► normalize ──► per-caller input formats
                                                                                            │
           ┌─────────────┬──────────┬──────┬──────┬───────┬─────────────┬───────┬───────────┘
           ▼             ▼          ▼      ▼      ▼       ▼             ▼       ▼
       Arrowhead      TopDom       DI    MSTD   OnTAD  SpectralTAD    deDoc   LPAD
           └─────────────┴──────────┴──────┴──┬───┴───────┴─────────────┴───────┘
                                              ▼
                              clean & merge results (combined_tads.tsv)
                                              ▼
                                  consensus TADs (consensusTADs)
```

Contents: [Requirements](#1-requirements) · [Build the images](#2-build-the-images-once) ·
[Quick start](#3-quick-start) · [Parameters](#4-parameters) · [What the pipeline does](#5-what-the-pipeline-does) ·
[Outputs](#6-outputs) · [FAQ](#7-faq) · [Directory layout](#8-directory-layout) · [Citation](#9-citation)

## 1. Requirements

| Dependency | Version | Notes |
|---|---|---|
| Nextflow | ≥ 25.10 | Uses the workflow `output {}` publishing syntax |
| Docker | Any recent version | The current user must be able to run `docker` directly (member of the `docker` group) |
| Java | 17+ | Required by Nextflow itself |

Every analysis tool runs inside a Docker image; nothing else (cooler, hictk, R, …) has to be installed on
the host. Containers run as the calling user (`-u $(id -u):$(id -g)`), so output files belong to you.

> The Nextflow work directory (`work/` under the launch directory by default, or `-w <dir>`) must be on a disk
> the Docker daemon can see. Do not put it under a per-user private `/tmp` (as some systems use); tasks would fail
> with `.command.sh: No such file or directory`.

### Install Nextflow

Skip this if `nextflow -version` already reports ≥ 25.10 and `java -version` reports 17 or newer.

```bash
# 1. Java 17+ (pick one)
sudo apt install openjdk-17-jre-headless      # Debian/Ubuntu
conda install -c conda-forge openjdk=17       # or via conda, no root needed

# 2. Nextflow
curl -s https://get.nextflow.io | bash        # downloads a `nextflow` launcher into the current directory
chmod +x nextflow
mv nextflow ~/.local/bin/                     # any directory on your $PATH

# 3. Check
nextflow -version
```

Without root, `conda install -c bioconda nextflow` also works, but check that the installed version is ≥ 25.10
(`nextflow -version`); the bioconda package can lag behind. To pin a version with the launcher:
`NXF_VER=25.10.0 nextflow -version`.

Docker must be installed separately, see the [Docker install guide](https://docs.docker.com/engine/install/). Then add
yourself to the `docker` group (`sudo usermod -aG docker $USER`, log out and back in) and check that
`docker run --rm hello-world` works without `sudo`.

## 2. Build the images (once)

```bash
bash /path/to/hic_tad_pipeline/build_docker_images.sh
```

## 3. Quick start

Single sample:

```bash
nextflow run /path/to/hic_tad_pipeline \
    --input sample.mcool \
    --resolution 50000 \
    --outdir results
```

Multiple samples (a samplesheet is recommended, so you choose the sample names):

```bash
nextflow run /path/to/hic_tad_pipeline \
    --input samplesheet.csv \
    --resolution 50000 \
    --species human \
    --outdir results \
    -resume
```

`samplesheet.csv` (see [assets/samplesheet_example.csv](assets/samplesheet_example.csv)):

```csv
sample,file
ctrl,/data/hic/ctrl.mcool
treat,data/treat.hic
```

- The header must be exactly `sample,file`.
- `sample` must be unique and may only contain letters, digits, `.`, `_` and `-` (it is used in file names).
- A relative `file` path is resolved against the directory containing the samplesheet.
- Samples in one samplesheet may mix formats (`.cool`, `.mcool`, `.hic`).

You can also pass a quoted glob; each matching file becomes one sample, named after the file without its extension:

```bash
nextflow run /path/to/hic_tad_pipeline --input '/data/hic/*.mcool' --resolution 50000
```

A quick trial run on two chromosomes with all eight callers:

```bash
nextflow run /path/to/hic_tad_pipeline --input sample.mcool --resolution 50000 \
    --chroms chr21,chr22 --callers arrowhead,topdom,di,mstd,ontad,spectraltad,dedoc,lpad
```

After a failure or a parameter change, add `-resume` to reuse the steps that already completed.

## 4. Parameters

| Parameter | Default | Description |
|---|---|---|
| `--input` | **required** | `.cool`/`.mcool`/`.hic` path (quoted globs allowed), or a `.csv` samplesheet |
| `--resolution` | **required** | Target bin size in bp, e.g. `50000`. See [5.2](#52-pick-the-target-resolution) for how it is obtained |
| `--outdir` | `results` | Output directory |
| `--norm_type` | `ICE` | `ICE`, `ICE_cis`, `KR` or `NONE`; see [5.5](#55-normalize) |
| `--callers` | `arrowhead,topdom,di,mstd,ontad,spectraltad` | Comma-separated subset of `arrowhead`, `topdom`, `di`, `mstd`, `ontad`, `spectraltad`, `dedoc`, `lpad` |
| `--species` | empty | `human` (chr1-22 + chrX) or `mouse` (chr1-19 + chrX); when empty, detected automatically (see [5.4](#54-subset-chromosomes)) |
| `--chroms` | empty | Comma-separated chromosome list with `chr` prefix, e.g. `chr1,chr2`; overrides `--species` |
| `--consensus_threshold` | `0` | Lowest MoC threshold reached by the iterative consensus selection |
| `--consensus_step` | `-0.05` | Threshold decrement per consensus round; must be negative |
| `--nproc` | `4` | Threads for hictk/cooler/juicer_tools during preprocessing, and number of parallel workers for the consensus step |

All parameters are validated before anything runs: missing required parameters, unknown caller names, an invalid
`--norm_type`/`--species`, a non-negative `--consensus_step`, a non-integer `--resolution`, missing input files,
unsupported file extensions, and duplicate or invalid sample names all stop the pipeline immediately with a message.

## 5. What the pipeline does

Each sample goes through the steps below independently; samples run in parallel.

### 5.1 Read the input

- `.cool`: used as is.
- `.mcool`: one resolution is extracted from `::resolutions/<bp>` (which one: see 5.2).
- `.hic`: converted to `.cool` with `hictk convert`. If the file contains explicit zero-count pixels (which makes
  hictk fail), the matrix is dumped, zero-count pixels are dropped, and it is reloaded.

The original input files are never modified; the first step works on a copy.

### 5.2 Pick the target resolution

- If the input already has `--resolution`, that resolution is used directly.
- Otherwise the pipeline takes the **coarsest** available resolution that divides `--resolution` evenly and
  aggregates it with `hictk zoomify` (only raw counts are aggregated; any existing weights are discarded and
  recomputed in 5.5). If no available resolution divides it, the run stops with an error listing the available
  resolutions.

### 5.3 Add the `chr` prefix

Chromosome names without a `chr` prefix (`1`, `X`, …) are renamed to `chr1`, `chrX`, …; names that already have it
are left untouched. Everything downstream (including `--chroms`) therefore uses `chr`-prefixed names.

### 5.4 Subset chromosomes

Only the selected chromosomes are kept; all other bins and every pixel touching them (including their
inter-chromosomal contacts) are removed, and bins are renumbered. The selection is:

1. `--chroms` if given (every listed chromosome must exist in the input, otherwise the run stops);
2. otherwise `--species`: `human` → chr1–chr22 + chrX, `mouse` → chr1–chr19 + chrX;
3. otherwise automatic: `human` if the input contains `chr20`, else `mouse`.

chrY, chrM and unplaced/alt contigs are therefore dropped by default. If the input already contains exactly the
selected chromosomes, the file is passed through unchanged.

### 5.5 Normalize

| `--norm_type` | Method | Output |
|---|---|---|
| `ICE` | `cooler balance` on all contacts of the selected chromosomes (cis + trans) | `.cool`, weights in column `weight` |
| `ICE_cis` | `cooler balance --cis-only` (each chromosome balanced on its own intra-chromosomal contacts) | `.cool`, weights in column `ICE_cis` |
| `KR` | converted to `.hic` with hictk, then `juicer_tools addNorm -k KR` | `.hic` with a KR normalization vector |
| `NONE` | no normalization; raw counts | `.cool` |

### 5.6 Convert to caller input formats

Only the formats needed by the enabled callers are generated, one file per chromosome, named
`<chrom>_<resolution>`:

| Format | Used by | Content |
|---|---|---|
| `<sample>.balanced.forcaller.hic` | Arrowhead | `.hic` file. For `ICE`/`ICE_cis`, the normalized values are written as the counts (Arrowhead then runs with `-k NONE`); for `KR` the KR vector is kept (Arrowhead runs with `-k KR`); for `NONE`, raw counts |
| `dense_matrix_with_coords/<chrom>_<res>.matrix` | TopDom, DI | Tab-separated dense N×N matrix; each row is prefixed with `chrom  start  end` |
| `dense_matrix_no_coords/<chrom>_<res>.matrix` | MSTD, OnTAD, SpectralTAD, LPAD | Tab-separated dense N×N matrix, values only |
| `sparse_matrix_bin1_dedoc/<chrom>_<res>.hicGraph` | deDoc | deDoc graph format: first line is the number of bins, then `bin_i  bin_j  value` with 1-based bin indices, diagonal excluded |

Values are the normalized contacts from 5.5 (or raw counts for `NONE`).

### 5.7 Call TADs

Each enabled caller runs once per sample on all given chromosomes.

`deDoc` and `LPAD` are not in the default `--callers`; add them explicitly if wanted.

**Failure handling.** A failing caller only produces a warning and is left out of the results; the remaining callers
and the consensus step continue. If **every** enabled caller fails for a sample, the pipeline stops with
`All enabled callers failed for sample(s): …`.

### 5.8 Clean and merge

Every caller's output is converted to a common table, `caller_results/combined_tads.tsv`:

| Column | Meaning |
|---|---|
| `chr` | chromosome (`chr`-prefixed) |
| `start` | TAD start, **1-based** bp (bin start + 1) |
| `end` | TAD end, bp, inclusive (bin end) |
| `meta.tool` | `arrowhead`, `TopDom`, `DI`, `MSTD`, `OnTAD`, `SpectralTAD`, `deDoc` or `LPAD` |

### 5.9 Consensus TADs

`consensusTADs::generate_tad_consensus_hierarchy()` is run on `combined_tads.tsv` with
`threshold = --consensus_threshold`, `step = --consensus_step` and `--nproc` parallel workers. It selects TADs that
are supported across callers (measured by the Measure of Concordance, MoC), starting from the strictest threshold
and lowering it by `step` each round down to `threshold`.

## 6. Outputs

```
<outdir>/
└── <sample>/
    ├── balanced/
    │   └── <sample>.balanced.cool        # normalized matrix (.hic for norm_type=KR)
    ├── caller_input/                     # caller input matrices (only formats used by the enabled callers)
    │   ├── <sample>.balanced.forcaller.hic
    │   ├── dense_matrix_with_coords/
    │   ├── dense_matrix_no_coords/
    │   └── sparse_matrix_bin1_dedoc/
    ├── caller_results/
    │   ├── <caller>/                     # raw output of each caller that succeeded
    │   └── combined_tads.tsv             # all callers in one table (see 5.8)
    └── consensus_tads/
        ├── consensus_tads.tsv
        └── consensus_tads_merged.tsv
```

`consensus_tads.tsv`:

| Column | Meaning |
|---|---|
| `chr`, `start`, `end` | consensus TAD, same coordinate convention as `combined_tads.tsv` |
| `score_source` | the caller TADs supporting it, e.g. `MSTD_1; SpectralTAD_1` |
| `threshold` | MoC threshold at which it was selected |
| `round` | consensus round in which it was selected |

`consensus_tads_merged.tsv` has the four columns of `combined_tads.tsv`: the consensus TADs (with
`meta.tool = consensus_round<N>`) followed by every caller TAD, convenient for plotting all tracks together.

## 7. FAQ

- **Why did a caller produce no folder in `caller_results/`?** It failed. Look for the warning in the console/log,
  then read `.command.err` / `.command.out` in the `work/xx/xxxxxx` directory it points to.
- **Memory.** Arrowhead always starts Java with `-Xmx16g`. DI, LPAD, TopDom and others load whole-chromosome dense
  matrices, so memory grows quadratically with finer resolution. At 10 kb or finer, try one or two chromosomes with
  `--chroms` first.
- **Editing scripts under `modules/*/scripts/` is not picked up by `-resume`.** The scripts are mounted into the
  containers, and Nextflow's cache only looks at the command text in the `.nf` files. After editing a script, rerun
  without `-resume` or with a different `-w` work directory.
- **Running on a cluster.** Set `process.executor` (e.g. `slurm`) and any queue/memory settings in your own config
  file and pass it with `-c my.config`. `CHOOSE_RESOLUTION`, `BALANCE` and `CONSENSUS_TADS` request `--nproc` CPUs.
- **Changing a caller's settings.** Edit the `.nf` file or the scripts under `modules/<caller>/`, then rerun without `-resume`.

## 8. Directory layout

```
hic_tad_pipeline/
├── main.nf                    # entry point: parameter validation + orchestration
├── nextflow.config            # parameter defaults, Docker, resources and error handling
├── build_docker_images.sh     # builds all images
├── subworkflows/
│   ├── prepare_input.nf       # steps 5.1–5.6
│   └── call_tads.nf           # steps 5.7–5.8
├── modules/<name>/<name>.nf   # one process per step; its scripts are in modules/<name>/scripts/
├── common_scripts/            # hictk helpers shared by several modules (.hic conversion, zoomify, zero-pixel fix)
├── docker/                    # Dockerfiles; DI's Perl/MATLAB scripts are in docker/di_scripts/
└── assets/samplesheet_example.csv
```

## 9. Citation

If you use this pipeline in published work, please cite:

> Pumin Li, Andras Hatos, Miljan Petrovic, Gian Marco Franceschini, Luca Nanni, Daniele Tavernari,
> Giovanni Ciriello. TADShop: systematic benchmarking and identification of topologically associating
> domains. *Nature Methods* **23**(6), 1227–1235 (2026). https://doi.org/10.1038/s41592-026-03100-2

The consensus TAD approach used here is described in the
[Methods section](https://www.nature.com/articles/s41592-026-03100-2#Sec6) of the paper.
