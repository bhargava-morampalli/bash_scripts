# CI/CD Pipeline with GitHub Actions

**Series: Part 11 of 12**

## Introduction

Continuous Integration and Continuous Deployment (CI/CD) automates testing and quality checks. Every push and pull request triggers:

- Pipeline execution tests
- nf-test suite
- Code linting
- Branch protection

In this post, we'll implement a complete CI/CD system using GitHub Actions.

## GitHub Actions Overview

### Workflow Structure

```yaml
name: Workflow Name
on: [push, pull_request]  # Triggers

jobs:
  job_name:
    runs-on: ubuntu-latest
    steps:
      - name: Step name
        run: command
```

**Key concepts**:
- **Workflows**: Automated processes
- **Jobs**: Groups of steps (run in parallel by default)
- **Steps**: Individual tasks
- **Runners**: Machines executing jobs

## CI Workflow

### `.github/workflows/ci.yml`

```yaml
name: nf-core CI

on:
  push:
    branches: [dev, main, master]
  pull_request:
  release:
    types: [published]

env:
  NXF_ANSI_LOG: false

concurrency:
  group: "${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}"
  cancel-in-progress: true

jobs:
  test:
    name: Run pipeline with test data
    runs-on: ubuntu-latest
    strategy:
      matrix:
        NXF_VER:
          - "23.04.0"
          - "latest-everything"

    steps:
      - name: Check out pipeline code
        uses: actions/checkout@v4

      - name: Install Nextflow
        uses: nf-core/setup-nextflow@v1
        with:
          version: "${{ matrix.NXF_VER }}"

      - name: Run pipeline with test config
        run: |
          nextflow run ${GITHUB_WORKSPACE} \
            -profile test,docker \
            --outdir ./results

  nf-test:
    name: Run nf-test
    runs-on: ubuntu-latest

    steps:
      - name: Check out pipeline code
        uses: actions/checkout@v4

      - name: Install Nextflow
        uses: nf-core/setup-nextflow@v1

      - name: Install nf-test
        run: |
          wget -qO- https://code.askimed.com/install/nf-test | bash
          sudo mv nf-test /usr/local/bin/

      - name: Run nf-test
        run: |
          nf-test test --profile docker --verbose
```

**Features**:
- **Matrix testing**: Multiple Nextflow versions
- **Concurrency control**: Cancel old runs when new pushed
- **Test profile**: Uses small test data
- **nf-test integration**: Automated module/workflow tests

## Linting Workflow

### `.github/workflows/linting.yml`

```yaml
name: nf-core linting

on:
  push:
    branches: [dev, main, master]
  pull_request:
  release:
    types: [published]

jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
      - uses: pre-commit/action@v3.0.0

  EditorConfig:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: editorconfig-checker/action-editorconfig-checker@main

  Prettier:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actionsx/prettier@v2
        with:
          args: --check .

  nf-core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Nextflow
        uses: nf-core/setup-nextflow@v1

      - uses: actions/setup-python@v4
        with:
          python-version: "3.11"

      - name: Install nf-core tools
        run: pip install nf-core

      - name: Run nf-core lint
        run: nf-core lint --dir ${GITHUB_WORKSPACE}
```

**Quality checks**:
- **pre-commit**: General code quality hooks
- **EditorConfig**: Consistent file formatting
- **Prettier**: Code formatting
- **nf-core lint**: Pipeline-specific linting

## Branch Protection Workflow

### `.github/workflows/branch.yml`

```yaml
name: Branch protection

on:
  pull_request:
    branches: [master, main]

jobs:
  branch-check:
    runs-on: ubuntu-latest
    steps:
      - name: Check branch name
        run: |
          if [[ "${{ github.head_ref }}" =~ ^(dev|patch)/ ]]; then
            echo "✅ PR from valid branch: ${{ github.head_ref }}"
          else
            echo "❌ PRs to master/main must come from dev or patch branches"
            echo "Current branch: ${{ github.head_ref }}"
            exit 1
          fi
```

**Enforces**: PRs to master must come from `dev` or `patch/*` branches.

## Test Profile Configuration

### `conf/test.config`

```groovy
/*
========================================================================================
    Test Configuration
========================================================================================
    Minimal test dataset for CI/CD
*/

params {
    config_profile_name        = 'Test profile'
    config_profile_description = 'Minimal test dataset to check pipeline function'

    // Limit resources for GitHub Actions
    max_cpus   = 2
    max_memory = '6.GB'
    max_time   = '6.h'

    // Input files (use test data)
    input  = "${projectDir}/tests/data/samplesheets/test_simple.csv"
    outdir = './results'

    // Minimal coverage for fast testing
    coverage_levels = '10x,20x'

    // Test parameters
    genome_size   = '1m'
    min_length    = 100
    length_weight = 5
}
```

**Design**:
- Minimal resources for fast execution
- Small test dataset
- Quick coverage levels
- Completes in < 10 minutes

## Test Data for CI

### Minimal Test Files

Create lightweight test data:

