# Generating Multi-Coverage Outputs

**Series: Part 8 of 12**

## Introduction

Our pipeline generates dozens or hundreds of output files (sample × coverage combinations). Without organization, this becomes chaos:

```
results/
├── native_1_10x.fastq.gz
├── native_1_20x.fastq.gz
├── native_1_50x.fastq.gz
├── native_2_10x.fastq.gz
├── native_2_20x.fastq.gz
... 100+ files in one directory!
```

In this post, we'll implement an organized output structure using Next flow's `publishDir` directive and meta map information.

## Target Output Structure

```
results/
├── native/
│   ├── 10x/
│   │   ├── native_1_filtered.fastq.gz
│   │   ├── native_2_filtered.fastq.gz
│   │   └── native_3_filtered.fastq.gz
│   ├── 20x/
│   │   ├── native_1_filtered.fastq.gz
│   │   ├── native_2_filtered.fastq.gz
│   │   └── native_3_filtered.fastq.gz
│   └── 50x/
│       └── ...
├── ivt/
│   ├── 10x/
│   │   ├── ivt_1_filtered.fastq.gz
│   │   ├── ivt_2_filtered.fastq.gz
│   │   └── ivt_3_filtered.fastq.gz
│   └── 20x/
│       └── ...
└── pipeline_info/
    ├── samplesheet.valid.csv
    └── software_versions.yml
```

**Benefits**:
- Easy to find specific condition/coverage combinations
- Compare same coverage across conditions
- Compare different coverages within conditions
- Clean, professional organization

## Understanding publishDir

### Basic Syntax

```groovy
process MY_PROCESS {
    publishDir '/path/to/output', mode: 'copy'

    output:
    path "output.txt"

    script:
    """
    echo "result" > output.txt
    """
}
```

**How it works**:
1. Process executes in work directory: `work/ab/cd1234.../`
2. Creates `output.txt` in work directory
3. `publishDir` copies to `/path/to/output/output.txt`

**Work directory preserved**: Original stays in work, copy goes to output (important for caching).

### publishDir Options

**`path`**: Where to publish (can use closures for dynamic paths)

**`mode`**: How to publish files
- `'copy'`: Copy files (safe, uses storage)
- `'symlink'`: Symbolic link (saves space, breaks if work cleaned)
- `'link'`: Hard link (saves space, same filesystem required)
- `'move'`: Move files (dangerous, breaks caching)

**`pattern`**: Which files to publish (glob pattern)

**`saveAs`**: Rename files or exclude (closure returning new name or null)

**`enabled`**: Boolean to enable/disable publishing

## Configuration Strategies

### Strategy 1: Module-Level Config (Our Approach)

Define publishDir in `conf/modules.config`:

```groovy
process {
    // Default for all processes
    publishDir = [
        path: { "${params.outdir}/${task.process.tokenize(':')[-1].tokenize('_')[0].toLowerCase()}" },
        mode: params.publish_dir_mode,
        saveAs: { filename -> filename.equals('versions.yml') ? null : filename }
    ]

    // Override for FILTLONG
    withName: 'FILTLONG' {
        publishDir = [
            path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" },
            mode: params.publish_dir_mode,
            pattern: '*.fastq.gz'
        ]
        label = 'process_medium'
    }

    // Override for SAMPLESHEET_CHECK
    withName: 'SAMPLESHEET_CHECK' {
        publishDir = [
            path: { "${params.outdir}/pipeline_info" },
            mode: params.publish_dir_mode,
            saveAs: { filename -> filename.equals('versions.yml') ? null : filename }
        ]
    }
}
```

**Advantages**:
- Clean separation: modules focus on logic, config handles output
- Easy to change output structure without editing modules
- nf-core standard pattern

### Strategy 2: Process-Level publishDir

Define directly in process:

```groovy
process FILTLONG {
    publishDir "${params.outdir}/${meta.condition}/${meta.coverage}x", mode: 'copy'

    // ...
}
```

**Trade-offs**:
- Simpler for small pipelines
- Harder to customize without editing modules
- Not recommended for nf-core

## Dynamic Paths with Meta Map

### The Power of Closures

```groovy
publishDir = [
    path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" }
]
```

**Closure syntax**: `{ ... }` creates a function evaluated at runtime.

**Why needed**: `meta` doesn't exist when config is parsed, only when process executes.

