/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

include { SAMPLESHEET_CHECK } from '../modules/local/samplesheet_check'
include { FILTLONG          } from '../modules/local/filtlong'

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow RNA_COVERAGE_BENCHMARK {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()

    //
    // MODULE: Validate samplesheet
    //
    SAMPLESHEET_CHECK (
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(SAMPLESHEET_CHECK.out.versions)

    //
    // Parse validated samplesheet and create channel
    //
    SAMPLESHEET_CHECK.out.csv
        .splitCsv(header: true, sep: ',')
        .map { row ->
            def meta = [
                id:        row.sample,
                condition: row.condition
            ]
            return [ meta, file(row.fastq, checkIfExists: true) ]
        }
        .set { ch_samples }

    //
    // Parse coverage levels from params
    //
    def coverage_list = params.coverage_levels
        .toString()
        .split(',')
        .collect { it.trim() }

    //
    // Create channel with all combinations of samples and coverage levels
    //
    ch_samples
        .combine(Channel.from(coverage_list))
        .map { meta, fastq, coverage ->
            def new_meta = meta.clone()
            new_meta.coverage = coverage
            new_meta.genome_size = params.genome_size
            new_meta.id = "${meta.id}_${coverage}x"
            return [ new_meta, fastq ]
        }
        .set { ch_filtlong_input }

    //
    // MODULE: Filter reads to specific coverage levels
    //
    FILTLONG (
        ch_filtlong_input
    )
    ch_versions = ch_versions.mix(FILTLONG.out.versions.first())

    emit:
    filtered_reads = FILTLONG.out.reads
    versions       = ch_versions
}

/*
========================================================================================
    THE END
========================================================================================
*/
