# Comprehensive Testing with nf-test

**Series: Part 9 of 12**

## Introduction

Testing is essential for maintainable pipelines. With nf-test, we can test at multiple levels:

- **Module tests**: Individual processes work correctly
- **Workflow tests**: Processes integrate properly
- **Pipeline tests**: End-to-end functionality

In this post, we'll implement a complete test suite following nf-core standards.

## nf-test Basics

### Installation

```bash
# Install nf-test
curl -fsSL https://code.askimed.com/install/nf-test | bash

# Or use conda
conda install -c bioconda nf-test
```

### Test File Structure

```groovy
nextflow_process {  //or nextflow_workflow, nextflow_pipeline
    name "Test FILTLONG"
    script "../main.nf"
    process "FILTLONG"

    test("Should filter reads to target coverage") {
        when {
            process {
                // Input data
            }
        }

        then {
            assert process.success
            assert snapshot(process.out).match()
        }
    }
}
```

## Module Testing

### Test Directory Structure

```
modules/local/filtlong/
├── main.nf
├── environment.yml
├── meta.yml
└── tests/
    ├── main.nf.test
    └── tags.yml
```

### FILTLONG Module Test

`modules/local/filtlong/tests/main.nf.test`:

```groovy
nextflow_process {

    name "Test FILTLONG"
    script "../main.nf"
    process "FILTLONG"

    tag "modules"
    tag "modules_local"
    tag "filtlong"

    test("Should filter E. coli reads to 50x coverage") {

        when {
            process {
                """
                input[0] = [
                    [
                        id: 'test',
                        condition: 'native',
                        coverage: '50x',
                        genome_size: 4600000,
                        min_length: 500,
                        length_weight: 10
                    ],
                    file(params.test_data['ecoli']['fastq_gz'], checkIfExists: true),
                    file('NO_ASSEMBLY'),
                    file('NO_ILLUMINA_1'),
                    file('NO_ILLUMINA_2')
                ]
                """
            }
        }

        then {
            assert process.success
            assert process.out.reads
            assert process.out.reads.size() == 1

            // Check output file exists
            def filtered_file = process.out.reads[0][1]
            assert filtered_file.exists()

            // Check output is gzipped FASTQ
            assert filtered_file.name.endsWith('.fastq.gz')

            // Versions file created
            assert process.out.versions
        }
    }

    test("Should handle reference-based filtering") {

        when {
            process {
                """
                input[0] = [
                    [
                        id: 'test_ref',
                        condition: 'native',
                        coverage: '30x',
                        genome_size: 4600000,
                        min_length: 500
                    ],
                    file(params.test_data['ecoli']['fastq_gz'], checkIfExists: true),
                    file(params.test_data['ecoli']['fasta'], checkIfExists: true),
                    file('NO_ILLUMINA_1'),
                    file('NO_ILLUMINA_2')
                ]
                """
            }
        }

        then {
            assert process.success
            assert process.out.reads.size() == 1
        }
    }

    test("Should work with minimal parameters") {

        when {
            process {
                """
                input[0] = [
                    [
                        id: 'test_minimal',
                        condition: 'native'
                    ],
                    file(params.test_data['ecoli']['fastq_gz'], checkIfExists: true),
                    file('NO_ASSEMBLY'),
                    file('NO_ILLUMINA_1'),
                    file('NO_ILLUMINA_2')
                ]
                """
            }
        }

        then {
            assert process.success
            // Without genome_size, filtlong runs but doesn't target coverage
        }
    }
}
```

**Test structure**:
- Multiple `test()` blocks for different scenarios
- `when`: Setup inputs
- `then`: Assert expected outcomes

### SAMPLESHEET_CHECK Module Test

`modules/local/samplesheet_check/tests/main.nf.test`:

```groovy
nextflow_process {

    name "Test SAMPLESHEET_CHECK"
    script "../main.nf"
    process "SAMPLESHEET_CHECK"

    tag "modules"
    tag "modules_local"
    tag "samplesheet_check"

    test("Should validate valid samplesheet") {

        when {
            process {
                """
                input[0] = file("${projectDir}/tests/data/samplesheets/test_simple.csv")
                """
            }
        }

        then {
            assert process.success
            assert process.out.csv
            assert snapshot(process.out).match()
        }
    }

    test("Should fail on invalid samplesheet") {

        when {
            process {
                """
                input[0] = file("${projectDir}/tests/data/samplesheets/test_invalid.csv")
                """
            }
        }

        then {
            assert process.failed
        }
    }
}
```

### Running Module Tests

```bash
# Run all tests
nf-test test

# Run specific module tests
nf-test test modules/local/filtlong/tests/main.nf.test

# Run tests with specific tags
nf-test test --tag filtlong

# Update snapshots
nf-test test --update-snapshot
```

## Workflow Testing

### Workflow Test Structure

`workflows/rna_coverage_benchmark/tests/main.nf.test`:

```groovy
nextflow_workflow {

    name "Test RNA_COVERAGE_BENCHMARK workflow"
    script "../main.nf"
    workflow "RNA_COVERAGE_BENCHMARK"

    tag "workflows"
    tag "rna_coverage_benchmark"

    test("Should process multiple samples at multiple coverages") {

        when {
            workflow {
                """
                input[0] = Channel.fromPath("${projectDir}/tests/data/samplesheets/test_with_params.csv")
                """
            }
            params {
                coverage_levels = "10x,20x"
            }
        }

        then {
            assert workflow.success
            assert workflow.out.filtered_reads
            assert workflow.out.filtered_reads.size() == 4  // 2 samples × 2 coverages
            assert workflow.out.versions
        }
    }

    test("Should handle per-sample genome sizes") {

        when {
            workflow {
                """
                input[0] = Channel.fromPath("${projectDir}/tests/data/samplesheets/test_mixed_genomes.csv")
                """
            }
            params {
                coverage_levels = "50x"
            }
        }

        then {
            assert workflow.success
            // Each sample can have different genome size
            assert workflow.out.filtered_reads.size() == 3  // 3 samples × 1 coverage
        }
    }
}
```

