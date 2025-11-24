# Samplesheet Format

## Introduction

The samplesheet is a CSV file that tells the pipeline which FASTQ files to process and what parameters to use.

## Required Columns

| Column | Description | Example |
|--------|-------------|---------|
| `sample` | Unique sample identifier | `native_1` |
| `condition` | Sample condition (`native` or `ivt`) | `native` |
| `fastq` | Full path to FASTQ file | `/data/sample1.fastq.gz` |

## Optional Columns

All Filtlong parameters can be specified per-sample:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `genome_size` | String | Genome/transcriptome size | `4.5m`, `4500000`, `4.5Mbp` |
| `min_length` | Integer | Minimum read length (bp) | `500`, `1000` |
| `length_weight` | Float | Read length prioritization weight | `10`, `15` |
| `mean_q_weight` | Float | Mean quality weight | `1`, `2` |
| `window_q_weight` | Float | Window quality weight | `1`, `3` |
| `keep_percent` | Float | Keep percentage of best reads | `90`, `95` |
| `min_mean_q` | Float | Minimum mean quality | `7`, `8` |
| `min_window_q` | Float | Minimum window quality | `5`, `7` |
| `window_size` | Integer | Window size for quality assessment | `250` |
| `trim` | Boolean | Enable read trimming | `yes`, `no`, `true`, `false` |
| `split` | Integer | Split reads longer than this | `100000` |
| `assembly` | String | Reference assembly FASTA path | `/ref/genome.fasta` |
| `illumina_1` | String | Illumina R1 FASTQ path | `/ref/R1.fastq.gz` |
| `illumina_2` | String | Illumina R2 FASTQ path | `/ref/R2.fastq.gz` |

## Examples

### Example 1: Simple (Global Parameters)

Use this format when all samples use the same parameters.

**samplesheet_simple.csv:**
```csv
sample,condition,fastq
native_1,native,/data/native_1.fastq.gz
native_2,native,/data/native_2.fastq.gz
native_3,native,/data/native_3.fastq.gz
ivt_1,ivt,/data/ivt_1.fastq.gz
ivt_2,ivt,/data/ivt_2.fastq.gz
ivt_3,ivt,/data/ivt_3.fastq.gz
```

**Command:**
```bash
nextflow run main.nf \
  --input samplesheet_simple.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  -profile docker
```

### Example 2: Per-Sample Parameters

Use this format when each sample needs different parameters.

**samplesheet_custom.csv:**
```csv
sample,condition,fastq,genome_size,min_length,length_weight
native_1,native,/data/native_1.fastq.gz,4.5m,500,10
native_2,native,/data/native_2.fastq.gz,4.5m,1000,15
native_3,native,/data/native_3.fastq.gz,5.2Mbp,500,10
ivt_1,ivt,/data/ivt_1.fastq.gz,4.5m,500,10
ivt_2,ivt,/data/ivt_2.fastq.gz,4.5m,800,12
ivt_3,ivt,/data/ivt_3.fastq.gz,4.5m,500,10
```

**Command:**
```bash
nextflow run main.nf \
  --input samplesheet_custom.csv \
  -profile docker
```

### Example 3: Mixed Approach

Use global defaults, but override for specific samples.

**samplesheet_mixed.csv:**
```csv
sample,condition,fastq,genome_size,min_length,length_weight
native_1,native,/data/native_1.fastq.gz,,,
native_2,native,/data/native_2.fastq.gz,5m,1000,
ivt_1,ivt,/data/ivt_1.fastq.gz,,,
ivt_2,ivt,/data/ivt_2.fastq.gz,,,15
```

**Command:**
```bash
nextflow run main.nf \
  --input samplesheet_mixed.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  -profile docker
```

**Result:**
- `native_1`: Uses all global parameters
- `native_2`: Overrides genome_size (5m) and min_length (1000)
- `ivt_1`: Uses all global parameters
- `ivt_2`: Overrides only length_weight (15)

### Example 4: Advanced with References

Use reference-based filtering with Illumina reads and reference assembly.

**samplesheet_advanced.csv:**
```csv
sample,condition,fastq,genome_size,min_length,length_weight,mean_q_weight,trim,assembly,illumina_1,illumina_2
native_1,native,/data/native_1.fastq.gz,4.5m,500,15,2,yes,,,
native_2,native,/data/native_2.fastq.gz,4.5m,1000,20,3,no,,,
native_3,native,/data/native_3.fastq.gz,4.5m,500,10,1,,/ref/genome.fasta,/ref/R1.fq.gz,/ref/R2.fq.gz
ivt_1,ivt,/data/ivt_1.fastq.gz,4.5m,500,10,1,,,,
```

## Rules and Validation

### Sample Names
- Must be unique
- Cannot contain spaces
- Can contain letters, numbers, underscores, hyphens

### Condition
- Must be exactly `native` or `ivt`
- Case-insensitive (converted to lowercase)

### FASTQ Files
- Must have extension: `.fastq`, `.fq`, `.fastq.gz`, or `.fq.gz`
- Path can be relative or absolute
- File existence is checked during pipeline execution

### Genome Size
- Multiple formats accepted (see [Parameters documentation](parameters.md#genome-size-formats))
- Examples: `4500000`, `4.5m`, `4.5M`, `4.5Mbp`, `4500k`
- Case-insensitive

### Boolean Values
- Accepted values: `true`, `false`, `yes`, `no`, `1`, `0`
- Case-insensitive

### Empty Values
- Leave cells empty (not "NA" or "null") to use global defaults
- Empty values inherit from command-line parameters

## Validation Errors

Common samplesheet errors and solutions:

### Missing Required Columns
```
Error: Missing required columns. Required: sample, condition, fastq
```
**Solution:** Ensure CSV has headers: `sample,condition,fastq`

### Duplicate Sample Names
```
Error: Sample name sample1 is duplicated
```
**Solution:** Make all sample names unique

### Invalid Condition
```
Error: Condition must be one of ['native', 'ivt'], got 'control'
```
**Solution:** Use only `native` or `ivt` for condition

### Invalid Genome Size Format
```
Error: Invalid genome size format: 4.5 m
```
**Solution:** Remove spaces: `4.5m` (not `4.5 m`)

### Invalid FASTQ Extension
```
Error: FASTQ file must have extension .fastq, .fq, .fastq.gz, or .fq.gz
```
**Solution:** Ensure FASTQ files have correct extensions

## Best Practices

1. **Use absolute paths** for FASTQ files to avoid confusion
2. **Test with a small dataset** first to validate your samplesheet
3. **Be consistent** with genome size formats within a project
4. **Document** any per-sample overrides in your lab notebook
5. **Version control** your samplesheets alongside your data

## Template

Use this template to create your own samplesheet:

```csv
sample,condition,fastq,genome_size,min_length,length_weight
SAMPLE_NAME,native,/path/to/file.fastq.gz,GENOME_SIZE,MIN_LENGTH,LENGTH_WEIGHT
```

Replace:
- `SAMPLE_NAME`: Unique identifier for your sample
- `native`: Either `native` or `ivt`
- `/path/to/file.fastq.gz`: Full path to FASTQ file
- `GENOME_SIZE`: e.g., `4.5m` (optional if provided globally)
- `MIN_LENGTH`: e.g., `500` (optional if provided globally)
- `LENGTH_WEIGHT`: e.g., `10` (optional if provided globally)
