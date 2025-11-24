# Creating Your First nf-core Module: FILTLONG

**Series: Part 3 of 12**

## Introduction

Now that we understand how filtlong works, let's build our first nf-core module to wrap it. This module will be the workhorse of our pipeline, handling all the complexity of dynamic parameter building, coverage calculations, and optional reference-based filtering.

By the end of this post, you'll understand:
- nf-core module structure and conventions
- DSL2 process definitions
- Dynamic command building in Groovy
- Input/output channel handling with meta maps
- Container and conda configuration
- Publishing strategies

## Module Structure

### Directory Layout

```
modules/local/filtlong/
├── main.nf          # Process definition
├── meta.yml         # Module metadata (we'll add in Post 10)
├── environment.yml  # Conda environment
└── tests/           # Module tests (we'll add in Post 9)
    └── main.nf.test
```

### Why `local/`?

nf-core has two types of modules:

**`modules/nf-core/`**: Shared modules from the nf-core modules repository
- Standardized, tested by community
- Imported using `nf-core modules install`
- Example: `modules/nf-core/fastqc/`

**`modules/local/`**: Custom modules specific to your pipeline
- Full control over implementation
- Can have pipeline-specific features
- Example: Our `modules/local/filtlong/` with custom parameter handling

We use `local/` because we need custom features (dynamic coverage calculation, flexible parameters) not in the standard module.

## Understanding the Meta Map

Before we dive into the code, let's understand the **meta map** pattern used throughout nf-core pipelines.

### What is a Meta Map?

A meta map is a Groovy map (similar to a Python dictionary) that carries metadata alongside data files:

```groovy
meta = [
    id: 'sample1',              // Unique sample identifier
    condition: 'native',         // Experimental condition
    coverage: '50x',            // Target coverage
    genome_size: 4500000,       // Genome size in bases
    min_length: 500,            // Minimum read length
    length_weight: 10           // Length weighting factor
    // ... more parameters
]
```

### Why Use Meta Maps?

**Channel structure with meta**:
```groovy
// Channel emits: [meta, file]
Channel.of([
    [id: 'sample1', condition: 'native', coverage: '50x'],
    file('sample1.fastq.gz')
])
```

**Benefits**:
1. **Metadata travels with data**: No need to join channels later
2. **Type safety**: All info in one structure
3. **Flexible**: Easy to add new metadata fields
4. **Publishable**: Use meta fields in output paths

**Example flow**:
```groovy
// Input
[meta, fastq] = [[id: 'sample1', coverage: '50x'], 'sample1.fastq.gz']

// Process uses meta to build command
FILTLONG(meta, fastq)

// Output keeps meta
[meta, filtered_fastq] = [[id: 'sample1', coverage: '50x'], 'sample1_50x.fastq.gz']

// Publish uses meta for path
publishDir "results/${meta.condition}/${meta.coverage}/"
```

## Building the FILTLONG Process

Let's build the module step by step. I'll show focused sections first, then the complete file at the end.

### Step 1: Process Declaration

```groovy
process FILTLONG {
    tag "$meta.id"
    label 'process_medium'
```

**Line-by-line**:
- `process FILTLONG`: Declares a process named FILTLONG
- `tag "$meta.id"`: Shows sample ID in Nextflow execution logs (helpful for tracking progress)
- `label 'process_medium'`: Resource label (defined in config) for medium CPU/memory jobs

**DSL2 Note**: In DSL2, processes are first-class objects that can be imported and called like functions.

### Step 2: Software Configuration

```groovy
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/filtlong:0.2.1--h9a82719_1' :
        'biocontainers/filtlong:0.2.1--h9a82719_1' }"
```

**Conda line**:
- `${moduleDir}`: Built-in variable pointing to module directory (`modules/local/filtlong/`)
- `environment.yml`: Conda environment specification

**Container line**:
- Ternary operator: `condition ? if_true : if_false`
- If Singularity: Use Singularity image URL
- Otherwise: Use Docker image name
- `biocontainers/filtlong:0.2.1--h9a82719_1`: Official biocontainer with filtlong v0.2.1

