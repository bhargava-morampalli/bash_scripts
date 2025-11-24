# Output

## Introduction

This document describes the output produced by the pipeline.

## Pipeline Output Directory Structure

The pipeline organizes outputs by condition and coverage level:

```
results/
├── native/                      # Native RNA samples
│   ├── 5x/
│   │   ├── sample1_5x.fastq.gz
│   │   ├── sample2_5x.fastq.gz
│   │   └── sample3_5x.fastq.gz
│   ├── 10x/
│   ├── 20x/
│   └── ... (all coverage levels)
├── ivt/                         # IVT RNA samples
│   ├── 5x/
│   │   ├── sample1_5x.fastq.gz
│   │   ├── sample2_5x.fastq.gz
│   │   └── sample3_5x.fastq.gz
│   └── ... (all coverage levels)
└── pipeline_info/               # Pipeline execution information
    ├── execution_report_*.html
    ├── execution_timeline_*.html
    ├── execution_trace_*.txt
    └── pipeline_dag_*.html
```

## Output Files

### Filtered FASTQ Files

**Location:** `results/<condition>/<coverage>x/*.fastq.gz`

**Description:** Gzip-compressed FASTQ files filtered to specific coverage levels using Filtlong.

**Naming convention:** `<sample>_<coverage>x.fastq.gz`

**Example:**
- `native_1_5x.fastq.gz` - Native sample 1 filtered to 5x coverage
- `ivt_2_100x.fastq.gz` - IVT sample 2 filtered to 100x coverage

### Coverage Levels

By default, the pipeline generates filtered datasets at these coverage levels:

- **Low coverage:** 5x, 10x, 20x, 30x, 40x, 50x, 60x, 70x, 80x, 90x
- **Medium coverage:** 100x, 150x, 200x
- **High coverage:** 500x, 1000x

These can be customized using the `--coverage_levels` parameter.

## Pipeline Information

### Execution Reports

**Location:** `results/pipeline_info/execution_report_*.html`

**Description:** Comprehensive HTML report with:
- Resource usage (CPU, memory, time)
- Task completion status
- Error messages (if any)

### Execution Timeline

**Location:** `results/pipeline_info/execution_timeline_*.html`

**Description:** Interactive Gantt chart showing:
- Task execution timeline
- Parallel execution visualization
- Task duration

### Execution Trace

**Location:** `results/pipeline_info/execution_trace_*.txt`

**Description:** Tab-delimited file with detailed execution metrics for each task:
- Task ID and name
- Status (COMPLETED, FAILED, etc.)
- Exit code
- Duration
- CPU and memory usage
- Input/output sizes

### Pipeline DAG

**Location:** `results/pipeline_info/pipeline_dag_*.html`

**Description:** Directed Acyclic Graph visualization showing:
- Workflow structure
- Task dependencies
- Data flow

## Using the Filtered Data

### Calculating Actual Coverage

To verify the actual coverage achieved:

```bash
# Count total bases in filtered file
zcat native_1_5x.fastq.gz | awk 'NR%4==2 {sum+=length($0)} END {print sum}'

# Divide by genome size to get coverage
# Example: 22,500,000 bases / 4,500,000 bp genome = 5x coverage
```

### Downstream Analysis

The filtered FASTQ files can be used directly with RNA modification detection tools such as:
- **m6Anet**: Direct RNA modification detection
- **Tombo**: Detection of modified bases
- **EpiNano**: m6A modification calling
- **Nanocompore**: RNA modification comparison
- **ELIGOS**: Modification detection using dwell time

### Quality Control

Check read length distribution:

```bash
zcat native_1_5x.fastq.gz | awk 'NR%4==2 {print length($0)}' | sort -n | uniq -c
```

Check read count:

```bash
zcat native_1_5x.fastq.gz | echo $((`wc -l`/4))
```

## File Sizes

Expected file sizes depend on:
- Genome/transcriptome size
- Coverage level
- Read length distribution

**Example estimates for 4.5 Mbp transcriptome:**
- 5x coverage: ~22.5 MB total bases → ~8-15 MB compressed FASTQ
- 100x coverage: ~450 MB total bases → ~150-250 MB compressed FASTQ
- 1000x coverage: ~4.5 GB total bases → ~1.5-2.5 GB compressed FASTQ

## Cleaning Up

To remove work directory (contains intermediate files):

```bash
rm -rf work/
```

**Warning:** Only remove the work directory after you're sure you won't need to resume the pipeline.

To remove just the intermediate files while keeping logs:

```bash
nextflow clean -f
```