**How it works**:
```groovy
// At parse time: Closure created
path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" }

// At runtime for each execution:
meta = [condition: 'native', coverage: '10x']
// Closure evaluated: "results/native/10x"

meta = [condition: 'ivt', coverage: '20x']
// Closure evaluated: "results/ivt/20x"
```

### Meta Map Requirements

Our FILTLONG process provides perfect meta:

```groovy
// From workflow
def new_meta = meta.clone()
new_meta.coverage = coverage
new_meta.condition = row.condition
new_meta.id = "${meta.id}_${coverage}"

// Emitted by FILTLONG
output:
tuple val(meta), path("*.fastq.gz"), emit: reads
```

**Meta contains**:
- `meta.id`: "sample1_10x"
- `meta.condition`: "native"
- `meta.coverage`: "10x"

**PublishDir uses**:
```groovy
path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" }
// Evaluates to: "results/native/10x"
```

## File Naming Strategies

### Option 1: Keep Original Name

```groovy
process FILTLONG {
    script:
    def prefix = "${meta.id}"  // e.g., "sample1_10x"
    """
    filtlong ... | gzip > ${prefix}.fastq.gz
    """
}
```

**Output**: `results/native/10x/sample1_10x.fastq.gz`

**Pro**: Unique filename includes coverage
**Con**: Coverage redundant (already in path)

### Option 2: Simplify with saveAs

```groovy
publishDir = [
    path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" },
    saveAs: { filename ->
        // Remove coverage suffix from filename
        filename.replaceAll(/_\d+x/, '_filtered')
    }
]
```

**Output**: `results/native/10x/sample1_filtered.fastq.gz`

**Pro**: Cleaner filenames
**Con**: Slightly more complex

### Option 3: Sample-Only Names

```groovy
process FILTLONG {
    script:
    def prefix = "${meta.id}".replaceAll(/_\d+x$/, '')  // Remove coverage
    """
    filtlong ... | gzip > ${prefix}.fastq.gz
    """
}
```

**Output**: `results/native/10x/sample1.fastq.gz`

**Pro**: Simplest filenames
**Con**: Need directory context to know coverage

**Our choice**: Option 1 (full names) for clarity.

## Pattern Filtering

### Publish Only Specific Files

```groovy
withName: 'FILTLONG' {
    publishDir = [
        path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" },
        pattern: '*.fastq.gz'  // Only FASTQ files
    ]
}
```

**Why**: FILTLONG might create other files (logs, versions.yml). Only publish FASTQ.

### Multiple publishDir Directives

```groovy
withName: 'FILTLONG' {
    publishDir = [
        [
            path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" },
            pattern: '*.fastq.gz',
            mode: 'copy'
        ],
        [
            path: { "${params.outdir}/logs/${meta.condition}/${meta.coverage}x" },
            pattern: '*.log',
            mode: 'copy'
        ]
    ]
}
```

**Result**: Different file types to different locations.

## Excluding Files with saveAs

### Skip Version Files

```groovy
publishDir = [
    path: { "${params.outdir}/pipeline_info" },
    saveAs: { filename ->
        filename.equals('versions.yml') ? null : filename
    }
]
```

**Logic**:
- `saveAs` returns `null`: Don't publish
- `saveAs` returns string: Publish with that name
- `saveAs` not specified: Publish with original name

**Use case**: Collect versions separately, don't duplicate in process outputs.

### Conditional Publishing

```groovy
saveAs: { filename ->
    if (filename.endsWith('.log')) {
        return params.save_logs ? filename : null
    }
    return filename
}
```

**User control**: `--save_logs` determines if logs published.

## Complete Configuration

### conf/modules.config

```groovy
/*
========================================================================================
    Module-specific Configuration
========================================================================================
*/

process {
    // Default publishing strategy for all processes
    publishDir = [
        path: { "${params.outdir}/${task.process.tokenize(':')[-1].tokenize('_')[0].toLowerCase()}" },
        mode: params.publish_dir_mode,
        saveAs: { filename -> filename.equals('versions.yml') ? null : filename }
    ]

    // FILTLONG: Organize by condition and coverage
    withName: 'FILTLONG' {
        publishDir = [
            path: { "${params.outdir}/${meta.condition}/${meta.coverage}x" },
            mode: params.publish_dir_mode,
            pattern: '*.fastq.gz'
        ]
        label = 'process_medium'
        cpus = 4
        memory = 8.GB
    }

    // SAMPLESHEET_CHECK: Pipeline info directory
    withName: 'SAMPLESHEET_CHECK' {
        publishDir = [
            path: { "${params.outdir}/pipeline_info" },
            mode: params.publish_dir_mode,
            saveAs: { filename -> filename.equals('versions.yml') ? null : filename }
        ]
        label = 'process_single'
    }
}
```

