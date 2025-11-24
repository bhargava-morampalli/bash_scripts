# RNA Modification Coverage Benchmarking Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**RNA Modification Coverage Benchmarking Pipeline** is a bioinformatics pipeline designed to benchmark RNA modification detection tools across different sequencing coverage levels. The pipeline uses [Filtlong](https://github.com/rrwick/Filtlong) to filter Nanopore direct RNA sequencing data to specific coverage depths, enabling systematic evaluation of how coverage affects modification detection accuracy.

### Pipeline Features

- **Coverage-based filtering**: Automatically generates datasets at multiple coverage levels (5x to 1000x)
- **Optimized for long reads**: Prioritizes longer reads (≥500 bp) with configurable length weights
- **Organized outputs**: Structured output directories by condition (native/IVT) and coverage level
- **nf-core compliant**: Follows nf-core best practices for reproducibility and portability
- **Container support**: Docker, Singularity, Podman, Conda environments available
- **Resource optimization**: Automatic resource scaling and retry logic

### Default Coverage Levels

The pipeline generates filtered datasets at the following coverage levels:
- **Low coverage**: 5x, 10x, 20x, 30x, 40x, 50x, 60x, 70x, 80x, 90x
- **Medium coverage**: 100x, 150x, 200x
- **High coverage**: 500x, 1000x

## Pipeline Output

The pipeline organizes outputs into separate directories by condition and coverage level:

```
results/
├── native/
│   ├── 5x/
│   │   ├── native_1_5x.fastq.gz
│   │   ├── native_2_5x.fastq.gz
│   │   └── native_3_5x.fastq.gz
│   ├── 10x/
│   │   ├── native_1_10x.fastq.gz
│   │   ├── native_2_10x.fastq.gz
│   │   └── native_3_10x.fastq.gz
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
    ├── execution_trace.txt
    └── pipeline_dag.html
```

## Quick Start

1. **Install Nextflow** (>= 23.04.0)
   ```bash
   curl -s https://get.nextflow.io | bash
   ```

2. **Install a container engine** (Docker, Singularity, Podman) or Conda

3. **Prepare your samplesheet** (`samplesheet.csv`):
   ```csv
   sample,condition,fastq
   native_1,native,/path/to/native_1.fastq.gz
   native_2,native,/path/to/native_2.fastq.gz
   native_3,native,/path/to/native_3.fastq.gz
   ivt_1,ivt,/path/to/ivt_1.fastq.gz
   ivt_2,ivt,/path/to/ivt_2.fastq.gz
   ivt_3,ivt,/path/to/ivt_3.fastq.gz
   ```

4. **Run the pipeline**:
   ```bash
   nextflow run main.nf \
     --input samplesheet.csv \
     --genome_size 4.5m \
     --outdir results \
     -profile docker
   ```

## Input Samplesheet

The input samplesheet must be a CSV file with the following columns:

| Column     | Description                                              |
|------------|----------------------------------------------------------|
| `sample`   | Custom sample name (must be unique)                      |
| `condition`| Condition type: `native` or `ivt`                        |
| `fastq`    | Full path to FASTQ file (can be gzipped)                 |

### Example Samplesheet

```csv
sample,condition,fastq
native_rep1,native,/data/native/rep1.fastq.gz
native_rep2,native,/data/native/rep2.fastq.gz
native_rep3,native,/data/native/rep3.fastq.gz
ivt_rep1,ivt,/data/ivt/rep1.fastq.gz
ivt_rep2,ivt,/data/ivt/rep2.fastq.gz
ivt_rep3,ivt,/data/ivt/rep3.fastq.gz
```

## Usage

### Required Parameters

- `--input`: Path to input samplesheet (CSV format)
- `--genome_size`: Size of genome/transcriptome for coverage calculation
  - Examples: `4.5m` (4.5 megabases), `100k` (100 kilobases), `3g` (3 gigabases)
  - This is used to calculate target bases: `coverage × genome_size`

### Optional Parameters

#### Coverage Options
- `--coverage_levels`: Comma-separated list of coverage levels (default: `'5,10,20,30,40,50,60,70,80,90,100,150,200,500,1000'`)
  - Example: `--coverage_levels '10,50,100,500'`

#### Filtlong Options
- `--min_length`: Minimum read length threshold in bp (default: `500`)
- `--length_weight`: Weight for read length in scoring (default: `10`, higher values prioritize longer reads)
- `--mean_q_weight`: Weight for mean quality in scoring (default: `1`)
- `--window_q_weight`: Weight for window quality in scoring (default: `1`)

