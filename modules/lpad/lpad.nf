process LPAD {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-lpad:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(dense_matrix_no_coords)

    output:
    tuple val(meta), path('lpad'), emit: results

    script:
    """
    bash /scripts/run_lpad.sh \\
        ${dense_matrix_no_coords} \\
        lpad
    """
}
