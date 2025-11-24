# Building the Main Workflow Orchestration

**Series: Part 5 of 12**

## Introduction

Now that we have our modules (FILTLONG and SAMPLESHEET_CHECK), it's time to orchestrate them into a complete workflow. In this post, we'll build the workflow that:

- Validates the samplesheet
- Parses it into channels with meta maps
- Merges per-sample and global parameters
- Combines samples with multiple coverage levels
- Executes filtlong for each combination
- Collects version information

This is where DSL2 really shines, allowing us to compose modular, reusable workflows.

## Workflow Structure Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  User Input: samplesheet.csv                │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│             SAMPLESHEET_CHECK (validation)                  │
│  Input:  path(samplesheet)                                  │
│  Output: validated CSV                                      │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│          Channel Operations (splitCsv, map)                 │
│  - Parse CSV rows                                           │
│  - Create meta maps                                         │
│  - Merge parameters (per-sample > global > default)        │
│  - Stage input files                                        │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│        Combine with Coverage Levels (10x, 20x, ...)        │
│  - Create sample × coverage combinations                    │
│  - Clone meta map for each coverage                         │
│  - Update IDs: sample1 → sample1_10x, sample1_20x          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              FILTLONG (parallel execution)                  │
│  Input:  [meta, fastq, assembly, illumina_1, illumina_2]   │
│  Output: [meta, filtered_fastq]                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│             Emit Results and Versions                       │
│  - filtered_reads channel                                   │
│  - versions channel                                         │
└─────────────────────────────────────────────────────────────┘
```

## Workflow File Structure

Our workflow lives in `workflows/rna_coverage_benchmark/main.nf`:

```groovy
/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check/main'
include { FILTLONG          } from '../../modules/local/filtlong/main'

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow RNA_COVERAGE_BENCHMARK {
    take:
    ch_samplesheet  // Input channel

    main:
    // Workflow logic here

    emit:
    filtered_reads = FILTLONG.out.reads
    versions       = ch_versions
}

/*
========================================================================================
    HELPER FUNCTIONS
========================================================================================
*/

def parseGenomeSize(size_str) {
    // Helper function for parsing genome sizes
}
```

## Step-by-Step Implementation

### Step 1: Include Modules

```groovy
include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check/main'
include { FILTLONG          } from '../../modules/local/filtlong/main'
```

**DSL2 include syntax**:
- Import specific processes from module files
- Relative paths from workflow file location
- Can rename on import: `include { FILTLONG as FILTER } from '...'`

### Step 2: Define Workflow Signature

```groovy
workflow RNA_COVERAGE_BENCHMARK {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:
    // Main workflow logic

    emit:
    filtered_reads = FILTLONG.out.reads
    versions       = ch_versions
}
```

**Workflow components**:

**`take:`** - Input declarations
- Like function parameters
- Defines what channels workflow expects
- Enables workflow reuse and composition

**`main:`** - Workflow body
- Process calls and channel operations
- Where the actual work happens

**`emit:`** - Output declarations
- Named outputs that callers can access
- Enables workflow chaining
- Example: `RNA_COVERAGE_BENCHMARK.out.filtered_reads`

### Step 3: Initialize Version Tracking

```groovy
main:

ch_versions = Channel.empty()
```

**Purpose**: Collect software versions from all processes for reproducibility.

**Pattern**: Start with empty channel, mix in versions from each process:
```groovy
ch_versions = ch_versions.mix(SAMPLESHEET_CHECK.out.versions)
ch_versions = ch_versions.mix(FILTLONG.out.versions.first())
```

**Why `.first()` for FILTLONG?**: FILTLONG runs multiple times (one per sample×coverage), but version is the same. Only take first instance to avoid duplicates.

### Step 4: Validate Samplesheet

```groovy
//
// MODULE: Validate samplesheet
//
SAMPLESHEET_CHECK (
    ch_samplesheet
)
ch_versions = ch_versions.mix(SAMPLESHEET_CHECK.out.versions)
```

**Simple process call**: Pass input channel, collect outputs.

**Channel flow**:
```groovy
// Input
ch_samplesheet: path(/path/to/samplesheet.csv)

