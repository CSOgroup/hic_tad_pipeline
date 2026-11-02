process MSTD {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-mstd:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(dense_matrix_no_coords)

    output:
    tuple val(meta), path('mstd'), emit: results

    script:
    """
    bash /scripts/run_mstd.sh \\
        ${dense_matrix_no_coords} \\
        mstd
    """
}
