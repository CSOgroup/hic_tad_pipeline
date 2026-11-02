def res_label(resolution) {
    def bp = resolution as Long
    if (bp % 1_000_000 == 0) return "${bp.intdiv(1_000_000)}m"
    if (bp % 1000 == 0)      return "${bp.intdiv(1000)}k"
    return "${bp}b"
}

process CHOOSE_RESOLUTION {
    tag "$meta.id"
    container 'local/hic-prep-input:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro -v ${moduleDir}/../../common_scripts:/common_scripts:ro"

    input:
    tuple val(meta), path(input_file)
    val resolution
    val nproc
    val preserve_source

    output:
    tuple val(meta), path("${meta.id}.at_${res_label(resolution)}.cool"), emit: rebinned_cool

    script:
    """
    bash /scripts/choose_resolution.sh \\
        ${input_file.name} \\
        ${resolution} \\
        . \\
        ${meta.id}.at_${res_label(resolution)} \\
        ${nproc} \\
        ${preserve_source}
    """
}
