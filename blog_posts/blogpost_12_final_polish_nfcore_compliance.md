# Final Polish and nf-core Compliance

**Series: Part 12 of 12 - Final Post!**

## Introduction

We've built a complete, tested, documented pipeline. In this final post, we'll add the finishing touches to make it publication-ready and nf-core compliant:

- Citations and attributions
- Code organization
- Running nf-core lint
- Version management
- Release preparation

Let's polish our pipeline to professional standards!

## CITATIONS.md

### Purpose

Proper attribution for all tools and frameworks used.

### Complete CITATIONS.md

```markdown
# bhargava-morampalli/bash_scripts: Citations

## Pipeline Tools

### [Nextflow](https://pubmed.ncbi.nlm.nih.gov/28398311/)

> Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables reproducible computational workflows. Nat Biotechnol. 2017 Apr 11;35(4):316-319. doi: 10.1038/nbt.3820. PubMed PMID: 28398311.

### [nf-core](https://pubmed.ncbi.nlm.nih.gov/32055031/)

> Ewels PA, Peltzer A, Fillinger S, Patel H, Alneberg J, Wilm A, Garcia MU, Di Tommaso P, Nahnsen S. The nf-core framework for community-curated bioinformatics pipelines. Nat Biotechnol. 2020 Mar;38(3):276-278. doi: 10.1038/s41587-020-0439-x. PubMed PMID: 32055031.

### [Filtlong](https://github.com/rrwick/Filtlong)

> Wick R. Filtlong: quality filtering tool for long reads. GitHub repository. Available at: https://github.com/rrwick/Filtlong

## Software Packaging/Containerisation Tools

### [Anaconda](https://anaconda.com)

> Anaconda Software Distribution. Computer software. Vers. 2-2.4.0. Anaconda, Nov. 2016. Web.

### [Bioconda](https://pubmed.ncbi.nlm.nih.gov/29967506/)

> Grüning B, Dale R, Sjödin A, Chapman BA, Rowe J, Tomkins-Tinch CH, Valieris R, Köster J; Bioconda Team. Bioconda: sustainable and comprehensive software distribution for the life sciences. Nat Methods. 2018 Jul;15(7):475-476. doi: 10.1038/s41592-018-0046-7. PubMed PMID: 29967506.

### [BioContainers](https://pubmed.ncbi.nlm.nih.gov/28379341/)

> da Veiga Leprevost F, Grüning B, Aflitos SA, Röst HL, Uszkoreit J, Barsnes H, Vaudel M, Moreno P, Gatto L, Weber J, Bai M, Jimenez RC, Sachsenberg T, Pfeuffer J, Alvarez RV, Griss J, Nesvizhskii AI, Perez-Riverol Y. BioContainers: an open-source and community-driven framework for software standardization. Bioinformatics. 2017 Aug 15;33(16):2580-2582. doi: 10.1093/bioinformatics/btx192. PubMed PMID: 28379341; PubMed Central PMCID: PMC5870671.

### [Docker](https://dl.acm.org/doi/10.5555/2600239.2600241)

> Merkel, D. (2014). Docker: lightweight linux containers for consistent development and deployment. Linux Journal, 2014(239), 2. doi: 10.5555/2600239.2600241.

### [Singularity](https://pubmed.ncbi.nlm.nih.gov/28494014/)

> Kurtzer GM, Sochat V, Bauer MW. Singularity: Scientific containers for mobility of compute. PLoS One. 2017 May 11;12(5):e0177459. doi: 10.1371/journal.pone.0177459. eCollection 2017. PubMed PMID: 28494014; PubMed Central PMCID: PMC5426675.

## Data

### [Nanopore Direct RNA Sequencing](https://pubmed.ncbi.nlm.nih.gov/31239823/)

> Garalde DR, Snell EA, Jachimowicz D, Sipos B, Lloyd JH, Bruce M, Pantic N, Admassu T, James P, Warland A, Jordan M, Ciccone J, Serra S, Keenan J, Martin S, McNeill L, Wallace EJ, Jayasinghe L, Wright C, Blasco J, Young S, Brocklebank D, Juul S, Clarke J, Heron AJ, Turner DJ. Highly parallel direct RNA sequencing on an array of nanopores. Nat Methods. 2018 Mar;15(3):201-206. doi: 10.1038/nmeth.4577. Epub 2018 Jan 22. PubMed PMID: 29334379.

## Other Tools

### [Python](https://www.python.org/)

> Van Rossum, G., & Drake, F. L. (2009). Python 3 Reference Manual. Scotts Valley, CA: CreateSpace.
```

## Code Organization

### Extract Helper Functions to lib/

We already did this in earlier posts, but ensure clean separation:

**lib/WorkflowMain.groovy**:
```groovy
class WorkflowMain {
    // Initialization and summary functions
    public static void initialise(workflow, params, log) {
        // ...
    }
}
```

