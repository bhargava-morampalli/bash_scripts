# RNA Modification Coverage Benchmarking Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**RNA Modification Coverage Benchmarking Pipeline** is a highly flexible, nf-core compliant Nextflow pipeline designed to benchmark RNA modification detection tools across different sequencing coverage levels. The pipeline uses [Filtlong](https://github.com/rrwick/Filtlong) to filter Nanopore direct RNA sequencing data to specific coverage depths.

### Key Features

✨ **Maximum Flexibility**: All Filtlong parameters can be specified **globally** (command-line) or **per-sample** (samplesheet)
📊 **Multi-Coverage Analysis**: Generates datasets at customizable coverage levels (default: 5x to 1000x)
🧬 **Flexible Genome Size Input**: Supports multiple formats (bp, Kbp, Mbp, Gbp)
🔧 **All Filtlong Options**: Exposes every filtlong parameter for fine-grained control
📁 **Organized Outputs**: Results structured by condition and coverage level
🐳 **Container Support**: Docker, Singularity, Podman, Conda ready
📖 **nf-core Compliant**: Follows latest nf-core best practices (DSL2)

### Default Coverage Levels

5x, 10x, 20x, 30x, 40x, 50x, 60x, 70x, 80x, 90x, 100x, 150x, 200x, 500x, 1000x

## Pipeline Output

```
results/
├── native/
│   ├── 5x/
│   │   ├── native_1_5x.fastq.gz
│   │   ├── native_2_5x.fastq.gz
│   │   └── native_3_5x.fastq.gz
│   ├── 10x/
│   └── ... (all coverage levels)
├── ivt/
│   ├── 5x/
│   │   ├── ivt_1_5x.fastq.gz
│   │   ├── ivt_2_5x.fastq.gz
│   │   └── ivt_3_5x.fastq.gz
│   └── ... (all coverage levels)
└── pipeline_info/
    ├── execution_report.html
    ├── execution_timeline.html
    └── pipeline_dag.html
```

## Quick Start

1. **Install Nextflow** (>= 23.04.0)
   ```bash
   curl -s https://get.nextflow.io | bash
   ```

2. **Install a container engine** (Docker, Singularity, Podman) or Conda

