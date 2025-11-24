# Building an nf-core Pipeline from Scratch: RNA Modification Benchmarking

**Series: Part 1 of 12**

## Introduction

Welcome to this comprehensive tutorial series where we'll build a production-ready bioinformatics pipeline following nf-core standards. Rather than just discussing theory, we'll work through a real-world use case: benchmarking RNA modification detection tools across different sequencing coverage levels.

By the end of this series, you'll understand how to:
- Design and implement nf-core-compliant pipelines
- Create flexible, reusable modules
- Implement comprehensive validation and testing
- Set up professional CI/CD workflows
- Document pipelines for community use

## The Problem We're Solving

### RNA Modification Detection Challenges

Direct RNA sequencing with Oxford Nanopore Technology allows us to detect RNA modifications (like m6A, pseudouridine, etc.) directly from native RNA without reverse transcription. However, different computational tools claim varying levels of accuracy. How do we systematically compare them?

**The Challenge**: Tool performance varies with sequencing coverage. A tool might work well at 100x coverage but poorly at 20x. We need to:

1. Generate datasets at multiple coverage levels (5x, 10x, 20x, 30x...100x, 150x, 200x, 500x, 1000x)
2. Apply each detection tool to all coverage levels
3. Compare results to ground truth (IVT vs native RNA)
4. Determine optimal coverage requirements for each tool

### Why Filtlong?

