# Implementing Flexible Per-Sample Parameters

**Series: Part 6 of 12**

## Introduction

One of the most powerful features of our pipeline is its flexible parameter system. Users can specify parameters at three levels:

1. **Per-sample** (highest priority) - in the samplesheet
2. **Global** (medium priority) - via command-line flags
3. **Default** (lowest priority) - in nextflow.config

This flexibility is crucial for benchmarking, where different samples might need different settings. In this post, we'll explore this system in depth with real examples and troubleshooting strategies.

## The Three-Tier Precedence System

### Visual Representation

```
┌─────────────────────────────────────────────────────────────┐
│                    Parameter Resolution                     │
│                                                             │
│  ┌───────────────┐                                         │
│  │ Per-Sample    │  ← Highest Priority                     │
│  │ (samplesheet) │    Overrides everything                 │
│  └───────┬───────┘                                         │
│          │                                                  │
│          ↓ (if not set)                                     │
│  ┌───────────────┐                                         │
│  │ Global        │  ← Medium Priority                      │
│  │ (--parameter) │    Applies to all samples              │
│  └───────┬───────┘                                         │
│          │                                                  │
│          ↓ (if not set)                                     │
│  ┌───────────────┐                                         │
│  │ Default       │  ← Lowest Priority                      │
│  │ (config)      │    Fallback value                       │
│  └───────────────┘                                         │
└─────────────────────────────────────────────────────────────┘
```

### Why This Design?

**Problem without flexibility**:
```bash
# All samples must use same parameters
nextflow run main.nf --genome_size 4.5m --min_length 500

# What if one sample is E. coli (4.6m) and another is yeast (12m)?
# You'd need to run the pipeline twice!
```

**Solution with three-tier system**:
```bash
# Set reasonable defaults for most samples
nextflow run main.nf --genome_size 4.5m --min_length 500 --input samples.csv

# But samplesheet can override for specific samples:
# sample1: 4.5m, 500bp (uses globals)
# ecoli: 4.6m, 500bp (overrides genome_size)
# yeast: 12m, 800bp (overrides both)
```

## Implementation Details

### Level 1: Defaults in Config

Define sensible defaults in `nextflow.config`:

```groovy
params {
    // Input/output
    input          = null
    outdir         = './results'

    // Coverage levels
    coverage_levels = '10x,20x,30x,40x,50x,60x,70x,80x,90x,100x'

    // Filtlong parameters (all optional - no defaults means user must specify)
    genome_size    = null  // Must be specified globally or per-sample
    min_length     = 500   // Reasonable default for RNA-seq
    length_weight  = 10    // Strongly favor longer reads
    mean_q_weight  = 1     // Standard quality weighting
    window_q_weight = 1    // Standard window weighting
    keep_percent   = null
    min_mean_q     = null
    min_window_q   = null
    window_size    = null
    trim           = false
    split          = null
}
```

**Design decisions**:

**`genome_size = null`**: No default because it's sample-specific. User MUST specify.

**`min_length = 500`**: Reasonable for most RNA-seq. Users can override if needed.

**`length_weight = 10`**: Optimized for RNA modifications (favor longer reads).

**Quality params = null**: No defaults. Only apply if user explicitly sets them.

### Level 2: Global Parameters (Command-Line)

Users specify via command-line flags:

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --genome_size 4.5m \
    --min_length 500 \
    --length_weight 10 \
    --mean_q_weight 2 \
    --coverage_levels "10x,20x,50x,100x"
