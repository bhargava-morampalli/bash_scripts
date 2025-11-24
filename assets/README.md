# Example Samplesheets

This directory contains example samplesheets demonstrating different usage patterns for the RNA modification coverage benchmarking pipeline.

## Available Examples

### `samplesheet_simple.csv`

**Purpose**: Minimal samplesheet for global parameter usage

**Description**: Contains only the three required columns (`sample`, `condition`, `fastq`). All filtlong parameters should be provided via command-line arguments (e.g., `--genome_size 4.5m --min_length 500 --length_weight 10`).

**Use Case**: Best for projects where all samples use identical processing parameters.

**Command Example**:
```bash
nextflow run main.nf \
  --input assets/samplesheet_simple.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  -profile docker
```

---

### `samplesheet_standard.csv`

**Purpose**: Standard samplesheet with common per-sample parameters

**Description**: Demonstrates per-sample specification of the most commonly used filtlong parameters (`genome_size`, `min_length`, `length_weight`). Also shows different genome size formats (4.5m, 4.5Mbp, 4500000) for reference.

**Use Case**: Projects where each sample needs different basic filtering parameters.

**Command Example**:
```bash
nextflow run main.nf \
  --input assets/samplesheet_standard.csv \
  -profile docker
```

---

### `samplesheet_advanced.csv`

**Purpose**: Advanced samplesheet showcasing all available parameters

**Description**: Demonstrates the full range of optional parameters including:
- Quality weight parameters (`mean_q_weight`, `window_q_weight`)
- Quality thresholds (`keep_percent`, `min_mean_q`)
- Read processing options (`trim`)
- Reference-based filtering (`assembly`, `illumina_1`, `illumina_2`)

**Use Case**: Complex projects requiring fine-grained control over filtering for different samples, including reference-guided filtering for specific samples.

**Command Example**:
```bash
nextflow run main.nf \
  --input assets/samplesheet_advanced.csv \
  -profile docker
```

---

### `samplesheet_test.csv`

**Purpose**: Minimal test samplesheet for CI/CD and quick testing

**Description**: Lightweight samplesheet used by automated tests and for quick validation that the pipeline runs correctly.

**Use Case**: Automated testing, CI/CD pipelines, and quick sanity checks.

---

## Complete Documentation

For comprehensive documentation on:
- All available samplesheet columns
- Parameter precedence rules (per-sample vs. global)
- Genome size format specifications
- Validation rules and error messages
- Additional usage examples

Please see:
- **[docs/samplesheet.md](../docs/samplesheet.md)** - Complete samplesheet format guide
- **[docs/parameters.md](../docs/parameters.md)** - All pipeline parameters reference
- **[docs/usage.md](../docs/usage.md)** - General usage guide

## Samplesheet Template

Quick template to get started:

```csv
sample,condition,fastq,genome_size,min_length,length_weight
SAMPLE_NAME,native,/path/to/file.fastq.gz,4.5m,500,10
```

Replace:
- `SAMPLE_NAME`: Your unique sample identifier
- `native`: Either `native` or `ivt`
- `/path/to/file.fastq.gz`: Full path to your FASTQ file
- `4.5m`: Your genome/transcriptome size
- `500`: Minimum read length in bp
- `10`: Read length prioritization weight
