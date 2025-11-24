#!/usr/bin/env nextflow
/*
========================================================================================
    RNA Modification Coverage Benchmarking Pipeline
========================================================================================
    Github : https://github.com/bhargava-morampalli/bash_scripts
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

include { validateParameters; paramsHelp } from 'plugin/nf-validation'

// Print help message if needed
if (params.help) {
    def logo = """
    ========================================
    RNA Modification Coverage Benchmark
    ========================================
    """.stripIndent()

    log.info logo
    log.info paramsHelp("nextflow run main.nf --input samplesheet.csv --outdir results")
    log.info """
    Note: All filtlong parameters can be specified either:
      1. Globally via command line (--genome_size, --min_length, --length_weight, etc.)
      2. Per-sample in the samplesheet (genome_size, min_length, length_weight columns)
      3. Per-sample values override global values
    """.stripIndent()
    exit 0
}

// Validate input parameters
if (params.validate_params) {
    validateParameters()
}

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { RNA_COVERAGE_BENCHMARK } from './workflows/rna_coverage_benchmark/main'

//
// WORKFLOW: Run main analysis workflow
//
workflow NFCORE_RNACOVERAGEBENCHMARK {

    // Check mandatory parameters
    if (!params.input) {
        error "Please provide an input samplesheet using --input"
    }

    RNA_COVERAGE_BENCHMARK (
        Channel.fromPath(params.input, checkIfExists: true)
    )
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
//
workflow {
    NFCORE_RNACOVERAGEBENCHMARK ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
