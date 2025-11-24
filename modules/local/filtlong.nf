process FILTLONG {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/filtlong:0.2.1--h9a82719_1' :
        'biocontainers/filtlong:0.2.1--h9a82719_1' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Calculate target bases based on genome size and coverage
    def target_bases = ""
    if (meta.genome_size && meta.coverage) {
        // Parse genome size (could be like "4.5m" or just a number)
        def size_str = meta.genome_size.toString()
        def multiplier = 1
        def size_value = size_str

        if (size_str =~ /[kK]$/) {
            multiplier = 1000
            size_value = size_str.replaceAll(/[kK]$/, '')
        } else if (size_str =~ /[mM]$/) {
            multiplier = 1000000
            size_value = size_str.replaceAll(/[mM]$/, '')
        } else if (size_str =~ /[gG]$/) {
            multiplier = 1000000000
            size_value = size_str.replaceAll(/[gG]$/, '')
        }

        def genome_bases = size_value.toFloat() * multiplier
        def coverage_val = meta.coverage.toString().replaceAll(/x$/, '').toInteger()
        def target = (genome_bases * coverage_val).toLong()
        target_bases = "--target_bases ${target}"
    }

    """
    filtlong \\
        $args \\
        $target_bases \\
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