```bash
# Generate tiny FASTQ
python << 'EOF'
import gzip

reads = ["@read{}\nACGT\n+\nIIII\n".format(i) for i in range(100)]

with gzip.open("tests/data/fastq/test.fastq.gz", "wt") as f:
    f.write("".join(reads))
EOF
```

**Test samplesheet** (`tests/data/samplesheets/test_simple.csv`):

```csv
sample,condition,fastq
test1,native,${projectDir}/tests/data/fastq/test.fastq.gz
test2,ivt,${projectDir}/tests/data/fastq/test.fastq.gz
```

## Workflow Triggers

### On Push

```yaml
on:
  push:
    branches: [dev, main]
```

**Effect**: Every push to dev/main triggers tests.

### On Pull Request

```yaml
on:
  pull_request:
    branches: [main]
```

**Effect**: Every PR to main triggers tests.

### On Release

```yaml
on:
  release:
    types: [published]
```

**Effect**: Creating a release triggers full test suite.

### Manual Trigger

```yaml
on:
  workflow_dispatch:
```

**Effect**: Can manually trigger from GitHub UI.

## Matrix Strategy

### Testing Multiple Versions

```yaml
strategy:
  matrix:
    NXF_VER:
      - "23.04.0"
      - "latest-everything"
    profile:
      - "docker"
      - "singularity"
```

**Result**: 4 test jobs (2 NXF versions × 2 profiles)

**Use case**: Ensure compatibility across versions.

## Artifacts and Reports

### Uploading Results

```yaml
- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: |
      results/**
      .nextflow.log
      .nf-test/reports/
```

**Features**:
- `if: always()`: Upload even if tests fail
- Multiple paths supported
- Available for download from GitHub UI

### Caching

```yaml
- name: Cache Nextflow assets
  uses: actions/cache@v3
  with:
    path: |
      ${{ runner.home }}/.nextflow
      work/conda
      work/singularity
    key: ${{ runner.os }}-nextflow-${{ hashFiles('**/main.nf') }}
```

**Benefits**:
- Faster subsequent runs
- Reduced downloads
- Lower costs for self-hosted runners

## Status Badges

Add to `README.md`:

```markdown
[![nf-core CI](https://github.com/bhargava-morampalli/bash_scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/bhargava-morampalli/bash_scripts/actions/workflows/ci.yml)
[![nf-core linting](https://github.com/bhargava-morampalli/bash_scripts/actions/workflows/linting.yml/badge.svg)](https://github.com/bhargava-morampalli/bash_scripts/actions/workflows/linting.yml)
```

**Shows**: Build status at a glance.

## GitHub Repository Settings

### Branch Protection Rules

Settings → Branches → Add rule:

**Rule for `main`**:
- ✅ Require pull request before merging
- ✅ Require status checks to pass
  - nf-core CI / test
  - nf-core CI / nf-test
  - nf-core linting / nf-core
- ✅ Require branches to be up to date
- ✅ Do not allow bypassing

### Required Reviews

- Require 1 reviewer approval
- Dismiss stale reviews on push
- Require review from code owners (optional)

## Local Testing Before Push

### Run Same Tests Locally

```bash
# Test profile
nextflow run . -profile test,docker

# nf-test
nf-test test

# Linting
nf-core lint .
```

**Benefit**: Catch issues before pushing.

## Debugging Failed Workflows

### View Logs

1. Go to Actions tab
2. Click failed workflow
3. Click failed job
4. Expand failed step

### Download Artifacts

1. Scroll to bottom of job
2. Download artifacts
3. Inspect `.nextflow.log`

### Re-run Failed Jobs

1. Click "Re-run jobs" button
2. Select "Re-run failed jobs"

## Complete CI/CD Setup

### File Structure

```
.github/
└── workflows/
    ├── ci.yml           # Main testing
    ├── linting.yml      # Code quality
    └── branch.yml       # Branch protection
```

### Configuration Files

```
conf/
├── base.config       # Base resources
├── test.config       # Test profile
└── modules.config    # Module config
```

### Test Data

```
tests/
├── data/
│   ├── fastq/
│   │   └── test.fastq.gz
│   └── samplesheets/
│       └── test_simple.csv
└── pipeline/
    └── main.nf.test
```

## Best Practices

1. **Fast CI tests**: Use minimal data
2. **Matrix testing**: Multiple versions
3. **Fail fast**: Quick feedback
4. **Cache dependencies**: Speed up runs
5. **Upload artifacts**: Debug failures
6. **Status badges**: Show build status
7. **Branch protection**: Require tests pass

## What's Next?

We now have automated CI/CD! In **Post 12** (final post), we'll add the finishing touches:

- CITATIONS.md
- Code organization
- nf-core lint compliance
- Release preparation

---

**Previous**: [Part 10 - Module Metadata](blogpost_10_module_metadata_documentation.md)
**Next**: [Part 12 - Final Polish and nf-core Compliance](blogpost_12_final_polish_nfcore_compliance.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. **CI/CD Pipeline with GitHub Actions** ← You are here
12. Final Polish and nf-core Compliance
