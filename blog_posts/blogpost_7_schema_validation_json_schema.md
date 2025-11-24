# Schema Validation with JSON Schema

**Series: Part 7 of 12**

## Introduction

Schema validation is your pipeline's first line of defense against bad inputs. Using JSON Schema, we can:

- Validate parameter types, ranges, and formats
- Provide clear error messages to users
- Generate automatic documentation
- Enable IDE autocomplete for parameters

In this post, we'll implement two schemas:
1. **nextflow_schema.json** - Validates command-line parameters
2. **assets/schema_input.json** - Validates samplesheet structure

## Why JSON Schema?

**Without schema validation**:
```bash
nextflow run main.nf --genome-size 4.5m  # Typo: should be genome_size
# Pipeline runs but genome_size is null, fails later
```

**With schema validation**:
```bash
nextflow run main.nf --genome-size 4.5m
ERROR: Unknown parameter --genome-size
Did you mean --genome_size?
# Fails immediately with helpful message
```

## Schema Structure Overview

```
Pipeline
├── nextflow_schema.json      ← Validates command-line params
│   ├── input_output_options
│   ├── filtlong_options
│   └── generic_options
│
└── assets/schema_input.json  ← Validates samplesheet structure
    └── Array of sample objects
        ├── Required: sample, condition, fastq
        └── Optional: 14 filtlong parameters
```

## Part 1: Parameter Schema (nextflow_schema.json)

### Basic Structure

```json
{
    "$schema": "http://json-schema.org/draft-07/schema",
    "title": "RNA Modification Coverage Benchmarking Pipeline",
    "description": "Pipeline for benchmarking RNA modification detection tools",
    "type": "object",
    "definitions": {
        "input_output_options": {...},
        "filtlong_options": {...},
        "generic_options": {...}
    },
    "allOf": [
        {"$ref": "#/definitions/input_output_options"},
        {"$ref": "#/definitions/filtlong_options"},
        {"$ref": "#/definitions/generic_options"}
    ]
}
```

**Key concepts**:
- `definitions`: Reusable schema sections
- `$ref`: References to other schema parts
- `allOf`: Combines multiple schema definitions

### Input/Output Options

```json
"input_output_options": {
    "title": "Input/output options",
    "type": "object",
    "required": ["input", "outdir"],
    "properties": {
        "input": {
            "type": "string",
            "format": "file-path",
            "mimetype": "text/csv",
            "pattern": "^\\S+\\.csv$",
            "schema": "assets/schema_input.json",
            "description": "Path to comma-separated file containing sample information."
        },
        "outdir": {
            "type": "string",
            "format": "directory-path",
            "description": "Output directory for results.",
            "default": "./results"
        },
        "genome_size": {
            "type": "string",
            "description": "Global genome size (e.g., '4.5m', '100k', '3g').",
            "pattern": "^[0-9]+(\\.[0-9]+)?([kmgKMG]([bB][pP]?)?)?$"
        }
    }
}
```

**Schema validation features**:

**`required: ["input", "outdir"]`**: These params must be provided.

**`pattern`**: Regex validation for genome size format.
- Matches: `4.5m`, `4.5M`, `4.5Mbp`, `4500000`, `4.5g`
- Rejects: `4.5x`, `abc`, `4.5 m` (space)

**`schema: "assets/schema_input.json"`**: Links to samplesheet schema for nested validation.

**`format: "file-path"`**: nf-validation plugin checks file exists.

### Filtlong Options

```json
"filtlong_options": {
    "title": "Filtlong filtering options",
    "type": "object",
    "properties": {
        "coverage_levels": {
            "type": "string",
            "default": "5,10,20,30,40,50,60,70,80,90,100,150,200,500,1000",
            "description": "Comma-separated list of coverage levels."
        },
        "min_length": {
            "type": "integer",
            "default": 500,
            "description": "Minimum read length (bp).",
            "minimum": 0
        },
        "length_weight": {
            "type": "number",
            "default": 10,
            "description": "Weight for read length in scoring.",
            "minimum": 0
        },
        "mean_q_weight": {
            "type": "number",
            "default": 1,
            "description": "Weight for mean quality.",
            "minimum": 0
        }
    }
}
```

**Type distinctions**:
- `integer`: Whole numbers (min_length, window_size)
- `number`: Floats (length_weight, mean_q_weight)
- `string`: Text (coverage_levels, genome_size)

**Range validation**:
- `minimum: 0`: Value must be non-negative
- Could also use `maximum`, `exclusiveMinimum`, etc.

## Part 2: Samplesheet Schema (assets/schema_input.json)

### Array Schema Structure