[Filtlong](https://github.com/rrwick/Filtlong) is a quality filtering tool for long reads that allows us to:
- Filter reads to specific target coverage levels
- Prioritize longer reads (important for RNA modifications spanning multiple bases)
- Weight reads by quality scores
- Maintain biological diversity in downsampled datasets

**Key Feature**: We can calculate `target_bases = genome_size × desired_coverage` and filtlong will intelligently select the best reads to reach that target.

## What We're Building

### Pipeline Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Input: Samplesheet                       │
│  sample,condition,fastq,genome_size,min_length,...          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              SAMPLESHEET_CHECK (Validation)                 │
│  - Validate CSV format                                      │
│  - Check file existence                                     │
│  - Parse genome sizes (4.5m, 4.5Mbp, 4500000)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    FILTLONG Module                          │
│  For each sample × coverage combination:                   │
│  - Calculate target_bases                                   │
│  - Apply length/quality weights                             │
│  - Filter to target coverage                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Organized Outputs                              │
│  results/                                                   │
│  ├── native/                                                │
│  │   ├── 10x/native_1_filtered.fastq.gz                    │
│  │   ├── 20x/native_1_filtered.fastq.gz                    │
│  │   └── ...                                                │
│  └── ivt/                                                   │
│      ├── 10x/ivt_1_filtered.fastq.gz                        │
│      └── ...                                                │
└─────────────────────────────────────────────────────────────┘
```

### Key Features We'll Implement

1. **Flexible Parameter System**
   - Global parameters: Apply same settings to all samples
   - Per-sample parameters: Each sample can have unique settings
   - Three-tier precedence: per-sample > command-line > defaults

2. **Comprehensive Validation**
   - CSV format validation
   - File existence checks
   - Flexible genome size parsing (4.5m, 4.5Mbp, 4500000bp)
   - JSON Schema validation for all inputs

3. **Organized Outputs**
   - Structured by condition (native/IVT) and coverage level
   - Human-readable file names
   - Version tracking for reproducibility

4. **Professional Testing**
   - Module-level tests with nf-test
   - Workflow-level integration tests
   - Pipeline-level end-to-end tests
   - Automated CI/CD with GitHub Actions

5. **Complete Documentation**
   - Usage guides
   - Parameter references
   - Samplesheet format documentation
   - API documentation for modules

## Understanding nf-core Standards

### Why nf-core?

[nf-core](https://nf-co.re/) is a community effort to collect a curated set of analysis pipelines built using Nextflow. Following nf-core standards provides:

- **Consistency**: Familiar structure across pipelines
- **Quality**: Automated linting and best practices
- **Portability**: Works with Docker, Singularity, Conda
- **Community**: Reusable modules and shared knowledge
- **Reproducibility**: Comprehensive testing and documentation

### nf-core Directory Structure

Let's understand the standard layout we'll be building:

```
pipeline/
├── .github/              # GitHub Actions CI/CD workflows
│   └── workflows/
│       ├── ci.yml        # Automated testing
│       ├── linting.yml   # Code quality checks
│       └── branch.yml    # Branch protection
│
├── assets/               # Pipeline assets
│   ├── schema_input.json # Samplesheet validation schema
│   └── samplesheet*.csv  # Example samplesheets
│
├── bin/                  # Executable scripts
│   └── check_samplesheet.py  # Validation script
│
├── conf/                 # Configuration files
│   ├── base.config       # Base process configuration
│   ├── modules.config    # Module-specific config
│   └── test.config       # Test profile config
│
├── docs/                 # Documentation
│   ├── usage.md          # How to run the pipeline
│   ├── output.md         # Output description
│   ├── parameters.md     # Parameter reference
│   └── samplesheet.md    # Samplesheet format guide
│
├── lib/                  # Groovy helper classes
│   └── WorkflowMain.groovy  # Main workflow utilities
│
├── modules/              # Pipeline modules
│   └── local/            # Local (custom) modules
│       ├── filtlong/
│       │   ├── main.nf   # Module implementation
│       │   ├── meta.yml  # Module metadata
│       │   └── tests/    # Module tests
│       │       └── main.nf.test
│       └── samplesheet_check/
│           ├── main.nf
│           ├── meta.yml
│           ├── environment.yml
│           └── tests/
│               └── main.nf.test
│
├── tests/                # Pipeline-level tests
│   ├── data/             # Minimal test data
│   │   ├── fastq/        # Test FASTQ files
│   │   └── samplesheets/ # Test samplesheets
│   └── pipeline/
│       └── main.nf.test  # Pipeline tests
│
├── workflows/            # Workflow definitions
│   └── rna_coverage_benchmark/
│       ├── main.nf       # Main workflow logic
│       └── tests/        # Workflow tests
│           └── main.nf.test
│
├── CITATIONS.md          # Tool citations
├── main.nf               # Pipeline entry point
├── nextflow.config       # Main configuration
└── nextflow_schema.json  # Parameter schema
```

### Key Concepts We'll Use

**Modules**: Self-contained process definitions that can be reused across pipelines. Think of them as functions that run specific tools.

**Workflows**: Collections of modules connected by channels. They define the data flow through your pipeline.

**Channels**: Nextflow's way of passing data between processes. They're asynchronous queues that enable parallel execution.

**Meta Maps**: Groovy maps (dictionaries) that carry metadata alongside your data files. Example:
```groovy
[
    id: 'sample1',
    condition: 'native',
    coverage: '10x',
    genome_size: 4500000
]
```

**DSL2**: Nextflow's Domain Specific Language version 2, which enables modular pipeline development. We'll use features like:
- `process`: Define computational tasks
- `workflow`: Orchestrate processes
- `include`: Import modules from other files
- Channel operators: `map`, `collect`, `splitCsv`, etc.

## Example Use Cases

### Use Case 1: Simple Batch Processing

You have 6 samples (3 native, 3 IVT) and want to filter all to the same coverage levels using global parameters:

```bash
nextflow run main.nf \
  --input samplesheet_simple.csv \
  --genome_size 4.5m \
  --min_length 500 \
  --length_weight 10 \
  -profile docker
```

**Samplesheet** (`samplesheet_simple.csv`):
```csv
sample,condition,fastq
native_1,native,/data/native_1.fastq.gz
native_2,native,/data/native_2.fastq.gz
native_3,native,/data/native_3.fastq.gz
ivt_1,ivt,/data/ivt_1.fastq.gz
ivt_2,ivt,/data/ivt_2.fastq.gz
ivt_3,ivt,/data/ivt_3.fastq.gz
```

### Use Case 2: Per-Sample Customization

Different samples have different genome sizes or require different filtering parameters:

```bash
nextflow run main.nf \
  --input samplesheet_standard.csv \
  -profile docker
```

**Samplesheet** (`samplesheet_standard.csv`):
```csv
sample,condition,fastq,genome_size,min_length,length_weight
native_1,native,/data/native_1.fastq.gz,4.5m,500,10
native_2,native,/data/native_2.fastq.gz,4.5m,1000,15
ecoli,native,/data/ecoli.fastq.gz,4.6Mbp,500,10
yeast,native,/data/yeast.fastq.gz,12m,800,12
```

### Use Case 3: Advanced Reference-Based Filtering

Some samples use reference genomes and Illumina data for hybrid filtering:

```csv
sample,condition,fastq,genome_size,min_length,length_weight,assembly,illumina_1,illumina_2
native_1,native,/data/ont.fastq.gz,4.5m,500,15,/ref/genome.fa,/data/R1.fq.gz,/data/R2.fq.gz
```

## What's Next?

In **Post 2**, we'll dive deep into how filtlong works, understand the math behind coverage-based filtering, and see practical examples of filtering reads to different coverage levels.

We'll explore:
- Quality vs. length trade-offs
- How filtlong calculates target bases
- Real command-line examples with different parameters
- Why this approach works well for RNA modification benchmarking

## Prerequisites

Before continuing with this series, you should have:

- **Basic Nextflow knowledge**: Understanding of processes and channels (we'll explain DSL2 specifics)
- **Command-line comfort**: Familiarity with bash/terminal operations
- **Git basics**: Cloning repositories, committing changes
- **Docker or Conda**: At least one container/environment management system installed

**Recommended but not required**:
- Experience running nf-core pipelines as a user
- Understanding of bioinformatics file formats (FASTQ, BAM)
- Basic Groovy syntax (we'll explain as we go)

## Resources

- **nf-core website**: https://nf-co.re/
- **Nextflow documentation**: https://nextflow.io/docs/latest/
- **Filtlong repository**: https://github.com/rrwick/Filtlong
- **nf-test documentation**: https://code.askimed.com/nf-test/

---

**Next**: [Part 2 - Understanding Filtlong and Coverage-Based Filtering](blogpost_2_understanding_filtlong_coverage_filtering.md)

**Series Navigation**:
1. **Introduction and Pipeline Overview** ← You are here
2. Understanding Filtlong and Coverage Filtering
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
