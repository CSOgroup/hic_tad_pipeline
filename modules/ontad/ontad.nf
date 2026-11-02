process ONTAD {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-ontad:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(dense_matrix_no_coords)

    output:
    tuple val(meta), path('ontad'), emit: results

    script:
    """
    bash /scripts/run_ontad.sh \\
        ${dense_matrix_no_coords} \\
        ontad
    """
}