// After SAMPLESHEET_CHECK
SAMPLESHEET_CHECK.out.csv: path(/path/to/work/.../samplesheet.valid.csv)
```

### Step 5: Parse CSV and Create Meta Maps

This is the most complex part - transforming CSV rows into properly structured channels with meta maps.

```groovy
SAMPLESHEET_CHECK.out.csv
    .splitCsv(header: true, sep: ',')
    .map { row ->
        def meta = [
            id:        row.sample,
            condition: row.condition
        ]

        // Add parameters (next section)

        return [ meta, fastq_file, assembly_file, illumina_1_file, illumina_2_file ]
    }
    .set { ch_samples }
```

**Channel operations breakdown**:

#### `.splitCsv(header: true, sep: ',')`

Splits CSV file into rows as maps:

```groovy
// Input CSV:
sample,condition,fastq,genome_size
sample1,native,/data/s1.fq.gz,4.5m

// After splitCsv:
[sample: 'sample1', condition: 'native', fastq: '/data/s1.fq.gz', genome_size: '4.5m']
```

**Options**:
- `header: true`: Use first row as keys
- `sep: ','`: Column separator (auto-detects if not specified)

#### `.map { row -> ... }`

Transform each row into desired output format:

```groovy
.map { row ->
    // Input: Map from CSV row
    // Output: List [meta, file1, file2, ...]
}
```

**DSL2 map pattern**: Most powerful channel operator. Transform any input to any output.

### Step 6: Parameter Merging Logic

This implements our three-tier parameter precedence: **per-sample > global > default**

```groovy
.map { row ->
    def meta = [
        id:        row.sample,
        condition: row.condition
    ]

    // Genome size - per-sample takes precedence over global
    if (row.genome_size && row.genome_size != '') {
        meta.genome_size = row.genome_size.toLong()
    } else if (params.genome_size) {
        meta.genome_size = parseGenomeSize(params.genome_size)
    }

    // Numeric parameters
    if (row.min_length && row.min_length != '') {
        meta.min_length = row.min_length.toInteger()
    } else if (params.min_length) {
        meta.min_length = params.min_length
    }

    if (row.length_weight && row.length_weight != '') {
        meta.length_weight = row.length_weight.toFloat()
    } else if (params.length_weight) {
        meta.length_weight = params.length_weight
    }

    // ... repeat for all parameters
```

**Pattern for each parameter**:
1. Check if per-sample value exists and is not empty
2. If yes: Use per-sample value (convert to proper type)
3. If no: Check if global param exists
4. If yes: Use global param
5. If no: Omit (process will use default or skip)

**Type conversions**:
- `.toLong()`: For genome sizes (large integers)
- `.toInteger()`: For lengths, sizes
- `.toFloat()`: For weights, percentages
- `.toLowerCase() == 'true'`: For booleans

**Groovy truth**: `if (row.min_length && row.min_length != '')` checks both existence AND non-empty string.

### Step 7: File Staging

```groovy
    // File paths for reference files
    def fastq_file = file(row.fastq, checkIfExists: true)
    def assembly_file = (row.assembly && row.assembly != '') ?
        file(row.assembly, checkIfExists: true) : file('NO_ASSEMBLY')
    def illumina_1_file = (row.illumina_1 && row.illumina_1 != '') ?
        file(row.illumina_1, checkIfExists: true) : file('NO_ILLUMINA_1')
    def illumina_2_file = (row.illumina_2 && row.illumina_2 != '') ?
        file(row.illumina_2, checkIfExists: true) : file('NO_ILLUMINA_2')

    return [ meta, fastq_file, assembly_file, illumina_1_file, illumina_2_file ]
}
```

**`file()` function**:
- Creates Nextflow Path object
- `checkIfExists: true`: Fails immediately if file missing (fast failure!)
- Enables Nextflow to stage files properly

**Ternary operator pattern**:
```groovy
(condition) ? if_true : if_false
```

**Placeholder files**: `file('NO_ASSEMBLY')` creates a placeholder that our FILTLONG module checks for.

**Why check exists here?**: Better to fail fast during channel creation than 2 hours later during execution.

### Step 8: Parse Coverage Levels

```groovy
//
// Parse coverage levels from params
//
def coverage_list = params.coverage_levels
    .toString()
    .split(',')
    .collect { it.trim() }
