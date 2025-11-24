process FILTLONG {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/filtlong:0.2.1--h9a82719_1' :
        'biocontainers/filtlong:0.2.1--h9a82719_1' }"

    input:
    tuple val(meta), path(reads), path(assembly), path(illumina_1), path(illumina_2)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Build filtlong command dynamically based on meta parameters
    def filtlong_options = []

    // Calculate target bases based on genome size and coverage
    if (meta.genome_size && meta.coverage) {
        def genome_bases = meta.genome_size  // Already parsed to integer in validation
        def coverage_val = meta.coverage.toString().replaceAll(/x$/, '').toInteger()
        def target = (genome_bases * coverage_val).toLong()
        filtlong_options << "--target_bases ${target}"
    }

    // Add numeric options if present in meta
    if (meta.min_length) filtlong_options << "--min_length ${meta.min_length}"
    if (meta.keep_percent) filtlong_options << "--keep_percent ${meta.keep_percent}"
    if (meta.min_mean_q) filtlong_options << "--min_mean_q ${meta.min_mean_q}"
    if (meta.min_window_q) filtlong_options << "--min_window_q ${meta.min_window_q}"
    if (meta.window_size) filtlong_options << "--window_size ${meta.window_size}"

    // Add weight options
    if (meta.length_weight) filtlong_options << "--length_weight ${meta.length_weight}"
    if (meta.mean_q_weight) filtlong_options << "--mean_q_weight ${meta.mean_q_weight}"
    if (meta.window_q_weight) filtlong_options << "--window_q_weight ${meta.window_q_weight}"

    // Add boolean options
    if (meta.trim) filtlong_options << "--trim"
    if (meta.split) filtlong_options << "--split ${meta.split}"

    // Add reference files if provided
    if (assembly && assembly.name != 'NO_ASSEMBLY') filtlong_options << "-a ${assembly}"
    if (illumina_1 && illumina_1.name != 'NO_ILLUMINA_1') filtlong_options << "-1 ${illumina_1}"
    if (illumina_2 && illumina_2.name != 'NO_ILLUMINA_2') filtlong_options << "-2 ${illumina_2}"

    // Join all options
    def options_str = filtlong_options.join(' ')

    """
    filtlong \\
        ${options_str} \\
        $reads \\
        | gzip > ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version 2>&1 | sed 's/Filtlong v//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version 2>&1 | sed 's/Filtlong v//')
    END_VERSIONS
    """
}
