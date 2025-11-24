# Module Metadata and Documentation

**Series: Part 10 of 12**

## Introduction

Professional pipelines need professional documentation. In this post, we'll add:

- **meta.yml files**: Machine-readable module metadata
- **Structured docs/**: Organized documentation
- **Usage guides**: How to run the pipeline
- **Parameter references**: Complete parameter documentation

These make your pipeline discoverable, maintainable, and ready for nf-core submission.

## Module Metadata (meta.yml)

### Purpose

The `meta.yml` file describes a module for:
- nf-core module registry
- Automatic documentation generation
- IDE integration and autocomplete
- Search and discovery

### Structure

```yaml
name: module_name
description: Brief description
keywords: [...]
tools: [...]
input: [...]
output: [...]
authors: [...]
maintainers: [...]
```

## FILTLONG meta.yml

**Location**: `modules/local/filtlong/meta.yml`

```yaml
name: filtlong
description: Quality filtering tool for long read sequencing data

keywords:
  - filtering
  - quality control
  - long reads
  - nanopore
  - pacbio
  - coverage
  - target bases

tools:
  - filtlong:
      description: Filtlong is a tool for filtering long reads by quality.
      homepage: https://github.com/rrwick/Filtlong
      documentation: https://github.com/rrwick/Filtlong/blob/main/README.md
      tool_dev_url: https://github.com/rrwick/Filtlong
      licence: ["GPL v3"]

input:
  - meta:
      type: map
      description: |
        Groovy Map containing sample information and filtlong parameters
        e.g. [ id:'test', condition:'native', coverage:'50x', genome_size:4500000, min_length:500, length_weight:10 ]

  - reads:
      type: file
      description: FASTQ file (can be gzipped)
      pattern: "*.{fastq,fq,fastq.gz,fq.gz}"

  - assembly:
      type: file
      description: Optional reference assembly in FASTA format for quality scoring
      pattern: "*.{fasta,fa,fna,fasta.gz,fa.gz,fna.gz}"

  - illumina_1:
      type: file
      description: Optional Illumina R1 reads for quality calibration
      pattern: "*.{fastq,fq,fastq.gz,fq.gz}"

  - illumina_2:
      type: file
      description: Optional Illumina R2 reads for quality calibration
      pattern: "*.{fastq,fq,fastq.gz,fq.gz}"

output:
  - meta:
      type: map
      description: |
        Groovy Map containing sample information
        e.g. [ id:'test', condition:'native', coverage:'50x' ]

  - reads:
      type: file
      description: Filtered FASTQ file (gzipped)
      pattern: "*.fastq.gz"

  - versions:
      type: file
      description: File containing software versions
      pattern: "versions.yml"

authors:
  - "@your-github-username"

maintainers:
  - "@your-github-username"
```

**Key sections**:
- **keywords**: For searchability
- **tools**: External tool information with links
- **input/output**: Detailed parameter documentation
- **pattern**: File extension patterns for validation

## SAMPLESHEET_CHECK meta.yml

**Location**: `modules/local/samplesheet_check/meta.yml`

```yaml
name: samplesheet_check
description: Validate and parse input samplesheet

keywords:
  - validation
  - samplesheet
  - csv

tools:
  - python:
      description: Python programming language
      homepage: https://www.python.org/
      documentation: https://docs.python.org/3/
      licence: ["PSF"]

input:
  - samplesheet:
      type: file
      description: Input samplesheet in CSV format
      pattern: "*.csv"

output:
  - csv:
      type: file
      description: Validated samplesheet
      pattern: "*.csv"

  - versions:
      type: file
      description: File containing software versions
      pattern: "versions.yml"

authors:
  - "@your-github-username"

maintainers:
  - "@your-github-username"
```

## Documentation Structure

### docs/ Directory

```
docs/
├── usage.md        # How to run the pipeline
├── output.md       # Output description
├── parameters.md   # Parameter reference
└── samplesheet.md  # Samplesheet format guide
```

## Usage Documentation

**docs/usage.md**:

```markdown
# Usage Guide

## Quick Start

```bash
nextflow run bhargava-morampalli/bash_scripts \
    --input samplesheet.csv \
    --genome_size 4.5m \
    --outdir results \
    -profile docker
```

## Input Samplesheet

Prepare a comma-separated samplesheet:

```csv
sample,condition,fastq,genome_size
sample1,native,/path/to/sample1.fastq.gz,4.5m
sample2,ivt,/path/to/sample2.fastq.gz,4.5m
```

See [samplesheet.md](samplesheet.md) for complete format documentation.

## Coverage Levels

Specify coverage levels to generate:

```bash
--coverage_levels "10x,50x,100x"
```

Default: `5,10,20,30,40,50,60,70,80,90,100,150,200,500,1000`

## Filtlong Parameters

### Required (one of)
- `--genome_size`: Global genome size, OR
- Per-sample `genome_size` column in samplesheet

### Optional
- `--min_length`: Minimum read length (default: 500)
- `--length_weight`: Length prioritization (default: 10)
- `--mean_q_weight`: Quality weighting (default: 1)

See [parameters.md](parameters.md) for complete reference.

## Profiles

### Docker
```bash
-profile docker
```

### Singularity
```bash
-profile singularity
```

### Conda
```bash
-profile conda
```

### Custom HPC
```bash
-profile your_institution
```

Add custom profile in `conf/your_institution.config`.

## Troubleshooting

### Out of memory
Increase memory in `nextflow.config`:

```groovy
process {
    withName: FILTLONG {
        memory = 16.GB
    }
}
```

### File not found
Ensure paths in samplesheet are absolute or relative to launch directory.
```

## Output Documentation

**docs/output.md**:

```markdown
# Output Documentation

## Directory Structure

```
results/
├── native/
│   ├── 10x/
│   │   ├── sample1_10x.fastq.gz
│   │   └── sample2_10x.fastq.gz
│   ├── 20x/
│   └── 50x/
├── ivt/
│   ├── 10x/
│   └── 20x/
└── pipeline_info/
    ├── samplesheet.valid.csv
    └── software_versions.yml
```

## File Descriptions

### Filtered FASTQ Files

**Location**: `results/{condition}/{coverage}/`

**Format**: `{sample}_{coverage}.fastq.gz`

**Content**: Quality-filtered long reads targeting specified coverage

**Usage**: Input to RNA modification detection tools

### Validated Samplesheet

**Location**: `results/pipeline_info/samplesheet.valid.csv`

**Purpose**: Validated and parsed samplesheet for reproducibility

### Software Versions

**Location**: `results/pipeline_info/software_versions.yml`

**Content**: All tool versions used in analysis

**Format**:
```yaml
FILTLONG:
  filtlong: 0.2.1
SAMPLESHEET_CHECK:
  python: 3.11.0
```

## Downstream Analysis

### Using filtered reads

```bash
# Example: Run modification caller
modification_caller \
    --input results/native/50x/sample1_50x.fastq.gz \
    --genome reference.fa \
    --output modifications.bed
```

### Comparing across coverage levels

```bash
# Process each coverage level
for cov in 10x 20x 50x 100x; do
    modification_caller \
        --input results/native/${cov}/sample1_${cov}.fastq.gz \
        --genome reference.fa \
        --output mods_${cov}.bed
done

# Compare results
compare_modifications mods_*.bed
```
```

## Parameter Documentation

**docs/parameters.md**:

```markdown
# Parameter Reference

## Required Parameters

### `--input`
**Type**: file path
**Format**: CSV
**Description**: Path to samplesheet with sample information

**Example**: `--input samplesheet.csv`

### `--outdir`
**Type**: directory path
**Default**: `./results`
**Description**: Output directory for results

## Coverage Parameters

### `--coverage_levels`
**Type**: string (comma-separated)
**Default**: `5,10,20,30,40,50,60,70,80,90,100,150,200,500,1000`
**Description**: Coverage depths to generate

**Example**: `--coverage_levels "10x,50x,100x"`

### `--genome_size`
**Type**: string
**Format**: Number with optional suffix (k/K, m/M, g/G, bp)
**Description**: Global genome size for coverage calculation

**Examples**:
- `--genome_size 4.5m` (4.5 megabases)
- `--genome_size 4500000` (4.5 million bases)
- `--genome_size 4.5Mbp` (4.5 megabases)

**Note**: Can be overridden per-sample in samplesheet

## Filtlong Filtering Parameters

### `--min_length`
**Type**: integer
**Default**: 500
**Description**: Minimum read length in base pairs

### `--length_weight`
**Type**: number
**Default**: 10
**Description**: Weight for read length in filtlong scoring

**Range**: 0 to infinity
**Higher values**: Strongly favor longer reads

### `--mean_q_weight`
**Type**: number
**Default**: 1
**Description**: Weight for mean quality score

### `--window_q_weight`
**Type**: number
**Default**: 1
**Description**: Weight for quality score in sliding windows

### `--keep_percent`
**Type**: number
**Range**: 0-100
**Description**: Keep top X percent of reads by score

### `--min_mean_q`
**Type**: number
**Description**: Minimum mean quality score threshold

### `--min_window_q`
**Type**: number
**Description**: Minimum window quality score threshold

## Parameter Precedence

Parameters can be specified at three levels:

1. **Per-sample** (highest priority) - in samplesheet
2. **Global** (medium) - command-line flags
3. **Default** (lowest) - nextflow.config

**Example**:
```bash
# Global length_weight = 5
nextflow run main.nf --length_weight 5 --input samples.csv

# But sample1 in CSV has length_weight=10
# Result: sample1 uses 10, others use 5
```
```

## Samplesheet Documentation

**docs/samplesheet.md**:

```markdown
# Samplesheet Format

## Required Columns

| Column | Type | Description |
|--------|------|-------------|
| sample | string | Unique sample identifier |
| condition | string | Experimental condition (native or ivt) |
| fastq | path | Path to FASTQ file |

## Optional Columns

| Column | Type | Description |
|--------|------|-------------|
| genome_size | string | Genome/transcriptome size (e.g., 4.5m) |
| min_length | integer | Minimum read length (bp) |
| length_weight | number | Read length weight |
| mean_q_weight | number | Mean quality weight |
| window_q_weight | number | Window quality weight |
| keep_percent | number | Percent of reads to keep (0-100) |
| min_mean_q | number | Minimum mean quality |
| min_window_q | number | Minimum window quality |
| window_size | integer | Sliding window size |
| trim | boolean | Trim read ends (true/false) |
| split | integer | Split reads longer than this |
| assembly | path | Reference genome FASTA |
| illumina_1 | path | Illumina R1 reads |
| illumina_2 | path | Illumina R2 reads |

## Examples

### Simple (Global Parameters)

```csv
sample,condition,fastq
sample1,native,/data/sample1.fastq.gz
sample2,native,/data/sample2.fastq.gz
sample3,ivt,/data/sample3.fastq.gz
```

Use with:
```bash
nextflow run main.nf --input samples.csv --genome_size 4.5m
```

### Standard (Per-Sample Parameters)

```csv
sample,condition,fastq,genome_size,min_length,length_weight
ecoli_1,native,/data/ec1.fq.gz,4.6m,500,10
yeast_1,native,/data/y1.fq.gz,12m,800,15
```

### Advanced (Reference-Based Filtering)

```csv
sample,condition,fastq,genome_size,min_length,assembly,illumina_1,illumina_2
sample1,native,ont.fq.gz,4.5m,500,ref.fa,R1.fq.gz,R2.fq.gz
```

## Validation Rules

- **sample**: Must be unique, no spaces
- **condition**: Must be 'native' or 'ivt'
- **fastq**: Must end in .fastq, .fq, .fastq.gz, or .fq.gz
- **genome_size**: Number with optional k/m/g suffix
- **Numeric fields**: Must be valid numbers
- **Boolean fields**: true/false, yes/no, 1/0
```

## README Update

Update main `README.md` with links to documentation:

```markdown
# RNA Modification Coverage Benchmarking Pipeline

## Documentation

- [Usage Guide](docs/usage.md) - How to run the pipeline
- [Output Documentation](docs/output.md) - Understanding results
- [Parameter Reference](docs/parameters.md) - Complete parameter guide
- [Samplesheet Format](docs/samplesheet.md) - Input file format

## Quick Start

```bash
nextflow run bhargava-morampalli/bash_scripts \
    --input samplesheet.csv \
    --genome_size 4.5m \
    -profile docker
```

See [docs/usage.md](docs/usage.md) for detailed usage instructions.

## Citation

If you use this pipeline, please cite:

```bibtex
@software{rna_coverage_benchmark,
  author = {Your Name},
  title = {RNA Modification Coverage Benchmarking Pipeline},
  url = {https://github.com/bhargava-morampalli/bash_scripts},
  year = {2024}
}
```

Also cite filtlong:
```bibtex
@software{filtlong,
  author = {Ryan Wick},
  title = {Filtlong},
  url = {https://github.com/rrwick/Filtlong},
  year = {2018}
}
```
```

## Best Practices

1. **Complete meta.yml**: Document all inputs/outputs
2. **Clear examples**: Real-world use cases
3. **Link between docs**: Easy navigation
4. **Keep updated**: Update docs with code changes
5. **Version information**: Include in all docs
6. **Troubleshooting section**: Common issues
7. **Citation information**: Proper attribution

## What's Next?

Our pipeline is now fully documented! In **Post 11**, we'll set up automated CI/CD:

- GitHub Actions workflows
- Automated testing
- Code quality checks
- Branch protection

---

**Previous**: [Part 9 - Testing with nf-test](blogpost_9_comprehensive_testing_nftest.md)
**Next**: [Part 11 - CI/CD with GitHub Actions](blogpost_11_cicd_github_actions.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. **Module Metadata and Documentation** ← You are here
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