```

**Example**:
```groovy
// params.coverage_levels = "10x, 20x, 50x, 100x"

coverage_list = ["10x", "20x", "50x", "100x"]
```

**Groovy collection methods**:
- `.split(',')`: Split string into array
- `.collect { it.trim() }`: Map operation, trim whitespace from each element

### Step 9: Combine Samples with Coverage Levels

This is where we create multiple outputs per sample:

```groovy
//
// Create channel with all combinations of samples and coverage levels
//
ch_samples
    .combine(Channel.from(coverage_list))
    .map { meta, fastq, assembly, illumina_1, illumina_2, coverage ->
        def new_meta = meta.clone()
        new_meta.coverage = coverage
        new_meta.id = "${meta.id}_${coverage}"
        return [ new_meta, fastq, assembly, illumina_1, illumina_2 ]
    }
    .set { ch_filtlong_input }
```

#### `.combine()` operator

Creates Cartesian product of channels:

```groovy
// ch_samples emits:
[meta1, file1, ...]
[meta2, file2, ...]

// Channel.from(["10x", "20x"]) emits:
"10x"
"20x"

// After .combine():
[meta1, file1, ..., "10x"]
[meta1, file1, ..., "20x"]
[meta2, file2, ..., "10x"]
[meta2, file2, ..., "20x"]
```

#### Clone and modify meta

```groovy
def new_meta = meta.clone()
new_meta.coverage = coverage
new_meta.id = "${meta.id}_${coverage}"
```

**Why clone?**: Groovy maps are passed by reference. Without cloning, modifying `meta` would affect all instances!

**Update ID**: `sample1` → `sample1_10x`, `sample1_20x`, etc.
- Unique identifier for each sample×coverage combination
- Used in output filenames and logging

**Visual example**:
```
Before combine:
  sample1 → [meta1, s1.fq.gz, ...]
  sample2 → [meta2, s2.fq.gz, ...]

After combine with ["10x", "20x"]:
  sample1_10x → [meta1+coverage:10x, s1.fq.gz, ...]
  sample1_20x → [meta1+coverage:20x, s1.fq.gz, ...]
  sample2_10x → [meta2+coverage:10x, s2.fq.gz, ...]
  sample2_20x → [meta2+coverage:20x, s2.fq.gz, ...]
```

### Step 10: Run FILTLONG

```groovy
//
// MODULE: Filter reads to specific coverage levels
//
FILTLONG (
    ch_filtlong_input
)
ch_versions = ch_versions.mix(FILTLONG.out.versions.first())
```

**Parallel execution**: Nextflow automatically parallelizes!
- All sample×coverage combinations run simultaneously
- Limited only by available resources (CPUs, memory)
- No explicit parallelization code needed

### Step 11: Emit Results

```groovy
emit:
filtered_reads = FILTLONG.out.reads
versions       = ch_versions
```

**Named outputs**: Allow calling workflow to access results:

```groovy
// In main.nf
RNA_COVERAGE_BENCHMARK(ch_samplesheet)

