# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-24

### Added - Major Feature Release 🎉

- **Per-sample parameter specification**: All filtlong parameters can now be specified per-sample in the samplesheet
- **Flexible genome size formats**: Supports multiple formats (4500000, 4.5m, 4.5Mbp, 4500k, 4.5g, etc.) - case-insensitive
- **All filtlong options exposed**: Complete access to all filtlong command-line parameters
- **Reference-based filtering**: Support for reference assembly and Illumina reads for quality assessment
- **Advanced samplesheet validation**: Parses and validates genome sizes, numeric parameters, and boolean values
- **Parameter priority system**: Per-sample > Command-line > Default configuration
- **Dynamic command building**: Filtlong commands are built dynamically based on available parameters
- **Multiple example samplesheets**: Simple, standard, and advanced examples provided

### Changed

- **Samplesheet format**: Now supports 14 optional columns for fine-grained control
- **Genome size**: Changed from required global parameter to optional (can be per-sample)
- **Module architecture**: Filtlong module now accepts reference files and builds commands dynamically
- **Workflow logic**: Enhanced parameter merging with proper precedence handling
- **Documentation**: Completely rewritten with comprehensive examples and explanations

### Optional Samplesheet Columns (New)

- `genome_size`: Per-sample genome/transcriptome size
- `min_length`: Minimum read length threshold
- `length_weight`: Read length prioritization weight
- `mean_q_weight`: Mean quality weight
- `window_q_weight`: Window quality weight
- `keep_percent`: Keep percentage of best reads
- `min_mean_q`: Minimum mean quality threshold
- `min_window_q`: Minimum window quality threshold
- `window_size`: Window size for quality assessment
- `trim`: Enable/disable read trimming
- `split`: Split reads longer than specified value
- `assembly`: Reference assembly FASTA path
- `illumina_1`: Illumina R1 reads path
- `illumina_2`: Illumina R2 reads path

### Features

- **Maximum flexibility**: Choose between global parameters, per-sample parameters, or mix both approaches
- **No genome size requirement**: Can specify genome size globally or per-sample
- **Format flexibility**: Genome sizes accept various formats and units
- **Complete filtlong control**: Access to all filtlong features including reference-based filtering
- **Smart parameter merging**: Per-sample values automatically override global defaults

### Documentation

- New comprehensive README with 3 detailed usage examples
- Parameter priority explanation with examples
- Genome size format table
- All filtlong parameters explained
- Troubleshooting section expanded
- Multiple example samplesheets (simple, standard, advanced)

### Technical

- Enhanced Python samplesheet validator with regex-based genome size parser
- Dynamic filtlong command construction in module
- Helper function for genome size parsing in Nextflow
- Support for reference files (assembly, Illumina reads)
- Improved error messages and validation

## [1.0.0] - 2025-11-24

### Added

- Initial release of RNA Modification Coverage Benchmarking Pipeline
- Filtlong-based read filtering to specific coverage levels
- Support for multiple coverage levels: 5x, 10x, 20x, 30x, 40x, 50x, 60x, 70x, 80x, 90x, 100x, 150x, 200x, 500x, 1000x
- Organized output structure by condition (native/IVT) and coverage level
- Configurable filtlong parameters (min_length, length_weight, quality weights)
- Samplesheet validation with Python script
- Support for Docker, Singularity, Podman, and Conda environments
- Comprehensive documentation and usage examples
- nf-core style configuration and module structure
- Resource optimization and automatic retry logic
- Pipeline execution reports (timeline, trace, DAG)

### Features

- **Coverage-based filtering**: Automatically generates datasets at user-specified coverage levels
- **Long read optimization**: Prioritizes longer reads (≥500 bp) with configurable length weights
- **Flexible input**: CSV samplesheet format with support for multiple conditions and replicates
- **Genome size parameter**: Calculates target bases based on genome/transcriptome size and desired coverage
- **Modular design**: DSL2 syntax with separate modules for each process
- **Quality control**: Validates input samplesheet format and file existence

### Documentation

- Comprehensive README with usage examples
- Parameter descriptions in nextflow_schema.json
- Example samplesheets provided in assets/
- Troubleshooting guide for common issues

[1.0.0]: https://github.com/bhargava-morampalli/bash_scripts/releases/tag/v1.0.0
