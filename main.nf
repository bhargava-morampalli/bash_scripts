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
    FUNCTIONS
========================================================================================
*/

class WorkflowMain {

    //
    // Print version information
    //
    public static String version(workflow) {
        return """
        RNA Modification Coverage Benchmark v${workflow.manifest.version}
        """.stripIndent()
    }

    //
    // Initialise workflow
    //
    public static void initialise(workflow, params, log) {
        // Print workflow version
        log.info version(workflow)

        // Print parameter summary log to screen
        log.info paramsSummaryLog(workflow, params)

        // Check Nextflow version
        checkNextflowVersion(workflow, log)
    }

    //
    // Generate parameter summary
    //
    public static String paramsSummaryLog(workflow, params) {
        def summary_log = """
        ========================================
        Pipeline Parameters
        ========================================
        Input samplesheet    : ${params.input}
        Output directory     : ${params.outdir}
        Coverage levels      : ${params.coverage_levels}
        Genome size (global) : ${params.genome_size ?: 'Per-sample'}
        Min read length      : ${params.min_length ?: 'Per-sample or default'}
        Length weight        : ${params.length_weight ?: 'Per-sample or default'}
        ========================================
        Note: Parameters can be specified globally or per-sample in the samplesheet.
        Per-sample values override global values.
        ========================================
        """.stripIndent()
        return summary_log
    }

    //
    // Check Nextflow version
    //
    private static void checkNextflowVersion(workflow, log) {
        if (workflow.nextflow.version.toString() < '23.04.0') {
            log.error "This workflow requires Nextflow version 23.04.0 or greater -- You are running version ${workflow.nextflow.version}"
            System.exit(1)
        }
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/
