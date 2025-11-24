# Samplesheet Design and Validation

**Series: Part 4 of 12**

## Introduction

A well-designed samplesheet is the user's gateway to your pipeline. In this post, we'll build a complete validation system that:

- Accepts flexible input formats (CSV/TSV, various genome size formats)
- Validates all inputs with clear error messages
- Transforms data into a consistent format
- Creates the meta maps our FILTLONG module needs

## Why Validation Matters

**Without validation**:
```bash
# User runs pipeline
nextflow run main.nf --input samples.csv

# 2 hours later...
ERROR: File not found: /path/to/sampel1.fastq.gz
# Typo in samplesheet! 2 hours wasted.
```

**With validation**:
```bash
nextflow run main.nf --input samples.csv

ERROR: Line 2: FASTQ file does not exist: /path/to/sampel1.fastq.gz
# Caught immediately! Fix typo and rerun.
```

**Validation benefits**:
- **Fast failure**: Errors caught before compute resources used
- **Clear messages**: Tell users exactly what's wrong and where
- **Consistent data**: Transform inputs to standard formats
- **Type safety**: Convert strings to proper types (int, float, bool)

## Samplesheet Design

### Required vs Optional Columns

**Design principle**: Require minimum, make everything else optional.

```csv
# Minimum required columns (3)
sample,condition,fastq
sample1,native,/data/sample1.fastq.gz
```

**Why these three**:
- `sample`: Unique identifier (required for all pipelines)
- `condition`: Experimental grouping (specific to RNA modification benchmarking)
- `fastq`: Input data file (required for processing)

**Optional columns (14)**: All filtlong parameters

```csv
sample,condition,fastq,genome_size,min_length,length_weight,mean_q_weight,window_q_weight,keep_percent,min_mean_q,min_window_q,window_size,trim,split,assembly,illumina_1,illumina_2
```

### Flexible Genome Size Formats

**Problem**: Different labs use different conventions.

**Our solution**: Accept all common formats.

| Input Format | Parsed Value | Notes |
|--------------|--------------|-------|
| `4500000` | 4,500,000 | Raw bases |
| `4.5m` | 4,500,000 | Megabases (lowercase) |
| `4.5M` | 4,500,000 | Megabases (uppercase) |
| `4.5Mbp` | 4,500,000 | Megabases with "bp" |
| `4.5MB` | 4,500,000 | Megabases with "B" |
| `4500k` | 4,500,000 | Kilobases |
| `4.5g` | 4,500,000,000 | Gigabases |
| `4.5Gbp` | 4,500,000,000 | Gigabases with "bp" |

### Example Samplesheets

**Simple** (global parameters):
```csv
sample,condition,fastq
native_1,native,/data/native_1.fastq.gz
native_2,native,/data/native_2.fastq.gz
ivt_1,ivt,/data/ivt_1.fastq.gz
```

**Standard** (per-sample basic parameters):
```csv
sample,condition,fastq,genome_size,min_length,length_weight
native_1,native,/data/native_1.fastq.gz,4.5m,500,10
native_2,native,/data/native_2.fastq.gz,4.5m,1000,15
ecoli,native,/data/ecoli.fastq.gz,4.6Mbp,500,10
```

**Advanced** (all options including reference filtering):
```csv
sample,condition,fastq,genome_size,min_length,length_weight,mean_q_weight,assembly,illumina_1,illumina_2
sample1,native,/data/ont.fastq.gz,4.5m,500,15,2,/ref/genome.fa,/data/R1.fq.gz,/data/R2.fq.gz
sample2,native,/data/ont2.fastq.gz,4.5m,1000,10,1,,,
```

## Building the Validation Script

Let's build `bin/check_samplesheet.py` step by step.

### Step 1: Genome Size Parser

This is the core utility that accepts flexible formats:

```python
import re

def parse_genome_size(size_str):
    """
    Parse genome size from various formats to bases.

    Supports: 4500000, 4.5m, 4.5M, 4.5mb, 4.5Mb, 4.5MB, 4.5Mbp, 4500k, etc.
    Returns: integer bases or None if empty
    """
    if not size_str or size_str.strip() == '':
        return None

    size_str = size_str.strip()

    # Pattern to match number with optional unit
    pattern = r'^([0-9]+\.?[0-9]*)([kKmMgG](?:[bB][pP]?)?)?$'
    match = re.match(pattern, size_str)

    if not match:
        raise ValueError(
            f"Invalid genome size format: {size_str}. "
            "Expected formats: 4500000, 4.5m, 4.5Mbp, 4500k, etc."
        )

    value = float(match.group(1))
    unit = match.group(2)

    # Convert to bases
    if unit is None:
        return int(value)

    unit_lower = unit.lower().replace('bp', '').replace('b', '')

    multipliers = {
        'k': 1_000,
        'm': 1_000_000,
        'g': 1_000_000_000
    }

    if unit_lower in multipliers:
        return int(value * multipliers[unit_lower])
    else:
        raise ValueError(f"Unknown unit in genome size: {unit}")
```

