process ARROWHEAD {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-arrowhead:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(hic_file)
    val resolution
    val chroms
    val norm_type

    output:
    tuple val(meta), path('arrowhead'), emit: results

    script:
    def arrowhead_norm = (norm_type == 'KR') ? 'KR' : 'NONE'
    """
    bash /scripts/run_arrowhead.sh \\
        ${hic_file} \\
        ${resolution} \\
        arrowhead \\
        "${chroms}" \\
        ${arrowhead_norm}
    """
}