```

**Access in workflow**:
```groovy
params.genome_size      // "4.5m"
params.min_length       // 500
params.length_weight    // 10
```

**Advantage**: Apply same settings to all samples without editing samplesheet.

**Limitation**: Can't differentiate between samples.

### Level 3: Per-Sample Parameters (Samplesheet)

Specify in samplesheet for sample-specific control:

```csv
sample,condition,fastq,genome_size,min_length,length_weight,mean_q_weight
sample1,native,s1.fq.gz,4.5m,500,10,1
ecoli,native,ec.fq.gz,4.6m,500,10,1
yeast,native,y.fq.gz,12m,800,15,2
```

**Access in workflow**:
```groovy
row.genome_size      // "4500000" (already parsed by Python validator)
row.min_length       // "500"
row.length_weight    // "10.0"
```

**Advantage**: Complete control per sample.

**Limitation**: More verbose, requires editing samplesheet.

## The Merging Logic

Here's the actual implementation from our workflow:

```groovy
.map { row ->
    def meta = [
        id:        row.sample,
        condition: row.condition
    ]

    // Genome size - per-sample takes precedence over global
    if (row.genome_size && row.genome_size != '') {
        // Per-sample value exists, use it
        meta.genome_size = row.genome_size.toLong()
    } else if (params.genome_size) {
        // No per-sample value, check global
        meta.genome_size = parseGenomeSize(params.genome_size)
    }
    // If neither exists, meta.genome_size is not set

    // Repeat for each parameter...
}
```

### Pattern Breakdown

**Step 1: Check per-sample value**
```groovy
if (row.genome_size && row.genome_size != '') {
    meta.genome_size = row.genome_size.toLong()
```

**Two conditions**:
- `row.genome_size`: Field exists in CSV
- `row.genome_size != ''`: Field is not empty string

**Why both?**: Python validator outputs empty strings for unspecified optional fields.

**Step 2: Fall back to global**
```groovy
} else if (params.genome_size) {
    meta.genome_size = parseGenomeSize(params.genome_size)
}
```

**Only executes if**: Per-sample value doesn't exist or is empty.

**Parse global**: Global params are strings (from command-line), need parsing.

**Step 3: Default handling**
```groovy
// If neither per-sample nor global exists, meta.genome_size is not set
// The FILTLONG module checks for this and skips --target_bases if missing
```

**Graceful degradation**: If parameter not set at any level, module handles it appropriately.

## Real-World Examples

### Example 1: All Samples Use Globals

**Scenario**: 6 samples, all same species, same parameters.

**Samplesheet** (`simple.csv`):
```csv
sample,condition,fastq
native_1,native,/data/n1.fq.gz
native_2,native,/data/n2.fq.gz
native_3,native,/data/n3.fq.gz
ivt_1,ivt,/data/i1.fq.gz
ivt_2,ivt,/data/i2.fq.gz
ivt_3,ivt,/data/i3.fq.gz
```

**Command**:
```bash
nextflow run main.nf \
    --input simple.csv \
    --genome_size 4.5m \
    --min_length 500 \
    --length_weight 10 \
    --coverage_levels "10x,50x,100x"
```

**Result**: All samples use:
- genome_size: 4,500,000
- min_length: 500
- length_weight: 10

**Filtlong commands generated**:
```bash
# Sample native_1, 10x coverage
filtlong --target_bases 45000000 --min_length 500 --length_weight 10 n1.fq.gz

# Sample native_1, 50x coverage
filtlong --target_bases 225000000 --min_length 500 --length_weight 10 n1.fq.gz

# ... etc for all samples and coverages
```

### Example 2: Mixed Parameters

**Scenario**: Multiple species with different genome sizes.

**Samplesheet** (`mixed.csv`):
```csv
sample,condition,fastq,genome_size,min_length
ecoli_1,native,/data/ec1.fq.gz,4.6m,
ecoli_2,native,/data/ec2.fq.gz,4.6m,
yeast_1,native,/data/y1.fq.gz,12m,800
human_1,native,/data/h1.fq.gz,3g,1000
```

**Command**:
```bash
nextflow run main.nf \
    --input mixed.csv \
    --min_length 500 \
    --length_weight 10 \
    --coverage_levels "50x,100x"
```

**Parameter resolution**:

| Sample | genome_size | min_length | Source |
|--------|-------------|------------|--------|
| ecoli_1 | 4,600,000 | 500 | Per-sample, Global |
| ecoli_2 | 4,600,000 | 500 | Per-sample, Global |
| yeast_1 | 12,000,000 | 800 | Per-sample, Per-sample |
| human_1 | 3,000,000,000 | 1000 | Per-sample, Per-sample |

**Commands generated**:
```bash
# ecoli_1, 50x
filtlong --target_bases 230000000 --min_length 500 --length_weight 10 ec1.fq.gz

# yeast_1, 50x
filtlong --target_bases 600000000 --min_length 800 --length_weight 10 y1.fq.gz

