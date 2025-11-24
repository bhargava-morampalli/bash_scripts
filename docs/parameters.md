# Parameters

## Introduction

This document describes all available pipeline parameters.

## Required Parameters

### `--input`

- **Type:** String (file path)
- **Description:** Path to input samplesheet in CSV format
- **Example:** `--input samplesheet.csv`

See [samplesheet documentation](samplesheet.md) for format details.

### `--outdir`

- **Type:** String (directory path)
- **Default:** `./results`
- **Description:** Output directory for pipeline results
- **Example:** `--outdir /path/to/results`

## Coverage Parameters

### `--coverage_levels`

- **Type:** String (comma-separated)
- **Default:** `'5,10,20,30,40,50,60,70,80,90,100,150,200,500,1000'`
- **Description:** Coverage levels to generate filtered datasets for
- **Example:** `--coverage_levels '10,50,100,500,1000'`

## Filtlong Parameters (Global Defaults)

These parameters set global defaults. Per-sample values in the samplesheet override these.

### `--genome_size`

- **Type:** String
- **Default:** `null` (must specify globally or per-sample)
- **Description:** Genome/transcriptome size for coverage calculation
- **Formats:** `4500000` (bases), `4.5m` (megabases), `4.5Mbp`, `4500k` (kilobases), `3.2g` (gigabases)
- **Example:** `--genome_size 4.5m`
- **Note:** Case-insensitive; per-sample values override this

### `--min_length`

- **Type:** Integer
- **Default:** `null`
- **Description:** Minimum read length threshold in base pairs
- **Example:** `--min_length 500`
- **Note:** Reads shorter than this are discarded

### `--length_weight`

- **Type:** Float
- **Default:** `null`
- **Description:** Weight for read length in Filtlong scoring
- **Example:** `--length_weight 10`
- **Note:** Higher values prioritize longer reads

### `--mean_q_weight`

- **Type:** Float
- **Default:** `null`
- **Description:** Weight for mean quality in Filtlong scoring
- **Example:** `--mean_q_weight 1`

### `--window_q_weight`

- **Type:** Float
- **Default:** `null`
- **Description:** Weight for window quality in Filtlong scoring
- **Example:** `--window_q_weight 1`

## Advanced Parameters

These parameters are rarely needed but available for advanced use cases.

### `--publish_dir_mode`

- **Type:** String
- **Default:** `copy`
- **Options:** `symlink`, `rellink`, `link`, `copy`, `copyNoFollow`, `move`
- **Description:** Method for publishing files to output directory
- **Example:** `--publish_dir_mode symlink`

### `--max_cpus`

- **Type:** Integer
- **Default:** `16`
- **Description:** Maximum CPUs to use for any single job
- **Example:** `--max_cpus 8`

### `--max_memory`

- **Type:** String
- **Default:** `128.GB`
- **Description:** Maximum memory to use for any single job
- **Example:** `--max_memory 64.GB`

### `--max_time`

- **Type:** String
- **Default:** `240.h`
- **Description:** Maximum time for any single job
- **Example:** `--max_time 48.h`

## Parameter Priority

When the same parameter is specified in multiple places:

1. **Highest Priority:** Per-sample value in samplesheet
2. **Medium Priority:** Command-line parameter
3. **Lowest Priority:** Default in `nextflow.config`

### Example

**Samplesheet:**
```csv
sample,condition,fastq,genome_size,min_length
sample1,native,sample1.fq.gz,5m,1000
sample2,native,sample2.fq.gz,,500
```

**Command:**
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  --min_length 600
```

**Result:**
- `sample1`: genome_size=5m (from samplesheet), min_length=1000 (from samplesheet)
- `sample2`: genome_size=4.5m (from command-line), min_length=500 (from samplesheet)

## Genome Size Formats

The pipeline accepts various genome size formats:

| Format | Example | Equivalent Bases |
|--------|---------|------------------|
| Raw bases | `4500000` | 4,500,000 |
| Kilobases | `4500k` or `4500K` | 4,500,000 |
| Megabases | `4.5m` or `4.5M` | 4,500,000 |
| Megabases | `4.5mb` or `4.5MB` | 4,500,000 |
| Megabases | `4.5Mbp` or `4.5MBP` | 4,500,000 |
| Gigabases | `3.2g` or `3.2G` | 3,200,000,000 |

**Note:** All formats are case-insensitive.

## Complete Example

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --outdir results \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  --mean_q_weight 1 \
  --window_q_weight 1 \
  --coverage_levels '5,10,20,50,100,200,500,1000' \
  --max_cpus 16 \
  --max_memory 64.GB \
  -profile docker \
  -resume
```
