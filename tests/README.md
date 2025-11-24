# Testing Infrastructure

This directory contains the testing infrastructure for the RNA Modification Coverage Benchmarking Pipeline, following nf-core standards with nf-test.

## Directory Structure

```
tests/
├── data/                       # Test data
│   ├── fastq/                  # Minimal test FASTQ files
│   │   ├── test_native_1.fastq.gz
│   │   └── test_ivt_1.fastq.gz
│   └── samplesheets/           # Test samplesheets
│       ├── test_simple.csv
│       ├── test_with_params.csv
│       └── test_invalid.csv
├── pipeline/                   # Pipeline-level tests
│   └── main.nf.test
└── README.md                   # This file
```

## Test Levels

### 1. Module Tests

Located in `modules/local/<module_name>/tests/main.nf.test`

- **SAMPLESHEET_CHECK**: Tests samplesheet validation
  - Valid simple samplesheet
  - Valid samplesheet with parameters
  - Invalid samplesheet (missing columns)

- **FILTLONG**: Tests read filtering
  - Basic parameter filtering
  - Per-sample parameter variations
  - Minimal parameters

### 2. Workflow Tests

Located in `workflows/rna_coverage_benchmark/tests/main.nf.test`

- Complete workflow with simple samplesheet
- Workflow with per-sample parameters
- Mixed global and per-sample parameters

### 3. Pipeline Tests

Located in `tests/pipeline/main.nf.test`

- Full pipeline execution with simple input
- Full pipeline with per-sample parameters
- Mixed parameter scenarios

## Test Data

### FASTQ Files

Minimal test FASTQ files with 3 reads each (~600-800 bp):
- `test_native_1.fastq.gz`: Native RNA sample
- `test_ivt_1.fastq.gz`: IVT RNA sample

### Samplesheets

1. **test_simple.csv**: Basic samplesheet (requires global parameters)
   ```csv
   sample,condition,fastq
   test_native_1,native,tests/data/fastq/test_native_1.fastq.gz
   test_ivt_1,ivt,tests/data/fastq/test_ivt_1.fastq.gz
   ```

2. **test_with_params.csv**: Samplesheet with per-sample parameters
   ```csv
   sample,condition,fastq,genome_size,min_length,length_weight
   test_native_1,native,tests/data/fastq/test_native_1.fastq.gz,2000,400,10
   test_ivt_1,ivt,tests/data/fastq/test_ivt_1.fastq.gz,2000,400,15
   ```

3. **test_invalid.csv**: Invalid samplesheet (missing condition column)

## Running Tests

### Prerequisites

Install nf-test:
```bash
curl -fsSL https://code.askimed.com/install/nf-test | bash
```

### Run All Tests

```bash
nf-test test
```

### Run Specific Test Levels

**Module tests only:**
```bash
nf-test test --tag modules
```

**Workflow tests only:**
```bash
nf-test test --tag workflows
```

**Pipeline tests only:**
```bash
nf-test test --tag pipeline
```

### Run Specific Module Tests

```bash
# Test SAMPLESHEET_CHECK module
nf-test test modules/local/samplesheet_check/tests/main.nf.test

# Test FILTLONG module
nf-test test modules/local/filtlong/tests/main.nf.test
```

### Run with Profiles

```bash
# Run with Docker
nf-test test --profile docker

# Run with Singularity
nf-test test --profile singularity
```

### Update Snapshots

If test outputs change intentionally, update snapshots:
```bash
nf-test test --update-snapshot
```

## Test Coverage

The testing infrastructure covers:

✅ **Input validation**
- Samplesheet format validation
- Parameter validation (genome size, numeric values, booleans)
- File existence checks

✅ **Core functionality**
- Filtlong filtering with various parameters
- Coverage level generation
- Per-sample parameter handling
- Global vs per-sample parameter precedence

✅ **Output organization**
- Directory structure by condition and coverage
- File naming conventions
- Pipeline info generation

✅ **Edge cases**
- Minimal parameters
- Maximum parameter combinations
- Invalid inputs
- Mixed parameter scenarios

## Adding New Tests

### 1. Module Tests

Create `modules/local/<module_name>/tests/main.nf.test`:

```groovy
nextflow_process {
    name "Test Process <MODULE_NAME>"
    script "../main.nf"
    process "<MODULE_NAME>"

    tag "modules"
    tag "modules_local"
    tag "<module_tag>"

    test("Test description") {
        when {
            process {
                """
                input[0] = // test input
                """
            }
        }

        then {
            assert process.success
            assert snapshot(process.out).match()
        }
    }
}
```

### 2. Workflow Tests

Create workflow-level tests in `workflows/<workflow_name>/tests/main.nf.test`

### 3. Pipeline Tests

Add pipeline-level tests in `tests/pipeline/main.nf.test`

## Test Data Guidelines

- Keep test data **minimal** (small FASTQ files)
- Use **realistic** but **simplified** scenarios
- Include **positive and negative** test cases
- Test **edge cases** and **error conditions**

## CI/CD Integration

Tests can be integrated into CI/CD pipelines:

```yaml
# .github/workflows/test.yml
- name: Run nf-test
  run: nf-test test --profile docker
```

## Troubleshooting

**Tests fail after code changes:**
1. Check if changes are intentional
2. Update snapshots if output format changed: `nf-test test --update-snapshot`
3. Review test expectations

**Can't find test data:**
- Ensure paths are relative to project root
- Check that test FASTQ files exist in `tests/data/fastq/`

**Module not found:**
- Verify module structure: `modules/local/<module>/main.nf`
- Check include paths in workflow files

## References

- [nf-test Documentation](https://code.askimed.com/nf-test/)
- [nf-core Testing Guidelines](https://nf-co.re/docs/contributing/modules#writing-tests)
- [Nextflow Testing Best Practices](https://www.nextflow.io/docs/latest/testing.html)