## Pipeline Testing

### Pipeline Test

`tests/pipeline/main.nf.test`:

```groovy
nextflow_pipeline {

    name "Test complete pipeline"
    script "main.nf"

    tag "pipeline"

    test("Should run end-to-end with test data") {

        when {
            params {
                input = "${projectDir}/tests/data/samplesheets/test_simple.csv"
                genome_size = "1m"
                min_length = 100
                coverage_levels = "10x,20x"
                outdir = "${outputDir}"
            }
        }

        then {
            assert workflow.success

            // Check output directories created
            assert path("${outputDir}/native/10x").exists()
            assert path("${outputDir}/native/20x").exists()

            // Check output files exist
            assert path("${outputDir}/native/10x").list().size() > 0
            assert path("${outputDir}/native/20x").list().size() > 0

            // Check pipeline info
            assert path("${outputDir}/pipeline_info").exists()
        }
    }

    test("Should handle global and per-sample parameters") {

        when {
            params {
                input = "${projectDir}/tests/data/samplesheets/test_with_params.csv"
                length_weight = 5  // Global default
                coverage_levels = "50x"
                outdir = "${outputDir}"
            }
        }

        then {
            assert workflow.success
            // Some samples override global length_weight
        }
    }
}
```

## Test Data

### Minimal Test Data

Create small test files for fast testing:

**Create test FASTQ** (`tests/data/fastq/test.fastq.gz`):

```bash
# Generate 100 synthetic reads
python << 'EOF'
import gzip
import random

def generate_read(i, length=1000):
    bases = "".join(random.choices("ACGT", k=length))
    quality = "".join(["I"] * length)
    return f"@read_{i}\n{bases}\n+\n{quality}\n"

with gzip.open("tests/data/fastq/test.fastq.gz", "wt") as f:
    for i in range(100):
        f.write(generate_read(i))
EOF
```

**Test samplesheet** (`tests/data/samplesheets/test_simple.csv`):

```csv
sample,condition,fastq
test1,native,../../tests/data/fastq/test.fastq.gz
test2,ivt,../../tests/data/fastq/test.fastq.gz
```

### Test Data Configuration

`nextflow.config`:

```groovy
params {
    test_data = [
        'test': [
            'fastq_gz': "${projectDir}/tests/data/fastq/test.fastq.gz"
        ]
    ]
}
```

## Snapshot Testing

### What Are Snapshots?

Snapshots capture expected output for regression testing.

```groovy
test("Should produce consistent output") {
    when {
        process {
            // inputs
        }
    }

    then {
        assert snapshot(process.out).match()
    }
}
```

**First run**: Creates snapshot file
**Subsequent runs**: Compares output to snapshot

### Snapshot Files

Stored in `tests/.nf-test/snapshots/`:

```json
{
  "Should filter reads": {
    "content": [
      {
        "0": [
          [
            {"id": "test", "condition": "native"},
            "test.fastq.gz:md5,abc123..."
          ]
        ]
      }
    ]
  }
}
```

### Updating Snapshots

```bash
# Update all snapshots
nf-test test --update-snapshot

# Update specific test
nf-test test modules/local/filtlong/tests/ --update-snapshot
```

## Complete Test Suite

### Directory Structure

```
tests/
├── data/
│   ├── fastq/
│   │   └── test.fastq.gz
│   └── samplesheets/
│       ├── test_simple.csv
│       ├── test_with_params.csv
│       └── test_invalid.csv
├── pipeline/
│   └── main.nf.test
└── .nf-test/
    ├── nf-test.config
    └── snapshots/
```

### nf-test Configuration

`.nf-test.config`:

```groovy
config {
    // Test profiles
    testsDir "tests"

    // Cleanup after tests
    cleanup = true

    // Profiles for different test scenarios
    profile "test" {
        params.max_cpus = 2
        params.max_memory = '6.GB'
    }
}
```

## Running Tests in CI/CD

### GitHub Actions Workflow

`.github/workflows/ci.yml`:

```yaml
name: nf-test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        nxf_version: ['23.04.0', 'latest-everything']

    steps:
      - uses: actions/checkout@v3

      - name: Install Nextflow
        uses: nf-core/setup-nextflow@v1
        with:
          version: ${{ matrix.nxf_version }}

      - name: Install nf-test
        run: |
          curl -fsSL https://code.askimed.com/install/nf-test | bash
          sudo mv nf-test /usr/local/bin/

      - name: Run nf-test
        run: nf-test test --profile test

      - name: Upload test reports
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-reports
          path: .nf-test/reports/
```

## Best Practices

1. **Test at all levels**: Module, workflow, pipeline
2. **Use small test data**: Fast execution
3. **Test error cases**: Not just success paths
4. **Use snapshots**: Catch regressions
5. **Tag tests**: Easy selective running
6. **CI integration**: Automated testing on every commit
7. **Keep tests maintainable**: Clear, focused tests

## What's Next?

Our pipeline is now tested! In **Post 10**, we'll add professional metadata and documentation:

- Module meta.yml files
- Complete documentation structure
- Usage guides and examples
- Parameter references

---

**Previous**: [Part 8 - Multi-Coverage Outputs](blogpost_8_generating_multi_coverage_outputs.md)
**Next**: [Part 10 - Module Metadata and Documentation](blogpost_10_module_metadata_documentation.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. **Comprehensive Testing with nf-test** ← You are here
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