#### Output Options
- `--outdir`: Output directory path (default: `'./results'`)
- `--publish_dir_mode`: Method for publishing files (default: `'copy'`)

### Complete Example

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  --outdir results \
  --coverage_levels '5,10,20,50,100,200,500,1000' \
  --min_length 500 \
  --length_weight 10 \
  -profile docker \
  -resume
```

### Using Different Profiles

**Docker** (recommended):
```bash
nextflow run main.nf --input samplesheet.csv --genome_size 4.5m -profile docker
```

**Singularity**:
```bash
nextflow run main.nf --input samplesheet.csv --genome_size 4.5m -profile singularity
```

**Conda**:
```bash
nextflow run main.nf --input samplesheet.csv --genome_size 4.5m -profile conda
```

**Podman**:
```bash
nextflow run main.nf --input samplesheet.csv --genome_size 4.5m -profile podman
```

## How It Works

### Workflow Overview

1. **Samplesheet Validation**: Validates input samplesheet format and file paths
2. **Coverage Calculation**: For each sample and coverage level, calculates target bases: `genome_size × coverage`
3. **Read Filtering**: Runs Filtlong with:
   - Target bases calculated from genome size and desired coverage
   - Minimum read length filter (≥500 bp by default)
   - Length weighting to prioritize longer reads
4. **Output Organization**: Saves filtered reads organized by condition and coverage level

### Filtlong Command

For each sample-coverage combination, the pipeline runs:

```bash
filtlong \
  --min_length 500 \
  --length_weight 10 \
  --mean_q_weight 1 \
  --window_q_weight 1 \
  --target_bases <calculated_bases> \
  input.fastq.gz \
  | gzip > output.fastq.gz
```

Where `target_bases = genome_size × coverage_level`

## Advanced Configuration

### Custom Coverage Levels

You can specify any coverage levels you need:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  --genome_size 4.5m \
  --coverage_levels '1,5,10,25,50,75,100,250,500,750,1000' \
  -profile docker
```

### Adjusting Filtlong Parameters

Prioritize longer reads even more:
```bash
--length_weight 20
```

Adjust minimum read length:
```bash
--min_length 1000
```

Consider quality scores more heavily:
```bash
--mean_q_weight 5 --window_q_weight 3
```

### Resource Configuration

Edit `conf/base.config` to adjust computational resources:

```groovy
withName: 'FILTLONG' {
    cpus   = 8
    memory = '32.GB'
    time   = '12.h'
}
```

## Troubleshooting

### Common Issues

**Issue**: Pipeline fails with "genome_size not provided"
- **Solution**: Always specify `--genome_size` parameter with appropriate suffix (k, m, or g)

**Issue**: Samplesheet validation fails
- **Solution**: Check that:
  - CSV has headers: `sample,condition,fastq`
  - All file paths exist and are accessible
  - Condition is either `native` or `ivt`
  - Sample names are unique

**Issue**: Out of memory errors
- **Solution**: Increase memory in `conf/base.config` for FILTLONG process

## Pipeline Information

### Tools Used

- [Filtlong](https://github.com/rrwick/Filtlong) v0.2.1 - Quality filtering for long reads
- [Nextflow](https://www.nextflow.io/) - Workflow management
- [Python](https://www.python.org/) 3.11 - Samplesheet validation

### Requirements

- Nextflow >= 23.04.0
- One of: Docker, Singularity, Podman, Conda
- Input: Nanopore direct RNA sequencing FASTQ files

## Credits

This pipeline was developed by Bhargava Morampalli for benchmarking RNA modification detection tools.

### References

- **Filtlong**: Wick RR (2017). Filtlong: quality filtering tool for long reads. https://github.com/rrwick/Filtlong
- **Nextflow**: Di Tommaso P, et al. (2017) Nextflow enables reproducible computational workflows. Nature Biotechnology. 35, 316–319. doi: 10.1038/nbt.3820
- **nf-core**: Ewels PA, et al. (2020) The nf-core framework for community-curated bioinformatics pipelines. Nature Biotechnology. 38, 276–278. doi: 10.1038/s41587-020-0439-x

## License

This pipeline is released under the MIT License.

## Support

For issues, questions, or suggestions, please open an issue on the [GitHub repository](https://github.com/bhargava-morampalli/bash_scripts/issues).
