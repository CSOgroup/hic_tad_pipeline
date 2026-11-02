process TOPDOM {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-topdom:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(dense_matrix_with_coords)

    output:
    tuple val(meta), path('topdom'), emit: results

    script:
    """
    bash /scripts/run_topdom.sh \\
        ${dense_matrix_with_coords} \\
        5 \\
        topdom
    """
}
