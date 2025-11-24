# Understanding Filtlong and Coverage-Based Filtering

**Series: Part 2 of 12**

## Introduction

Before we start building our pipeline, we need to understand the tool at its core: **filtlong**. In this post, we'll explore how filtlong works, the mathematics behind coverage-based filtering, and practical examples that will inform our pipeline design decisions.

## What is Filtlong?

[Filtlong](https://github.com/rrwick/Filtlong) is a quality filtering tool for long reads (PacBio or Oxford Nanopore). Unlike simple length cutoffs or random subsampling, filtlong intelligently selects reads based on multiple criteria to create high-quality subsets while maintaining biological diversity.

### Why Not Just Use `seqtk sample`?

You might ask: why not just randomly subsample reads? Let's compare:

**Random Subsampling (seqtk)**:
```bash
# Get 10% of reads randomly
seqtk sample input.fastq 0.1 > output.fastq
```
- ✗ No quality consideration
- ✗ No length bias (might lose important long reads)
- ✗ No coverage targeting
- ✓ Fast and simple

**Intelligent Filtering (filtlong)**:
```bash
# Get best reads targeting 50x coverage
filtlong --target_bases 225000000 \
         --min_length 500 \
         --length_weight 10 \
         input.fastq > output.fastq
```
- ✓ Prioritizes high-quality reads
- ✓ Can weight by length (important for structural analysis)
- ✓ Precise coverage targeting
- ✓ Can use reference genomes for quality assessment
- ✗ Slower (but parallelizable)

**For benchmarking**, we want filtlong because:
1. We need **consistent coverage** across samples (not percentages)
2. RNA modifications often span multiple bases, so **longer reads are better**
3. We want the **highest quality reads** at each coverage level
4. We need **reproducible subsampling** (not random)

## Coverage Math: The Foundation

### Understanding Coverage

**Coverage** (or sequencing depth) is the average number of reads overlapping each base in your genome/transcriptome:

```
Coverage (X) = (Total Bases Sequenced) / (Genome Size)
```

**Example**:
- Genome size: 4.5 Mbp = 4,500,000 bp
- Total sequencing: 450,000,000 bp
- Coverage: 450M / 4.5M = **100x**

### The Target Bases Calculation

Filtlong's `--target_bases` parameter tells it how many total bases to keep. To achieve a specific coverage, we calculate:

```
target_bases = genome_size × desired_coverage
```

**Practical Examples**:

| Genome Size | Desired Coverage | Calculation | Target Bases |
|-------------|------------------|-------------|--------------|
| 4.5 Mbp | 10x | 4,500,000 × 10 | 45,000,000 |
| 4.5 Mbp | 50x | 4,500,000 × 50 | 225,000,000 |
| 4.5 Mbp | 100x | 4,500,000 × 100 | 450,000,000 |
| 4.6 Mbp (E. coli) | 30x | 4,600,000 × 30 | 138,000,000 |
| 12 Mbp (Yeast) | 50x | 12,000,000 × 50 | 600,000,000 |

### What Filtlong Does

Given a target, filtlong:
1. **Scores each read** based on length and quality
2. **Sorts reads** by score (best first)
3. **Accumulates reads** until target_bases is reached
4. **Outputs selected reads** in original order

This ensures you get the **best reads** up to your target coverage.

## Filtlong Parameters Explained

### Core Parameters

#### `--target_bases` (Coverage Control)

The most important parameter for our pipeline:

```bash
# Get exactly 100x coverage of a 4.5 Mbp genome
filtlong --target_bases 450000000 input.fastq > output.fastq
```

**How it works**: Filtlong keeps the best reads until total bases reaches this threshold.

**Trade-off**: Setting this too low might exclude important reads; too high defeats the purpose of downsampling.

#### `--min_length` (Length Filtering)

Exclude reads shorter than this threshold:

```bash
# Only keep reads >= 500 bp
filtlong --target_bases 450000000 \
         --min_length 500 \
         input.fastq > output.fastq
```

**Why this matters for RNA modifications**:
- Many modifications affect 3-5 bases
- Short reads might not capture the full modification signature
- Longer reads provide more context for base calling algorithms

**Trade-off**: Higher values give cleaner data but reduce total yield. For RNA-seq, 500-1000 bp is typical.

#### `--length_weight` (Length Prioritization)

Weight factor for read length in scoring (default: 1):

```bash
# Strongly prioritize longer reads
filtlong --target_bases 450000000 \
         --min_length 500 \
         --length_weight 10 \
         input.fastq > output.fastq
```

**How scoring works**:
```
read_score = (quality_score × 1) + (length × length_weight)
```

**Examples**:
- `length_weight = 1`: Balanced (default)
- `length_weight = 10`: Strongly favor longer reads
- `length_weight = 0`: Ignore length, only quality matters

**For RNA modifications**, we typically use `length_weight = 10` because:
- Longer reads span more modification sites
- Better for isoform analysis
- More reliable base calling

### Quality Parameters

#### `--mean_q_weight` (Average Quality)

Weight factor for mean read quality (default: 1):

```bash
# Prioritize reads with high average quality
filtlong --mean_q_weight 3 input.fastq > output.fastq
```

**Use case**: When you want overall high-quality reads regardless of length.

#### `--window_q_weight` (Window Quality)

Weight factor for quality in sliding windows:

```bash
# Emphasize consistent quality across read
filtlong --window_q_weight 2 input.fastq > output.fastq
```

**Difference from mean_q_weight**:
- `mean_q_weight`: Penalizes reads with low overall quality
- `window_q_weight`: Penalizes reads with quality drops (even if mean is OK)

#### `--min_mean_q` (Hard Quality Filter)

Exclude reads below this mean quality threshold:

```bash
# Only keep reads with mean Q-score >= 8
filtlong --min_mean_q 8 input.fastq > output.fastq
```

**Values**:
- Q8: 84% base accuracy (lenient)
- Q10: 90% base accuracy (moderate)
- Q12: 94% base accuracy (strict)

**Trade-off**: Stricter filtering gives cleaner data but may reduce coverage or introduce bias.

### Advanced Reference-Based Filtering

#### `--assembly` (Reference Genome)

Use a reference genome to assess read quality:

```bash
# Filter based on alignment to reference
filtlong --target_bases 450000000 \
         --assembly reference.fasta \
         input.fastq > output.fastq
```

**How it works**: Filtlong aligns reads to the reference (using minimap2 internally) and uses alignment quality as part of the scoring.

**When to use**:
- When you have a high-quality reference genome
- For organisms with low heterozygosity
- When you want to bias towards "typical" sequences

**When NOT to use**:
- Novel transcripts or isoforms
- High variation between sample and reference
- When you want to discover new sequences

#### `--illumina_1` / `--illumina_2` (Hybrid Filtering)

Use Illumina short reads to assess long-read quality:

```bash
# Use Illumina data to validate long reads
filtlong --target_bases 450000000 \
         --illumina_1 reads_R1.fastq.gz \
         --illumina_2 reads_R2.fastq.gz \
         nanopore.fastq > output.fastq
```

**How it works**: Filtlong compares long reads to k-mers from Illumina reads. Long reads with more matching k-mers score higher.

**Use case**: When you have both Illumina and long reads from the same sample.

## Practical Examples

### Example 1: Basic Coverage Filtering

**Scenario**: Filter *E. coli* direct RNA-seq to 50x coverage, keeping only reads ≥ 500 bp.

```bash
# Genome size: 4.6 Mbp
# Target coverage: 50x
# Target bases: 4,600,000 × 50 = 230,000,000

filtlong --target_bases 230000000 \
         --min_length 500 \
         input.fastq.gz | gzip > ecoli_50x.fastq.gz
```

**What happens**:
1. Filtlong reads all sequences from `input.fastq.gz`
2. Excludes reads < 500 bp
3. Scores remaining reads by length and quality
4. Outputs best reads until 230 Mbp total

### Example 2: Prioritizing Long Reads

**Scenario**: Same as above, but strongly favor longer reads for isoform analysis.

```bash
filtlong --target_bases 230000000 \
         --min_length 500 \
         --length_weight 15 \
         input.fastq.gz | gzip > ecoli_50x_long.fastq.gz
```

**Difference**: With `length_weight = 15`, a 2000 bp read scores much higher than a 1000 bp read, even if the shorter read has slightly better quality.

**Read distribution comparison**:

```
Default (length_weight = 1):
  N50: 1200 bp
  Longest: 8500 bp
  Mean length: 950 bp

High weight (length_weight = 15):
  N50: 2400 bp
  Longest: 12000 bp
  Mean length: 1850 bp
```

### Example 3: Quality-Focused Filtering

**Scenario**: You need high-quality reads for accurate modification calling, even if they're shorter.

```bash
filtlong --target_bases 230000000 \
         --min_length 500 \
         --length_weight 5 \
         --mean_q_weight 4 \
         --min_mean_q 9 \
         input.fastq.gz | gzip > ecoli_50x_hq.fastq.gz
```

**Settings explained**:
- `length_weight = 5`: Still favor longer reads, but not as strongly
- `mean_q_weight = 4`: Strongly weight by quality
- `min_mean_q = 9`: Hard cutoff (Q9 = 87% accuracy)

### Example 4: Reference-Guided Filtering

**Scenario**: You have a high-quality reference genome and want reads that align well.

```bash
filtlong --target_bases 230000000 \
         --min_length 500 \
         --length_weight 10 \
         --assembly ecoli_reference.fasta \
         input.fastq.gz | gzip > ecoli_50x_ref.fastq.gz
```

**Use case**:
- Known genome, looking for expression patterns
- Want to exclude artifacts or contamination
- Reference-based modification calling

**Warning**: This will bias against:
- Novel splice variants
- RNA editing events
- Contamination (which you might want to identify)

### Example 5: Multi-Coverage Series

**Scenario**: Generate multiple coverage levels from one dataset for benchmarking.

```bash
# 10x coverage (46 Mbp)
filtlong --target_bases 46000000 --min_length 500 --length_weight 10 \
         input.fastq.gz | gzip > ecoli_10x.fastq.gz

# 25x coverage (115 Mbp)
filtlong --target_bases 115000000 --min_length 500 --length_weight 10 \
         input.fastq.gz | gzip > ecoli_25x.fastq.gz

# 50x coverage (230 Mbp)
filtlong --target_bases 230000000 --min_length 500 --length_weight 10 \
         input.fastq.gz | gzip > ecoli_50x.fastq.gz

# 100x coverage (460 Mbp)
filtlong --target_bases 460000000 --min_length 500 --length_weight 10 \
         input.fastq.gz | gzip > ecoli_100x.fastq.gz
```

**This is exactly what our pipeline will automate!**

## Design Decisions for Our Pipeline

Based on this understanding, we'll design our pipeline to:

### 1. Flexible Coverage Specification

**Support multiple input methods**:
```groovy
// Method 1: Single coverage as string
params.coverage = "10x"

// Method 2: Multiple coverages as comma-separated
params.coverage = "10x,20x,50x,100x"

// Method 3: Per-sample in samplesheet
// (each sample can have different coverages)
```

### 2. Flexible Genome Size Formats

**Parse various formats**:
```groovy
"4500000"   → 4500000     // Raw bases
"4.5m"      → 4500000     // Megabases (lowercase)
"4.5M"      → 4500000     // Megabases (uppercase)
"4.5Mbp"    → 4500000     // Megabases + bp
"4500k"     → 4500000     // Kilobases
"4.5Gbp"    → 4500000000  // Gigabases
```

**Why**: Different labs use different conventions. Our pipeline should accept all.

### 3. Expose All Filtlong Parameters

**In samplesheet**:
```csv
sample,fastq,genome_size,min_length,length_weight,mean_q_weight,...
sample1,data.fq.gz,4.5m,500,10,1
```

**Why**: Maximum flexibility. Users can fine-tune for their specific needs.

### 4. Parameter Precedence System

**Three-tier system**:
```
1. Per-sample (in samplesheet) - HIGHEST PRIORITY
2. Command-line (--parameter)
3. Default (in config) - LOWEST PRIORITY
```

**Example**:
```bash
# Global default
nextflow run main.nf --input samples.csv --length_weight 5

# But sample1 in samplesheet specifies length_weight 15
# → sample1 uses 15, others use 5
```

### 5. Smart Output Organization

**Organize by condition and coverage**:
```
results/
├── native/
│   ├── 10x/
│   ├── 20x/
│   └── 50x/
└── ivt/
    ├── 10x/
    ├── 20x/
    └── 50x/
```

**Why**: Easy to compare same conditions across coverage, or same coverage across conditions.

## Common Pitfalls and Solutions

### Pitfall 1: Not Enough Input Coverage

**Problem**: You request 100x but only have 80x input data.

**Filtlong behavior**: Returns all input reads (won't reach target).

**Solution**: Add validation to check input coverage before filtering.

```groovy
// Check if we have enough data
def input_bases = calculate_total_bases(fastq)
def target = genome_size * coverage

if (input_bases < target) {
    log.warn "Sample ${sample}: Input has ${input_bases} bp, need ${target} bp for ${coverage}x. Using all reads."
}
```

### Pitfall 2: Inconsistent Filtering Between Samples

**Problem**: Different samples use different `min_length`, making coverage not comparable.

**Solution**: Either enforce same filtering globally, or document differences clearly.

```bash
# Good: Consistent
filtlong --target_bases X --min_length 500 --length_weight 10

# Bad: Inconsistent (unless documented)
filtlong --target_bases X --min_length 500   # sample 1
filtlong --target_bases X --min_length 1000  # sample 2
# These are not comparable!
```

### Pitfall 3: Over-Filtering

**Problem**: Setting `min_mean_q` too high removes most reads.

**Example**:
```bash
# Too strict for typical nanopore data
filtlong --min_mean_q 12 input.fastq
# Might output nothing!
```

**Solution**: Check read quality distribution first:

```bash
# Check quality distribution
nanostat input.fastq

# Typical nanopore RNA-seq: mean Q ~ 7-10
# Set threshold conservatively
filtlong --min_mean_q 7  # Remove only worst 20%
```

## Performance Considerations

### Speed

Filtlong is relatively slow for large files:

```
Dataset size    Runtime (1 CPU)
1 GB           ~5-10 minutes
10 GB          ~50-100 minutes
50 GB          ~4-8 hours
```

**Pipeline optimization**: Process samples in parallel!

```groovy
// Nextflow automatically parallelizes
// All samples run simultaneously (resource-limited)
FILTLONG(samples)
```

### Memory

Filtlong loads entire input into memory for sorting:

```
Input size    Memory needed
1 GB          ~2-3 GB
10 GB         ~20-30 GB
50 GB         ~100-150 GB
```

**Pipeline solution**: Set memory requirements per process:

```groovy
process FILTLONG {
    memory '32 GB'  // Adjust based on input size
    // ...
}
```

## What's Next?

Now that we understand filtlong and coverage math, in **Post 3** we'll create our first nf-core module that wraps filtlong with all these features:

- Dynamic target_bases calculation
- Flexible parameter passing
- Proper input/output handling
- Container and conda support
- Resource management

We'll write a production-ready module that handles all the edge cases we've discussed.

---

**Previous**: [Part 1 - Introduction](blogpost_1_introduction_rna_modification_benchmarking_pipeline.md)
**Next**: [Part 3 - Creating Your First nf-core Module: FILTLONG](blogpost_3_creating_first_nfcore_module_filtlong.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. **Understanding Filtlong and Coverage Filtering** ← You are here
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
