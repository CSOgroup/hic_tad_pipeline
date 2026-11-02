process CONSENSUS_TADS {
    tag "$meta.id"
    container 'local/hic-tad-consensus_tads:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(clean_results)
    val threshold
    val step
    val workers

    output:
    tuple val(meta), path('consensus_tads'), emit: consensus

    script:
    """
    bash /scripts/run_consensus_tads.sh \\
        ${clean_results} \\
        consensus_tads \\
        ${threshold} \\
        ${step} \\
        ${workers}
    """
}