# human_1, 50x
filtlong --target_bases 150000000000 --min_length 1000 --length_weight 10 h1.fq.gz
```

### Example 3: Advanced Per-Sample Customization

**Scenario**: Each sample needs completely different filtering strategy.

**Samplesheet** (`advanced.csv`):
```csv
sample,condition,fastq,genome_size,min_length,length_weight,mean_q_weight,min_mean_q,assembly
sample1,native,s1.fq.gz,4.5m,500,15,2,8,
sample2,native,s2.fq.gz,4.5m,1000,10,3,9,
sample3,native,s3.fq.gz,4.5m,500,10,1,,/ref/genome.fa
```

**Command** (minimal globals, mostly per-sample):
```bash
nextflow run main.nf \
    --input advanced.csv \
    --coverage_levels "50x,100x"
```

**Parameter resolution**:

**sample1**:
- genome_size: 4.5m (per-sample)
- min_length: 500 (per-sample)
- length_weight: 15 (per-sample)
- mean_q_weight: 2 (per-sample)
- min_mean_q: 8 (per-sample)

**sample2**:
- genome_size: 4.5m (per-sample)
- min_length: 1000 (per-sample - longer reads)
- length_weight: 10 (per-sample)
- mean_q_weight: 3 (per-sample - higher quality focus)
- min_mean_q: 9 (per-sample - stricter quality)

**sample3**:
- genome_size: 4.5m (per-sample)
- min_length: 500 (per-sample)
- length_weight: 10 (per-sample)
- mean_q_weight: 1 (per-sample)
- assembly: /ref/genome.fa (per-sample - reference-based filtering)

## Testing Parameter Precedence

### Test 1: Per-Sample Overrides Global

**Samplesheet**:
```csv
sample,condition,fastq,min_length
test1,native,test.fq.gz,1000
```

**Command**:
```bash
nextflow run main.nf --input test.csv --min_length 500 --genome_size 4.5m
```

**Expected**: test1 uses min_length=1000 (not 500)

**Verification**:
```bash
# Check work directory
cat work/xx/xxxxx.../.command.sh
# Should contain: --min_length 1000
```

### Test 2: Global Used When Per-Sample Empty

**Samplesheet**:
```csv
sample,condition,fastq,min_length
test2,native,test.fq.gz,
```

**Command**:
```bash
nextflow run main.nf --input test.csv --min_length 500 --genome_size 4.5m
```

**Expected**: test2 uses min_length=500 (from global)

**Verification**:
```bash
cat work/xx/xxxxx.../.command.sh
# Should contain: --min_length 500
```

### Test 3: Default Used When Neither Set

**Samplesheet**:
```csv
sample,condition,fastq
test3,native,test.fq.gz
```

**Command** (no --min_length specified):
```bash
nextflow run main.nf --input test.csv --genome_size 4.5m
```

**Expected**: test3 uses min_length=500 (from nextflow.config default)

**Config**:
```groovy
params {
    min_length = 500  // Default
}
```

## Common Issues and Solutions

### Issue 1: Parameter Not Applied

**Symptom**: Set parameter but filtlong command doesn't include it.

**Diagnosis**:
```groovy
// Add debug output in workflow
.map { row ->
    def meta = [...]
    log.info "Sample ${row.sample}: min_length = ${meta.min_length}"
    return [meta, ...]
}
```

**Common causes**:

1. **Typo in samplesheet column name**
```csv
sample,condition,fastq,minlength  ← Should be min_length
```

2. **Empty string not handled**
```groovy
// Wrong - doesn't check for empty string
if (row.min_length) {
    meta.min_length = row.min_length.toInteger()
}

// Correct
if (row.min_length && row.min_length != '') {
    meta.min_length = row.min_length.toInteger()
}
```

3. **Type mismatch**
```csv
sample,condition,fastq,min_length
test,native,test.fq.gz,500.5  ← Float, should be int
```

### Issue 2: Per-Sample Not Overriding Global

**Symptom**: Set per-sample value but global is used.

**Debug**:
```groovy
.map { row ->
    println "Row genome_size: ${row.genome_size}"
    println "Empty? ${row.genome_size == ''}"
    println "Params genome_size: ${params.genome_size}"
}
```

**Common causes**:

1. **Condition order wrong**
```groovy
// Wrong - checks global first
if (params.genome_size) {
    meta.genome_size = parseGenomeSize(params.genome_size)
} else if (row.genome_size && row.genome_size != '') {
    meta.genome_size = row.genome_size.toLong()
}