3. **Prepare your samplesheet** - See [Samplesheet Format](#samplesheet-format) below

4. **Run the pipeline**:
   ```bash
   # Simple: Using global parameters
   nextflow run main.nf \
     --input samplesheet.csv \
     --genome_size 4.5m \
     --min_length 500 \
     --length_weight 10 \
     --outdir results \
     -profile docker

   # Or: Using per-sample parameters (no global parameters needed)
   nextflow run main.nf \
     --input samplesheet_with_params.csv \
     --outdir results \
     -profile docker
   ```

## Samplesheet Format

### Required Columns

| Column     | Description                                    |
|------------|------------------------------------------------|
| `sample`   | Unique sample identifier                       |
| `condition`| Condition type: `native` or `ivt`              |
| `fastq`    | Full path to FASTQ file (can be gzipped)       |

### Optional Columns (All Filtlong Parameters)

| Column           | Description                                       | Format/Values                      |
|------------------|---------------------------------------------------|------------------------------------|
| `genome_size`    | Genome/transcriptome size for coverage calc       | `4.5m`, `4500000`, `4.5Mbp`, etc.  |
| `min_length`     | Minimum read length threshold                     | Integer (bp)                       |
| `length_weight`  | Weight for read length in scoring                 | Float (default: 10)                |
| `mean_q_weight`  | Weight for mean quality in scoring                | Float (default: 1)                 |
| `window_q_weight`| Weight for window quality in scoring              | Float (default: 1)                 |
| `keep_percent`   | Keep only this percentage of best reads           | Float 0-100                        |
| `min_mean_q`     | Minimum mean quality threshold                    | Float                              |
| `min_window_q`   | Minimum window quality threshold                  | Float                              |
| `window_size`    | Window size for quality assessment                | Integer                            |
| `trim`           | Enable read trimming                              | `true`, `false`, `yes`, `no`       |
| `split`          | Split reads longer than this value                | Integer (bp)                       |
| `assembly`       | Path to reference assembly (FASTA)                | File path                          |
| `illumina_1`     | Path to Illumina R1 for quality assessment        | File path                          |
| `illumina_2`     | Path to Illumina R2 for quality assessment        | File path                          |

**Important**: Per-sample parameters **override** global parameters!

### Example 1: Simple (Global Parameters)

**samplesheet_simple.csv**:
```csv
sample,condition,fastq
native_1,native,/data/native_1.fastq.gz
native_2,native,/data/native_2.fastq.gz
native_3,native,/data/native_3.fastq.gz
ivt_1,ivt,/data/ivt_1.fastq.gz
ivt_2,ivt,/data/ivt_2.fastq.gz
ivt_3,ivt,/data/ivt_3.fastq.gz
```

**Command**:
```bash
nextflow run main.nf \
  --input samplesheet_simple.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  --outdir results \
  -profile docker
```

### Example 2: Per-Sample Parameters

**samplesheet_persample.csv**:
```csv
sample,condition,fastq,genome_size,min_length,length_weight
native_1,native,/data/native_1.fastq.gz,4.5m,500,10
native_2,native,/data/native_2.fastq.gz,4.5Mbp,1000,15
native_3,native,/data/native_3.fastq.gz,4500000,500,10
ivt_1,ivt,/data/ivt_1.fastq.gz,4.5m,500,10
ivt_2,ivt,/data/ivt_2.fastq.gz,4.5m,800,12
ivt_3,ivt,/data/ivt_3.fastq.gz,4.5m,500,10
```

**Command** (no global parameters needed):
```bash
nextflow run main.nf \
  --input samplesheet_persample.csv \
  --outdir results \
  -profile docker
```

### Example 3: Advanced (Mixed Parameters + References)

**samplesheet_advanced.csv**:
```csv
sample,condition,fastq,genome_size,min_length,length_weight,mean_q_weight,window_q_weight,trim,assembly,illumina_1,illumina_2
native_1,native,/data/native_1.fastq.gz,4.5m,500,15,2,2,yes,,,
native_2,native,/data/native_2.fastq.gz,4.5m,1000,20,3,3,no,,,
native_3,native,/data/native_3.fastq.gz,4.5m,500,10,1,1,,/ref/genome.fasta,/ref/R1.fq.gz,/ref/R2.fq.gz
ivt_1,ivt,/data/ivt_1.fastq.gz,4.5m,500,10,1,1,,,,
ivt_2,ivt,/data/ivt_2.fastq.gz,4.5m,800,12,2,2,,,,
ivt_3,ivt,/data/ivt_3.fastq.gz,4.5m,500,10,1,1,yes,,,
```

## Genome Size Formats

The pipeline accepts genome sizes in multiple formats:

| Format       | Example    | Equivalent Bases |
|--------------|------------|------------------|
| Raw bases    | `4500000`  | 4,500,000        |
| Kilobases    | `4500k`    | 4,500,000        |
| Megabases    | `4.5m`     | 4,500,000        |
| Megabases    | `4.5mb`    | 4,500,000        |
| Megabases    | `4.5Mbp`   | 4,500,000        |
| Gigabases    | `3.2g`     | 3,200,000,000    |

Case-insensitive: `4.5m`, `4.5M`, `4.5mb`, `4.5MB`, `4.5Mbp` all work!

## Usage

### Command-Line Parameters

#### Required
- `--input`: Path to samplesheet CSV

#### Optional (Global Defaults)

**Coverage & Output:**
- `--outdir`: Output directory (default: `./results`)
- `--coverage_levels`: Comma-separated coverage levels (default: `'5,10,20,30,40,50,60,70,80,90,100,150,200,500,1000'`)

**Filtlong Parameters** (all optional, can be overridden per-sample):
- `--genome_size`: Genome/transcriptome size (e.g., `4.5m`)
- `--min_length`: Minimum read length (e.g., `500`)
- `--length_weight`: Length weight in scoring (e.g., `10`)
- `--mean_q_weight`: Mean quality weight (e.g., `1`)
- `--window_q_weight`: Window quality weight (e.g., `1`)

**Execution:**
- `-profile`: Execution profile (`docker`, `singularity`, `conda`, `podman`)
- `-resume`: Resume previous run

### Complete Examples

**Example 1: Basic usage with global parameters**
```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  --coverage_levels '5,10,20,50,100,200,500,1000' \
  --outdir results \
  -profile docker \
  -resume
```

**Example 2: Per-sample parameters (maximum flexibility)**
```bash
nextflow run main.nf \
  --input samplesheet_with_params.csv \
  --coverage_levels '10,50,100,500' \
  --outdir results \
  -profile singularity
```

**Example 3: Mixed approach**
```bash
# Global defaults, but some samples override in samplesheet
nextflow run main.nf \
  --input samplesheet_mixed.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  --outdir results \
  -profile docker
```

### Using Different Profiles

**Docker** (recommended):
```bash
-profile docker
```

**Singularity**:
```bash
-profile singularity
```

**Conda**:
```bash
-profile conda
```

**Podman**:
```bash
-profile podman
```

## How It Works

### Workflow Overview

1. **Samplesheet Validation**: Validates format, parses genome sizes, validates parameters
2. **Parameter Merging**: Per-sample parameters override global defaults
3. **Coverage Expansion**: Creates all sample × coverage combinations
4. **Filtlong Filtering**:
   - Calculates target bases: `genome_size × coverage`
   - Applies filtlong with specified parameters
   - Outputs filtered reads
5. **Organization**: Saves results by condition and coverage level

### Filtlong Command

The pipeline builds filtlong commands dynamically. Example:

```bash
filtlong \
  --min_length 500 \
  --length_weight 10 \
  --mean_q_weight 1 \
  --window_q_weight 1 \
  --target_bases 22500000 \
  input.fastq.gz \
  | gzip > output.fastq.gz
```

Where `target_bases = 4.5m × 5x = 22,500,000 bases`

## Filtlong Parameters Explained

### Length-Based Filtering
- `--min_length`: Hard cutoff - discard reads shorter than this
- `--length_weight`: How much to prioritize longer reads (higher = more prioritization)

### Quality-Based Filtering
- `--mean_q_weight`: Weight for average quality across entire read
- `--window_q_weight`: Weight for quality in sliding windows
- `--min_mean_q`: Minimum average quality threshold
- `--min_window_q`: Minimum window quality threshold
- `--window_size`: Size of sliding window for quality assessment

### Output Control
- `--target_bases`: Keep best reads up to this many total bases (calculated from genome_size × coverage)
- `--keep_percent`: Keep only best X% of reads by bases

### Processing Options
- `--trim`: Remove poor-quality regions from read ends
- `--split`: Split reads longer than specified value

### Reference-Based Filtering
- `--assembly` (`-a`): Reference assembly FASTA for scoring
- `--illumina_1` (`-1`): Illumina R1 reads for quality calibration
- `--illumina_2` (`-2`): Illumina R2 reads for quality calibration

## Advanced Configuration

### Custom Coverage Levels

```bash
--coverage_levels '1,2,5,10,15,20,30,40,50,75,100,150,200,300,500,750,1000'
```

### Resource Configuration

Edit `conf/base.config`:

```groovy
withName: 'FILTLONG' {
    cpus   = 8
    memory = '64.GB'
    time   = '24.h'
}
```

## Troubleshooting

### Common Issues

**Issue**: "Genome size not provided"
- **Solution**: Either (1) specify `--genome_size` globally, OR (2) provide `genome_size` column in samplesheet for each sample

**Issue**: Samplesheet validation fails
- **Solution**: Check that:
  - Required columns present: `sample`, `condition`, `fastq`
  - Condition is `native` or `ivt`
  - File paths are correct
  - Genome size format is valid (e.g., `4.5m`, not `4.5 m`)
  - Sample names are unique

**Issue**: Invalid genome size format
- **Solution**: Use formats like: `4500000`, `4.5m`, `4.5M`, `4.5mb`, `4.5Mbp`, `4500k`

**Issue**: Out of memory
- **Solution**: Increase memory in `conf/base.config` for FILTLONG process

**Issue**: Parameters not working
- **Solution**: Remember per-sample parameters override globals. Check samplesheet for conflicting values.

## Parameter Priority

When the same parameter is specified in multiple places:

1. **Highest Priority**: Per-sample value in samplesheet
2. **Medium Priority**: Command-line parameter (`--genome_size`)
3. **Lowest Priority**: Default in `nextflow.config`

Example:
```csv
# samplesheet.csv
sample,condition,fastq,genome_size,min_length
sample1,native,/data/s1.fq.gz,5m,1000
sample2,native,/data/s2.fq.gz,,500
```

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  --min_length 600
```

Result:
- `sample1`: genome_size=5m (from samplesheet), min_length=1000 (from samplesheet)
- `sample2`: genome_size=4.5m (from command-line), min_length=500 (from samplesheet)

## Pipeline Information

### Tools

- **[Filtlong](https://github.com/rrwick/Filtlong) v0.2.1** - Quality filtering for long reads
- **[Nextflow](https://www.nextflow.io/) >= 23.04.0** - Workflow management
- **[Python](https://www.python.org/) 3.11** - Samplesheet validation

### Requirements

- Nextflow >= 23.04.0
- Container engine (Docker/Singularity/Podman) OR Conda
- Input: Nanopore direct RNA sequencing FASTQ files

## Credits

Developed by Bhargava Morampalli for benchmarking RNA modification detection tools across sequencing coverage depths.

### References

- **Filtlong**: Wick RR (2017). Filtlong: quality filtering tool for long reads. https://github.com/rrwick/Filtlong
- **Nextflow**: Di Tommaso P, et al. (2017) Nextflow enables reproducible computational workflows. Nature Biotechnology. 35, 316–319. doi: 10.1038/nbt.3820
- **nf-core**: Ewels PA, et al. (2020) The nf-core framework for community-curated bioinformatics pipelines. Nature Biotechnology. 38, 276–278. doi: 10.1038/s41587-020-0439-x

## License

MIT License - see LICENSE file

## Support

For issues, questions, or suggestions:
- Open an issue: [GitHub Issues](https://github.com/bhargava-morampalli/bash_scripts/issues)
- Check documentation: This README
- Example samplesheets: `assets/` directory