**Why both?**: Different execution environments prefer different tools:
- HPC clusters: Often use Singularity
- Cloud/local: Often use Docker
- Development: Might use Conda

### Step 3: Input Definition

```groovy
    input:
    tuple val(meta), path(reads), path(assembly), path(illumina_1), path(illumina_2)
```

**DSL2 Input Syntax**:
- `tuple`: Multiple values bundled together
- `val(meta)`: Value channel (the meta map)
- `path(reads)`: File channel (input FASTQ)
- `path(assembly)`: Optional reference genome
- `path(illumina_1)`: Optional Illumina R1
- `path(illumina_2)`: Optional Illumina R2

**Handling Optional Inputs**: We'll pass placeholder values (like `'NO_ASSEMBLY'`) for missing files, checking in the script.

### Step 4: Output Definition

```groovy
    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    path "versions.yml"                , emit: versions
```

**Output Channels**:
- `tuple val(meta), path("*.fastq.gz")`: Meta + filtered reads (preserves metadata!)
- `path "versions.yml"`: Software versions (separate channel)

**emit**: Names the output channel for referencing:
```groovy
FILTLONG(input_ch)
filtered_reads = FILTLONG.out.reads     // Get the reads channel
versions = FILTLONG.out.versions         // Get the versions channel
```

### Step 5: Conditional Execution

```groovy
    when:
    task.ext.when == null || task.ext.when
```

**Purpose**: Allow conditional process execution via config:

```groovy
// In nextflow.config
process {
    withName: FILTLONG {
        ext.when = { meta.coverage as int > 0 }  // Only run if coverage specified
    }
}
```

**Default behavior**: If `task.ext.when` not set, process always runs.

### Step 6: Script Section - Dynamic Command Building

This is where the magic happens. We build the filtlong command dynamically based on meta map contents.

#### Define Output Prefix

```groovy
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
```

**Groovy Elvis Operator** (`?:`):
- Use `task.ext.prefix` if set, otherwise use `meta.id`
- Allows output naming customization via config

#### Coverage Calculation

```groovy
    // Build filtlong command dynamically based on meta parameters
    def filtlong_options = []

    // Calculate target bases based on genome size and coverage
    if (meta.genome_size && meta.coverage) {
        def genome_bases = meta.genome_size  // Already parsed to integer in validation
        def coverage_val = meta.coverage.toString().replaceAll(/x$/, '').toInteger()
        def target = (genome_bases * coverage_val).toLong()
        filtlong_options << "--target_bases ${target}"
    }
```

**Step-by-step**:
1. Create empty list for options: `def filtlong_options = []`
2. Check if both `genome_size` and `coverage` exist in meta
3. Get genome size (already integer from validation)
4. Parse coverage string: `"50x"` → `50` (remove trailing 'x')
5. Calculate target: `4,500,000 × 50 = 225,000,000`
6. Cast to Long (large numbers need explicit type)
7. Add to options list: `<< "--target_bases 225000000"`

**Why `.toLong()`?**: 1000x coverage of human genome = 3 trillion bases (exceeds Integer.MAX_VALUE)

#### Numeric Parameters

```groovy
    // Add numeric options if present in meta
    if (meta.min_length) filtlong_options << "--min_length ${meta.min_length}"
    if (meta.keep_percent) filtlong_options << "--keep_percent ${meta.keep_percent}"
    if (meta.min_mean_q) filtlong_options << "--min_mean_q ${meta.min_mean_q}"
    if (meta.min_window_q) filtlong_options << "--min_window_q ${meta.min_window_q}"
    if (meta.window_size) filtlong_options << "--window_size ${meta.window_size}"
```

**Pattern**: For each optional parameter, check if it exists in meta, then add to command.

**Groovy truth**: `if (meta.min_length)` is true if:
- Field exists AND
- Value is not null AND
- Value is not 0, false, or empty string

#### Weight Parameters

```groovy
    // Add weight options
    if (meta.length_weight) filtlong_options << "--length_weight ${meta.length_weight}"
    if (meta.mean_q_weight) filtlong_options << "--mean_q_weight ${meta.mean_q_weight}"
    if (meta.window_q_weight) filtlong_options << "--window_q_weight ${meta.window_q_weight}"
```