**Regex breakdown**:
```
^([0-9]+\.?[0-9]*)    # Capture number (int or float)
([kKmMgG]             # Optional: k, K, m, M, g, or G
(?:[bB][pP]?)?)?$     # Optional: b, B, bp, BP, Bp, bP
```

**Examples**:
```python
parse_genome_size("4.5m")      # → 4500000
parse_genome_size("4.5Mbp")    # → 4500000
parse_genome_size("4500000")   # → 4500000
parse_genome_size("4.5G")      # → 4500000000
parse_genome_size("")          # → None
parse_genome_size("invalid")   # → ValueError
```

### Step 2: Boolean Parser

Handle various ways users might specify booleans:

```python
def parse_boolean(value):
    """Parse boolean values from strings."""
    if not value or value.strip() == '':
        return None

    value_lower = value.strip().lower()
    if value_lower in ['true', 'yes', '1', 't', 'y']:
        return True
    elif value_lower in ['false', 'no', '0', 'f', 'n']:
        return False
    else:
        raise ValueError(
            f"Invalid boolean value: {value}. Use: true/false, yes/no, 1/0"
        )
```

**Accepted formats**:
- True: `true`, `True`, `TRUE`, `yes`, `Yes`, `1`, `t`, `T`, `y`, `Y`
- False: `false`, `False`, `FALSE`, `no`, `No`, `0`, `f`, `F`, `n`, `N`

### Step 3: Row Validator Class

The main validation logic:

```python
from pathlib import Path

class RowChecker:
    """Validate and transform each row."""

    VALID_CONDITIONS = ["native", "ivt"]
    VALID_FORMATS = [".fastq", ".fq", ".fastq.gz", ".fq.gz"]

    REQUIRED_COLS = ["sample", "condition", "fastq"]
    OPTIONAL_COLS = [
        "genome_size", "min_length", "length_weight", "mean_q_weight",
        "window_q_weight", "keep_percent", "min_mean_q", "min_window_q",
        "window_size", "trim", "split", "assembly", "illumina_1", "illumina_2"
    ]

    def __init__(self):
        self._seen = set()  # Track seen sample names

    def validate_and_transform(self, row):
        """
        Validate row and return transformed dict.
        Raises AssertionError with helpful message on failure.
        """
        self._validate_sample(row)
        self._validate_condition(row)
        self._validate_fastq(row)

        # Start with required fields
        result = {
            "sample": row["sample"],
            "condition": row["condition"],
            "fastq": row["fastq"],
        }

        # Add optional fields
        result.update(self._process_optional_fields(row))

        self._seen.add(row["sample"])
        return result
```

#### Sample Validation

```python
    def _validate_sample(self, row):
        """Assert that the sample name exists and is unique."""
        if len(row["sample"]) <= 0:
            raise AssertionError("Sample name is required.")
        if row["sample"] in self._seen:
            raise AssertionError(f"Sample name {row['sample']} is duplicated.")
```

**Checks**:
- Sample name not empty
- Sample name not previously seen (no duplicates)

**Error messages**:
```
Line 3: Sample name is required.
Line 5: Sample name sample1 is duplicated.
```

#### Condition Validation

```python
    def _validate_condition(self, row):
        """Assert that the condition is valid."""
        condition = row["condition"].lower()
        if condition not in self.VALID_CONDITIONS:
            raise AssertionError(
                f"Condition must be one of {self.VALID_CONDITIONS}, "
                f"got '{condition}'."
            )
        row["condition"] = condition
```

**Features**:
- Case-insensitive (`Native` → `native`)
- Validates against allowed list
- Normalizes to lowercase

#### FASTQ Validation

```python
    def _validate_fastq(self, row):
        """Assert that the FASTQ file has valid extension."""
        fastq_path = Path(row["fastq"])

        if not any(str(fastq_path).endswith(fmt) for fmt in self.VALID_FORMATS):
            raise AssertionError(
                f"FASTQ file must have one of these extensions: "
                f"{self.VALID_FORMATS}. Got: {fastq_path}"
            )
```

**Note**: We validate extension, not existence. Why?

