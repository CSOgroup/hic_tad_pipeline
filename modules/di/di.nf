process DI {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-di:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(dense_matrix_with_coords)
    val resolution

    output:
    tuple val(meta), path('di'), emit: results

    script:
    """
    bash /scripts/run_di.sh \\
        ${dense_matrix_with_coords} \\
        ${resolution} \\
        2000000 \\
        di
    """
}