Same pattern for weight parameters.

#### Boolean and Special Options

```groovy
    // Add boolean options
    if (meta.trim) filtlong_options << "--trim"
    if (meta.split) filtlong_options << "--split ${meta.split}"
```

**Trim**: Boolean flag (no value)
**Split**: Special parameter with value (max split size)

#### Reference Files

```groovy
    // Add reference files if provided
    if (assembly && assembly.name != 'NO_ASSEMBLY') filtlong_options << "-a ${assembly}"
    if (illumina_1 && illumina_1.name != 'NO_ILLUMINA_1') filtlong_options << "-1 ${illumina_1}"
    if (illumina_2 && illumina_2.name != 'NO_ILLUMINA_2') filtlong_options << "-2 ${illumina_2}"
```

**Placeholder pattern**:
- Workflow passes `file('NO_ASSEMBLY')` for missing assembly
- Check filename to distinguish real files from placeholders
- Only add option if real file provided

**Why not null?**: Nextflow channels don't handle null well. Placeholder files are more robust.

#### Join Options

```groovy
    // Join all options
    def options_str = filtlong_options.join(' ')
```

**Example**:
```groovy
filtlong_options = [
    "--target_bases 225000000",
    "--min_length 500",
    "--length_weight 10"
]
options_str = "--target_bases 225000000 --min_length 500 --length_weight 10"
```

### Step 7: Command Execution

```groovy
    """
    filtlong \\
        ${options_str} \\
        $reads \\
        | gzip > ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version 2>&1 | sed 's/Filtlong v//')
    END_VERSIONS
    """
```

**Triple-quoted string** (`"""`): Bash script to execute

**Command breakdown**:
```bash
filtlong \                                    # Run filtlong
    --target_bases 225000000 \               # With dynamic options
    --min_length 500 \
    --length_weight 10 \
    sample1.fastq.gz \                       # Input file
    | gzip > sample1.fastq.gz                # Compress and save
```