**lib/NfcoreTemplate.groovy** (optional):
```groovy
class NfcoreTemplate {
    public static String logo(workflow, monochrome_logs) {
        // ASCII logo
    }

    public static void email(workflow, params, summary_params, log, multiqc_report) {
        // Email notification logic
    }
}
```

### Groovy Helper Functions

**workflows/rna_coverage_benchmark/main.nf**:
```groovy
/*
========================================================================================
    HELPER FUNCTIONS
========================================================================================
*/

def parseGenomeSize(size_str) {
    // Keep helper functions in workflow file or extract to lib/
}
```

**Best practice**: Small helpers in workflow, reusable utilities in `lib/`.

## Running nf-core lint

### Install nf-core Tools

```bash
pip install nf-core
```

### Run Lint

```bash
cd /path/to/pipeline
nf-core lint .
```

### Common Lint Issues

#### 1. Missing nextflow_schema.json Fields

**Error**: "Parameter X not in schema"

**Fix**: Add to `nextflow_schema.json`:
```json
{
  "parameter_name": {
    "type": "string",
    "description": "..."
  }
}
```

#### 2. Module Versions Not Captured

**Error**: "Module doesn't emit versions"

**Fix**: Ensure all modules have:
```groovy
output:
path "versions.yml", emit: versions
```

#### 3. Missing meta.yml

**Error**: "Module missing meta.yml"

**Fix**: Create `modules/local/*/meta.yml` for each module.

#### 4. Inconsistent Naming

**Error**: "Process names must be uppercase"

**Fix**: Use `PROCESS_NAME` not `Process_name`.

#### 5. Missing Test Data

**Error**: "No test profile"

**Fix**: Add `conf/test.config` and `tests/` directory.

### Lint Configuration

Create `.nf-core.yml`:
```yaml
repository_type: pipeline
nf_core_version: "2.11.1"

lint:
  # Ignore specific tests
  actions_awstest: false  # Not using AWS
  actions_awsfulltest: false

  # Custom checks
  files_exist:
    - CODE_OF_CONDUCT.md
    - CITATIONS.md
    - LICENSE
    - README.md
    - nextflow_schema.json
```

## Version Management

### nextflow.config

```groovy
manifest {
    name            = 'bhargava-morampalli/bash_scripts'
    author          = 'Your Name'
    homePage        = 'https://github.com/bhargava-morampalli/bash_scripts'
    description     = 'RNA modification coverage benchmarking pipeline'
    mainScript      = 'main.nf'
    nextflowVersion = '!>=23.04.0'
    version         = '2.0.0'
}
```

**Version numbering** (Semantic Versioning):
- **Major** (2.0.0): Breaking changes
- **Minor** (2.1.0): New features, backwards compatible
- **Patch** (2.0.1): Bug fixes

### CHANGELOG.md

Track all changes:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-01-15

### Added
- Per-sample parameter specification in samplesheet
- Flexible genome size parsing (4.5m, 4.5Mbp, etc.)
- Comprehensive nf-test suite
- Complete documentation in docs/
- CI/CD with GitHub Actions

### Changed
- **BREAKING**: Samplesheet format updated with optional columns
- Workflow now supports per-sample parameters
- Output organized by condition and coverage

### Fixed
- Genome size parsing edge cases
- Parameter precedence logic

## [1.0.0] - 2023-12-01

### Added
- Initial release
- FILTLONG module for coverage filtering
- Basic samplesheet validation
```

## Release Preparation

### Pre-Release Checklist

- [ ] All tests pass
- [ ] Documentation complete
- [ ] CHANGELOG updated
- [ ] Version bumped in manifest
- [ ] nf-core lint passes (or documented exceptions)
- [ ] README updated
- [ ] Examples tested

### Creating a Release

#### 1. Tag Version

```bash
git tag -a v2.0.0 -m "Release version 2.0.0"
git push origin v2.0.0
```

#### 2. GitHub Release

1. Go to repository → Releases
2. Click "Draft a new release"
3. Select tag: `v2.0.0`
4. Release title: `v2.0.0 - Major Release`
5. Description:
```markdown
## RNA Modification Coverage Benchmarking Pipeline v2.0.0

### Major Features
- Per-sample parameter flexibility
- Comprehensive testing with nf-test
- Full nf-core compliance
- Automated CI/CD

### What's Changed
- See [CHANGELOG.md](CHANGELOG.md) for complete details

### Installation
```bash
nextflow run bhargava-morampalli/bash_scripts -r 2.0.0 --input samplesheet.csv -profile docker
```

