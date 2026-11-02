process SPECTRALTAD {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-spectraltad:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(dense_matrix_no_coords)

    output:
    tuple val(meta), path('spectraltad'), emit: results

    script:
    """
    bash /scripts/run_spectraltad.sh \\
        ${dense_matrix_no_coords} \\
        spectraltad
    """
}