### nextflow.config (relevant sections)

```groovy
params {
    outdir = './results'
    publish_dir_mode = 'copy'
}

includeConfig 'conf/modules.config'
```

## Example Output

### Running the Pipeline

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --genome_size 4.5m \
    --coverage_levels "10x,50x,100x" \
    -profile docker
```

**Samplesheet**:
```csv
sample,condition,fastq
native_1,native,/data/n1.fq.gz
native_2,native,/data/n2.fq.gz
ivt_1,ivt,/data/i1.fq.gz
```

### Generated Structure

```
results/
├── native/
│   ├── 10x/
│   │   ├── native_1_10x.fastq.gz
│   │   └── native_2_10x.fastq.gz
│   ├── 50x/
│   │   ├── native_1_50x.fastq.gz
│   │   └── native_2_50x.fastq.gz
│   └── 100x/
│       ├── native_1_100x.fastq.gz
│       └── native_2_100x.fastq.gz
├── ivt/
│   ├── 10x/
│   │   └── ivt_1_10x.fastq.gz
│   ├── 50x/
│   │   └── ivt_1_50x.fastq.gz
│   └── 100x/
│       └── ivt_1_100x.fastq.gz
└── pipeline_info/
    └── samplesheet.valid.csv
```

**Total**: 9 filtered files (3 samples × 3 coverages) organized in 6 coverage directories.

## Advanced: Multidimensional Organization

### By Sample First, Then Coverage

```groovy
path: { "${params.outdir}/${meta.id.replaceAll(/_\d+x$/, '')}/${meta.coverage}x" }
```

**Result**:
```
results/
├── native_1/
│   ├── 10x/native_1_10x.fastq.gz
│   ├── 50x/native_1_50x.fastq.gz
│   └── 100x/native_1_100x.fastq.gz
├── native_2/
│   └── ...
└── ivt_1/
    └── ...
```

**Use case**: When analyzing one sample across all coverages.

### Flat with Subdirectories

```groovy
path: { "${params.outdir}/filtered/${meta.condition}" }
```

**Result**:
```
results/
└── filtered/
    ├── native/
    │   ├── native_1_10x.fastq.gz
    │   ├── native_1_50x.fastq.gz
    │   ├── native_2_10x.fastq.gz
    │   └── ...
    └── ivt/
        └── ...
```

**Use case**: When coverage distinction less important than condition grouping.

## Troubleshooting

### Issue: Files Not Published

**Check**:
1. Process completed successfully?
2. Pattern matches output files?
3. `saveAs` not returning null?

**Debug**:
```groovy
publishDir = [
    path: { println "Publishing to: ${params.outdir}/${meta.condition}"; "${params.outdir}/${meta.condition}" },
    mode: 'copy'
]
```

### Issue: Wrong Directory Structure

**Debug meta map**:
```groovy
script:
println "Meta: ${meta}"
println "Path: ${params.outdir}/${meta.condition}/${meta.coverage}x"
```

### Issue: Files Overwriting Each Other

**Cause**: Non-unique filenames in same directory.

**Solution**: Include unique identifier in filename:
```groovy
def prefix = "${meta.id}"  // Includes sample name
```

## Best Practices

1. **Use meta maps** for dynamic paths
2. **Use closures** for runtime path evaluation
3. **Group related files** (by condition, coverage, sample)
4. **Keep work directory separate** (don't move, copy/link)
5. **Pattern match** to publish only relevant files
6. **Document structure** in README/docs
7. **Test with small datasets** before full run

## What's Next?

We have a complete, working pipeline with organized outputs! In **Post 9**, we'll ensure it keeps working by implementing comprehensive testing with nf-test:

- Module-level tests
- Workflow-level tests
- Pipeline-level end-to-end tests
- Test data generation
- Snapshot testing

---

**Previous**: [Part 7 - Schema Validation](blogpost_7_schema_validation_json_schema.md)
**Next**: [Part 9 - Comprehensive Testing with nf-test](blogpost_9_comprehensive_testing_nftest.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. **Generating Multi-Coverage Outputs** ← You are here
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