```json
{
    "$schema": "http://json-schema.org/draft-07/schema",
    "title": "RNA Modification Coverage Benchmarking - Samplesheet Schema",
    "type": "array",
    "items": {
        "type": "object",
        "required": ["sample", "condition", "fastq"],
        "properties": {
            "sample": {...},
            "condition": {...},
            "fastq": {...},
            // 14 optional parameters
        }
    }
}
```

**Key points**:
- `type: "array"`: Samplesheet is list of samples
- `items`: Schema for each sample object
- `required`: Only 3 fields required, rest optional

### Required Fields

```json
"sample": {
    "type": "string",
    "pattern": "^\\S+$",
    "errorMessage": "Sample name must be provided and cannot contain spaces",
    "meta": ["id"]
},
"condition": {
    "type": "string",
    "pattern": "^(native|ivt)$",
    "errorMessage": "Condition must be either 'native' or 'ivt'",
    "meta": ["condition"]
},
"fastq": {
    "type": "string",
    "format": "file-path",
    "pattern": "^\\S+\\.(fastq|fq)(\\.gz)?$",
    "errorMessage": "FASTQ file must have extension .fastq, .fq, .fastq.gz, or .fq.gz"
}
```

**Pattern validation**:

**`^\\S+$`**: One or more non-whitespace characters (no spaces in sample names)

**`^(native|ivt)$`**: Exactly "native" or "ivt" (case-sensitive after Python validation normalizes it)

**`^\\S+\\.(fastq|fq)(\\.gz)?$`**: Valid FASTQ extensions

**`errorMessage`**: Custom error shown to user (nf-validation feature)

**`meta`**: Indicates field goes into meta map (nf-core pattern)

### Optional Numeric Fields

```json
"genome_size": {
    "type": "string",
    "pattern": "^[0-9]+(\\.[0-9]+)?([kKmMgG]([bB][pP]?)?)?$",
    "errorMessage": "Genome size must be a number optionally followed by k/K, m/M, or g/G. Examples: 4500000, 4.5m, 4.5Mbp"
},
"min_length": {
    "type": "integer",
    "minimum": 0,
    "errorMessage": "Minimum read length must be a positive integer"
},
"length_weight": {
    "type": "number",
    "minimum": 0,
    "errorMessage": "Length weight must be a non-negative number"
},
"keep_percent": {
    "type": "number",
    "minimum": 0,
    "maximum": 100,
    "errorMessage": "Keep percent must be between 0 and 100"
}
```

**Range constraints**:
- `minimum: 0`: No negative values
- `minimum: 0, maximum: 100`: Percentage values

### File Path Fields

```json
"assembly": {
    "type": "string",
    "format": "file-path",
    "pattern": "^\\S+\\.(fa|fasta|fna)(\\.gz)?$",
    "errorMessage": "Assembly file must have extension .fa, .fasta, or .fna (optionally gzipped)"
},
"illumina_1": {
    "type": "string",
    "format": "file-path",
    "pattern": "^\\S+\\.(fastq|fq)(\\.gz)?$",
    "errorMessage": "Illumina R1 file must have FASTQ extension"
},
"illumina_2": {
    "type": "string",
    "format": "file-path",
    "pattern": "^\\S+\\.(fastq|fq)(\\.gz)?$",
    "errorMessage": "Illumina R2 file must have FASTQ extension"
}
```

**File validation**: `format: "file-path"` checks file exists (if nf-validation configured to do so).

## Validation in Action

### Command-Line Validation

**Invalid parameter name**:
```bash
$ nextflow run main.nf --genome-size 4.5m
ERROR: Unknown parameter: --genome-size
Did you mean: --genome_size
```

**Invalid type**:
```bash
$ nextflow run main.nf --min_length abc
ERROR: --min_length: 'abc' is not a valid integer
```

**Invalid format**:
```bash
$ nextflow run main.nf --genome_size 4.5x
ERROR: --genome_size: '4.5x' does not match pattern
Expected: number with optional k/m/g suffix (e.g., 4.5m)
```

### Samplesheet Validation

**Missing required field**:
```csv
sample,condition
sample1,native
```
```
ERROR: Samplesheet validation failed
Line 2: Missing required property 'fastq'
```

**Invalid condition**:
```csv
sample,condition,fastq
sample1,control,data.fq.gz
```
```
ERROR: Line 2: condition 'control' does not match pattern ^(native|ivt)$
Condition must be either 'native' or 'ivt'
```

**Out of range**:
```csv
sample,condition,fastq,keep_percent
sample1,native,data.fq.gz,150
```
```
ERROR: Line 2: keep_percent 150 exceeds maximum 100
Keep percent must be between 0 and 100
```

## Integration with nf-validation Plugin

Add to `nextflow.config`:

```groovy
plugins {
    id 'nf-validation@1.1.3'
}

validation {
    parametersSchema = "$projectDir/nextflow_schema.json"
}
```

