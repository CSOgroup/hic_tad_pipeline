process CLEAN_RESULTS {
    tag "$meta.id"
    container 'local/hic-tad-clean_results:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(caller_dirs)
    val resolution
    val callers
    val chroms

    output:
    tuple val(meta), path('combined_tads.tsv'), emit: clean_results

    script:
    """
    bash /scripts/run_clean_results.sh \\
        . \\
        ${resolution} \\
        . \\
        '${callers}' \\
        '${chroms}'
    """
}
