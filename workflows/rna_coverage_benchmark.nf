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
    // Parse validated samplesheet and create channel with all metadata
    //
    SAMPLESHEET_CHECK.out.csv
        .splitCsv(header: true, sep: ',')
        .map { row ->
            def meta = [
                id:        row.sample,
                condition: row.condition
            ]

            // Add per-sample filtlong parameters (override globals if present)
            // Genome size - per-sample takes precedence over global
            if (row.genome_size && row.genome_size != '') {
                meta.genome_size = row.genome_size.toLong()
            } else if (params.genome_size) {
                // Parse global genome_size
                meta.genome_size = parseGenomeSize(params.genome_size)
            }

            // Numeric parameters
            if (row.min_length && row.min_length != '') meta.min_length = row.min_length.toInteger()
            else if (params.min_length) meta.min_length = params.min_length

            if (row.length_weight && row.length_weight != '') meta.length_weight = row.length_weight.toFloat()
            else if (params.length_weight) meta.length_weight = params.length_weight

            if (row.mean_q_weight && row.mean_q_weight != '') meta.mean_q_weight = row.mean_q_weight.toFloat()
            else if (params.mean_q_weight) meta.mean_q_weight = params.mean_q_weight

            if (row.window_q_weight && row.window_q_weight != '') meta.window_q_weight = row.window_q_weight.toFloat()
            else if (params.window_q_weight) meta.window_q_weight = params.window_q_weight

            if (row.keep_percent && row.keep_percent != '') meta.keep_percent = row.keep_percent.toFloat()
            if (row.min_mean_q && row.min_mean_q != '') meta.min_mean_q = row.min_mean_q.toFloat()
            if (row.min_window_q && row.min_window_q != '') meta.min_window_q = row.min_window_q.toFloat()
            if (row.window_size && row.window_size != '') meta.window_size = row.window_size.toInteger()
            if (row.split && row.split != '') meta.split = row.split.toInteger()

            // Boolean parameters
            if (row.trim && row.trim != '') {
                meta.trim = row.trim.toLowerCase() == 'true'
            }

            // File paths for reference files
            def fastq_file = file(row.fastq, checkIfExists: true)
            def assembly_file = (row.assembly && row.assembly != '') ? file(row.assembly, checkIfExists: true) : file('NO_ASSEMBLY')
            def illumina_1_file = (row.illumina_1 && row.illumina_1 != '') ? file(row.illumina_1, checkIfExists: true) : file('NO_ILLUMINA_1')
            def illumina_2_file = (row.illumina_2 && row.illumina_2 != '') ? file(row.illumina_2, checkIfExists: true) : file('NO_ILLUMINA_2')

            return [ meta, fastq_file, assembly_file, illumina_1_file, illumina_2_file ]
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
        .map { meta, fastq, assembly, illumina_1, illumina_2, coverage ->
            def new_meta = meta.clone()
            new_meta.coverage = coverage
            new_meta.id = "${meta.id}_${coverage}x"
            return [ new_meta, fastq, assembly, illumina_1, illumina_2 ]
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
    HELPER FUNCTIONS
========================================================================================
*/

def parseGenomeSize(size_str) {
    """
    Parse genome size from string to bases
    Supports: 4.5m, 4.5M, 4.5mb, 4.5Mbp, 4500k, 4500K, 4500000, etc.
    """
    if (!size_str) return null

    size_str = size_str.toString().trim()

    // Check if it's already just a number
    if (size_str.isNumber()) {
        return size_str.toLong()
    }

    // Parse with units
    def pattern = ~/^([0-9]+\.?[0-9]*)([kKmMgG](?:[bB][pP]?)?)?$/
    def matcher = size_str =~ pattern

    if (!matcher) {
        error "Invalid genome size format: ${size_str}. Expected formats: 4500000, 4.5m, 4.5Mbp, 4500k, etc."
    }

    def value = matcher[0][1].toFloat()
    def unit = matcher[0][2]

    if (!unit) {
        return value.toLong()
    }

    def unit_lower = unit.toLowerCase().replaceAll(/(bp|b)$/, '')

    def multipliers = [
        'k': 1_000,
        'm': 1_000_000,
        'g': 1_000_000_000
    ]

    if (unit_lower in multipliers) {
        return (value * multipliers[unit_lower]).toLong()
    }

    error "Unknown unit in genome size: ${unit}"
}

/*
========================================================================================
    THE END
========================================================================================
*/