Add to workflow:

```groovy
include { validateParameters } from 'plugin/nf-validation'

workflow {
    validateParameters()

    // Rest of workflow
}
```

**Automatic features**:
- Parameter validation before execution
- `--help` shows all parameters with descriptions
- `--schema-ignore-params` to skip specific validations

## Complete Schema Files

### Complete nextflow_schema.json (abbreviated)

```json
{
    "$schema": "http://json-schema.org/draft-07/schema",
    "title": "RNA Modification Coverage Benchmarking Pipeline",
    "description": "Pipeline for benchmarking RNA modification detection",
    "type": "object",
    "definitions": {
        "input_output_options": {
            "title": "Input/output options",
            "type": "object",
            "required": ["input", "outdir"],
            "properties": {
                "input": {
                    "type": "string",
                    "format": "file-path",
                    "mimetype": "text/csv",
                    "pattern": "^\\S+\\.csv$",
                    "schema": "assets/schema_input.json",
                    "description": "Path to samplesheet."
                },
                "outdir": {
                    "type": "string",
                    "format": "directory-path",
                    "description": "Output directory.",
                    "default": "./results"
                },
                "genome_size": {
                    "type": "string",
                    "description": "Global genome size (e.g., '4.5m').",
                    "pattern": "^[0-9]+(\\.[0-9]+)?([kmgKMG]([bB][pP]?)?)?$"
                }
            }
        },
        "filtlong_options": {
            "title": "Filtlong options",
            "type": "object",
            "properties": {
                "coverage_levels": {
                    "type": "string",
                    "default": "5,10,20,30,40,50,60,70,80,90,100,150,200,500,1000",
                    "description": "Coverage levels to generate."
                },
                "min_length": {
                    "type": "integer",
                    "default": 500,
                    "minimum": 0
                },
                "length_weight": {
                    "type": "number",
                    "default": 10,
                    "minimum": 0
                }
            }
        }
    },
    "allOf": [
        {"$ref": "#/definitions/input_output_options"},
        {"$ref": "#/definitions/filtlong_options"}
    ]
}
```

### Complete assets/schema_input.json (abbreviated)

```json
{
    "$schema": "http://json-schema.org/draft-07/schema",
    "title": "RNA Modification Coverage - Samplesheet Schema",
    "type": "array",
    "items": {
        "type": "object",
        "required": ["sample", "condition", "fastq"],
        "properties": {
            "sample": {
                "type": "string",
                "pattern": "^\\S+$",
                "errorMessage": "Sample name cannot contain spaces"
            },
            "condition": {
                "type": "string",
                "pattern": "^(native|ivt)$",
                "errorMessage": "Condition must be 'native' or 'ivt'"
            },
            "fastq": {
                "type": "string",
                "format": "file-path",
                "pattern": "^\\S+\\.(fastq|fq)(\\.gz)?$"
            },
            "genome_size": {
                "type": "string",
                "pattern": "^[0-9]+(\\.[0-9]+)?([kmgKMG]([bB][pP]?)?)?$"
            },
            "min_length": {"type": "integer", "minimum": 0},
            "length_weight": {"type": "number", "minimum": 0},
            "keep_percent": {"type": "number", "minimum": 0, "maximum": 100}
        }
    }
}
```

## Benefits of Schema Validation

1. **Early error detection**: Fail before consuming resources
2. **Clear error messages**: Tell users exactly what's wrong
3. **Auto-documentation**: `--help` generated from schema
4. **IDE support**: Tools can provide autocomplete
5. **Type safety**: Prevent type-related bugs
6. **Format validation**: Ensure correct file extensions, patterns

## What's Next?

We now have comprehensive validation! In **Post 8**, we'll implement organized multi-coverage outputs using publishDir strategies:

- Dynamic output paths based on meta map
- Organizing by condition and coverage
- Keeping work directories clean
- Output file naming conventions

---

**Previous**: [Part 6 - Per-Sample Parameters](blogpost_6_implementing_flexible_per_sample_parameters.md)
**Next**: [Part 8 - Generating Multi-Coverage Outputs](blogpost_8_generating_multi_coverage_outputs.md)

**Series Navigation**:
1. Introduction and Pipeline Overview
2. Understanding Filtlong and Coverage Filtering
3. Creating Your First nf-core Module
4. Samplesheet Design and Validation
5. Building the Main Workflow
6. Implementing Flexible Per-Sample Parameters
7. **Schema Validation with JSON Schema** ← You are here
8. Generating Multi-Coverage Outputs
9. Comprehensive Testing with nf-test
10. Module Metadata and Documentation
11. CI/CD Pipeline with GitHub Actions
12. Final Polish and nf-core Compliance
