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
    log.info paramsHelp("nextflow run main.nf --input samplesheet.csv --genome_size 4.5m --outdir results")
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

include { RNA_COVERAGE_BENCHMARK } from './workflows/rna_coverage_benchmark'

//
// WORKFLOW: Run main analysis workflow
//
workflow NFCORE_RNACOVERAGEBENCHMARK {

    // Check mandatory parameters
    if (!params.input) {
        error "Please provide an input samplesheet using --input"
    }
    if (!params.genome_size) {
        error "Please provide genome/transcriptome size using --genome_size (e.g., '4.5m' for 4.5 megabases)"
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
        Genome size          : ${params.genome_size}
        Coverage levels      : ${params.coverage_levels}
        Min read length      : ${params.min_length}
        Length weight        : ${params.length_weight}
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