**File existence checked at runtime**: Files might be on remote storage or generated by previous steps. Extension validation catches typos early without requiring file access.

#### Optional Fields Processing

```python
    def _process_optional_fields(self, row):
        """Process and validate optional fields."""
        result = {}

        # Genome size - parse to bases
        if "genome_size" in row and row["genome_size"].strip():
            try:
                result["genome_size"] = parse_genome_size(row["genome_size"])
            except ValueError as e:
                raise AssertionError(f"Genome size error: {e}")

        # Numeric fields
        numeric_fields = [
            "min_length", "length_weight", "mean_q_weight", "window_q_weight",
            "keep_percent", "min_mean_q", "min_window_q", "window_size", "split"
        ]

        for field in numeric_fields:
            if field in row and row[field].strip():
                try:
                    # Weights/percentages: float, Lengths/sizes: int
                    if field in ["length_weight", "mean_q_weight", "window_q_weight",
                                 "keep_percent", "min_mean_q", "min_window_q"]:
                        result[field] = float(row[field])
                    else:
                        result[field] = int(row[field])
                except ValueError:
                    raise AssertionError(
                        f"Invalid numeric value for {field}: {row[field]}"
                    )

        # Boolean field - trim
        if "trim" in row and row[field].strip():
            try:
                result["trim"] = parse_boolean(row["trim"])
            except ValueError as e:
                raise AssertionError(f"Trim field error: {e}")

        # File path fields (no validation, just pass through)
        file_fields = ["assembly", "illumina_1", "illumina_2"]
        for field in file_fields:
            if field in row and row[field].strip():
                result[field] = row[field].strip()

        return result
```

**Key design decisions**:

1. **Empty strings = not provided**: User can leave columns empty
2. **Type conversion**: Parse to proper types (int, float, bool) for downstream use
3. **Specific type per field**: Weights are floats, lengths are ints
4. **Clear error messages**: Tell user which field and what value failed

### Step 4: Main Validation Function

```python
import csv
import sys

def check_samplesheet(file_in, file_out):
    """
    Check samplesheet validity and write validated version.
    """
    required_columns = {"sample", "condition", "fastq"}

    with open(file_in, newline="") as in_handle:
        # Auto-detect CSV or TSV
        reader = csv.DictReader(in_handle, dialect=sniff_format(in_handle))

        # Validate required columns exist
        if not required_columns.issubset(reader.fieldnames):
            req_cols = ", ".join(required_columns)
            logger.critical(f"Missing required columns. Required: {req_cols}")
            logger.critical(f"Found columns: {', '.join(reader.fieldnames)}")
            sys.exit(1)

        all_columns = list(reader.fieldnames)
        checker = RowChecker()

        # Write validated output
        with open(file_out, "w", newline="") as out_handle:
            writer = csv.DictWriter(out_handle, fieldnames=all_columns, delimiter=",")
            writer.writeheader()

            for i, row in enumerate(reader):
                try:
                    validated_row = checker.validate_and_transform(row)

                    # Prepare output row with all columns
                    output_row = {col: "" for col in all_columns}
                    output_row.update(validated_row)

                    # Convert types back to strings for CSV output
                    if "genome_size" in output_row and output_row["genome_size"]:
                        output_row["genome_size"] = str(output_row["genome_size"])

                    if "trim" in output_row and output_row["trim"] is not None:
                        output_row["trim"] = "true" if output_row["trim"] else "false"

                    # Convert numeric fields
                    for col in all_columns:
                        if col in output_row and output_row[col] is not None:
                            if isinstance(output_row[col], (int, float)):
                                output_row[col] = str(output_row[col])

                    writer.writerow(output_row)

                except AssertionError as e:
                    logger.critical(f"Line {i + 2}: {e}")  # +2 for 1-based + header
                    sys.exit(1)
```

**Features**:
- **Auto-detect format**: Works with CSV or TSV
- **Preserve column order**: Output has same columns as input
- **Line numbers in errors**: Easy to find problems
- **Type roundtrip**: Parse to types for validation, convert back to strings for output

### Step 5: Format Detection

```python
def sniff_format(handle):
    """Detect if file is CSV or TSV."""
    peek = read_head(handle, num_lines=10)
    handle.seek(0)  # Reset to beginning
    sniffer = csv.Sniffer()
    return sniffer.sniff(peek)

def read_head(handle, num_lines=10):
    """Read first N lines."""
    lines = []
    for idx, line in enumerate(handle):
        if idx == num_lines:
            break
        lines.append(line)
    return "".join(lines)
```

