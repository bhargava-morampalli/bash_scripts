# Usage

## Introduction

This document describes how to use the RNA Modification Coverage Benchmarking Pipeline.

## Quick Start

### 1. Prepare Your Samplesheet

Create a CSV file with your samples. See [samplesheet documentation](samplesheet.md) for details.

**Minimal example:**
```csv
sample,condition,fastq
sample1,native,/path/to/sample1.fastq.gz
sample2,ivt,/path/to/sample2.fastq.gz
```

### 2. Run the Pipeline

**With global parameters:**
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  --outdir results \
  -profile docker
```

**With per-sample parameters:**
```bash
nextflow run main.nf \
  --input samplesheet_with_params.csv \
  --outdir results \
  -profile docker
```

## Running with Different Profiles

### Docker (Recommended)
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  -profile docker
```

### Singularity
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  -profile singularity
```

### Conda
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  -profile conda
```

### Podman
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  -profile podman
```

## Updating the Pipeline

To update to the latest version:

```bash
git pull origin master
```

## Reproducing Previous Runs

The pipeline automatically generates execution reports in `results/pipeline_info/`. To reproduce a previous run, use the same parameters and the `-resume` flag:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  -profile docker \
  -resume
```

## Core Nextflow Arguments

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Available profiles:
- `docker` - Use Docker containers
- `singularity` - Use Singularity containers
- `conda` - Use Conda environments
- `podman` - Use Podman containers
- `test` - A minimal testing dataset

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same.

### `-c`

Specify a custom config file. This allows you to override default settings.

```bash
nextflow run main.nf -c custom.config
```

## Troubleshooting

### Out of Memory Errors

If you encounter out of memory errors, increase resources in `conf/base.config`:

```groovy
withName: 'FILTLONG' {
    memory = '64.GB'
}
```

### Pipeline Fails to Start

Check that:
- Nextflow version is >= 23.04.0
- Docker/Singularity/Conda is installed and running
- Input samplesheet exists and is correctly formatted

### Permission Errors with Docker

Add the `--platform` flag if running on ARM/Apple Silicon:

```bash
nextflow run main.nf -profile docker,arm
```

For more help, see the [Troubleshooting Guide](troubleshooting.md) or open an issue on GitHub.