**Backslashes** (`\`): Line continuation for readability

**Version tracking**:
```bash
cat <<-END_VERSIONS > versions.yml
"FILTLONG":
    filtlong: $(filtlong --version 2>&1 | sed 's/Filtlong v//')
END_VERSIONS
```

Creates YAML file with software version for reproducibility.

**Dollar escaping**:
- `${prefix}`: Groovy variable (evaluated by Nextflow)
- `\$(filtlong --version)`: Bash command (evaluated at runtime)

### Step 8: Stub Section

```groovy
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version 2>&1 | sed 's/Filtlong v//')
    END_VERSIONS
    """
```

**Purpose**: Fast execution for testing workflow logic without running real tools.

**Usage**:
```bash
nextflow run main.nf -stub
# Creates empty output files, skips actual filtlong execution
```

**When to use**:
- Testing channel operations
- Validating publishDir paths
- Checking workflow structure
- CI/CD smoke tests

## Environment Configuration

Create `modules/local/filtlong/environment.yml`:

```yaml
name: filtlong
channels:
  - conda-forge
  - bioconda
dependencies:
  - bioconda::filtlong=0.2.1
```

**Purpose**: Specifies exact software versions for conda environments.

## Complete Module Code

Now that we understand each part, here's the complete `modules/local/filtlong/main.nf`:

```groovy
process FILTLONG {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/filtlong:0.2.1--h9a82719_1' :
        'biocontainers/filtlong:0.2.1--h9a82719_1' }"

    input:
    tuple val(meta), path(reads), path(assembly), path(illumina_1), path(illumina_2)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Build filtlong command dynamically based on meta parameters
    def filtlong_options = []

    // Calculate target bases based on genome size and coverage
    if (meta.genome_size && meta.coverage) {
        def genome_bases = meta.genome_size  // Already parsed to integer in validation
        def coverage_val = meta.coverage.toString().replaceAll(/x$/, '').toInteger()
        def target = (genome_bases * coverage_val).toLong()
        filtlong_options << "--target_bases ${target}"
    }

    // Add numeric options if present in meta
    if (meta.min_length) filtlong_options << "--min_length ${meta.min_length}"
    if (meta.keep_percent) filtlong_options << "--keep_percent ${meta.keep_percent}"
    if (meta.min_mean_q) filtlong_options << "--min_mean_q ${meta.min_mean_q}"
    if (meta.min_window_q) filtlong_options << "--min_window_q ${meta.min_window_q}"
    if (meta.window_size) filtlong_options << "--window_size ${meta.window_size}"

    // Add weight options
    if (meta.length_weight) filtlong_options << "--length_weight ${meta.length_weight}"
    if (meta.mean_q_weight) filtlong_options << "--mean_q_weight ${meta.mean_q_weight}"
    if (meta.window_q_weight) filtlong_options << "--window_q_weight ${meta.window_q_weight}"

    // Add boolean options
    if (meta.trim) filtlong_options << "--trim"
    if (meta.split) filtlong_options << "--split ${meta.split}"

    // Add reference files if provided
    if (assembly && assembly.name != 'NO_ASSEMBLY') filtlong_options << "-a ${assembly}"
    if (illumina_1 && illumina_1.name != 'NO_ILLUMINA_1') filtlong_options << "-1 ${illumina_1}"
    if (illumina_2 && illumina_2.name != 'NO_ILLUMINA_2') filtlong_options << "-2 ${illumina_2}"

    // Join all options
    def options_str = filtlong_options.join(' ')

    """
    filtlong \\
        ${options_str} \\
        $reads \\
        | gzip > ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version 2>&1 | sed 's/Filtlong v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version 2>&1 | sed 's/Filtlong v//')
    END_VERSIONS
    """
}
```

## Usage Examples

### Example 1: Simple Usage

```groovy
// In workflow
include { FILTLONG } from './modules/local/filtlong/main'

workflow {
    // Create input channel
    input_ch = Channel.of([
        [
            id: 'sample1',
            coverage: '50x',
            genome_size: 4500000,
            min_length: 500,
            length_weight: 10
        ],
        file('sample1.fastq.gz'),
        file('NO_ASSEMBLY'),
        file('NO_ILLUMINA_1'),
        file('NO_ILLUMINA_2')
    ])

    // Run process
    FILTLONG(input_ch)

    // Use output
    FILTLONG.out.reads.view()
}
```

**Generated command**:
```bash
filtlong --target_bases 225000000 --min_length 500 --length_weight 10 sample1.fastq.gz | gzip > sample1.fastq.gz
```

### Example 2: With Reference Genome

```groovy
input_ch = Channel.of([
    [
        id: 'sample2',
        coverage: '100x',
        genome_size: 4600000,
        min_length: 500,
        length_weight: 10
    ],
    file('sample2.fastq.gz'),
    file('ecoli_ref.fasta'),  // Real reference
    file('NO_ILLUMINA_1'),
    file('NO_ILLUMINA_2')
])
```

**Generated command**:
```bash
filtlong --target_bases 460000000 --min_length 500 --length_weight 10 -a ecoli_ref.fasta sample2.fastq.gz | gzip > sample2.fastq.gz
```

### Example 3: Full Hybrid Filtering

```groovy
input_ch = Channel.of([
    [
        id: 'sample3',
        coverage: '50x',
        genome_size: 4500000,
        min_length: 500,
        length_weight: 10,
        mean_q_weight: 2
    ],
    file('nanopore.fastq.gz'),
    file('reference.fasta'),
    file('illumina_R1.fastq.gz'),
    file('illumina_R2.fastq.gz')
])
```

**Generated command**:
```bash
filtlong --target_bases 225000000 --min_length 500 --length_weight 10 --mean_q_weight 2 -a reference.fasta -1 illumina_R1.fastq.gz -2 illumina_R2.fastq.gz nanopore.fastq.gz | gzip > sample3.fastq.gz
```

## Design Decisions and Trade-offs

### Decision 1: Meta-based Parameters vs Config-based

**Our choice**: Meta-based (parameters in meta map)

**Alternative**: Config-based (parameters in `task.ext.args`)

```groovy
// Config-based approach
process {
    withName: FILTLONG {
        ext.args = '--min_length 500 --length_weight 10'
    }
}
```

**Trade-offs**:

| Approach | Pros | Cons |
|----------|------|------|
| Meta-based | Per-sample flexibility, programmatic control | More complex code |
| Config-based | Simple, standard nf-core pattern | All samples same params |

**Why meta-based?**: Benchmarking requires different parameters per sample (different genomes, different coverage levels).

### Decision 2: Placeholder Files vs Optional Channels

**Our choice**: Placeholder files (`NO_ASSEMBLY`)

**Alternative**: Optional channels with `mix()` operators

```groovy
// Optional approach (more complex)
input:
tuple val(meta), path(reads)
each path(assembly)  // Optional

workflow {
    reads_ch = Channel.of(...)
    assembly_ch = Channel.fromPath('*.fasta').mix(Channel.of('NO_FILE'))
    FILTLONG(reads_ch.combine(assembly_ch))
}
```

**Trade-offs**:

| Approach | Pros | Cons |
|----------|------|------|
| Placeholders | Simple logic, clear intent | Slight overhead |
| Optional channels | More "pure" Nextflow | Complex channel ops |

**Why placeholders?**: Simpler module code, easier to understand, clearer error messages.

### Decision 3: Dynamic Command Building vs Template

**Our choice**: Dynamic building in Groovy

**Alternative**: External template file

```groovy
// Template approach
template 'filtlong.sh'
```

**Trade-offs**:

| Approach | Pros | Cons |
|----------|------|------|
| Dynamic | All logic in one file, flexible | Groovy required |
| Template | Cleaner for complex scripts | Split logic |

**Why dynamic?**: Our command is relatively simple, and keeping everything in one file is easier to maintain.

## Common Pitfalls

### Pitfall 1: Forgetting to Stage Files

**Wrong**:
```groovy
input:
tuple val(meta), val(reads)  // val() instead of path()
```

**Correct**:
```groovy
input:
tuple val(meta), path(reads)  // path() stages file in work dir
```

**Why it matters**: `path()` copies/symlinks file to process work directory. `val()` just passes the string.

### Pitfall 2: Integer Overflow

**Wrong**:
```groovy
def target = (genome_bases * coverage_val).toInteger()
// Human genome 100x = 300,000,000,000 > Integer.MAX_VALUE!
```

**Correct**:
```groovy
def target = (genome_bases * coverage_val).toLong()
```

### Pitfall 3: Not Escaping Dollar Signs

**Wrong**:
```groovy
"""
echo $(date) > log.txt  # Nextflow evaluates $(date) before execution!
"""
```

**Correct**:
```groovy
"""
echo \$(date) > log.txt  # Bash evaluates at runtime
"""
```

## Testing the Module

Quick test without full workflow:

```bash
# Create test directory
mkdir -p test_filtlong
cd test_filtlong

# Create minimal workflow
cat > test.nf <<'EOF'
#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { FILTLONG } from '../modules/local/filtlong/main'

workflow {
    meta = [
        id: 'test',
        coverage: '10x',
        genome_size: 1000000,
        min_length: 100,
        length_weight: 5
    ]

    input_ch = Channel.of([
        meta,
        file(params.test_fastq),
        file('NO_ASSEMBLY'),
        file('NO_ILLUMINA_1'),
        file('NO_ILLUMINA_2')
    ])

    FILTLONG(input_ch)
    FILTLONG.out.reads.view()
}
EOF

# Run test
nextflow run test.nf --test_fastq /path/to/test.fastq.gz -profile docker
```

**Expected output**:
```
[test, /path/to/work/xx/xxxxx.../test.fastq.gz]
```

## What's Next?

We now have a functional FILTLONG module! But how do we get data into it? In **Post 4**, we'll build the samplesheet validation system that:

- Parses CSV samplesheets with flexible formats
- Validates file existence and formats
- Parses genome sizes (4.5m, 4.5Mbp, etc.)
- Creates the meta maps we use here
- Provides helpful error messages

---

**Previous**: [Part 2 - Understanding Filtlong](blogpost_2_understanding_filtlong_coverage_filtering.md)
**Next**: [Part 4 - Samplesheet Design and Validation](blogpost_4_samplesheet_design_validation.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. **Creating Your First nf-core Module** ← You are here
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