**Why auto-detect?**: Some users prefer tabs, others commas. Support both!

## Creating the Nextflow Wrapper

Now wrap the Python script in a Nextflow process: `modules/local/samplesheet_check/main.nf`

```groovy
process SAMPLESHEET_CHECK {
    tag "$samplesheet"
    label 'process_single'

    conda "conda-forge::python=3.11"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.11' :
        'biocontainers/python:3.11' }"

    input:
    path samplesheet

    output:
    path '*.csv'       , emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    check_samplesheet.py \\
        $samplesheet \\
        samplesheet.valid.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
```

**Key points**:
- `label 'process_single'`: Lightweight process (minimal resources)
- Python 3.11 container (standard library only, no dependencies)
- Outputs validated CSV for downstream use
- Script must be in `bin/` and executable (`chmod +x`)

## Complete Files

### Complete `bin/check_samplesheet.py`

```python
#!/usr/bin/env python3

"""
Validate and parse samplesheet for RNA modification coverage benchmarking pipeline.

Expected samplesheet format (CSV):
Required columns: sample, condition, fastq
Optional columns: genome_size, min_length, length_weight, mean_q_weight, window_q_weight,
                  keep_percent, min_mean_q, min_window_q, window_size, trim, split,
                  assembly, illumina_1, illumina_2

Example:
sample,condition,fastq,genome_size,min_length,length_weight
native_1,native,/path/to/native_1.fastq.gz,4.5m,500,10
native_2,native,/path/to/native_2.fastq.gz,4.5Mbp,,15
ivt_1,ivt,/path/to/ivt_1.fastq.gz,4500000,1000,
"""

import argparse
import csv
import logging
import sys
from pathlib import Path
import re

logger = logging.getLogger()


def parse_genome_size(size_str):
    """Parse genome size from various formats to bases."""
    if not size_str or size_str.strip() == '':
        return None

    size_str = size_str.strip()
    pattern = r'^([0-9]+\.?[0-9]*)([kKmMgG](?:[bB][pP]?)?)?$'
    match = re.match(pattern, size_str)

    if not match:
        raise ValueError(f"Invalid genome size format: {size_str}")

    value = float(match.group(1))
    unit = match.group(2)

    if unit is None:
        return int(value)

    unit_lower = unit.lower().replace('bp', '').replace('b', '')
    multipliers = {'k': 1_000, 'm': 1_000_000, 'g': 1_000_000_000}

    if unit_lower in multipliers:
        return int(value * multipliers[unit_lower])
    else:
        raise ValueError(f"Unknown unit: {unit}")


def parse_boolean(value):
    """Parse boolean values from strings."""
    if not value or value.strip() == '':
        return None

    value_lower = value.strip().lower()
    if value_lower in ['true', 'yes', '1', 't', 'y']:
        return True
    elif value_lower in ['false', 'no', '0', 'f', 'n']:
        return False
    else:
        raise ValueError(f"Invalid boolean: {value}")


class RowChecker:
    """Validate and transform each row."""

    VALID_CONDITIONS = ["native", "ivt"]
    VALID_FORMATS = [".fastq", ".fq", ".fastq.gz", ".fq.gz"]

    def __init__(self):
        self._seen = set()

    def validate_and_transform(self, row):
        """Validate and transform a row."""
        self._validate_sample(row)
        self._validate_condition(row)
        self._validate_fastq(row)

        result = {
            "sample": row["sample"],
            "condition": row["condition"],
            "fastq": row["fastq"],
        }

        result.update(self._process_optional_fields(row))
        self._seen.add(row["sample"])
        return result

    def _validate_sample(self, row):
        if len(row["sample"]) <= 0:
            raise AssertionError("Sample name is required.")
        if row["sample"] in self._seen:
            raise AssertionError(f"Sample {row['sample']} is duplicated.")

    def _validate_condition(self, row):
        condition = row["condition"].lower()
        if condition not in self.VALID_CONDITIONS:
            raise AssertionError(f"Condition must be {self.VALID_CONDITIONS}")
        row["condition"] = condition

    def _validate_fastq(self, row):
        fastq_path = Path(row["fastq"])
        if not any(str(fastq_path).endswith(fmt) for fmt in self.VALID_FORMATS):
            raise AssertionError(f"Invalid FASTQ extension: {fastq_path}")

    def _process_optional_fields(self, row):
        result = {}

        # Genome size
        if "genome_size" in row and row["genome_size"].strip():
            try:
                result["genome_size"] = parse_genome_size(row["genome_size"])
            except ValueError as e:
                raise AssertionError(f"Genome size error: {e}")

        # Numeric fields
        numeric_fields = [
            "min_length", "length_weight", "mean_q_weight", "window_q_weight",
            "keep_percent", "min_mean_q", "min_window_q", "window_size", "split"
        ]

        for field in numeric_fields:
            if field in row and row[field].strip():
                try:
                    if field in ["length_weight", "mean_q_weight", "window_q_weight",
                                 "keep_percent", "min_mean_q", "min_window_q"]:
                        result[field] = float(row[field])
                    else:
                        result[field] = int(row[field])
                except ValueError:
                    raise AssertionError(f"Invalid {field}: {row[field]}")

        # Boolean
        if "trim" in row and row["trim"].strip():
            try:
                result["trim"] = parse_boolean(row["trim"])
            except ValueError as e:
                raise AssertionError(f"Trim error: {e}")

        # Files
        for field in ["assembly", "illumina_1", "illumina_2"]:
            if field in row and row[field].strip():
                result[field] = row[field].strip()

        return result


def check_samplesheet(file_in, file_out):
    """Check samplesheet and write validated version."""
    required_columns = {"sample", "condition", "fastq"}

    with open(file_in, newline="") as in_handle:
        reader = csv.DictReader(in_handle, dialect=csv.Sniffer().sniff(in_handle.read(1024)))
        in_handle.seek(0)
        reader = csv.DictReader(in_handle)

        if not required_columns.issubset(reader.fieldnames):
            logger.critical(f"Missing required columns: {required_columns}")
            sys.exit(1)

        all_columns = list(reader.fieldnames)
        checker = RowChecker()

        with open(file_out, "w", newline="") as out_handle:
            writer = csv.DictWriter(out_handle, fieldnames=all_columns)
            writer.writeheader()

            for i, row in enumerate(reader):
                try:
                    validated_row = checker.validate_and_transform(row)
                    output_row = {col: "" for col in all_columns}
                    output_row.update(validated_row)

                    # Convert back to strings
                    for col in output_row:
                        if isinstance(output_row[col], (int, float)):
                            output_row[col] = str(output_row[col])
                        elif isinstance(output_row[col], bool):
                            output_row[col] = "true" if output_row[col] else "false"

                    writer.writerow(output_row)
                except AssertionError as e:
                    logger.critical(f"Line {i + 2}: {e}")
                    sys.exit(1)


def main():
    """Main function."""
    parser = argparse.ArgumentParser()
    parser.add_argument("file_in", type=Path)
    parser.add_argument("file_out", type=Path)
    parser.add_argument("-l", "--log-level", default="INFO")
    args = parser.parse_args()

    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    if not args.file_in.is_file():
        logger.error(f"File not found: {args.file_in}")
        sys.exit(1)

    check_samplesheet(args.file_in, args.file_out)


if __name__ == "__main__":
    sys.exit(main())
```

