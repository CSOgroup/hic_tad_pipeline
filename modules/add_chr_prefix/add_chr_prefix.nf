process ADD_CHR_PREFIX {
    tag "$meta.id"
    container 'local/hic-prep-input:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro"

    input:
    tuple val(meta), path(input_cool)
    val preserve_source

    output:
    tuple val(meta), path("${meta.id}.chr_prefixed.cool"), emit: chr_prefixed_cool

    script:
    def stage_cmd = preserve_source.toString() == 'true'
        ? "cp ${input_cool.name} ${meta.id}.chr_prefixed.cool"
        : "ln -s \$(readlink -f ${input_cool.name}) ${meta.id}.chr_prefixed.cool"
    """
    ${stage_cmd}
    python3 /scripts/add_chr_prefix.py ${meta.id}.chr_prefixed.cool
    """
}