RNA_COVERAGE_BENCHMARK.out.filtered_reads.view()
RNA_COVERAGE_BENCHMARK.out.versions.collectFile(name: 'software_versions.yml')
```

## Helper Function: Parse Genome Size

We need the same genome size parsing in Groovy (for global params) as we have in Python (for samplesheet):

```groovy
def parseGenomeSize(size_str) {
    """
    Parse genome size from string to bases.
    Supports: 4.5m, 4.5M, 4.5mb, 4.5Mbp, 4500k, 4500K, 4500000, etc.
    """
    if (!size_str) return null

    size_str = size_str.toString().trim()

    // Check if it's already just a number
    if (size_str.isNumber()) {
        return size_str.toLong()
    }

    // Parse with units
    def pattern = ~/^([0-9]+\.?[0-9]*)([kKmMgG](?:[bB][pP]?)?)?$/
    def matcher = size_str =~ pattern

    if (!matcher) {
        error "Invalid genome size format: ${size_str}"
    }

    def value = matcher[0][1].toFloat()
    def unit = matcher[0][2]

    if (!unit) {
        return value.toLong()
    }

    def unit_lower = unit.toLowerCase().replaceAll(/(bp|b)$/, '')

    def multipliers = [
        'k': 1_000,
        'm': 1_000_000,
        'g': 1_000_000_000
    ]

    if (unit_lower in multipliers) {
        return (value * multipliers[unit_lower]).toLong()
    }

    error "Unknown unit in genome size: ${unit}"
}
```

**Groovy regex syntax**: `~/pattern/` creates regex pattern, `str =~ pattern` creates matcher.

**Accessing matches**: `matcher[0][1]` gets first match, second capture group.

## Complete Workflow File

Here's the complete `workflows/rna_coverage_benchmark/main.nf`:

```groovy
/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check/main'
include { FILTLONG          } from '../../modules/local/filtlong/main'

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow RNA_COVERAGE_BENCHMARK {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()

    //
    // MODULE: Validate samplesheet
    //
    SAMPLESHEET_CHECK (
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(SAMPLESHEET_CHECK.out.versions)

    //
    // Parse validated samplesheet and create channel with all metadata
    //
    SAMPLESHEET_CHECK.out.csv
        .splitCsv(header: true, sep: ',')
        .map { row ->
            def meta = [
                id:        row.sample,
                condition: row.condition
            ]

            // Add per-sample filtlong parameters (override globals if present)
            // Genome size - per-sample takes precedence over global
            if (row.genome_size && row.genome_size != '') {
                meta.genome_size = row.genome_size.toLong()
            } else if (params.genome_size) {
                meta.genome_size = parseGenomeSize(params.genome_size)
            }

            // Numeric parameters
            if (row.min_length && row.min_length != '') meta.min_length = row.min_length.toInteger()
            else if (params.min_length) meta.min_length = params.min_length

            if (row.length_weight && row.length_weight != '') meta.length_weight = row.length_weight.toFloat()
            else if (params.length_weight) meta.length_weight = params.length_weight

            if (row.mean_q_weight && row.mean_q_weight != '') meta.mean_q_weight = row.mean_q_weight.toFloat()
            else if (params.mean_q_weight) meta.mean_q_weight = params.mean_q_weight

            if (row.window_q_weight && row.window_q_weight != '') meta.window_q_weight = row.window_q_weight.toFloat()
            else if (params.window_q_weight) meta.window_q_weight = params.window_q_weight

            if (row.keep_percent && row.keep_percent != '') meta.keep_percent = row.keep_percent.toFloat()
            if (row.min_mean_q && row.min_mean_q != '') meta.min_mean_q = row.min_mean_q.toFloat()
            if (row.min_window_q && row.min_window_q != '') meta.min_window_q = row.min_window_q.toFloat()
            if (row.window_size && row.window_size != '') meta.window_size = row.window_size.toInteger()
            if (row.split && row.split != '') meta.split = row.split.toInteger()

            // Boolean parameters
            if (row.trim && row.trim != '') {
                meta.trim = row.trim.toLowerCase() == 'true'
            }

            // File paths for reference files
            def fastq_file = file(row.fastq, checkIfExists: true)
            def assembly_file = (row.assembly && row.assembly != '') ? file(row.assembly, checkIfExists: true) : file('NO_ASSEMBLY')
            def illumina_1_file = (row.illumina_1 && row.illumina_1 != '') ? file(row.illumina_1, checkIfExists: true) : file('NO_ILLUMINA_1')
            def illumina_2_file = (row.illumina_2 && row.illumina_2 != '') ? file(row.illumina_2, checkIfExists: true) : file('NO_ILLUMINA_2')

            return [ meta, fastq_file, assembly_file, illumina_1_file, illumina_2_file ]
        }
        .set { ch_samples }

    //
    // Parse coverage levels from params
    //
    def coverage_list = params.coverage_levels
        .toString()
        .split(',')
        .collect { it.trim() }

    //
    // Create channel with all combinations of samples and coverage levels
    //
    ch_samples
        .combine(Channel.from(coverage_list))
        .map { meta, fastq, assembly, illumina_1, illumina_2, coverage ->
            def new_meta = meta.clone()
            new_meta.coverage = coverage
            new_meta.id = "${meta.id}_${coverage}"
            return [ new_meta, fastq, assembly, illumina_1, illumina_2 ]
        }
        .set { ch_filtlong_input }

    //
    // MODULE: Filter reads to specific coverage levels
    //
    FILTLONG (
        ch_filtlong_input
    )
    ch_versions = ch_versions.mix(FILTLONG.out.versions.first())

    emit:
    filtered_reads = FILTLONG.out.reads
    versions       = ch_versions
}

/*
========================================================================================
    HELPER FUNCTIONS
========================================================================================
*/

def parseGenomeSize(size_str) {
    """
    Parse genome size from string to bases
    Supports: 4.5m, 4.5M, 4.5mb, 4.5Mbp, 4500k, 4500K, 4500000, etc.
    """
    if (!size_str) return null

    size_str = size_str.toString().trim()

    if (size_str.isNumber()) {
        return size_str.toLong()
    }

    def pattern = ~/^([0-9]+\.?[0-9]*)([kKmMgG](?:[bB][pP]?)?)?$/
    def matcher = size_str =~ pattern

    if (!matcher) {
        error "Invalid genome size format: ${size_str}"
    }

    def value = matcher[0][1].toFloat()
    def unit = matcher[0][2]

    if (!unit) {
        return value.toLong()
    }

    def unit_lower = unit.toLowerCase().replaceAll(/(bp|b)$/, '')

    def multipliers = [
        'k': 1_000,
        'm': 1_000_000,
        'g': 1_000_000_000
    ]

    if (unit_lower in multipliers) {
        return (value * multipliers[unit_lower]).toLong()
    }

    error "Unknown unit in genome size: ${unit}"
}
```

## Usage Examples

### Example 1: Run workflow with global parameters

```groovy
// main.nf
workflow {
    ch_samplesheet = Channel.fromPath(params.input)

    RNA_COVERAGE_BENCHMARK(ch_samplesheet)

    RNA_COVERAGE_BENCHMARK.out.filtered_reads.view()
}
```

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --genome_size 4.5m \
    --min_length 500 \
    --length_weight 10 \
    --coverage_levels "10x,20x,50x" \
    -profile docker
```

### Example 2: Per-sample parameters override globals

**Samplesheet**:
```csv
sample,condition,fastq,genome_size,min_length
sample1,native,s1.fq.gz,4.5m,500
sample2,native,s2.fq.gz,4.6m,1000
```

**Command**:
```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --min_length 500 \
    --coverage_levels "10x,20x" \
    -profile docker
```

**Result**:
- sample1: Uses genome_size=4.5m from samplesheet, min_length=500 from samplesheet
- sample2: Uses genome_size=4.6m from samplesheet, min_length=1000 from samplesheet (overrides global)

## Common Patterns and Best Practices

### Pattern 1: Channel Debugging

Add `.view()` to inspect channel contents:

```groovy
ch_samples
    .view { "Sample: $it" }
    .combine(Channel.from(coverage_list))
    .view { "Combined: $it" }
```

### Pattern 2: Conditional Channel Operations

```groovy
ch_samples
    .branch {
        has_assembly: it[2].name != 'NO_ASSEMBLY'
        no_assembly:  it[2].name == 'NO_ASSEMBLY'
    }
    .set { branched }

// Different processing for each branch
FILTLONG_WITH_REF(branched.has_assembly)
FILTLONG_NO_REF(branched.no_assembly)
```

### Pattern 3: Error Handling

```groovy
.map { row ->
    try {
        def fastq_file = file(row.fastq, checkIfExists: true)
        // ... rest of logic
    } catch (Exception e) {
        error "Failed to process sample ${row.sample}: ${e.message}"
    }
}
```

## What's Next?

We now have a fully functional workflow! But we've referenced the parameter merging logic extensively. In **Post 6**, we'll dive deep into the three-tier parameter precedence system:

- Detailed explanation of per-sample vs global vs default
- Testing parameter precedence
- Real-world examples of when to use each tier
- Troubleshooting parameter issues

---

**Previous**: [Part 4 - Samplesheet Design and Validation](blogpost_4_samplesheet_design_validation.md)
**Next**: [Part 6 - Implementing Flexible Per-Sample Parameters](blogpost_6_implementing_flexible_per_sample_parameters.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. **Building the Main Workflow** ← You are here
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
