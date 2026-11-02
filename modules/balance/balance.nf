process BALANCE {
    tag "$meta.id"
    container 'local/hic-prep-input:1.0'
    containerOptions "-v ${moduleDir}/scripts:/scripts:ro -v ${moduleDir}/../../common_scripts:/common_scripts:ro"

    input:
    tuple val(meta), path(input_file)
    val resolution
    val norm_type
    val nproc
    val preserve_source

    output:
    tuple val(meta), path("${meta.id}.balanced.cool"),
        optional: true,
        emit: balanced_cool

    tuple val(meta), path("${meta.id}.balanced.hic"),
        optional: true,
        emit: balanced_hic

    script:
    def ext         = input_file.name.tokenize('.').last().toLowerCase()
    def use_hic     = norm_type == 'KR' || (norm_type == 'NONE' && ext == 'hic')
    def norm_script = use_hic ? 'balance_through_hic.sh' : 'balance_through_cool.sh'

    """
    bash /scripts/${norm_script} \\
        ${input_file.name} \\
        ${resolution} \\
        . \\
        ${meta.id}.balanced \\
        ${norm_type} \\
        ${nproc} \\
        ${preserve_source}
    """
}
