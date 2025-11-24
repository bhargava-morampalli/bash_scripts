# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
