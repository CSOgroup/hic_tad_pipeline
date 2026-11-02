process DEDOC {
    tag "$meta.id"
    label 'ignore_errors'
    container 'local/hic-tad-dedoc:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(dedoc_input, stageAs: 'dedoc_graphs')

    output:
    tuple val(meta), path('dedoc'), emit: results

    script:
    """
    bash /scripts/run_dedoc.sh \\
        ${dedoc_input} \\
        dedoc
    """
}
