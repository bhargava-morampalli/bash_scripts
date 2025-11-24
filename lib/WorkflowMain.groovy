/*
========================================================================================
    WorkflowMain Class
========================================================================================
    Main workflow initialization and helper functions
----------------------------------------------------------------------------------------
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