### Documentation
- [Usage Guide](docs/usage.md)
- [Parameter Reference](docs/parameters.md)
- [Samplesheet Format](docs/samplesheet.md)
```

#### 3. Zenodo DOI (Optional)

Link GitHub to Zenodo for citable DOI:
1. Link repository to Zenodo
2. Create release
3. Zenodo automatically creates DOI
4. Add DOI badge to README

## Final Directory Structure

```
pipeline/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── linting.yml
│       └── branch.yml
├── assets/
│   ├── schema_input.json
│   ├── samplesheet_simple.csv
│   ├── samplesheet_standard.csv
│   └── README.md
├── bin/
│   └── check_samplesheet.py
├── conf/
│   ├── base.config
│   ├── modules.config
│   └── test.config
├── docs/
│   ├── usage.md
│   ├── output.md
│   ├── parameters.md
│   └── samplesheet.md
├── lib/
│   └── WorkflowMain.groovy
├── modules/
│   └── local/
│       ├── filtlong/
│       │   ├── main.nf
│       │   ├── meta.yml
│       │   ├── environment.yml
│       │   └── tests/
│       └── samplesheet_check/
│           ├── main.nf
│           ├── meta.yml
│           ├── environment.yml
│           └── tests/
├── tests/
│   ├── data/
│   │   ├── fastq/
│   │   └── samplesheets/
│   └── pipeline/
│       └── main.nf.test
├── workflows/
│   └── rna_coverage_benchmark/
│       ├── main.nf
│       └── tests/
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .nf-core.yml
├── .prettierignore
├── .prettierrc.yml
├── CHANGELOG.md
├── CITATIONS.md
├── CODE_OF_CONDUCT.md
├── LICENSE
├── README.md
├── main.nf
├── nextflow.config
└── nextflow_schema.json
```

## Submission to nf-core (Optional)

### Requirements

1. **Passes nf-core lint**: No critical errors
2. **Comprehensive tests**: Module, workflow, pipeline
3. **Documentation**: Complete and clear
4. **CI/CD**: GitHub Actions set up
5. **Community value**: Useful to others

### Submission Process

1. **Discuss**: Slack #new-pipelines
2. **Fork**: nf-core/tools template
3. **Develop**: Follow guidelines
4. **PR**: Submit to nf-core
5. **Review**: Community feedback
6. **Merge**: Becomes official nf-core pipeline

### Benefits

- **Visibility**: Listed on nf-core website
- **Community**: Contributors and users
- **Maintenance**: Shared responsibility
- **Quality**: Regular updates and reviews

## Maintenance Best Practices

### Regular Updates

- **Monthly**: Check for Nextflow updates
- **Quarterly**: Review dependencies
- **Annually**: Major version bump

### Issue Management

- **Label issues**: bug, enhancement, question
- **Respond quickly**: Within 1 week
- **Close resolved**: Keep clean

### Community Engagement

- **Welcome contributions**: Clear CONTRIBUTING.md
- **Be responsive**: Answer questions
- **Give credit**: Acknowledge contributors

## Congratulations!

You've built a production-ready, nf-core-compliant pipeline from scratch! You now understand:

✅ **Module development**: Creating reusable processes
✅ **Workflow orchestration**: Connecting modules with channels
✅ **Parameter systems**: Three-tier precedence
✅ **Validation**: Schema and samplesheet checking
✅ **Testing**: nf-test at all levels
✅ **Documentation**: Complete user guides
✅ **CI/CD**: Automated quality assurance
✅ **nf-core compliance**: Following best practices

## What's Next?

### Enhance Your Pipeline

1. **Add more modules**: QC, alignment, visualization
2. **Support more tools**: Compare filtlong with alternatives
3. **Add reports**: MultiQC integration
4. **Optimize performance**: Caching, parallelization

### Learn More

- **nf-core website**: https://nf-co.re/
- **Nextflow patterns**: https://nextflow-io.github.io/patterns/
- **Community**: Slack workspace
- **Training**: nf-core tutorials

### Share Your Work

- **Publish**: Create releases
- **Write**: Blog posts or papers
- **Present**: Conferences and meetups
- **Contribute**: Help others learn

## Final Thoughts

Building pipelines is an iterative process. Start simple, test often, and gradually add complexity. The skills you've learned here apply to any bioinformatics pipeline.

Thank you for following this series! Happy pipelining! 🚀

---

**Previous**: [Part 11 - CI/CD with GitHub Actions](blogpost_11_cicd_github_actions.md)

**Series Complete!** 🎉

**Full Series Navigation**:
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
11. CI/CD Pipeline with GitHub Actions
12. **Final Polish and nf-core Compliance** ← You are here

---

## Series Summary

This 12-part series covered complete nf-core pipeline development:

**Foundation** (Posts 1-2): Understanding the problem and tools
**Core Development** (Posts 3-6): Building modules and workflows
**Advanced Features** (Posts 7-8): Validation and output organization
**Professional Polish** (Posts 9-12): Testing, documentation, CI/CD, compliance

You now have all the tools to build production-ready bioinformatics pipelines!