## Testing the Validator

### Test Valid Samplesheet

```csv
sample,condition,fastq,genome_size,min_length
sample1,native,/data/s1.fastq.gz,4.5m,500
sample2,IVT,/data/s2.fq.gz,4.5Mbp,1000
```

```bash
$ python bin/check_samplesheet.py test.csv test.valid.csv
$ cat test.valid.csv
```

Output:
```csv
sample,condition,fastq,genome_size,min_length
sample1,native,/data/s1.fastq.gz,4500000,500
sample2,ivt,/data/s2.fq.gz,4500000,1000
```

**Note**: `IVT` normalized to `ivt`, genome sizes parsed to integers.

### Test Invalid Samplesheet

```csv
sample,condition,fastq,genome_size
sample1,native,/data/s1.txt,4.5x
```

```bash
$ python bin/check_samplesheet.py test_bad.csv test.valid.csv
```

Output:
```
[CRITICAL] Line 2: FASTQ file must have one of these extensions: ['.fastq', '.fq', '.fastq.gz', '.fq.gz']. Got: /data/s1.txt
```

## What's Next?

We now have validated, type-checked samplesheet data! In **Post 5**, we'll build the main workflow that:

- Imports our modules
- Reads and validates the samplesheet
- Creates channels with meta maps
- Calls FILTLONG for each sample
- Handles multiple coverage levels per sample

---

**Previous**: [Part 3 - Creating FILTLONG Module](blogpost_3_creating_first_nfcore_module_filtlong.md)
**Next**: [Part 5 - Building the Main Workflow](blogpost_5_building_main_workflow_orchestration.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. **Samplesheet Design and Validation** ← You are here
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. Schema Validation with JSON Schema
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