// Correct - checks per-sample first
if (row.genome_size && row.genome_size != '') {
    meta.genome_size = row.genome_size.toLong()
} else if (params.genome_size) {
    meta.genome_size = parseGenomeSize(params.genome_size)
}
```

2. **Samplesheet not validated**
- Python validator should have already parsed genome_size to integer
- If still string in workflow, validator might not have run

### Issue 3: All Samples Get Same Value

**Symptom**: Different per-sample values in samplesheet, but all samples use first value.

**Cause**: Meta map not cloned before modification:
```groovy
// Wrong - all samples share same meta reference
def meta = [id: 'shared']
ch_samples.map {
    meta.genome_size = row.genome_size  // Modifies shared object!
    return [meta, ...]
}

// Correct - create new meta for each sample
ch_samples.map { row ->
    def meta = [  // New map for each iteration
        id: row.sample,
        genome_size: row.genome_size
    ]
    return [meta, ...]
}
```

## Best Practices

### Practice 1: Document Parameter Sources

Add comments to samplesheet explaining non-obvious values:

```csv
sample,condition,fastq,genome_size,min_length,length_weight,comment
sample1,native,s1.fq.gz,4.5m,500,10,Standard parameters
sample2,native,s2.fq.gz,4.5m,1000,15,Longer reads for isoform analysis
sample3,native,s3.fq.gz,4.5m,500,5,Lower length weight for coverage
```

### Practice 2: Use Globals for Common Values

**Bad**: Repeat same value for every sample
```csv
sample,condition,fastq,genome_size,min_length,length_weight
s1,native,s1.fq.gz,4.5m,500,10
s2,native,s2.fq.gz,4.5m,500,10
s3,native,s3.fq.gz,4.5m,500,10
```

**Good**: Use global for common values
```bash
nextflow run main.nf --input simple.csv \
    --genome_size 4.5m --min_length 500 --length_weight 10
```

```csv
sample,condition,fastq
s1,native,s1.fq.gz
s2,native,s2.fq.gz
s3,native,s3.fq.gz
```

### Practice 3: Override Only What's Different

**Bad**: Specify all parameters even when using globals
```csv
sample,condition,fastq,genome_size,min_length,length_weight,mean_q_weight
ecoli,native,ec.fq.gz,4.6m,500,10,1
yeast,native,y.fq.gz,12m,500,10,1
```

**Good**: Only override what changes
```csv
sample,condition,fastq,genome_size
ecoli,native,ec.fq.gz,4.6m
yeast,native,y.fq.gz,12m
```

```bash
# Specify common values as globals
nextflow run main.nf --input samples.csv \
    --min_length 500 --length_weight 10 --mean_q_weight 1
```

### Practice 4: Validate Before Running

Test with `-stub` for quick validation:

```bash
# Check parameter resolution without running filtlong
nextflow run main.nf --input samples.csv \
    --genome_size 4.5m \
    --coverage_levels "10x" \
    -stub

# Check work directory for generated commands
ls -la work/*/*/.command.sh | head -1 | xargs cat
```

## When to Use Each Level

### Use Per-Sample When:
- Different species (different genome sizes)
- Sample-specific quality issues (need stricter filtering)
- Different experimental goals (some need long reads, others need quantity)
- Reference-based filtering for specific samples

### Use Global When:
- All samples same species
- Consistent experimental protocol
- Want to easily change parameters without editing samplesheet
- Testing different parameter combinations

### Use Defaults When:
- Values rarely change
- Standard best practices
- Values that make sense for 90% of use cases

## What's Next?

We now have flexible parameter handling! But how do we validate that users are providing valid parameters? In **Post 7**, we'll implement schema validation using JSON Schema:

- Define parameter types, ranges, and patterns
- Validate command-line parameters
- Validate samplesheet structure
- Generate helpful parameter documentation automatically

---

**Previous**: [Part 5 - Building the Main Workflow](blogpost_5_building_main_workflow_orchestration.md)
**Next**: [Part 7 - Schema Validation with JSON Schema](blogpost_7_schema_validation_json_schema.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. **Implementing Flexible Per-Sample Parameters** ← You are here
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
